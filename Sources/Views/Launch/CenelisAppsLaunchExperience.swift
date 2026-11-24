import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Catalogue Réutilisable des Applications de l'Écosystème « Cenelis Apps × Viple Live »
// Ce composant autonome est conçu pour être intégré tel quel au démarrage de toutes les applications iOS
// du Groupe Cenelis / Viple SA : il suffit de passer `CenelisAppsIntroView(currentApp: .vipleMail)` (ou `.livriaStore`, etc.).

public enum CenelisEcosystemApp: String, CaseIterable, Identifiable, Sendable {
    case vipleMail
    case cenelisWorkspace
    case livriaStore
    case vipleEtMoi
    case cenelisAcademy
    case livriaSocial
    case looby
    case livriaMarketplace

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .vipleMail:         return "Viple Mail"
        case .cenelisWorkspace:  return "Cenelis Workspace"
        case .livriaStore:       return "Livria Store"
        case .vipleEtMoi:        return "Viple & Moi"
        case .cenelisAcademy:    return "Cenelis Academy"
        case .livriaSocial:      return "Livria Social"
        case .looby:             return "Looby"
        case .livriaMarketplace: return "Livria Marketplace"
        }
    }

    public var subtitle: String {
        switch self {
        case .vipleMail:         return "Messagerie & Chiffrement Cenelis MailRTE"
        case .cenelisWorkspace:  return "Portail Collaboratif & Gouvernance Cenelis"
        case .livriaStore:       return "Librairie Numérique & Édition Culturelle"
        case .vipleEtMoi:        return "Espace Personnel & Services Viple Live"
        case .cenelisAcademy:    return "Formation, Parcours & Certification"
        case .livriaSocial:      return "Réseau Culturel & Communautés"
        case .looby:             return "Économie Locale & Commerces de Proximité"
        case .livriaMarketplace: return "Place de Marché Créateurs & Partenaires"
        }
    }

    public var assetName: String {
        switch self {
        case .vipleMail:         return "EcoIconVipleMail"
        case .cenelisWorkspace:  return "EcoIconCenelisWorkspace"
        case .livriaStore:       return "EcoIconLivriaStore"
        case .vipleEtMoi:        return "EcoIconVipleEtMoi"
        case .cenelisAcademy:    return "EcoIconCenelisAcademy"
        case .livriaSocial:      return "EcoIconLivriaSocial"
        case .looby:             return "EcoIconLooby"
        case .livriaMarketplace: return "EcoIconLivriaMarketplace"
        }
    }

    public var fallbackSymbol: String {
        switch self {
        case .vipleMail:         return "envelope.open.fill"
        case .cenelisWorkspace:  return "building.columns.fill"
        case .livriaStore:       return "book.closed.fill"
        case .vipleEtMoi:        return "person.crop.circle.badge.checkmark"
        case .cenelisAcademy:    return "graduationcap.fill"
        case .livriaSocial:      return "bubble.left.and.exclamationmark.bubble.right.fill"
        case .looby:             return "infinity"
        case .livriaMarketplace: return "bag.fill"
        }
    }

    public var signatureGlow: Color {
        switch self {
        case .vipleMail:         return Color(red: 0.14, green: 0.68, blue: 1.00)
        case .cenelisWorkspace:  return Color(red: 0.12, green: 0.76, blue: 0.54)
        case .livriaStore:       return Color(red: 0.68, green: 0.34, blue: 0.98)
        case .vipleEtMoi:        return Color(red: 0.36, green: 0.52, blue: 1.00)
        case .cenelisAcademy:    return Color(red: 0.96, green: 0.72, blue: 0.22)
        case .livriaSocial:      return Color(red: 0.95, green: 0.33, blue: 0.68)
        case .looby:             return Color(red: 0.22, green: 0.88, blue: 0.66)
        case .livriaMarketplace: return Color(red: 0.86, green: 0.38, blue: 0.88)
        }
    }

    public var fallbackGradient: [Color] {
        switch self {
        case .vipleMail:
            return [Color(red: 0.02, green: 0.22, blue: 0.72), Color(red: 0.08, green: 0.72, blue: 0.98)]
        case .cenelisWorkspace:
            return [Color(red: 0.05, green: 0.22, blue: 0.16), Color(red: 0.10, green: 0.44, blue: 0.31)]
        case .livriaStore:
            return [Color(red: 0.52, green: 0.24, blue: 0.96), Color(red: 0.95, green: 0.36, blue: 0.68)]
        case .vipleEtMoi:
            return [Color(red: 0.08, green: 0.09, blue: 0.22), Color(red: 0.31, green: 0.27, blue: 0.90)]
        case .cenelisAcademy:
            return [Color(red: 0.05, green: 0.34, blue: 0.26), Color(red: 0.86, green: 0.52, blue: 0.14)]
        case .livriaSocial:
            return [Color(red: 0.62, green: 0.26, blue: 0.96), Color(red: 0.96, green: 0.34, blue: 0.62)]
        case .looby:
            return [Color(red: 0.16, green: 0.82, blue: 0.58), Color(red: 0.24, green: 0.58, blue: 0.96)]
        case .livriaMarketplace:
            return [Color(red: 0.56, green: 0.24, blue: 0.94), Color(red: 0.94, green: 0.36, blue: 0.66)]
        }
    }

    /// Dégradé d'atterrissage exact lors du plongeon zoomé vers le LaunchScreen propre à l'application cible
    public func portalLandingGradient(for colorScheme: ColorScheme) -> LinearGradient {
        switch self {
        case .vipleMail:
            if colorScheme == .dark {
                return LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.05, blue: 0.12),
                        Color(red: 0.03, green: 0.12, blue: 0.28),
                        Color(red: 0.04, green: 0.22, blue: 0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                return LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.16, blue: 0.48),
                        Color(red: 0.00, green: 0.45, blue: 0.86),
                        Color(red: 0.12, green: 0.70, blue: 0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        default:
            return LinearGradient(
                colors: fallbackGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Acte 1 : LaunchScreen Motion Design « Cenelis Apps • Écosystème Viple »

public struct CenelisAppsIntroView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let currentApp: CenelisEcosystemApp
    public let onPortalEntered: () -> Void

    @State private var startDate: Date = Date()
    @State private var didAppear: Bool = false

    // Repères temporels chorégraphiés (en secondes, cadencés à 120 Hz via TimelineView)
    private let tSpinEnd: Double = 1.88       // Fin de la rotation orbitale 3D : l'appli cible se verrouille au premier plan
    private let tLockEnd: Double = 2.44       // Convergence au centre + onde de choc lumineuse
    private let tPortalEnd: Double = 2.96     // Fin du plongeon zoomé à travers l'icône vers le LaunchScreen de l'appli

    private let apps: [CenelisEcosystemApp] = CenelisEcosystemApp.allCases

    public init(
        currentApp: CenelisEcosystemApp = .vipleMail,
        onPortalEntered: @escaping () -> Void
    ) {
        self.currentApp = currentApp
        self.onPortalEntered = onPortalEntered
    }

    private var targetAppIndex: Int {
        apps.firstIndex(of: currentApp) ?? 0
    }

    public var body: some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let orbitRadius = min(max(minDim * 0.355, 118), 156)

            TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: false)) { timeline in
                let rawElapsed = didAppear ? max(0, timeline.date.timeIntervalSince(startDate)) : 0
                let t = reduceMotion ? min(rawElapsed * 1.45, tPortalEnd) : min(rawElapsed, tPortalEnd)

                // Courbes normalisées par phase
                let introP = Self.easeOutBack(Self.clamp01(t / 0.56))
                let titleP = Self.easeOutCubic(Self.clamp01((t - 0.06) / 0.52))
                let spinP = Self.easeInOutCubic(Self.clamp01(t / tSpinEnd))
                let lockP = Self.easeInOutCubic(Self.clamp01((t - tSpinEnd) / (tLockEnd - tSpinEnd)))
                let diveP = Self.clamp01((t - tLockEnd) / (tPortalEnd - tLockEnd))
                let diveAccel = pow(diveP, 2.85)

                // Chrome périphérique (s'écarte vers l'extérieur lorsque la caméra plonge dans l'application)
                let chromeFade = 1.0 - Self.easeInCubic(Self.clamp01((t - (tLockEnd - 0.06)) / 0.34))
                let chromeScale = 1.0 + 0.24 * diveAccel

                ZStack {
                    // 1. Fond Cosmique Architectural Cenelis × Viple + Nébuleuses + Grille de Précision + Particules 120fps
                    CenelisCosmicBackdropCanvas(
                        elapsed: t,
                        accentGlow: currentApp.signatureGlow,
                        lockProgress: lockP
                    )
                    .ignoresSafeArea()

                    // 2. Scène Principale (En-tête « Cenelis Apps » + Constellation Orbitale 3D + Pied de page dynamique)
                    VStack(spacing: 0) {
                        Spacer(minLength: max(22, geo.size.height * 0.06))

                        headerTitleBlock(elapsed: t, titleP: titleP)
                            .opacity(chromeFade)
                            .scaleEffect(chromeScale)

                        Spacer(minLength: 10)

                        // Système Orbital 3D & Portail d'Entrée dans l'Application
                        orbitalConstellationStage(
                            elapsed: t,
                            orbitRadius: orbitRadius,
                            introP: introP,
                            spinP: spinP,
                            lockP: lockP,
                            diveP: diveP,
                            diveAccel: diveAccel
                        )
                        .frame(width: orbitRadius * 2.55, height: orbitRadius * 2.20)

                        Spacer(minLength: 10)

                        bottomStatusBlock(elapsed: t, titleP: titleP, lockP: lockP)
                            .opacity(chromeFade)
                            .scaleEffect(1.0 + 0.12 * diveAccel)

                        Spacer(minLength: max(26, geo.size.height * 0.065))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // 3. Voile Lumineux du Portail qui fusionne pixel pour pixel avec le LaunchScreen de l'appli cible
                    if diveP > 0.01 {
                        currentApp.portalLandingGradient(for: colorScheme)
                            .ignoresSafeArea()
                            .opacity(Self.smoothstep(0.18, 0.96, diveP))
                            .allowsHitTesting(false)
                    }
                }
            }
        }
        .onAppear {
            startDate = Date()
            didAppear = true
        }
        .task {
            let speedDivisor: Double = reduceMotion ? 1.45 : 1.0

            // Haptique 1 : Déploiement de la constellation Cenelis Apps
            try? await Task.sleep(nanoseconds: UInt64((0.16 / speedDivisor) * 1_000_000_000))
            if Task.isCancelled { return }
            Self.fireImpact(.soft, intensity: 0.55)

            // Haptique 2 : Verrouillage orbital sur Viple Mail au premier plan
            try? await Task.sleep(nanoseconds: UInt64(((tSpinEnd - 0.16) / speedDivisor) * 1_000_000_000))
            if Task.isCancelled { return }
            Self.fireImpact(.rigid, intensity: 0.65)

            // Haptique 3 : Plongeon immersif (zoom dans le logo Viple Mail)
            try? await Task.sleep(nanoseconds: UInt64(((tLockEnd - tSpinEnd) / speedDivisor) * 1_000_000_000))
            if Task.isCancelled { return }
            Self.fireImpact(.medium, intensity: 0.90)

            // Passage fluide au LaunchScreen de Viple Mail au pic du portail lumineux
            try? await Task.sleep(nanoseconds: UInt64(((tPortalEnd - tLockEnd) / speedDivisor) * 1_000_000_000))
            if Task.isCancelled { return }
            onPortalEntered()
        }
    }

    // MARK: - En-tête Cinétique « Cenelis Apps »

    private func headerTitleBlock(elapsed: Double, titleP: Double) -> some View {
        let shimmerPhase = (elapsed * 0.72).truncatingRemainder(dividingBy: 1.0)

        return VStack(spacing: 12) {
            // Badge institutionnel Groupe Cenelis × Viple
            HStack(spacing: 7) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.16, green: 0.88, blue: 0.64), Color(red: 0.22, green: 0.74, blue: 1.00)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 7, height: 7)
                    .shadow(color: Color(red: 0.16, green: 0.88, blue: 0.64).opacity(0.9), radius: 5)

                Text("GROUPE CENELIS  ×  ÉCOSYSTÈME VIPLE")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Color.white.opacity(0.92))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6.5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.32),
                                        Color(red: 0.22, green: 0.76, blue: 1.00).opacity(0.45),
                                        Color(red: 0.16, green: 0.84, blue: 0.58).opacity(0.35)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .offset(y: CGFloat(1.0 - titleP) * -14)
            .opacity(titleP)

            // Titre principal « Cenelis Apps » avec reflet spéculaire animé
            VStack(spacing: 5) {
                HStack(spacing: 9) {
                    Text("Cenelis")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Apps")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 0.24, green: 0.82, blue: 1.00), location: 0.0),
                                    .init(color: Color.white, location: CGFloat(max(0.05, min(0.95, shimmerPhase)))),
                                    .init(color: Color(red: 0.20, green: 0.88, blue: 0.66), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: Color(red: 0.12, green: 0.58, blue: 1.00).opacity(0.35), radius: 16, x: 0, y: 6)

                Text("Toutes vos applications connectées par Viple Live ID")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .scaleEffect(0.90 + 0.10 * titleP)
            .opacity(titleP)
        }
    }

    // MARK: - Scène Orbitale 3D des 8 Applications + Verrouillage & Zoom Portail

    private func orbitalConstellationStage(
        elapsed: Double,
        orbitRadius: CGFloat,
        introP: Double,
        spinP: Double,
        lockP: Double,
        diveP: Double,
        diveAccel: Double
    ) -> some View {
        // Inclinaison 3D de l'anneau orbital (perspective spatiale : haut = arrière-plan, bas = premier plan proche caméra)
        let tiltRatio: CGFloat = 0.56
        let count = apps.count

        // Calcul analytique de l'angle de base pour que `currentApp` (ex: Viple Mail) effectue 1,35 tour fluide
        // et s'arrête exactement à θ = +π/2 (zénith avant, au plus près de l'utilisateur !)
        let targetSlotAngle = (2.0 * Double.pi * Double(targetAppIndex)) / Double(count)
        let endBaseAngle = (Double.pi / 2.0) - targetSlotAngle
        let startBaseAngle = endBaseAngle - (2.0 * Double.pi * (reduceMotion ? 0.35 : 1.35))
        let currentBaseAngle = startBaseAngle + (endBaseAngle - startBaseAngle) * spinP

        return ZStack {
            // A. Anneaux orbitaux lumineux, sillages cométaires & rayons d'énergie radiaux (Canvas 120fps)
            CenelisOrbitalRingsCanvas(
                elapsed: elapsed,
                orbitRadius: orbitRadius,
                tiltRatio: tiltRatio,
                baseAngle: currentBaseAngle,
                appCount: count,
                introProgress: CGFloat(min(1.0, max(0.0, introP))),
                lockProgress: lockP,
                accentColor: currentApp.signatureGlow
            )
            .opacity(1.0 - Self.clamp01(diveP * 2.2))

            // B. Onde de choc lumineuse lors du verrouillage central de l'application cible
            if lockP > 0.05 {
                let waveP = Self.clamp01((lockP - 0.05) / 0.95)
                let waveDiameter = 76.0 + orbitRadius * 1.65 * CGFloat(waveP)
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                currentApp.signatureGlow.opacity(0.85 * (1.0 - waveP)),
                                Color.white.opacity(0.65 * (1.0 - waveP))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(max(1.0, 3.5 * (1.0 - waveP)))
                    )
                    .frame(width: waveDiameter, height: waveDiameter)
                    .blur(radius: 1.2)
            }

            // C. Cœur Central « Cenelis × Ruban Viple » (zIndex = 0 : les icônes au fond passent derrière, celles devant passent devant !)
            CenelisVipleCentralHub(elapsed: elapsed)
                .scaleEffect(CGFloat(max(0.01, (0.35 + 0.65 * introP) * (1.0 - 0.55 * lockP) * (1.0 - diveP))))
                .opacity(Double(min(1.0, max(0.0, introP))) * (1.0 - Self.smoothstep(0.15, 0.88, lockP)))
                .zIndex(0)

            // D. Les 8 Icônes Officielles en Orbite 3D
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                let isTarget = (index == targetAppIndex)
                let theta = currentBaseAngle + (2.0 * Double.pi * Double(index)) / Double(count)

                let cosT = CGFloat(cos(theta))
                let sinT = CGFloat(sin(theta)) // -1 = arrière-plan haut, +1 = premier plan bas
                let depth01 = (sinT + 1.0) * 0.5

                // Déploiement radial initial
                let activeRadius = orbitRadius * CGFloat(introP)

                // Position sur l'ellipse 3D
                let orbitX = cosT * activeRadius
                let orbitY = sinT * activeRadius * tiltRatio

                if isTarget {
                    // L'application cible (Viple Mail) glisse du premier plan orbital jusqu'au centre exact (0, 0),
                    // grandit majestueusement puis plonge vers la caméra (zoom x15.5) !
                    let posX = orbitX * (1.0 - CGFloat(lockP))
                    let posY = orbitY * (1.0 - CGFloat(lockP))

                    let orbitPerspectiveScale = 0.76 + 0.42 * depth01
                    let lockedCenterScale: CGFloat = 1.48
                    let preDiveScale = orbitPerspectiveScale + (lockedCenterScale - orbitPerspectiveScale) * CGFloat(lockP)
                    let portalZoomScale = preDiveScale * (1.0 + 14.8 * CGFloat(diveAccel))

                    CenelisAppTileIcon(
                        app: app,
                        size: 62,
                        isHighlighted: lockP > 0.02,
                        highlightIntensity: lockP
                    )
                    .scaleEffect(max(0.01, CGFloat(min(1.12, max(0, introP))) * portalZoomScale))
                    .offset(x: posX, y: posY)
                    .opacity(1.0 - Self.smoothstep(0.68, 0.99, diveP))
                    .zIndex(lockP > 0.05 ? 50 : Double(sinT * 10.0 + 0.5))
                } else {
                    // Les 7 applications sœurs convergent élégamment en halo stellaire pendant le verrouillage
                    let siblingShrink = 1.0 - CGFloat(Self.smoothstep(0.0, 0.78, lockP))
                    let posX = orbitX * (0.45 + 0.55 * siblingShrink)
                    let posY = orbitY * (0.45 + 0.55 * siblingShrink)
                    let perspectiveScale = (0.74 + 0.36 * depth01) * (0.45 + 0.55 * siblingShrink)
                    let depthOpacity = Double(0.68 + 0.32 * depth01) * Double(siblingShrink)

                    CenelisAppTileIcon(
                        app: app,
                        size: 54,
                        isHighlighted: false,
                        highlightIntensity: 0
                    )
                    .scaleEffect(max(0.01, CGFloat(min(1.12, max(0, introP))) * perspectiveScale))
                    .offset(x: posX, y: posY)
                    .opacity(max(0, min(1, Double(introP) * depthOpacity)))
                    .zIndex(Double(sinT * 10.0))
                }
            }
        }
    }

    // MARK: - Bloc d'État Inférieur (Piliers Viple → Ouverture de l'Application Cible)

    private func bottomStatusBlock(elapsed: Double, titleP: Double, lockP: Double) -> some View {
        ZStack {
            // Phase 1 : Signature des 3 Piliers Viple pendant la rotation orbitale
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    ecosystemPillarChip(title: "Viple Tech", dotColor: Color(red: 0.14, green: 0.72, blue: 0.98))
                    ecosystemPillarChip(title: "Viple Jeunesse", dotColor: Color(red: 0.98, green: 0.34, blue: 0.48))
                    ecosystemPillarChip(title: "Solidarités", dotColor: Color(red: 0.98, green: 0.72, blue: 0.16))
                }

                Text("SSO Unifié  •  Sécurité Cenelis  •  Cloud Souverain")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.56))
            }
            .opacity(titleP * (1.0 - Self.smoothstep(0.0, 0.45, lockP)))
            .offset(y: CGFloat(lockP) * 10)

            // Phase 2 : Verrouillage sur l'application cible (ex. « Ouverture de Viple Mail »)
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(currentApp.signatureGlow)

                    Text("Ouverture de \(currentApp.displayName)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(currentApp.signatureGlow.opacity(0.55), lineWidth: 1)
                        )
                )

                Text(currentApp.subtitle)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.78))
            }
            .opacity(Self.smoothstep(0.18, 0.68, lockP))
            .scaleEffect(0.92 + 0.08 * CGFloat(Self.smoothstep(0.18, 0.68, lockP)))
        }
        .frame(height: 64)
    }

    private func ecosystemPillarChip(title: String, dotColor: Color) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.86))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.07))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Fonctions Mathématiques d'Interpolation Cinématique & Haptique

    private static func clamp01(_ x: Double) -> Double {
        min(1.0, max(0.0, x))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        guard edge1 > edge0 else { return x >= edge1 ? 1.0 : 0.0 }
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3.0 - 2.0 * t)
    }

    private static func easeOutCubic(_ t: Double) -> Double {
        let inv = 1.0 - clamp01(t)
        return 1.0 - inv * inv * inv
    }

    private static func easeInCubic(_ t: Double) -> Double {
        let c = clamp01(t)
        return c * c * c
    }

    private static func easeInOutCubic(_ t: Double) -> Double {
        let c = clamp01(t)
        return c < 0.5
            ? 4.0 * c * c * c
            : 1.0 - pow(-2.0 * c + 2.0, 3.0) / 2.0
    }

    private static func easeOutBack(_ t: Double) -> Double {
        let c = clamp01(t)
        let c1 = 1.42
        let c3 = c1 + 1.0
        return 1.0 + c3 * pow(c - 1.0, 3.0) + c1 * pow(c - 1.0, 2.0)
    }

    @MainActor
    private static func fireImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
        #endif
    }
}

