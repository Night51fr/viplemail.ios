import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Métriques d'Écran Adaptatives (Optimisation iPhone SE 375×667pt & Formats Compacts)

public enum VipleMailLayout {
    @MainActor
    public static var screenWidth: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width
        #else
        return 393
        #endif
    }

    @MainActor
    public static var screenHeight: CGFloat {
        #if canImport(UIKit)
        return UIScreen.main.bounds.height
        #else
        return 852
        #endif
    }

    /// Vrai sur iPhone SE (1re, 2e, 3e génération — 375pt), iPhone mini et mode Zoom d'affichage (320pt)
    @MainActor
    public static var isCompactPhone: Bool {
        screenWidth <= 385
    }

    /// Vrai sur les écrans de hauteur compacte type iPhone SE (667pt)
    @MainActor
    public static var isShortPhone: Bool {
        screenHeight <= 700
    }
}

// MARK: - Mode d'Apparence Utilisateur « Viple Mail » (Automatique iOS, Clair ou Sombre OLED)

public enum VipleMailAppearanceMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: return "Automatique"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    public var subtitle: String {
        switch self {
        case .system: return "Suit le réglage d'apparence d'iOS"
        case .light: return "Fond clair lumineux en permanence"
        case .dark: return "Mode sombre OLED optimisé"
        }
    }

    public var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.stars.fill"
        }
    }

    public var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Chargeur & Cache Persistant sur Disque des Logos Expéditeurs (BIMI, Gravatar, Marques & Viple Live ID)

@MainActor
public final class VipleMailAvatarImageCache {
    public static let shared = VipleMailAvatarImageCache()

