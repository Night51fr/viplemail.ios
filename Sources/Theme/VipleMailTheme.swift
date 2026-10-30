import SwiftUI

// MARK: - Design System & Palette « Viple Mail » (iOS 18+ / 2026 • Identité Viple Live ID)

public enum VipleMailPalette {
    public static let cobaltDeep = Color(red: 0.02, green: 0.14, blue: 0.42)
    public static let primary = Color(red: 0.00, green: 0.47, blue: 0.83)       // #0078D4 Viple Live Blue
    public static let azureGlow = Color(red: 0.16, green: 0.78, blue: 0.98)     // #28C7FA Viple Cyan
    public static let indigo = Color(red: 0.31, green: 0.27, blue: 0.90)
    public static let vipGold = Color(red: 0.96, green: 0.62, blue: 0.04)
    public static let starYellow = Color(red: 0.92, green: 0.70, blue: 0.03)
    public static let success = Color(red: 0.06, green: 0.73, blue: 0.51)
    public static let warning = Color(red: 0.98, green: 0.45, blue: 0.09)
    public static let danger = Color(red: 0.94, green: 0.27, blue: 0.27)

    public static let background = Color(red: 0.95, green: 0.97, blue: 1.00)
    public static let surface = Color.white
    public static let surfaceSubtle = Color(red: 0.92, green: 0.95, blue: 0.99)
    public static let border = Color(red: 0.84, green: 0.89, blue: 0.96)
    public static let ink = Color(red: 0.05, green: 0.10, blue: 0.22)
    public static let inkSecondary = Color(red: 0.28, green: 0.36, blue: 0.48)
    public static let inkMuted = Color(red: 0.46, green: 0.54, blue: 0.65)

    public static let heroGradient = LinearGradient(
        colors: [cobaltDeep, primary, azureGlow],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
        return Color(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0)
    }
}

// MARK: - Modificateur de Carte Glassmorphic Viple Mail

public struct VipleMailCardModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var padding: CGFloat

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(VipleMailPalette.surface)
                    .shadow(color: VipleMailPalette.cobaltDeep.opacity(0.06), radius: 14, x: 0, y: 5)
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
}

// MARK: - Logo Horizontal « Viple Mail » (Signature Visuelle Haut-Gauche)

public struct VipleMailHorizontalLogoView: View {
    public var height: CGFloat = 36
    public var lightModeOnDarkBackground: Bool = false

    public init(height: CGFloat = 36, lightModeOnDarkBackground: Bool = false) {
        self.height = height
        self.lightModeOnDarkBackground = lightModeOnDarkBackground
    }

    public var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: height * 0.26, style: .continuous)
                    .fill(VipleMailPalette.heroGradient)
                    .frame(width: height, height: height)
                    .shadow(color: VipleMailPalette.primary.opacity(0.35), radius: 6, x: 0, y: 3)

                Image(systemName: "envelope.open.fill")
                    .font(.system(size: height * 0.46, weight: .bold))
                    .foregroundStyle(.white)

                Text("V")
                    .font(.system(size: height * 0.24, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.cobaltDeep)
                    .offset(y: -height * 0.04)
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    Text("Viple")
                        .font(.system(size: height * 0.56, weight: .black, design: .rounded))
                        .foregroundStyle(lightModeOnDarkBackground ? Color.white : VipleMailPalette.ink)
                    Text("Mail")
                        .font(.system(size: height * 0.56, weight: .semibold, design: .rounded))
                        .foregroundStyle(lightModeOnDarkBackground ? VipleMailPalette.azureGlow : VipleMailPalette.primary)
                }
                Text("VIPLE LIVE ID • @VIPLEMAIL.FR")
                    .font(.system(size: max(8.5, height * 0.21), weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(lightModeOnDarkBackground ? Color.white.opacity(0.78) : VipleMailPalette.inkMuted)
            }
        }
    }
}

// MARK: - Avatar Expéditeur / Contact avec Badge VIP

public struct VipleMailAvatarView: View {
    public let name: String
    public let email: String
    public var size: CGFloat = 44
    public var isVip: Bool = false
    public var isUnread: Bool = false

    public init(name: String, email: String, size: CGFloat = 44, isVip: Bool = false, isUnread: Bool = false) {
        self.name = name
        self.email = email
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

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(VipleMailPalette.avatarGradient(for: email.isEmpty ? name : email))
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(
                    Circle()
                        .stroke(isVip ? VipleMailPalette.vipGold : Color.white.opacity(0.45), lineWidth: isVip ? 2 : 1)
                )

            if isVip {
                ZStack {
                    Circle()
                        .fill(VipleMailPalette.vipGold)
                        .frame(width: size * 0.38, height: size * 0.38)
                    Image(systemName: "crown.fill")
                        .font(.system(size: size * 0.20, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 2, y: 2)
            } else if isUnread {
                Circle()
                    .fill(VipleMailPalette.primary)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 1, y: 1)
            }
        }
    }
}
