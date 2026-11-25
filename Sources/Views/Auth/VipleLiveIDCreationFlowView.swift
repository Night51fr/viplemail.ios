import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Studio Interactif Étape par Étape « Création Viple Live ID » (Motion Design 60/120 Hz, Passeport Holographique & Vérification Temps Réel)

@MainActor
public struct VipleLiveIDCreationFlowView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public enum Step: Int, CaseIterable, Identifiable {
        case identity = 0
        case mailboxHandle = 1
        case securityKey = 2
        case ecosystemActivation = 3

        public var id: Int { rawValue }

        public var stepNumber: Int { rawValue + 1 }

        public var shortTitle: String {
            switch self {
            case .identity: return "Identité"
            case .mailboxHandle: return "Adresse"
            case .securityKey: return "Sécurité"
            case .ecosystemActivation: return "Activation"
            }
        }

        public var headline: String {
            switch self {
            case .identity: return "Qui êtes-vous ?"
            case .mailboxHandle: return "Choisissez votre adresse @viplemail.fr"
            case .securityKey: return "Protégez votre Viple Live ID"
            case .ecosystemActivation: return "Votre passeport souverain est prêt"
            }
        }

        public var subtitle: String {
            switch self {
            case .identity:
                return "Votre identité Viple Live ID vous accompagne sur Viple Mail, Livria, Cenelis Academy et Looby."
            case .mailboxHandle:
                return "Une boîte officielle chiffrée de 5 Go vérifiée en direct sur mail.viplemail.fr."
            case .securityKey:
                return "Sécurisée par TLS 1.3 et le conteneur post-quantique hybride Cenelis MailRTE."
            case .ecosystemActivation:
                return "Vérifiez votre carte Viple Live ID et activez instantanément votre messagerie et votre écosystème."
            }
        }