    #if canImport(UIKit)
    private let cache = NSCache<NSString, UIImage>()
    private var negativeCacheExpiry: [String: Date] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]
    #endif
    private let session: URLSession
    private let delegate = VipleMailTLSSessionDelegate()
    private let diskDirectory: URL

    private static let positiveDiskTTL: TimeInterval = 14 * 86400 // 14 jours sur disque local iOS
    private static let negativeDiskTTL: TimeInterval = 24 * 3600  // 24h pour les expéditeurs sans logo

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: cfg, delegate: delegate, delegateQueue: nil)

        let cachesRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let dir = cachesRoot.appendingPathComponent("SenderLogos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.diskDirectory = dir

        #if canImport(UIKit)
        self.cache.countLimit = 400
        #endif
    }

    public static func resolvedAvatarURL(explicitUrl: String?, email: String) -> URL? {
        if let raw = explicitUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let fullRaw: String
            if raw.lowercased().hasPrefix("http://") || raw.lowercased().hasPrefix("https://") {
                fullRaw = raw
            } else if raw.hasPrefix("/") {
                fullRaw = "https://identity-v2.viple.digital\(raw)"
            } else {
                fullRaw = raw
            }
            if fullRaw.contains("/api/mobile/v1/mail/avatar") && !fullRaw.contains("d=") {
                let sep = fullRaw.contains("?") ? "&" : "?"
                return URL(string: "\(fullRaw)\(sep)d=404")
            }
            return URL(string: fullRaw)
        }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanEmail.isEmpty, cleanEmail.contains("@") else { return nil }
        let encoded = cleanEmail.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? cleanEmail
        return URL(string: "https://mail.viplemail.fr/api/mobile/v1/mail/avatar?email=\(encoded)&d=404")
    }

    private static func normalizedSenderKey(explicitUrl: String?, email: String) -> String {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanEmail.isEmpty {
            return "sender:\(cleanEmail)"
        }
        return "url:\((explicitUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    #if canImport(UIKit)
    public func cachedImage(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    public func cachedImageSynchronously(explicitUrl: String?, email: String) -> UIImage? {
        let logicalKey = Self.normalizedSenderKey(explicitUrl: explicitUrl, email: email)
        if let mem = cache.object(forKey: logicalKey as NSString) {
            return mem
        }
        if let negExp = negativeCacheExpiry[logicalKey], negExp > Date() {
            return nil
        }

        let hash = Self.sha256Hex(logicalKey)
        let pngURL = diskDirectory.appendingPathComponent("\(hash).png")
        let fm = FileManager.default
        if fm.fileExists(atPath: pngURL.path),
           let attrs = try? fm.attributesOfItem(atPath: pngURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < Self.positiveDiskTTL,
           let data = try? Data(contentsOf: pngURL),
           let img = UIImage(data: data) {
            cache.setObject(img, forKey: logicalKey as NSString)
            return img
        }
        return nil
    }

    public func loadImage(explicitUrl: String?, email: String) async -> UIImage? {
        guard let url = Self.resolvedAvatarURL(explicitUrl: explicitUrl, email: email) else {
            return nil
        }

        let logicalKey = Self.normalizedSenderKey(explicitUrl: explicitUrl, email: email)
        if let existing = cache.object(forKey: logicalKey as NSString) {
            return existing
        }
        if let negExp = negativeCacheExpiry[logicalKey], negExp > Date() {
            return nil
        }

        let hash = Self.sha256Hex(logicalKey)
        let pngURL = diskDirectory.appendingPathComponent("\(hash).png")
        let noneURL = diskDirectory.appendingPathComponent("\(hash).none")
        let fm = FileManager.default

        if fm.fileExists(atPath: pngURL.path),
           let attrs = try? fm.attributesOfItem(atPath: pngURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < Self.positiveDiskTTL,
           let diskData = try? Data(contentsOf: pngURL),
           let diskImg = UIImage(data: diskData) {
            cache.setObject(diskImg, forKey: logicalKey as NSString)
            return diskImg
        }

        if fm.fileExists(atPath: noneURL.path),
           let attrs = try? fm.attributesOfItem(atPath: noneURL.path),
           let modDate = attrs[.modificationDate] as? Date,
           Date().timeIntervalSince(modDate) < Self.negativeDiskTTL {
            negativeCacheExpiry[logicalKey] = modDate.addingTimeInterval(Self.negativeDiskTTL)
            return nil
        }

        if let running = inFlight[logicalKey] {
            return await running.value
        }

        let sessionRef = self.session
        let fetchTask = Task<UIImage?, Never> { [weak self] in
            do {
                var req = URLRequest(url: url)
                req.setValue("image/png,image/jpeg,image/*;q=0.8", forHTTPHeaderField: "Accept")
                let (data, response) = try await sessionRef.data(for: req)
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode),
                       data.count > 80,
                       let img = UIImage(data: data) {
                        if let normalizedPng = img.pngData() {
                            try? normalizedPng.write(to: pngURL, options: .atomic)
                        } else {
                            try? data.write(to: pngURL, options: .atomic)
                        }
                        try? FileManager.default.removeItem(at: noneURL)
                        self?.cache.setObject(img, forKey: logicalKey as NSString)
                        return img
                    } else if http.statusCode == 404 || http.statusCode == 204 {
                        try? Data("0".utf8).write(to: noneURL, options: .atomic)
                        self?.negativeCacheExpiry[logicalKey] = Date().addingTimeInterval(Self.negativeDiskTTL)
                        return nil
                    }
                }
            } catch { }
            return nil
        }

        inFlight[logicalKey] = fetchTask
        let result = await fetchTask.value
        inFlight.removeValue(forKey: logicalKey)
        return result
    }
    #endif
}

// MARK: - Design System & Palette Dynamique Clair / Sombre OLED « Viple Mail » (iOS 18+ / 2026)

public enum VipleMailPalette {
    private static func dynamicColor(
        light: (CGFloat, CGFloat, CGFloat, CGFloat),
        dark: (CGFloat, CGFloat, CGFloat, CGFloat)
    ) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
        #else
        return Color(red: Double(light.0), green: Double(light.1), blue: Double(light.2)).opacity(Double(light.3))
        #endif
    }

    // Couleurs identitaires & accents calibrés Clair / Sombre (compatibles Studio Chromatique #032)
    public static let cobaltDeep = Color(red: 0.02, green: 0.14, blue: 0.42)
    public static let primarySolid = Color(red: 0.00, green: 0.47, blue: 0.83) // #0078D4 pour fonds pleins
    private static let defaultPrimary = dynamicColor(
        light: (0.000, 0.471, 0.831, 1.0), // #0078D4 Viple Live Blue
        dark:  (0.165, 0.565, 1.000, 1.0)  // #2A90FF Luminous Azure (contraste élevé sur ardoise OLED)
    )
    public static var primary: Color {
        if let rawTheme = UserDefaults.standard.string(forKey: "viple.mail.beta.fastChromaticTheme.v1"),
           let theme = BetaChromaticTheme(rawValue: rawTheme) {
            return theme.primaryColor
        }
        return defaultPrimary
    }
    public static let azureGlow = dynamicColor(
        light: (0.160, 0.780, 0.980, 1.0), // #28C7FA
        dark:  (0.260, 0.820, 1.000, 1.0)  // #42D1FF
    )
    public static let indigo = dynamicColor(
        light: (0.310, 0.270, 0.900, 1.0),
        dark:  (0.510, 0.549, 0.973, 1.0)
    )
    public static let vipGold = dynamicColor(
        light: (0.945, 0.590, 0.035, 1.0),
        dark:  (0.984, 0.749, 0.141, 1.0)
    )
    public static let starYellow = dynamicColor(
        light: (0.910, 0.680, 0.030, 1.0),
        dark:  (0.980, 0.800, 0.082, 1.0)
    )
    public static let success = dynamicColor(
        light: (0.059, 0.690, 0.480, 1.0),
        dark:  (0.204, 0.827, 0.600, 1.0)
    )
    public static let warning = dynamicColor(
        light: (0.960, 0.450, 0.086, 1.0),
        dark:  (0.984, 0.573, 0.235, 1.0)
    )
    public static let danger = dynamicColor(
        light: (0.910, 0.235, 0.235, 1.0),
        dark:  (0.973, 0.443, 0.443, 1.0)
    )

    // Surfaces & hiérarchie de profondeur Clair / Sombre OLED (compatible Noir Pur OLED #039)
    private static let defaultBackground = dynamicColor(
        light: (0.949, 0.969, 1.000, 1.0), // #F2F7FF
        dark:  (0.027, 0.043, 0.078, 1.0)  // #070B14 Noir saphir OLED profond
    )
    private static let pureOledBackground = dynamicColor(
        light: (0.949, 0.969, 1.000, 1.0),
        dark:  (0.000, 0.000, 0.000, 1.0)  // #000000 Noir Pur OLED 0 nit
    )
    public static var background: Color {
        UserDefaults.standard.bool(forKey: "viple.mail.beta.fastOledPureBlack.v1")
            ? pureOledBackground
            : defaultBackground
    }
    public static let surface = dynamicColor(
        light: (1.000, 1.000, 1.000, 1.0), // #FFFFFF
        dark:  (0.063, 0.090, 0.149, 1.0)  // #101726 Carte ardoise nuit
    )
    public static let surfaceElevated = dynamicColor(
        light: (1.000, 1.000, 1.000, 1.0), // #FFFFFF
        dark:  (0.090, 0.129, 0.208, 1.0)  // #172135 Carte surélevée / courrier non lu / segment actif
    )
    public static let surfaceSubtle = dynamicColor(
        light: (0.922, 0.949, 0.992, 1.0), // #EBF2FD
        dark:  (0.098, 0.137, 0.220, 1.0)  // #192338 Champs de saisie, puces & blocs secondaires
    )
    public static let toastSurface = dynamicColor(
        light: (0.035, 0.125, 0.340, 0.96),
        dark:  (0.110, 0.165, 0.275, 0.98)
    )
    public static let border = dynamicColor(
        light: (0.839, 0.890, 0.961, 1.0),  // #D6E3F5
        dark:  (0.580, 0.702, 0.890, 0.17)  // Liseré verre lumineux subtil en mode sombre
    )
    public static let borderStrong = dynamicColor(
        light: (0.682, 0.769, 0.890, 1.0),  // #AEC4E3 Bordure contrastée (pastilles PIN, contours actifs)
        dark:  (0.580, 0.702, 0.890, 0.36)  // Liseré verre renforcé en mode sombre OLED
    )

    // Typographie haute lisibilité WCAG AAA
    public static let ink = dynamicColor(
        light: (0.051, 0.102, 0.220, 1.0), // #0D1A38
        dark:  (0.945, 0.965, 0.992, 1.0)  // #F1F6FD Blanc doux sans halo OLED
    )
    public static let inkSecondary = dynamicColor(
        light: (0.278, 0.361, 0.478, 1.0), // #475C7A
        dark:  (0.667, 0.729, 0.820, 1.0)  // #AABAd1
    )
    public static let inkMuted = dynamicColor(
        light: (0.455, 0.537, 0.651, 1.0), // #7489A6
        dark:  (0.494, 0.569, 0.682, 1.0)  // #7E91AE
    )

    // Couleurs concrètes (non-dynamiques) résolues directement via SwiftUI ColorScheme
    // pour garantir un contraste maximal dans 100 % des champs de saisie (TextField, SecureField, UITextView)
    // sans jamais dépendre de l'héritage implicite UITraitCollection sous iOS 18-27+.
    public static let lightInkSolid = Color(red: 0.051, green: 0.102, blue: 0.220)           // #0D1A38
    public static let darkInkSolid = Color(red: 0.945, green: 0.965, blue: 0.992)            // #F1F6FD
    public static let lightMutedSolid = Color(red: 0.455, green: 0.537, blue: 0.651)         // #7489A6
    public static let darkMutedSolid = Color(red: 0.545, green: 0.624, blue: 0.741)          // #8B9FBD
    public static let lightSurfaceSolid = Color(red: 1.000, green: 1.000, blue: 1.000)       // #FFFFFF
    public static let darkSurfaceSolid = Color(red: 0.063, green: 0.090, blue: 0.149)        // #101726
    public static let lightSurfaceSubtleSolid = Color(red: 0.922, green: 0.949, blue: 0.992) // #EBF2FD
    public static let darkSurfaceSubtleSolid = Color(red: 0.098, green: 0.137, blue: 0.220)  // #192338
    public static let darkPrimarySolid = Color(red: 0.165, green: 0.565, blue: 1.000)        // #2A90FF

    public static func resolvedInk(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkInkSolid : lightInkSolid
    }

    public static func resolvedMuted(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkMutedSolid : lightMutedSolid
    }

    public static func resolvedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurfaceSolid : lightSurfaceSolid
    }

    public static func resolvedSurfaceSubtle(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkSurfaceSubtleSolid : lightSurfaceSubtleSolid
    }

    public static func resolvedCursorTint(for scheme: ColorScheme) -> Color {
        scheme == .dark ? darkPrimarySolid : primarySolid
    }

    public static func prompt(_ placeholder: String) -> Text {
        Text(placeholder).foregroundStyle(inkMuted)
    }

    public static func prompt(_ placeholder: String, scheme: ColorScheme) -> Text {
        Text(placeholder).foregroundStyle(resolvedMuted(for: scheme))
    }

    public static let heroGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.16, blue: 0.48),
            Color(red: 0.00, green: 0.45, blue: 0.86),
            Color(red: 0.12, green: 0.70, blue: 0.96)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static func authBackdropGradient(for scheme: ColorScheme) -> LinearGradient {
        if scheme == .dark {
            return LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.07, blue: 0.18),
                    Color(red: 0.03, green: 0.13, blue: 0.30),
                    background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                cobaltDeep,
                Color(red: 0.00, green: 0.32, blue: 0.72),
                background
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    public static func avatarGradient(for seed: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [Color(red: 0.00, green: 0.47, blue: 0.83), Color(red: 0.16, green: 0.78, blue: 0.98)],
            [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.55, green: 0.36, blue: 0.96)],
            [Color(red: 0.05, green: 0.65, blue: 0.55), Color(red: 0.20, green: 0.83, blue: 0.60)],
            [Color(red: 0.88, green: 0.29, blue: 0.45), Color(red: 0.98, green: 0.45, blue: 0.25)],
            [Color(red: 0.85, green: 0.52, blue: 0.04), Color(red: 0.96, green: 0.72, blue: 0.15)],
            [Color(red: 0.12, green: 0.32, blue: 0.72), Color(red: 0.24, green: 0.56, blue: 0.95)]
        ]
        let hash = abs(seed.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) })
        let pair = palettes[hash % palettes.count]
        return LinearGradient(colors: pair, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    public static func colorFromHex(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 120, 212)
        }
        let rf = CGFloat(r) / 255.0
        let gf = CGFloat(g) / 255.0
        let bf = CGFloat(b) / 255.0

        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            let lightColor = UIColor(red: rf, green: gf, blue: bf, alpha: 1.0)
            guard traits.userInterfaceStyle == .dark else { return lightColor }

            // Luminance relative : éclaircit automatiquement les teintes sombres (ex: #475569, #003D8F, #0050D7) sur fond OLED
            let luminance = 0.2126 * rf + 0.7152 * gf + 0.0722 * bf
            if luminance < 0.34 {
                var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
                if lightColor.getHue(&h, saturation: &s, brightness: &br, alpha: &a) {
                    let boostedBrightness = max(br, 0.82)
                    let balancedSaturation = s > 0.12 ? min(max(s * 0.85, 0.45), 0.78) : s
                    return UIColor(hue: h, saturation: balancedSaturation, brightness: boostedBrightness, alpha: a)
                }
            }
            return lightColor
        })
        #else
        return Color(red: Double(rf), green: Double(gf), blue: Double(bf))
        #endif
    }
}