// MARK: - Tuile d'Icône Officielle iOS avec Reflet Verre & Halo Dynamique

private struct CenelisAppTileIcon: View {
    let app: CenelisEcosystemApp
    let size: CGFloat
    let isHighlighted: Bool
    let highlightIntensity: Double

    private var cornerRadius: CGFloat {
        size * 0.23
    }

    var body: some View {
        ZStack {
            // Halo néon ambiant sous l'icône
            RoundedRectangle(cornerRadius: cornerRadius * 1.15, style: .continuous)
                .fill(app.signatureGlow.opacity(isHighlighted ? 0.52 : 0.26))
                .frame(width: size * (isHighlighted ? 1.18 : 1.04), height: size * (isHighlighted ? 1.18 : 1.04))
                .blur(radius: isHighlighted ? 14 : 7)

            // Rendu de la vraie icône officielle issue d'Assets.xcassets (ou icône vectorielle de secours)
            Group {
                #if canImport(UIKit)
                if let uiImage = UIImage(named: app.assetName) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFill()
                } else {
                    fallbackVectorTile
                }
                #else
                fallbackVectorTile
                #endif
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHighlighted ? 0.85 : 0.45),
                                app.signatureGlow.opacity(isHighlighted ? 0.70 : 0.22),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 1.8 : 1.0
                    )
            )
            .shadow(
                color: Color.black.opacity(0.42),
                radius: isHighlighted ? 16 : 9,
                x: 0,
                y: isHighlighted ? 8 : 5
            )
        }
    }

    private var fallbackVectorTile: some View {
        ZStack {
            LinearGradient(
                colors: app.fallbackGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: app.fallbackSymbol)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Médaillon Central « Cenelis × Ruban Vectoriel Viple »

private struct CenelisVipleCentralHub: View {
    let elapsed: Double

    var body: some View {
        let ringAngle = Angle.degrees(elapsed * 58.0)
        let pulse = 1.0 + 0.045 * sin(elapsed * 4.2)

        return ZStack {
            // Halo énergétique central
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.22, green: 0.64, blue: 1.00).opacity(0.38),
                            Color(red: 0.10, green: 0.78, blue: 0.56).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 6,
                        endRadius: 62
                    )
                )
                .frame(width: 124, height: 124)
                .scaleEffect(pulse)

            // Couronne conique irisée en rotation continue
            Circle()
                .strokeBorder(
                    AngularGradient(
                        colors: [
                            Color(red: 0.98, green: 0.32, blue: 0.48), // Jeunesse
                            Color(red: 0.18, green: 0.74, blue: 0.98), // Tech
                            Color(red: 0.12, green: 0.82, blue: 0.58), // Cenelis
                            Color(red: 0.98, green: 0.74, blue: 0.16), // Solidarités
                            Color(red: 0.34, green: 0.30, blue: 0.94), // Viple Indigo
                            Color(red: 0.98, green: 0.32, blue: 0.48)
                        ],
                        center: .center
                    ),
                    lineWidth: 2.4
                )
                .frame(width: 82, height: 82)
                .rotationEffect(ringAngle)

            // Sphère de verre sombre Cenelis × Viple
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.13, blue: 0.25),
                            Color(red: 0.04, green: 0.08, blue: 0.16)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 74, height: 74)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.50), radius: 12, x: 0, y: 6)

            // Ruban vectoriel officiel à 3 branches « Viple » + Monogramme Cenelis
            VipleTriRibbonSymbol()
                .frame(width: 44, height: 44)
                .scaleEffect(pulse)
        }
    }
}