        public var symbolName: String {
            switch self {
            case .identity: return "person.crop.rectangle.stack.fill"
            case .mailboxHandle: return "at.badge.plus"
            case .securityKey: return "lock.shield.fill"
            case .ecosystemActivation: return "sparkles"
            }
        }
    }

    private enum HandleCheckState: Equatable {
        case idle
        case checking
        case available(email: String, suggestions: [String])
        case unavailable(reason: String, suggestions: [String])
    }

    @Namespace private var stepNamespace

    @State private var currentStep: Step = .identity
    @State private var navigationDirectionForward: Bool = true
    @State private var flowStartDate: Date = Date()

    // Étape 1 — Identité
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    @State private var displayNameEditedManually: Bool = false

    // Étape 2 — Identifiant @viplemail.fr
    @State private var desiredHandle: String = ""
    @State private var handleEditedManually: Bool = false
    @State private var handleCheckState: HandleCheckState = .idle
    @State private var handleCheckTask: Task<Void, Never>? = nil

    // Étape 3 — Sécurité
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPasswordPlain: Bool = false

    // Étape 4 — Consentement & Séquence d'activation cinématique
    @State private var acceptedTermsAndPrivacy: Bool = false
    @State private var stepErrorMessage: String? = nil
    @State private var isRunningActivationSequence: Bool = false
    @State private var activationPhaseIndex: Int = 0

    private let ecosystemPreviewApps: [CenelisEcosystemApp] = [
        .vipleMail, .livriaStore, .livriaSocial, .cenelisAcademy, .looby, .vipleEtMoi
    ]

    public init() {}

    private var sanitizedHandle: String {
        Self.normalizeHandle(desiredHandle)
    }

    private var previewEmail: String {
        let h = sanitizedHandle
        return h.isEmpty ? "votre.nom@viplemail.fr" : "\(h)@viplemail.fr"
    }

    private var previewDisplayName: String {
        let manual = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !manual.isEmpty { return manual }
        let combined = "\(firstName.trimmingCharacters(in: .whitespacesAndNewlines)) \(lastName.trimmingCharacters(in: .whitespacesAndNewlines))"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return combined.isEmpty ? "Votre Identité Viple" : combined
    }

    private var previewInitials: String {
        let clean = previewDisplayName
        if clean == "Votre Identité Viple" { return "VL" }
        let parts = clean.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(clean.prefix(2)).uppercased()
    }

    private var passwordStrengthScore: Int {
        var s = 0
        if password.count >= 6 { s += 1 }
        if password.count >= 10 { s += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil && password.rangeOfCharacter(from: .decimalDigits) != nil {
            s += 1
        }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()-_=+[]{};:,.<>/?~")) != nil {
            s += 1
        }
        return min(4, s)
    }

    private var passwordStrengthLabel: (text: String, color: Color) {
        switch passwordStrengthScore {
        case 0: return ("À définir", Color.white.opacity(0.55))
        case 1: return ("Standard", Color.orange)
        case 2: return ("Robuste", Color(red: 0.22, green: 0.78, blue: 0.98))
        case 3: return ("Très élevé", Color(red: 0.16, green: 0.86, blue: 0.62))
        default: return ("Souverain Maximum", Color(red: 0.12, green: 0.92, blue: 0.66))
        }
    }

    public var body: some View {
        ZStack {
            // 1. Fond Motion Design Aurora & Orbites Cosmiques Cenelis × Viple
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : (1.0 / 60.0))) { timeline in
                let elapsed = timeline.date.timeIntervalSince(flowStartDate)
                liveAuroraBackdrop(elapsed: elapsed)
            }
            .ignoresSafeArea()

            if isRunningActivationSequence {
                activationCinemaOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(50)
            } else {
                VStack(spacing: 0) {
                    topNavigationHeader
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 13 : 18)
                        .padding(.top, 8)
                        .padding(.bottom, 6)

                    stepProgressRail
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 13 : 18)
                        .padding(.bottom, 10)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: VipleMailLayout.isCompactPhone ? 14 : 18) {
                            // 2. Carte Passeport Holographique Interactive en Direct
                            TimelineView(.animation(minimumInterval: reduceMotion ? 0.3 : (1.0 / 60.0))) { timeline in
                                let elapsed = timeline.date.timeIntervalSince(flowStartDate)
                                liveHolographicPassportCard(elapsed: elapsed)
                            }

                            // 3. Contenu Étape par Étape avec Transition Cinétique Directionnelle
                            stepContentContainer
                                .id(currentStep)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: navigationDirectionForward ? .trailing : .leading)
                                            .combined(with: .opacity),
                                        removal: .move(edge: navigationDirectionForward ? .leading : .trailing)
                                            .combined(with: .opacity)
                                    )
                                )

                            legalQuickFooter
                                .padding(.top, 4)
                                .padding(.bottom, 20)
                        }
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 13 : 18)
                        .padding(.top, 4)
                    }

                    bottomActionBar
                }
            }
        }
        .onChange(of: vm.isAuthenticated) { _, isAuth in
            if isAuth {
                dismiss()
            }
        }
    }

    // MARK: - Fond Motion Design Aurora 60fps

    private func liveAuroraBackdrop(elapsed: Double) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let baseGrad = Gradient(colors: [
                Color(red: 0.02, green: 0.05, blue: 0.14),
                Color(red: 0.03, green: 0.11, blue: 0.27),
                Color(red: 0.04, green: 0.08, blue: 0.20)
            ])
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(baseGrad, startPoint: .zero, endPoint: CGPoint(x: w, y: h))
            )

            let stepHueShift = Double(currentStep.rawValue) * 0.65
            let t = reduceMotion ? 0.0 : elapsed

            let orb1Center = CGPoint(
                x: w * (0.22 + 0.16 * sin(t * 0.55 + stepHueShift)),
                y: h * (0.18 + 0.08 * cos(t * 0.42))
            )
            let orb2Center = CGPoint(
                x: w * (0.82 + 0.14 * cos(t * 0.48 + stepHueShift)),
                y: h * (0.36 + 0.10 * sin(t * 0.37))
            )
            let orb3Center = CGPoint(
                x: w * (0.48 + 0.18 * sin(t * 0.31)),
                y: h * (0.82 + 0.07 * cos(t * 0.51 + stepHueShift))
            )

            let orb1Radius = max(w, h) * 0.48
            context.fill(
                Path(ellipseIn: CGRect(x: orb1Center.x - orb1Radius, y: orb1Center.y - orb1Radius, width: orb1Radius * 2, height: orb1Radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color(red: 0.06, green: 0.52, blue: 0.98).opacity(0.34), .clear]),
                    center: orb1Center,
                    startRadius: 4,
                    endRadius: orb1Radius
                )
            )

            let orb2Radius = max(w, h) * 0.44
            context.fill(
                Path(ellipseIn: CGRect(x: orb2Center.x - orb2Radius, y: orb2Center.y - orb2Radius, width: orb2Radius * 2, height: orb2Radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color(red: 0.38, green: 0.28, blue: 0.96).opacity(0.28), .clear]),
                    center: orb2Center,
                    startRadius: 4,
                    endRadius: orb2Radius
                )
            )

            let orb3Radius = max(w, h) * 0.42
            context.fill(
                Path(ellipseIn: CGRect(x: orb3Center.x - orb3Radius, y: orb3Center.y - orb3Radius, width: orb3Radius * 2, height: orb3Radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [Color(red: 0.08, green: 0.78, blue: 0.74).opacity(0.20), .clear]),
                    center: orb3Center,
                    startRadius: 4,
                    endRadius: orb3Radius
                )
            )

            // Anneaux orbitaux architecturaux subtils
            let ringCenter = CGPoint(x: w * 0.5, y: h * 0.24)
            for idx in 0..<3 {
                let r = CGFloat(115 + idx * 54)
                let rect = CGRect(x: ringCenter.x - r, y: ringCenter.y - r * 0.58, width: r * 2, height: r * 1.16)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.055 - Double(idx) * 0.012)),
                    lineWidth: 1
                )
            }
        }
    }

    // MARK: - Barre Supérieure & Rail d'Étapes Animé

    private var topNavigationHeader: some View {
        HStack(spacing: 12) {
            Button {
                triggerLightHaptic()
                if let prev = Step(rawValue: currentStep.rawValue - 1) {
                    navigationDirectionForward = false
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        stepErrorMessage = nil
                        currentStep = prev
                    }
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: currentStep == .identity ? "xmark" : "chevron.left")
                        .font(.system(size: 13.5, weight: .bold))
                    Text(currentStep == .identity ? "Fermer" : "Retour")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.14)))
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "person.badge.shield.checkmark.fill")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.azureGlow)
                Text("VIPLE LIVE ID STUDIO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.8))
            )
        }
    }

    private var stepProgressRail: some View {
        HStack(spacing: 8) {
            ForEach(Step.allCases) { step in
                let isCompleted = step.rawValue < currentStep.rawValue
                let isCurrent = step == currentStep

                Button {
                    if step.rawValue < currentStep.rawValue {
                        triggerLightHaptic()
                        navigationDirectionForward = false
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                            stepErrorMessage = nil
                            currentStep = step
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(
                                    isCurrent
                                        ? VipleMailPalette.azureGlow
                                        : (isCompleted ? Color(red: 0.14, green: 0.84, blue: 0.58) : Color.white.opacity(0.16))
                                )
                                .frame(width: 22, height: 22)

                            if isCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10.5, weight: .black))
                                    .foregroundStyle(.white)
                            } else {
                                Text("\(step.stepNumber)")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(isCurrent ? Color(red: 0.02, green: 0.08, blue: 0.22) : .white.opacity(0.8))
                            }
                        }

                        if isCurrent {
                            Text(step.shortTitle)
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .matchedGeometryEffect(id: "activeStepLabel", in: stepNamespace)
                        }
                    }
                    .padding(.horizontal, isCurrent ? 11 : 6)
                    .padding(.vertical, 6)
                    .frame(maxWidth: isCurrent ? .infinity : nil)
                    .background(
                        Capsule()
                            .fill(isCurrent ? Color.white.opacity(0.18) : Color.white.opacity(0.07))
                            .overlay(
                                Capsule()
                                    .stroke(isCurrent ? VipleMailPalette.azureGlow.opacity(0.65) : Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(step.rawValue > currentStep.rawValue)
            }
        }
    }

    // MARK: - Carte Passeport Viple Live ID Holographique Interactive

    private func liveHolographicPassportCard(elapsed: Double) -> some View {
        let tiltX = reduceMotion ? 0.0 : sin(elapsed * 1.15) * 2.6
        let tiltY = reduceMotion ? 0.0 : cos(elapsed * 0.88) * 3.2
        let sheenPhase = reduceMotion ? 0.5 : (sin(elapsed * 0.95) * 0.5 + 0.5)
        let isHandleVerified: Bool = {
            if case .available = handleCheckState { return true }
            return false
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.azureGlow)
                    Text(VipleMailLayout.isCompactPhone ? "PASSEPORT VIPLE LIVE ID" : "PASSEPORT NUMÉRIQUE VIPLE LIVE ID")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.white.opacity(0.90))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: 4)

                HStack(spacing: 4) {
                    Circle()
                        .fill(passwordStrengthScore >= 1 ? Color(red: 0.16, green: 0.88, blue: 0.60) : VipleMailPalette.azureGlow)
                        .frame(width: 6.5, height: 6.5)
                    Text(passwordStrengthScore >= 1 ? "MailRTE Prêt" : "Étape \(currentStep.stepNumber)/4")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.15)))
            }

            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.16, green: 0.72, blue: 1.00),
                                    Color(red: 0.38, green: 0.32, blue: 0.98)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: Color(red: 0.16, green: 0.72, blue: 1.00).opacity(0.42), radius: 10, y: 4)

                    Text(previewInitials)
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(previewDisplayName)
                        .font(.system(size: 18.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: previewDisplayName)

                    HStack(spacing: 6) {
                        Text(previewEmail)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.azureGlow)
                            .lineLimit(1)

                        if isHandleVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.64))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()
                .overlay(Color.white.opacity(0.16))

            // Dock d'applications Cenelis × Viple débloquées par ce Viple Live ID
            HStack(spacing: 8) {
                Text("Accès unifié :")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 6) {
                    ForEach(ecosystemPreviewApps) { app in
                        ecosystemMiniAppIcon(app)
                    }
                }

                Spacer(minLength: 0)

                Text("5 Go")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
        }
        .padding(18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.07, green: 0.18, blue: 0.44).opacity(0.92),
                                Color(red: 0.14, green: 0.16, blue: 0.46).opacity(0.90),
                                Color(red: 0.04, green: 0.28, blue: 0.56).opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Reflet holographique mobile
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: max(0, sheenPhase - 0.28)),
                                .init(color: Color.white.opacity(0.15), location: sheenPhase),
                                .init(color: .clear, location: min(1, sheenPhase + 0.28))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.45),
                            VipleMailPalette.azureGlow.opacity(0.45),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 10)
        .rotation3DEffect(.degrees(tiltX), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
        .rotation3DEffect(.degrees(tiltY), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
    }

    private func ecosystemMiniAppIcon(_ app: CenelisEcosystemApp) -> some View {
        Group {
            #if canImport(UIKit)
            if let uiImg = UIImage(named: app.assetName) {
                Image(uiImage: uiImg)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.32), lineWidth: 0.6)
                    )
            } else {
                fallbackMiniIcon(app)
            }
            #else
            fallbackMiniIcon(app)
            #endif
        }
    }

    private func fallbackMiniIcon(_ app: CenelisEcosystemApp) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(LinearGradient(colors: app.fallbackGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 24, height: 24)
            Image(systemName: app.fallbackSymbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Conteneur de l'Étape Courante

    private var stepContentContainer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: currentStep.symbolName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("ÉTAPE \(currentStep.stepNumber) SUR 4")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                    Text(currentStep.headline)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                }
            }

            Text(currentStep.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let err = stepErrorMessage ?? vm.authErrorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(VipleMailPalette.danger)
                    Text(err)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.danger)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.danger.opacity(0.10))
                )
            }

            switch currentStep {
            case .identity:
                identityStepFields
            case .mailboxHandle:
                mailboxHandleStepFields
            case .securityKey:
                securityKeyStepFields
            case .ecosystemActivation:
                ecosystemActivationStepFields
            }
        }
        .vipleMailCard(cornerRadius: 24, padding: 18)
    }

    // MARK: - Étape 1 : Identité

    private var identityStepFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prénom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    TextField("Ex : Camille", text: $firstName, prompt: VipleMailPalette.prompt("Ex : Camille", scheme: colorScheme))
                        .vipleMailTextInput()
                        .textContentType(.givenName)
                        .padding(13)
                        .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                        .onChange(of: firstName) { _, _ in syncSuggestedIdentityFields() }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    TextField("Ex : Laurent", text: $lastName, prompt: VipleMailPalette.prompt("Ex : Laurent", scheme: colorScheme))
                        .vipleMailTextInput()
                        .textContentType(.familyName)
                        .padding(13)
                        .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                        .onChange(of: lastName) { _, _ in syncSuggestedIdentityFields() }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Nom d'affichage public")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                    Text("Visible par vos destinataires")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                HStack(spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField(
                        "Ex : Camille Laurent",
                        text: Binding(
                            get: { displayName },
                            set: { newVal in
                                displayNameEditedManually = true
                                displayName = newVal
                            }
                        ),
                        prompt: VipleMailPalette.prompt("Ex : Camille Laurent", scheme: colorScheme)
                    )
                    .vipleMailTextInput()
                    .textContentType(.name)
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }
        }
    }

    // MARK: - Étape 2 : Adresse @viplemail.fr & Disponibilité Temps Réel

    private var mailboxHandleStepFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Votre identifiant @viplemail.fr")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.primary)
                        TextField(
                            "prenom.nom",
                            text: Binding(
                                get: { desiredHandle },
                                set: { newVal in
                                    handleEditedManually = true
                                    desiredHandle = newVal.lowercased()
                                    scheduleHandleAvailabilityCheck()
                                }
                            ),
                            prompt: VipleMailPalette.prompt("prenom.nom", scheme: colorScheme)
                        )
                        .vipleMailTextInput()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 13)

                    Text("@viplemail.fr")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(VipleMailPalette.heroGradient)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(VipleMailPalette.border, lineWidth: 1)
                )
            }

            handleAvailabilityBanner

            if !currentSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggestions disponibles en 1 toucher :")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(currentSuggestions, id: \.self) { sug in
                                Button {
                                    triggerLightHaptic()
                                    handleEditedManually = true
                                    desiredHandle = sug
                                    scheduleHandleAvailabilityCheck(immediate: true)
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("\(sug)@viplemail.fr")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    }
                                    .foregroundStyle(VipleMailPalette.primary)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(
                                        Capsule()
                                            .fill(VipleMailPalette.primary.opacity(0.11))
                                            .overlay(Capsule().stroke(VipleMailPalette.primary.opacity(0.28), lineWidth: 1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            scheduleHandleAvailabilityCheck(immediate: true)
        }
    }

    private var currentSuggestions: [String] {
        switch handleCheckState {
        case .available(_, let sugs), .unavailable(_, let sugs):
            return sugs
        default:
            return []
        }
    }

    @ViewBuilder
    private var handleAvailabilityBanner: some View {
        switch handleCheckState {
        case .idle:
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(VipleMailPalette.primary)
                Text("Utilisez des lettres, chiffres, points ou tirets (au moins 2 caractères).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary.opacity(0.08)))

        case .checking:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                    .tint(VipleMailPalette.primary)
                Text("Vérification de disponibilité sur mail.viplemail.fr…")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                Spacer(minLength: 0)
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

        case .available(let email, _):
            HStack(spacing: 9) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VipleMailPalette.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adresse disponible !")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(VipleMailPalette.success)
                    Text("\(email) vous est réservée dès l'activation.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VipleMailPalette.success.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VipleMailPalette.success.opacity(0.35), lineWidth: 1))
            )

        case .unavailable(let reason, _):
            HStack(spacing: 9) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VipleMailPalette.danger)
                Text(reason)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.danger)
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(VipleMailPalette.danger.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(VipleMailPalette.danger.opacity(0.30), lineWidth: 1))
            )
        }
    }

    // MARK: - Étape 3 : Sécurité & Jauge d'Entropie Animée

    private var securityKeyStepFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Mot de passe Viple Live ID")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                    Button {
                        showPasswordPlain.toggle()
                    } label: {
                        Label(showPasswordPlain ? "Masquer" : "Afficher", systemImage: showPasswordPlain ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    .buttonStyle(.plain)
                }

                Group {
                    if showPasswordPlain {
                        TextField("Minimum 6 caractères", text: $password, prompt: VipleMailPalette.prompt("Minimum 6 caractères", scheme: colorScheme))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Minimum 6 caractères", text: $password, prompt: VipleMailPalette.prompt("Minimum 6 caractères", scheme: colorScheme))
                    }
                }
                .vipleMailTextInput()
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            // Jauge d'entropie à 4 segments
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { idx in
                        Capsule()
                            .fill(idx < passwordStrengthScore ? passwordStrengthLabel.color : VipleMailPalette.border)
                            .frame(height: 6)
                            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: passwordStrengthScore)
                    }
                }

                HStack {
                    Text("Niveau de protection : \(passwordStrengthLabel.text)")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(passwordStrengthScore > 0 ? passwordStrengthLabel.color : VipleMailPalette.inkMuted)
                    Spacer()
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirmer le mot de passe")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                Group {
                    if showPasswordPlain {
                        TextField("Répétez votre mot de passe", text: $confirmPassword, prompt: VipleMailPalette.prompt("Répétez votre mot de passe", scheme: colorScheme))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Répétez votre mot de passe", text: $confirmPassword, prompt: VipleMailPalette.prompt("Répétez votre mot de passe", scheme: colorScheme))
                    }
                }
                .vipleMailTextInput()
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 7) {
                securityCriterionRow(met: password.count >= 6, text: "Au moins 6 caractères (requis)")
                securityCriterionRow(met: password.count >= 8 && password.rangeOfCharacter(from: .decimalDigits) != nil, text: "8+ caractères avec au moins un chiffre (recommandé)")
                securityCriterionRow(met: !confirmPassword.isEmpty && password == confirmPassword, text: "Confirmation identique au mot de passe")
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.surfaceSubtle))
        }
    }

    private func securityCriterionRow(met: Bool, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundStyle(met ? VipleMailPalette.success : VipleMailPalette.inkMuted)
                .scaleEffect(met ? 1.08 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.65), value: met)

            Text(text)
                .font(.system(size: 12, weight: met ? .bold : .medium))
                .foregroundStyle(met ? VipleMailPalette.ink : VipleMailPalette.inkSecondary)
        }
    }

    // MARK: - Étape 4 : Récapitulatif Écosystème & Consentement App Store

    private var ecosystemActivationStepFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 10) {
                summaryFeatureRow(
                    icon: "envelope.badge.shield.half.filled.fill",
                    tint: VipleMailPalette.primary,
                    title: "Boîte officielle \(previewEmail)",
                    detail: "5 Go IMAP/SMTP TLS 1.3 + Chiffrement Cenelis MailRTE activé par défaut"
                )
                summaryFeatureRow(
                    icon: "iphone.gen3.radiowaves.left.and.right",
                    tint: VipleMailPalette.success,
                    title: "Gestionnaire d'appareils Viple Live ID",
                    detail: "Suivez sur quelles applications vos appareils sont connectés et coupez-les à distance"
                )
                summaryFeatureRow(
                    icon: "square.grid.2x2.fill",
                    tint: Color(red: 0.48, green: 0.30, blue: 0.96),
                    title: "Accès unifié à tout l'écosystème Cenelis",
                    detail: "Connexion en 1 toucher sur Livria Store, Livria Social, Cenelis Academy et Looby"
                )
            }

            Divider()

            Button {
                triggerLightHaptic()
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    acceptedTermsAndPrivacy.toggle()
                    stepErrorMessage = nil
                }
            } label: {
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: acceptedTermsAndPrivacy ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(acceptedTermsAndPrivacy ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                        .padding(.top, 1)

                    Text("J'accepte les Conditions Générales d'Utilisation et la Politique de Confidentialité RGPD de Viple Mail & Viple Live ID (zéro pistage publicitaire, suppression libre du compte à tout moment).")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.ink)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(acceptedTermsAndPrivacy ? VipleMailPalette.primary.opacity(0.09) : VipleMailPalette.surfaceSubtle)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(acceptedTermsAndPrivacy ? VipleMailPalette.primary.opacity(0.35) : VipleMailPalette.border, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func summaryFeatureRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.surfaceSubtle))
    }

    // MARK: - Barre d'Action Inférieure & Liens Légaux

    private var legalQuickFooter: some View {
        HStack(spacing: 14) {
            if let privUrl = URL(string: "https://mail.viplemail.fr/privacy") {
                Link("Confidentialité", destination: privUrl)
            }
            Text("•").foregroundStyle(.white.opacity(0.45))
            if let termsUrl = URL(string: "https://mail.viplemail.fr/terms") {
                Link("Conditions (EULA)", destination: termsUrl)
            }
            Text("•").foregroundStyle(.white.opacity(0.45))
            if let supUrl = URL(string: "https://mail.viplemail.fr/support") {
                Link("Assistance", destination: supUrl)
            }
        }
        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.82))
        .frame(maxWidth: .infinity)
    }

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color.white.opacity(0.14))

            Button {
                handlePrimaryAction()
            } label: {
                HStack(spacing: 9) {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: currentStep == .ecosystemActivation ? "bolt.shield.fill" : "arrow.right.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                    }
                    Text(currentStep == .ecosystemActivation ? "Créer mon Viple Live ID maintenant" : "Continuer vers l'étape \(currentStep.stepNumber + 1)")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.48, blue: 0.94),
                                    Color(red: 0.24, green: 0.34, blue: 0.96)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color(red: 0.04, green: 0.48, blue: 0.94).opacity(0.45), radius: 12, y: 5)
                )
            }
            .buttonStyle(.plain)
            .disabled(vm.isLoading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Séquence Cinématique d'Activation du Viple Live ID

    private var activationCinemaOverlay: some View {
        let stages = [
            "Génération cryptographique de votre Viple Live ID (CID)…",
            "Provisionnement de \(previewEmail) sur Stalwart TLS 1.3…",
            "Scellement des clés hybrides Cenelis MailRTE…"
        ]

        return VStack(spacing: 24) {
            ZStack {
                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(VipleMailPalette.azureGlow.opacity(0.32 - Double(ring) * 0.08), lineWidth: 2)
                        .frame(width: CGFloat(106 + ring * 34), height: CGFloat(106 + ring * 34))
                        .scaleEffect(activationPhaseIndex >= ring ? 1.06 : 0.88)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: activationPhaseIndex)
                }

                Circle()
                    .fill(VipleMailPalette.heroGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: VipleMailPalette.azureGlow.opacity(0.55), radius: 20)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("Activation de votre Viple Live ID")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                Text(previewEmail)
                    .font(.system(size: 14.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(VipleMailPalette.azureGlow)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0..<stages.count, id: \.self) { idx in
                    HStack(spacing: 10) {
                        if activationPhaseIndex > idx {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(red: 0.18, green: 0.92, blue: 0.62))
                        } else if activationPhaseIndex == idx {
                            ProgressView()
                                .tint(VipleMailPalette.azureGlow)
                                .controlSize(.small)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.white.opacity(0.35))
                        }

                        Text(stages[idx])
                            .font(.system(size: 13, weight: activationPhaseIndex >= idx ? .bold : .medium, design: .rounded))
                            .foregroundStyle(activationPhaseIndex >= idx ? .white : .white.opacity(0.55))
                    }
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.18), lineWidth: 1))
            )
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Logique de Validation, Suggestions & Création

    private func syncSuggestedIdentityFields() {
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !displayNameEditedManually {
            displayName = "\(fn) \(ln)".trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !handleEditedManually {
            let combined = [fn, ln].filter { !$0.isEmpty }.joined(separator: ".")
            desiredHandle = Self.normalizeHandle(combined)
        }
    }

    private static func normalizeHandle(_ raw: String) -> String {
        let folded = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: ".")
        let allowed = folded.filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
        return String(allowed.prefix(40)).trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
    }

    private func scheduleHandleAvailabilityCheck(immediate: Bool = false) {
        handleCheckTask?.cancel()
        let candidate = sanitizedHandle
        guard candidate.count >= 2 else {
            handleCheckState = .idle
            return
        }
        handleCheckState = .checking
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)

        handleCheckTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            guard !Task.isCancelled else { return }
            do {
                let res = try await VipleMailAPIClient.shared.checkHandleAvailability(
                    handle: candidate,
                    firstName: fn,
                    lastName: ln
                )
                guard !Task.isCancelled else { return }
                if res.available {
                    handleCheckState = .available(email: res.email, suggestions: res.suggestions)
                } else {
                    handleCheckState = .unavailable(
                        reason: res.reason ?? "Cette adresse @viplemail.fr est déjà utilisée.",
                        suggestions: res.suggestions
                    )
                }
            } catch {
                guard !Task.isCancelled else { return }
                handleCheckState = .available(email: "\(candidate)@viplemail.fr", suggestions: [])
            }
        }
    }

    private func handlePrimaryAction() {
        stepErrorMessage = nil
        vm.authErrorMessage = nil

        switch currentStep {
        case .identity:
            let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard fn.count >= 2 else {
                triggerErrorHaptic()
                stepErrorMessage = "Veuillez indiquer votre prénom (au moins 2 caractères)."
                return
            }
            syncSuggestedIdentityFields()
            advanceTo(.mailboxHandle)

        case .mailboxHandle:
            let h = sanitizedHandle
            guard h.count >= 2 else {
                triggerErrorHaptic()
                stepErrorMessage = "Choisissez un identifiant d'au moins 2 caractères pour votre boîte @viplemail.fr."
                return
            }
            if case .unavailable(let reason, _) = handleCheckState {
                triggerErrorHaptic()
                stepErrorMessage = reason
                return
            }
            advanceTo(.securityKey)

        case .securityKey:
            guard password.count >= 6 else {
                triggerErrorHaptic()
                stepErrorMessage = "Votre mot de passe doit comporter au moins 6 caractères."
                return
            }
            guard password == confirmPassword else {
                triggerErrorHaptic()
                stepErrorMessage = "La confirmation ne correspond pas à votre mot de passe."
                return
            }
            advanceTo(.ecosystemActivation)

        case .ecosystemActivation:
            guard acceptedTermsAndPrivacy else {
                triggerErrorHaptic()
                stepErrorMessage = "Veuillez accepter les Conditions d'Utilisation et la Politique de Confidentialité pour activer votre Viple Live ID."
                return
            }
            launchRegistrationSequence()
        }
    }

    private func advanceTo(_ next: Step) {
        triggerLightHaptic()
        navigationDirectionForward = true
        withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
            currentStep = next
        }
    }

    private func launchRegistrationSequence() {
        let cleanHandle = sanitizedHandle
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let dn = previewDisplayName

        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            activationPhaseIndex = 0
            isRunningActivationSequence = true
        }

        Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation { activationPhaseIndex = 1 }
            try? await Task.sleep(nanoseconds: 420_000_000)
            withAnimation { activationPhaseIndex = 2 }

            await vm.registerAccount(
                emailMode: "viplemail",
                emailUser: cleanHandle,
                customEmail: "\(cleanHandle)@viplemail.fr",
                password: password,
                firstName: fn.isEmpty ? cleanHandle.capitalized : fn,
                lastName: ln,
                displayName: dn
            )

            if vm.isAuthenticated {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                dismiss()
            } else {
                triggerErrorHaptic()
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isRunningActivationSequence = false
                }
            }
        }
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func triggerErrorHaptic() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }
}