// MARK: - Modificateur de Carte Adaptative Clair / Sombre « Viple Mail »

public struct VipleMailCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var cornerRadius: CGFloat
    public var padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VipleMailPalette.surface)
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.36)
                            : VipleMailPalette.cobaltDeep.opacity(0.06),
                        radius: colorScheme == .dark ? 12 : 14,
                        x: 0,
                        y: colorScheme == .dark ? 6 : 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(VipleMailPalette.border, lineWidth: 1)
            )
    }
}

extension View {
    public func vipleMailCard(cornerRadius: CGFloat = 20, padding: CGFloat = 16) -> some View {
        modifier(VipleMailCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    public func vipleMailTextInput() -> some View {
        modifier(VipleMailTextInputModifier())
    }
}

// MARK: - Modificateur & Éditeur Multiligne Haute Lisibilité (Zéro Texte Blanc sur Blanc Clair/Sombre iOS 18-27+)

public struct VipleMailTextInputModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(VipleMailPalette.resolvedInk(for: colorScheme))
            .tint(VipleMailPalette.resolvedCursorTint(for: colorScheme))
            .environment(\.colorScheme, colorScheme)
    }
}

public struct VipleMailMultiLineEditor: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding public var text: String
    public var placeholder: String
    public var fontSize: CGFloat
    public var minHeight: CGFloat
    public var horizontalInset: CGFloat
    public var verticalInset: CGFloat
    public var isFocused: Binding<Bool>?

    public init(
        text: Binding<String>,
        placeholder: String = "",
        fontSize: CGFloat = 16,
        minHeight: CGFloat = 120,
        horizontalInset: CGFloat = 16,
        verticalInset: CGFloat = 12,
        isFocused: Binding<Bool>? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.fontSize = fontSize
        self.minHeight = minHeight
        self.horizontalInset = horizontalInset
        self.verticalInset = verticalInset
        self.isFocused = isFocused
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: fontSize))
                    .foregroundStyle(VipleMailPalette.resolvedMuted(for: colorScheme))
                    .padding(.horizontal, horizontalInset)
                    .padding(.vertical, verticalInset)
                    .allowsHitTesting(false)
            }

            #if canImport(UIKit)
            _VipleMailUITextViewRepresentable(
                text: $text,
                isDark: colorScheme == .dark,
                fontSize: fontSize,
                minHeight: minHeight,
                horizontalInset: horizontalInset,
                verticalInset: verticalInset,
                isFocused: isFocused
            )
            .frame(minHeight: minHeight)
            #else
            TextEditor(text: $text)
                .font(.system(size: fontSize))
                .vipleMailTextInput()
                .frame(minHeight: minHeight)
            #endif
        }
    }
}