/// Dessin vectoriel fidèle du ruban officiel à 3 branches Viple (Jeunesse, Tech, Solidarités)
private struct VipleTriRibbonSymbol: View {
    var body: some View {
        Canvas { ctx, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.54
            let s = min(size.width, size.height) / 170.0

            // Branche gauche : Viple Jeunesse (Corail / Rose)
            var leftWing = Path()
            leftWing.move(to: CGPoint(x: cx - 56 * s, y: cy - 66 * s))
            leftWing.addCurve(
                to: CGPoint(x: cx, y: cy + 54 * s),
                control1: CGPoint(x: cx - 36 * s, y: cy - 40 * s),
                control2: CGPoint(x: cx - 18 * s, y: cy - 6 * s)
            )
            leftWing.addCurve(
                to: CGPoint(x: cx - 70 * s, y: cy - 48 * s),
                control1: CGPoint(x: cx - 16 * s, y: cy + 36 * s),
                control2: CGPoint(x: cx - 44 * s, y: cy - 8 * s)
            )
            leftWing.closeSubpath()
            ctx.fill(
                leftWing,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 1.00, green: 0.29, blue: 0.45), Color(red: 0.98, green: 0.44, blue: 0.52)]),
                    startPoint: CGPoint(x: cx - 68 * s, y: cy - 68 * s),
                    endPoint: CGPoint(x: cx, y: cy + 54 * s)
                )
            )

            let leftDot = Path(ellipseIn: CGRect(x: cx - 68 * s, y: cy - 82 * s, width: 20 * s, height: 20 * s))
            ctx.fill(leftDot, with: .color(Color(red: 1.00, green: 0.29, blue: 0.45)))

            // Branche droite : Viple Tech (Cyan / Bleu électrique)
            var rightWing = Path()
            rightWing.move(to: CGPoint(x: cx + 56 * s, y: cy - 66 * s))
            rightWing.addCurve(
                to: CGPoint(x: cx, y: cy + 54 * s),
                control1: CGPoint(x: cx + 36 * s, y: cy - 40 * s),
                control2: CGPoint(x: cx + 18 * s, y: cy - 6 * s)
            )
            rightWing.addCurve(
                to: CGPoint(x: cx + 70 * s, y: cy - 48 * s),
                control1: CGPoint(x: cx + 16 * s, y: cy + 36 * s),
                control2: CGPoint(x: cx + 44 * s, y: cy - 8 * s)
            )
            rightWing.closeSubpath()
            ctx.fill(
                rightWing,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.01, green: 0.52, blue: 0.78), Color(red: 0.22, green: 0.74, blue: 0.97)]),
                    startPoint: CGPoint(x: cx + 68 * s, y: cy - 68 * s),
                    endPoint: CGPoint(x: cx, y: cy + 54 * s)
                )
            )

            let rightDot = Path(ellipseIn: CGRect(x: cx + 48 * s, y: cy - 82 * s, width: 20 * s, height: 20 * s))
            ctx.fill(rightDot, with: .color(Color(red: 0.18, green: 0.74, blue: 0.98)))

            // Cœur central : Solidarités & Union Cenelis (Ambre / Or)
            var centerHeart = Path()
            centerHeart.move(to: CGPoint(x: cx, y: cy + 64 * s))
            centerHeart.addCurve(
                to: CGPoint(x: cx, y: cy - 12 * s),
                control1: CGPoint(x: cx - 22 * s, y: cy + 10 * s),
                control2: CGPoint(x: cx - 18 * s, y: cy - 26 * s)
            )
            centerHeart.addCurve(
                to: CGPoint(x: cx, y: cy + 64 * s),
                control1: CGPoint(x: cx + 18 * s, y: cy - 26 * s),
                control2: CGPoint(x: cx + 22 * s, y: cy + 10 * s)
            )
            centerHeart.closeSubpath()
            ctx.fill(
                centerHeart,
                with: .linearGradient(
                    Gradient(colors: [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.99, green: 0.78, blue: 0.18)]),
                    startPoint: CGPoint(x: cx, y: cy - 20 * s),
                    endPoint: CGPoint(x: cx, y: cy + 64 * s)
                )
            )

            let centerDot = Path(ellipseIn: CGRect(x: cx - 9.5 * s, y: cy - 34 * s, width: 19 * s, height: 19 * s))
            ctx.fill(centerDot, with: .color(Color(red: 0.98, green: 0.72, blue: 0.14)))
        }
    }
}