#if canImport(UIKit)
private struct _VipleMailUITextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    let isDark: Bool
    let fontSize: CGFloat
    let minHeight: CGFloat
    let horizontalInset: CGFloat
    let verticalInset: CGFloat
    let isFocused: Binding<Bool>?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.isOpaque = false
        tv.textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
        tv.textContainer.lineFragmentPadding = 0
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.text = text
        applyStyle(to: tv)
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            context.coordinator.isUpdatingFromSwiftUI = true
            uiView.text = text
            context.coordinator.isUpdatingFromSwiftUI = false
        }
        applyStyle(to: uiView)

        if let focusBinding = isFocused, focusBinding.wrappedValue, !uiView.isFirstResponder, uiView.window != nil {
            Task { @MainActor [weak uiView] in
                guard let uiView, uiView.window != nil, !uiView.isFirstResponder else { return }
                uiView.becomeFirstResponder()
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? max(220, uiView.window?.bounds.width ?? 340)
        let fitting = uiView.sizeThatFits(CGSize(width: max(80, targetWidth), height: .greatestFiniteMagnitude))
        return CGSize(width: targetWidth, height: max(minHeight, ceil(fitting.height)))
    }

    func applyStyle(to tv: UITextView) {
        let uiFont = UIFont.systemFont(ofSize: fontSize)
        let fgColor = isDark
            ? UIColor(red: 0.945, green: 0.965, blue: 0.992, alpha: 1.0) // #F1F6FD sur fond sombre OLED
            : UIColor(red: 0.051, green: 0.102, blue: 0.220, alpha: 1.0) // #0D1A38 sur fond clair
        let caretColor = isDark
            ? UIColor(red: 0.165, green: 0.565, blue: 1.000, alpha: 1.0) // #2A90FF
            : UIColor(red: 0.000, green: 0.471, blue: 0.831, alpha: 1.0) // #0078D4

        tv.overrideUserInterfaceStyle = isDark ? .dark : .light
        tv.keyboardAppearance = isDark ? .dark : .light
        tv.backgroundColor = .clear
        tv.isOpaque = false
        tv.font = uiFont
        tv.textColor = fgColor
        tv.tintColor = caretColor
        tv.typingAttributes = [
            .font: uiFont,
            .foregroundColor: fgColor
        ]
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: _VipleMailUITextViewRepresentable
        var isUpdatingFromSwiftUI = false

        init(_ parent: _VipleMailUITextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.applyStyle(to: textView)
            if parent.isFocused?.wrappedValue == false {
                parent.isFocused?.wrappedValue = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused?.wrappedValue == true {
                parent.isFocused?.wrappedValue = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isUpdatingFromSwiftUI else { return }
            parent.applyStyle(to: textView)
            let updated = textView.text ?? ""
            if parent.text != updated {
                parent.text = updated
            }
            textView.invalidateIntrinsicContentSize()
        }
    }
}
#endif

// MARK: - Logo Horizontal « Viple Mail » (Signature Visuelle Haut-Gauche Adaptative)

public struct VipleMailHorizontalLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    public var height: CGFloat = 36
    public var lightModeOnDarkBackground: Bool = false
    public var showSubtitle: Bool = true

    public init(
        height: CGFloat = 36,
        lightModeOnDarkBackground: Bool = false,
        showSubtitle: Bool = true
    ) {
        self.height = height
        self.lightModeOnDarkBackground = lightModeOnDarkBackground
        self.showSubtitle = showSubtitle
    }

    private var effectiveHeight: CGFloat {
        VipleMailLayout.isCompactPhone ? min(height, 30) : height
    }

    public var body: some View {
        let h = effectiveHeight
        HStack(spacing: VipleMailLayout.isCompactPhone ? 7 : 10) {
            ZStack {
                RoundedRectangle(cornerRadius: h * 0.26, style: .continuous)
                    .fill(VipleMailPalette.heroGradient)
                    .frame(width: h, height: h)
                    .shadow(
                        color: VipleMailPalette.primarySolid.opacity(colorScheme == .dark ? 0.45 : 0.32),
                        radius: 6,
                        x: 0,
                        y: 3
                    )

                Image(systemName: "envelope.open.fill")
                    .font(.system(size: h * 0.46, weight: .bold))
                    .foregroundStyle(.white)

                Text("V")
                    .font(.system(size: h * 0.24, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.cobaltDeep)
                    .offset(y: -h * 0.04)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 3.5) {
                    Text("Viple")
                        .font(.system(size: h * 0.56, weight: .black, design: .rounded))
                        .foregroundStyle(lightModeOnDarkBackground ? Color.white : VipleMailPalette.ink)
                    Text("Mail")
                        .font(.system(size: h * 0.56, weight: .semibold, design: .rounded))
                        .foregroundStyle((lightModeOnDarkBackground || colorScheme == .dark) ? VipleMailPalette.azureGlow : VipleMailPalette.primary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: true, vertical: false)

                if showSubtitle {
                    Text("Un service Viple Live")
                        .font(.system(size: max(8.5, h * 0.24), weight: .bold, design: .rounded))
                        .tracking(VipleMailLayout.isCompactPhone ? 0.1 : 0.3)
                        .foregroundStyle(lightModeOnDarkBackground ? Color.white.opacity(0.82) : VipleMailPalette.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.80)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .layoutPriority(2)
    }
}

// MARK: - Avatar Expéditeur / Contact Synchronisé Viple Live ID avec Badge VIP

public struct VipleMailAvatarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var beta = VipleBetaStore.shared
    public let name: String
    public let email: String
    public var avatarUrl: String? = nil
    public var size: CGFloat = 44
    public var isVip: Bool = false
    public var isUnread: Bool = false

    #if canImport(UIKit)
    @State private var loadedImage: UIImage? = nil
    #endif
    @State private var livingHaloSpin: Bool = false

    public init(
        name: String,
        email: String,
        avatarUrl: String? = nil,
        size: CGFloat = 44,
        isVip: Bool = false,
        isUnread: Bool = false
    ) {
        self.name = name
        self.email = email
        self.avatarUrl = avatarUrl
        self.size = size
        self.isVip = isVip
        self.isUnread = isUnread
    }

    private var initials: String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let src = clean.isEmpty ? email : clean
        let parts = src.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(src.prefix(2)).uppercased()
    }

    private var isSovereignVipleDomain: Bool {
        let low = email.lowercased()
        return low.hasSuffix("@viplemail.fr") || low.hasSuffix("@cenelis.com")
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if beta.isEnabled(.f038) && (isSovereignVipleDomain || isVip || isUnread) {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: isVip
                                    ? [VipleMailPalette.vipGold, .yellow, .orange, VipleMailPalette.vipGold]
                                    : [VipleMailPalette.primary, .cyan, VipleMailPalette.indigo, VipleMailPalette.primary],
                                center: .center
                            ),
                            lineWidth: max(2.0, size * 0.055)
                        )
                        .frame(width: size + 5, height: size + 5)
                        .rotationEffect(.degrees(livingHaloSpin ? 360 : 0))
                        .onAppear {
                            guard !livingHaloSpin else { return }
                            withAnimation(.linear(duration: 6.5).repeatForever(autoreverses: false)) {
                                livingHaloSpin = true
                            }
                        }
                }

                Circle()
                    .fill(VipleMailPalette.avatarGradient(for: email.isEmpty ? name : email))
                    .frame(width: size, height: size)

                Text(initials)
                    .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                #if canImport(UIKit)
                if let img = loadedImage ?? VipleMailAvatarImageCache.shared.cachedImageSynchronously(explicitUrl: avatarUrl, email: email) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .transition(.opacity)
                }
                #endif
            }
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(
                        isVip
                            ? VipleMailPalette.vipGold
                            : Color.white.opacity(colorScheme == .dark ? 0.16 : 0.45),
                        lineWidth: isVip ? 2 : 1
                    )
            )
            .task(id: "\(email.lowercased())|\(avatarUrl ?? "")") {
                #if canImport(UIKit)
                if let img = await VipleMailAvatarImageCache.shared.loadImage(explicitUrl: avatarUrl, email: email) {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        self.loadedImage = img
                    }
                }
                #endif
            }

            if isVip {
                ZStack {
                    Circle()
                        .fill(VipleMailPalette.vipGold)
                        .frame(width: size * 0.38, height: size * 0.38)
                        .overlay(Circle().stroke(VipleMailPalette.surface, lineWidth: 1.5))
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 2, y: 2)
            } else if isUnread {
                Circle()
                    .fill(VipleMailPalette.primary)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(VipleMailPalette.surface, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
    }
}