// MARK: - Anneaux Orbitaux 3D, Sillages Cométaires & Faisceaux Radiaux (120fps Canvas)

private struct CenelisOrbitalRingsCanvas: View {
    let elapsed: Double
    let orbitRadius: CGFloat
    let tiltRatio: CGFloat
    let baseAngle: Double
    let appCount: Int
    let introProgress: CGFloat
    let lockProgress: Double
    let accentColor: Color

    var body: some View {
        Canvas { ctx, size in
            let cx = size.width * 0.5
            let cy = size.height * 0.5
            let rx = orbitRadius * introProgress
            let ry = rx * tiltRatio
            let fade = max(0, 1.0 - lockProgress * 1.15)
            guard rx > 4, fade > 0.01 else { return }

            // 1. Anneau orbital principal en ellipse 3D
            let mainRect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            let mainRing = Path(ellipseIn: mainRect)
            ctx.stroke(
                mainRing,
                with: .color(Color.white.opacity(0.15 * fade)),
                style: StrokeStyle(lineWidth: 1.2)
            )

            // 2. Anneau externe technique pointillé (inspiration grille architecturale Cenelis)
            let outerRx = rx * 1.19
            let outerRy = ry * 1.19
            let outerRect = CGRect(x: cx - outerRx, y: cy - outerRy, width: outerRx * 2, height: outerRy * 2)
            let outerRing = Path(ellipseIn: outerRect)
            ctx.stroke(
                outerRing,
                with: .color(accentColor.opacity(0.22 * fade)),
                style: StrokeStyle(lineWidth: 1.0, dash: [4, 7], dashPhase: CGFloat(-elapsed * 28.0))
            )

            // 3. Anneau interne subtil
            let innerRx = rx * 0.62
            let innerRy = ry * 0.62
            let innerRect = CGRect(x: cx - innerRx, y: cy - innerRy, width: innerRx * 2, height: innerRy * 2)
            ctx.stroke(
                Path(ellipseIn: innerRect),
                with: .color(Color(red: 0.16, green: 0.84, blue: 0.62).opacity(0.16 * fade)),
                style: StrokeStyle(lineWidth: 0.9, dash: [2, 5], dashPhase: CGFloat(elapsed * 20.0))
            )

            // 4. Rayons énergétiques reliant le cœur Cenelis × Viple à chaque application
            for i in 0..<appCount {
                let theta = baseAngle + (2.0 * Double.pi * Double(i)) / Double(appCount)
                let px = cx + CGFloat(cos(theta)) * rx
                let py = cy + CGFloat(sin(theta)) * ry

                var spoke = Path()
                spoke.move(to: CGPoint(x: cx, y: cy))
                spoke.addLine(to: CGPoint(x: px, y: py))
                ctx.stroke(
                    spoke,
                    with: .color(Color.white.opacity(0.07 * fade)),
                    style: StrokeStyle(lineWidth: 0.8)
                )

                // Impulsion lumineuse voyageant du cœur vers chaque icône
                let pulsePos = ((elapsed * 1.15) + Double(i) * 0.125).truncatingRemainder(dividingBy: 1.0)
                let dotX = cx + (px - cx) * CGFloat(pulsePos)
                let dotY = cy + (py - cy) * CGFloat(pulsePos)
                let dotRect = CGRect(x: dotX - 2.2, y: dotY - 2.2, width: 4.4, height: 4.4)
                ctx.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(accentColor.opacity(0.65 * (1.0 - pulsePos * 0.5) * fade))
                )
            }

            // 5. Deux arcs cométaires lumineux courant sur l'ellipse principale
            for cometIndex in 0..<2 {
                let headAngle = elapsed * 2.6 + Double(cometIndex) * Double.pi
                let segments = 18
                for s in 0..<segments {
                    let frac0 = Double(s) / Double(segments)
                    let frac1 = Double(s + 1) / Double(segments)
                    let a0 = headAngle - frac0 * 0.85
                    let a1 = headAngle - frac1 * 0.85
                    var seg = Path()
                    seg.move(to: CGPoint(x: cx + CGFloat(cos(a0)) * rx, y: cy + CGFloat(sin(a0)) * ry))
                    seg.addLine(to: CGPoint(x: cx + CGFloat(cos(a1)) * rx, y: cy + CGFloat(sin(a1)) * ry))
                    let alpha = (1.0 - frac0) * 0.55 * fade
                    let col = cometIndex == 0 ? accentColor : Color(red: 0.16, green: 0.88, blue: 0.64)
                    ctx.stroke(seg, with: .color(col.opacity(alpha)), style: StrokeStyle(lineWidth: 2.4 * CGFloat(1.0 - frac0 * 0.6), lineCap: .round))
                }
            }
        }
    }
}

// MARK: - Fond Cosmique & Grille Architecturale Cenelis (120fps Canvas)

private struct CenelisCosmicBackdropCanvas: View {
    let elapsed: Double
    let accentGlow: Color
    let lockProgress: Double

    var body: some View {
        ZStack {
            // Base nuit saphir profond (identique en clair/sombre pour un contraste cinématographique maximal)
            LinearGradient(
                colors: [
                    Color(red: 0.020, green: 0.035, blue: 0.082),
                    Color(red: 0.035, green: 0.075, blue: 0.165),
                    Color(red: 0.024, green: 0.095, blue: 0.125)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { ctx, size in
                let w = size.width
                let h = size.height

                // 1. Nébuleuses volumétriques respirantes (Viple Indigo + Tech Cyan + Émeraude Cenelis)
                let orb1Center = CGPoint(
                    x: w * (0.28 + 0.10 * CGFloat(sin(elapsed * 0.9))),
                    y: h * (0.26 + 0.06 * CGFloat(cos(elapsed * 0.7)))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: orb1Center.x - w * 0.55, y: orb1Center.y - w * 0.55, width: w * 1.1, height: w * 1.1)),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 0.24, green: 0.22, blue: 0.86).opacity(0.28), Color.clear]),
                        center: orb1Center,
                        startRadius: 10,
                        endRadius: w * 0.55
                    )
                )

                let orb2Center = CGPoint(
                    x: w * (0.74 + 0.08 * CGFloat(cos(elapsed * 0.8))),
                    y: h * (0.66 + 0.07 * CGFloat(sin(elapsed * 0.6)))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: orb2Center.x - w * 0.55, y: orb2Center.y - w * 0.55, width: w * 1.1, height: w * 1.1)),
                    with: .radialGradient(
                        Gradient(colors: [Color(red: 0.06, green: 0.56, blue: 0.44).opacity(0.24), Color.clear]),
                        center: orb2Center,
                        startRadius: 10,
                        endRadius: w * 0.55
                    )
                )

                // Halo central qui s'intensifie dans la teinte de l'application cible lors du verrouillage
                let centerPt = CGPoint(x: w * 0.5, y: h * 0.5)
                let focusRadius = w * (0.48 + 0.25 * CGFloat(lockProgress))
                ctx.fill(
                    Path(ellipseIn: CGRect(x: centerPt.x - focusRadius, y: centerPt.y - focusRadius, width: focusRadius * 2, height: focusRadius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [accentGlow.opacity(0.18 + 0.26 * lockProgress), Color.clear]),
                        center: centerPt,
                        startRadius: 4,
                        endRadius: focusRadius
                    )
                )

                // 2. Grille architecturale subtile (clin d'œil à l'identité Cenelis Workspace)
                let gridSpacing: CGFloat = 44
                var gridPath = Path()
                var gx: CGFloat = (w.truncatingRemainder(dividingBy: gridSpacing)) * 0.5
                while gx < w {
                    gridPath.move(to: CGPoint(x: gx, y: 0))
                    gridPath.addLine(to: CGPoint(x: gx, y: h))
                    gx += gridSpacing
                }
                var gy: CGFloat = (h.truncatingRemainder(dividingBy: gridSpacing)) * 0.5
                while gy < h {
                    gridPath.move(to: CGPoint(x: 0, y: gy))
                    gridPath.addLine(to: CGPoint(x: w, y: gy))
                    gy += gridSpacing
                }
                ctx.stroke(gridPath, with: .color(Color.white.opacity(0.028)), style: StrokeStyle(lineWidth: 0.6))

                // 3. Particules stellaires en lévitation douce
                for i in 0..<26 {
                    let seed = Double(i) * 1.6180339
                    let baseX = (sin(seed * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1.0)
                    let baseY = (cos(seed * 78.233) * 29432.1234).truncatingRemainder(dividingBy: 1.0)
                    let normX = abs(baseX)
                    let normY = abs(baseY)

                    let driftY = (normY - elapsed * (0.022 + Double(i % 4) * 0.006)).truncatingRemainder(dividingBy: 1.0)
                    let wrappedY = driftY < 0 ? driftY + 1.0 : driftY
                    let px = CGFloat(normX) * w + CGFloat(sin(elapsed * 1.3 + seed)) * 8.0
                    let py = CGFloat(wrappedY) * h

                    let twinkle = 0.25 + 0.55 * (0.5 + 0.5 * sin(elapsed * 3.1 + seed * 5.0))
                    let dotSize = CGFloat(1.6 + Double(i % 3) * 0.9)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px - dotSize * 0.5, y: py - dotSize * 0.5, width: dotSize, height: dotSize)),
                        with: .color(Color.white.opacity(twinkle * 0.55))
                    )
                }
            }
        }
    }
}
