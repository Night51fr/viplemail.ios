import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Expérience Native 100 % « Cenelis Academy » Embarquée dans l'Aide Viple Mail iOS
// Récupère en direct le cours « Bienvenue sur Viple Mail, Visio, MailRTE » depuis https://academy.prod.cenelis.com
// et reproduit à l'identique la palette minérale Pin & Cuivre, la typographie, le lecteur Fluide/Focus,
// les bulles de vulgarisation {{...}}, la ré-explication et l'évaluation 4 onglets (Quiz + Lacunes -> 100%).

private enum EmbeddedAcademyPalette {
    static func dyn(_ light: (Double, Double, Double), _ dark: (Double, Double, Double)) -> Color {
        #if canImport(UIKit)
        return Color(UIColor { tr in
            let c = tr.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1.0)
        })
        #else
        return Color(red: light.0, green: light.1, blue: light.2)
        #endif
    }

    static let pine = dyn((0.078, 0.325, 0.275), (0.196, 0.765, 0.612))          // #145346 / #32C39C
    static let pineSolid = Color(red: 0.078, green: 0.325, blue: 0.275)          // #145346
    static let pineDeep = Color(red: 0.047, green: 0.204, blue: 0.173)           // #0C342C
    static let pineSoft = dyn((0.914, 0.961, 0.945), (0.090, 0.215, 0.184))
    static let pineBorder = dyn((0.745, 0.882, 0.843), (0.165, 0.380, 0.325))

    static let copper = dyn((0.722, 0.365, 0.098), (0.945, 0.576, 0.235))        // #B85D19 / #F1933C
    static let copperSolid = Color(red: 0.722, green: 0.365, blue: 0.098)
    static let copperSoft = dyn((0.992, 0.949, 0.902), (0.245, 0.145, 0.075))
    static let copperBorder = dyn((0.953, 0.816, 0.678), (0.485, 0.285, 0.145))

    static let gold = Color(red: 0.945, green: 0.733, blue: 0.212)               // #F1BB36

    static let background = dyn((0.980, 0.973, 0.957), (0.039, 0.082, 0.071))    // #FAF8F4 / #0A1512
    static let surface = dyn((1.000, 1.000, 1.000), (0.071, 0.137, 0.118))       // #FFFFFF / #12231E
    static let surfaceSubtle = dyn((0.953, 0.945, 0.922), (0.098, 0.180, 0.157))
    static let border = dyn((0.878, 0.867, 0.835), (0.165, 0.267, 0.235))

    static let ink = dyn((0.075, 0.125, 0.110), (0.949, 0.973, 0.965))
    static let inkSecondary = dyn((0.325, 0.392, 0.369), (0.675, 0.765, 0.733))
    static let inkMuted = dyn((0.510, 0.569, 0.549), (0.475, 0.569, 0.537))

    static let success = dyn((0.082, 0.502, 0.239), (0.204, 0.827, 0.600))
    static let successSoft = dyn((0.925, 0.992, 0.961), (0.075, 0.235, 0.175))
    static let danger = dyn((0.725, 0.110, 0.110), (0.973, 0.443, 0.443))
    static let dangerSoft = dyn((0.996, 0.949, 0.949), (0.255, 0.095, 0.095))

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.090, green: 0.365, blue: 0.306),
                Color(red: 0.051, green: 0.220, blue: 0.184),
                Color(red: 0.035, green: 0.145, blue: 0.122)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var copperGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.847, green: 0.447, blue: 0.157),
                Color(red: 0.659, green: 0.314, blue: 0.071)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func sfSymbol(for webIcon: String?) -> String {
        switch webIcon ?? "" {
        case "mail": return "envelope.fill"
        case "users": return "person.3.fill"
        case "userCheck": return "person.badge.shield.checkmark.fill"
        case "video": return "play.rectangle.fill"
        case "calendar": return "calendar"
        case "shieldCheck": return "checkmark.shield.fill"
        case "shield": return "shield.lefthalf.filled"
        case "sparkles": return "sparkles"
        case "zap": return "bolt.fill"
        case "globe": return "globe.europe.africa.fill"
        case "lock": return "lock.shield.fill"
        case "share2", "send": return "paperplane.fill"
        case "award": return "medal.fill"
        case "messageSquare": return "bubble.left.and.bubble.right.fill"
        case "checkCircle": return "checkmark.circle.fill"
        default: return "graduationcap.fill"
        }
    }
}

// MARK: - Modèles JSON API Cenelis Academy

private struct AcademyPublicCourseEnvelope: Codable, Sendable {
    let ok: Bool
    let contentVersion: String?
    let course: EmbeddedAcademyCourse?
    let bubbles: [String: EmbeddedAcademyBubble]?
}

private struct EmbeddedAcademyBubble: Codable, Identifiable, Sendable {
    var id: String { q + title }
    let q: String
    let title: String
    let analogy: String
    let def: String
    let why: String
}

private struct EmbeddedAcademyShortcut: Codable, Sendable {
    let label: String
    let range: [Int]
    let icon: String?
}

private struct EmbeddedAcademyChapter: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let range: [Int]
    let icon: String?
}

private struct EmbeddedAcademyReexplain: Codable, Sendable {
    let analogy: String?
    let simple: String?
    let example: String?
    let essential: String?
}

private struct EmbeddedAcademyFlowStep: Codable, Sendable {
    let icon: String?
    let tag: String?
    let title: String
    let text: String
}

private struct EmbeddedAcademyBlock: Codable, Sendable {
    let type: String
    let icon: String?
    let heading: String?
    let intro: String?
    let paragraphs: [String]?
    let text: String?
    let variant: String?
    let title: String?
    let steps: [EmbeddedAcademyFlowStep]?
    let items: [EmbeddedBlockPolyItem]?
    let headers: [String]?
    let rows: [[String]]?
}

private struct EmbeddedBlockPolyItem: Codable, Sendable {
    let icon: String?
    let label: String?
    let whereLocation: String?
    let desc: String?
    let code: String?
    let title: String?
    let def: String?
    let tag: String?
    let steps: [String]?

    enum CodingKeys: String, CodingKey {
        case icon, label, desc, code, title, def, tag, steps
        case whereLocation = "where"
    }
}

private struct EmbeddedAcademyPart: Codable, Identifiable, Sendable {
    let id: String
    let chapter: Int?
    let title: String
    let duration: String?
    let summary: String?
    let blocks: [EmbeddedAcademyBlock]
    let reexplain: EmbeddedAcademyReexplain?
}

private struct EmbeddedAcademyRemediation: Codable, Sendable {
    let q: String
    let options: [String]
    let correct: Int
    let successNote: String?
}

private struct EmbeddedAcademyQuizQuestion: Codable, Sendable {
    let topic: String?
    let partIdx: Int?
    let q: String
    let options: [String]
    let correct: Int
    let whyWrong: String?
    let explain: String?
    let remediation: EmbeddedAcademyRemediation?
}

private struct EmbeddedAcademyCourse: Codable, Sendable {
    let id: String
    let number: String?
    let passThresholdPct: Int?
    let badgeLabel: String?
    let icon: String?
    let duration: String?
    let title: String
    let subtitle: String?
    let shortcutBannerTitle: String?
    let shortcutBannerSubtitle: String?
    let roleShortcuts: [EmbeddedAcademyShortcut]?
    let chapters: [EmbeddedAcademyChapter]?
    let parts: [EmbeddedAcademyPart]
    let quiz: [EmbeddedAcademyQuizQuestion]
}

// MARK: - Composants Signature Cenelis Academy (Badges, Constellation Orbitale, Confettis)

private struct EmbeddedAcademyBadge: View {
    enum Style { case pine, copper, success, gold, muted }
    let text: String
    var icon: String? = nil
    var style: Style = .pine

    var body: some View {
        let (fg, bg, brd): (Color, Color, Color) = {
            switch style {
            case .pine: return (EmbeddedAcademyPalette.pine, EmbeddedAcademyPalette.pineSoft, EmbeddedAcademyPalette.pineBorder)
            case .copper: return (EmbeddedAcademyPalette.copper, EmbeddedAcademyPalette.copperSoft, EmbeddedAcademyPalette.copperBorder)
            case .success: return (EmbeddedAcademyPalette.success, EmbeddedAcademyPalette.successSoft, EmbeddedAcademyPalette.success.opacity(0.35))
            case .gold: return (Color(red: 0.45, green: 0.30, blue: 0.02), EmbeddedAcademyPalette.gold.opacity(0.24), EmbeddedAcademyPalette.gold.opacity(0.55))
            case .muted: return (EmbeddedAcademyPalette.inkSecondary, EmbeddedAcademyPalette.surfaceSubtle, EmbeddedAcademyPalette.border)
            }
        }()

        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
            }
            Text(text)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 9)
        .padding(.vertical, 4.5)
        .background(Capsule(style: .continuous).fill(bg))
        .overlay(Capsule(style: .continuous).stroke(brd, lineWidth: 1))
    }
}

private struct EmbeddedMasteryRing: View {
    let percent: Double
    let size: CGFloat
    var ringColor: Color = EmbeddedAcademyPalette.gold

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: CGFloat(min(1.0, max(0.0, percent / 100.0))))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(percent.rounded()))%")
                .font(.system(size: size * 0.25, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

private struct EmbeddedOrbitalHeroBanner: View {
    let course: EmbeddedAcademyCourse
    let completedCount: Int
    let xpEarned: Int
    let onStartOrResume: () -> Void

    var body: some View {
        let total = max(1, course.parts.count)
        let pct = Double(completedCount) / Double(total) * 100.0

        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(EmbeddedAcademyPalette.heroGradient)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let center = CGPoint(x: size.width * 0.82, y: size.height * 0.34)
                    for i in 0..<3 {
                        let rx = CGFloat(42 + i * 28)
                        let ry = CGFloat(24 + i * 16)
                        let rect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
                        var p = Path()
                        p.addEllipse(in: rect)
                        ctx.stroke(p, with: .color(.white.opacity(0.11)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

                        let angle = t * (0.55 - Double(i) * 0.12) + Double(i) * 2.1
                        let sx = center.x + CGFloat(cos(angle)) * rx
                        let sy = center.y + CGFloat(sin(angle)) * ry
                        let dotRect = CGRect(x: sx - 3.5, y: sy - 3.5, width: 7, height: 7)
                        ctx.fill(Path(ellipseIn: dotRect), with: .color(EmbeddedAcademyPalette.gold))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(EmbeddedAcademyPalette.gold)
                        Text("CENELIS ACADEMY • PARCOURS OFFICIEL")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .tracking(0.7)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.14)))

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(EmbeddedAcademyPalette.gold)
                        Text("\(xpEarned) XP")
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.24)))
                }

                Text(course.title)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                if let sub = course.subtitle {
                    Text(sub)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(3)
                }

                HStack(spacing: 14) {
                    EmbeddedMasteryRing(percent: pct, size: 52)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(completedCount) / \(course.parts.count) pages assimilées • \(course.duration ?? "14 min")")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.18)).frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [EmbeddedAcademyPalette.gold, EmbeddedAcademyPalette.copperSolid], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, geo.size.width * CGFloat(pct / 100.0)), height: 6)
                            }
                        }
                        .frame(height: 6)
                    }

                    Button(action: onStartOrResume) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill")
                            Text(completedCount == 0 ? "Démarrer" : "Continuer")
                        }
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.pineDeep)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(EmbeddedAcademyPalette.gold))
                    }
                }
            }
            .padding(20)
        }
    }
}

// MARK: - Vue Principale « CenelisAcademyHelpView » (100 % identique à Cenelis Academy iOS + Retour vers Viple Mail)

public struct CenelisAcademyHelpView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading: Bool = true
    @State private var course: EmbeddedAcademyCourse? = nil
    @State private var bubbles: [String: EmbeddedAcademyBubble] = [:]
    @State private var loadError: String? = nil

    // État du lecteur Academy
    @State private var isOverviewMode: Bool = false
    @State private var activeStepIndex: Int = 0 // 0..<parts.count = leçons, parts.count = Évaluation Finale
    @State private var isFocusDeckMode: Bool = false
    @State private var isShowingTocSheet: Bool = false
    @State private var activeBubbleSheet: EmbeddedAcademyBubble? = nil
    @State private var expandedReexplainPartIds: Set<String> = []
    @State private var unclearPartIds: Set<String> = []
    @State private var completedPartIds: Set<String> = []
    @State private var xpPoints: Int = 0
    @State private var xpToastText: String? = nil

    // État de l'évaluation 4 onglets (Quiz + Rattrapage 100 %)
    @State private var evalTab: Int = 0
    @State private var selectedQuizAnswers: [Int: Int] = [:]
    @State private var quizSubmitted: Bool = false
    @State private var remediatedQuestionIndices: Set<Int> = []
    @State private var remediationSelectedOption: [Int: Int] = [:]
    @State private var showConfetti: Bool = false

    private let progressDefaultsKey = "viplemail.academy.help.completed.v1"
    private let xpDefaultsKey = "viplemail.academy.help.xp.v1"

    public init() {}

    public var body: some View {
        ZStack {
            EmbeddedAcademyPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                academyNavigationBar

                if let course {
                    progressBarStrip(course: course)

                    if isOverviewMode {
                        courseCatalogOverview(course: course)
                    } else if activeStepIndex < course.parts.count {
                        let part = course.parts[activeStepIndex]
                        if isFocusDeckMode {
                            focusDeckReader(course: course, part: part)
                        } else {
                            fluidLessonReader(course: course, part: part)
                        }
                        readerStickyBottomBar(course: course, part: part)
                    } else {
                        evaluationFourTabsView(course: course)
                    }
                } else if isLoading {
                    Spacer()
                    VStack(spacing: 14) {
                        ProgressView()
                            .tint(EmbeddedAcademyPalette.pine)
                            .scaleEffect(1.2)
                        Text("Chargement du cours depuis Cenelis Academy…")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    }
                    Spacer()
                } else {
                    Spacer()
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(EmbeddedAcademyPalette.copper)
                        Text(loadError ?? "Impossible de joindre Cenelis Academy.")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") {
                            Task { await loadCourseFromAcademyApi() }
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(EmbeddedAcademyPalette.pineSolid))
                    }
                    .padding(24)
                    Spacer()
                }
            }

            if let toast = xpToastText {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(EmbeddedAcademyPalette.gold)
                        Text(toast)
                            .font(.system(size: 13.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(EmbeddedAcademyPalette.pineDeep))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                    .padding(.top, 58)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(50)
            }

            if showConfetti {
                EmbeddedConfettiOverlay()
                    .allowsHitTesting(false)
                    .zIndex(60)
            }
        }
        .task {
            restoreSavedProgress()
            await loadCourseFromAcademyApi()
        }
        .sheet(isPresented: $isShowingTocSheet) {
            if let course {
                tocDrawerSheet(course: course)
            }
        }
        .sheet(item: $activeBubbleSheet) { bubble in
            bubbleExplainerModal(bubble)
        }
    }

    // MARK: - En-tête identitaire Cenelis Academy avec bouton Retour vers Viple Mail

    private var academyNavigationBar: some View {
        HStack(spacing: 10) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .black))
                    Text("Retour")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(EmbeddedAcademyPalette.pine)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(EmbeddedAcademyPalette.pineSoft))
                .overlay(Capsule().stroke(EmbeddedAcademyPalette.pineBorder, lineWidth: 1))
            }

            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(EmbeddedAcademyPalette.pineSolid)
                        .frame(width: 28, height: 28)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(EmbeddedAcademyPalette.gold)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("CENELIS")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(EmbeddedAcademyPalette.copper)
                    Text("Academy")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)
                }
            }

            Spacer()

            if let course {
                Button {
                    isShowingTocSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 12, weight: .bold))
                        Text(activeStepIndex < course.parts.count
                             ? "Page \(activeStepIndex + 1)/\(course.parts.count)"
                             : "Quiz Final")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(EmbeddedAcademyPalette.pine)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6.5)
                    .background(Capsule().fill(EmbeddedAcademyPalette.pineSoft))
                }

                if activeStepIndex < course.parts.count && !isOverviewMode {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isFocusDeckMode.toggle()
                        }
                    } label: {
                        Image(systemName: isFocusDeckMode ? "rectangle.stack.fill" : "text.page.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(EmbeddedAcademyPalette.copper)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(EmbeddedAcademyPalette.copperSoft))
                    }
                    .accessibilityLabel(isFocusDeckMode ? "Mode Fluide" : "Mode Focus")
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(EmbeddedAcademyPalette.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(EmbeddedAcademyPalette.border).frame(height: 1)
        }
    }

    private func progressBarStrip(course: EmbeddedAcademyCourse) -> some View {
        let totalSteps = max(1, course.parts.count + 1)
        let frac = CGFloat(min(totalSteps, activeStepIndex + 1)) / CGFloat(totalSteps)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(EmbeddedAcademyPalette.pineSoft)
                Rectangle()
                    .fill(LinearGradient(
                        colors: [EmbeddedAcademyPalette.pineSolid, EmbeddedAcademyPalette.copperSolid],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geo.size.width * frac)
                    .animation(.spring(response: 0.4, dampingFraction: 0.82), value: activeStepIndex)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Vue d'ensemble optionnelle + Lecteur Fluide Cenelis Academy

    private func courseCatalogOverview(course: EmbeddedAcademyCourse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                EmbeddedOrbitalHeroBanner(
                    course: course,
                    completedCount: completedPartIds.count,
                    xpEarned: xpPoints
                ) {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        isOverviewMode = false
                    }
                }

                ForEach(course.chapters ?? []) { ch in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(ch.title)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                        let startIdx = ch.range.first ?? 0
                        let endIdx = min(course.parts.count - 1, ch.range.last ?? startIdx)
                        if startIdx <= endIdx {
                            ForEach(startIdx...endIdx, id: \.self) { idx in
                                let p = course.parts[idx]
                                Button {
                                    activeStepIndex = idx
                                    isOverviewMode = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: completedPartIds.contains(p.id) ? "checkmark.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(completedPartIds.contains(p.id) ? EmbeddedAcademyPalette.success : EmbeddedAcademyPalette.pine)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(idx + 1). \(p.title)")
                                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                                .foregroundStyle(EmbeddedAcademyPalette.ink)
                                                .multilineTextAlignment(.leading)
                                            Text(p.duration ?? "2 min")
                                                .font(.system(size: 12))
                                                .foregroundStyle(EmbeddedAcademyPalette.inkMuted)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(EmbeddedAcademyPalette.inkMuted)
                                    }
                                    .padding(14)
                                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(EmbeddedAcademyPalette.surface))
                                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func fluidLessonReader(course: EmbeddedAcademyCourse, part: EmbeddedAcademyPart) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Color.clear.frame(height: 1).id("ACADEMY_TOP")

                    if activeStepIndex == 0 {
                        EmbeddedOrbitalHeroBanner(
                            course: course,
                            completedCount: completedPartIds.count,
                            xpEarned: xpPoints
                        ) {
                            isShowingTocSheet = true
                        }

                        if let shortcuts = course.roleShortcuts, !shortcuts.isEmpty {
                            shortcutsBanner(course: course, shortcuts: shortcuts)
                        }
                    }

                    pageHeroCard(course: course, part: part)

                    ForEach(Array(part.blocks.enumerated()), id: \.offset) { _, block in
                        renderBlock(block)
                    }

                    pedagogicalSupportSection(part: part)
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .onChange(of: activeStepIndex) { _, _ in
                withAnimation {
                    proxy.scrollTo("ACADEMY_TOP", anchor: .top)
                }
            }
        }
    }

    private func focusDeckReader(course: EmbeddedAcademyCourse, part: EmbeddedAcademyPart) -> some View {
        TabView {
            VStack(alignment: .leading, spacing: 14) {
                EmbeddedAcademyBadge(text: "Carte d'introduction", icon: "sparkles", style: .copper)
                pageHeroCard(course: course, part: part)
                Spacer()
            }
            .padding(16)

            ForEach(Array(part.blocks.enumerated()), id: \.offset) { bIdx, block in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        EmbeddedAcademyBadge(text: "Carte \(bIdx + 1) / \(part.blocks.count)", icon: "rectangle.stack.fill", style: .copper)
                        renderBlock(block)
                    }
                    .padding(16)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }

    private func shortcutsBanner(course: EmbeddedAcademyCourse, shortcuts: [EmbeddedAcademyShortcut]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(course.shortcutBannerTitle ?? "Accès rapide par rubrique")
                .font(.system(size: 14.5, weight: .black, design: .rounded))
                .foregroundStyle(EmbeddedAcademyPalette.copper)
            if let sub = course.shortcutBannerSubtitle {
                Text(sub)
                    .font(.system(size: 12.5))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, sc in
                        Button {
                            if let target = sc.range.first, target < course.parts.count {
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                                    activeStepIndex = target
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: EmbeddedAcademyPalette.sfSymbol(for: sc.icon))
                                    .font(.system(size: 11.5, weight: .bold))
                                Text(sc.label)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(EmbeddedAcademyPalette.pineSolid))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.copperSoft))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.copperBorder, lineWidth: 1))
    }

    private func pageHeroCard(course: EmbeddedAcademyCourse, part: EmbeddedAcademyPart) -> some View {
        let isDone = completedPartIds.contains(part.id)
        let chapterTitle = course.chapters?.first(where: { $0.id == part.chapter })?.title ?? "Chapitre \(part.chapter ?? 1)"

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                EmbeddedAcademyBadge(text: chapterTitle, icon: "bookmark.fill", style: .pine)
                Spacer()
                if let dur = part.duration {
                    EmbeddedAcademyBadge(text: dur, icon: "clock.fill", style: .muted)
                }
            }

            Text(part.title)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(EmbeddedAcademyPalette.ink)

            if let summary = part.summary {
                Text(summary)
                    .font(.system(size: 14.5))
                    .lineSpacing(4)
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
            }

            if isDone {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Page déjà assimilée (+25 XP acquis)")
                }
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(EmbeddedAcademyPalette.success)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    // MARK: - Rendu Polymorphique des Blocs Cenelis Academy

    @ViewBuilder
    private func renderBlock(_ block: EmbeddedAcademyBlock) -> some View {
        switch block.type {
        case "prose":
            proseCard(block)
        case "callout":
            calloutCard(block)
        case "visual_flow":
            visualFlowCard(block)
        case "ui_buttons":
            uiButtonsCard(block)
        case "terms":
            termsCard(block)
        case "scenarios":
            scenariosCard(block)
        case "table":
            tableCard(block)
        default:
            EmptyView()
        }
    }

    private func proseCard(_ block: EmbeddedAcademyBlock) -> some View {
        let paragraphs = block.paragraphs ?? (block.text != nil ? [block.text!] : [])
        let detectedBubbles = extractBubbleKeys(from: paragraphs.joined(separator: " "))

        return VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading {
                HStack(spacing: 8) {
                    Image(systemName: EmbeddedAcademyPalette.sfSymbol(for: block.icon))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(EmbeddedAcademyPalette.pine)
                    Text(heading)
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)
                }
            }

            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, p in
                Text(formatAcademyInlineMarkdown(p))
                    .font(.system(size: 15.5, weight: .regular))
                    .lineSpacing(5)
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }

            if !detectedBubbles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detectedBubbles, id: \.key) { item in
                            Button {
                                if let found = bubbles[item.key] {
                                    activeBubbleSheet = found
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: "questionmark.bubble.fill")
                                    Text("C'est quoi : \(item.label) ?")
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(EmbeddedAcademyPalette.copper)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background(Capsule().fill(EmbeddedAcademyPalette.copperSoft))
                                .overlay(Capsule().stroke(EmbeddedAcademyPalette.copperBorder, lineWidth: 1))
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    private func calloutCard(_ block: EmbeddedAcademyBlock) -> some View {
        let isCopper = block.variant == "copper" || block.variant == "amber" || block.variant == "warn"
        let bg = isCopper ? EmbeddedAcademyPalette.copperSoft : EmbeddedAcademyPalette.pineSoft
        let brd = isCopper ? EmbeddedAcademyPalette.copperBorder : EmbeddedAcademyPalette.pineBorder
        let accent = isCopper ? EmbeddedAcademyPalette.copper : EmbeddedAcademyPalette.pine

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: EmbeddedAcademyPalette.sfSymbol(for: block.icon))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                Text(block.title ?? "À retenir")
                    .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
            }
            if let text = block.text {
                Text(formatAcademyInlineMarkdown(text))
                    .font(.system(size: 14.5))
                    .lineSpacing(4)
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(bg))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(brd, lineWidth: 1))
    }

    private func visualFlowCard(_ block: EmbeddedAcademyBlock) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
            if let intro = block.intro {
                Text(intro)
                    .font(.system(size: 13.5))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
            }
            ForEach(Array((block.steps ?? []).enumerated()), id: \.offset) { idx, st in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(EmbeddedAcademyPalette.pineSoft)
                            .frame(width: 40, height: 40)
                        Image(systemName: EmbeddedAcademyPalette.sfSymbol(for: st.icon))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(EmbeddedAcademyPalette.pine)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let tag = st.tag {
                            Text(tag.uppercased())
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(EmbeddedAcademyPalette.copper)
                        }
                        Text(st.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                        Text(st.text)
                            .font(.system(size: 13.5))
                            .lineSpacing(3)
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    }
                }
                if idx < (block.steps?.count ?? 0) - 1 {
                    Divider()
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    private func uiButtonsCard(_ block: EmbeddedAcademyBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
            if let intro = block.intro {
                Text(intro)
                    .font(.system(size: 13.5))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
            }
            ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, it in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: EmbeddedAcademyPalette.sfSymbol(for: it.icon))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(EmbeddedAcademyPalette.pineSolid))
                        Text(it.label ?? "")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                        Spacer()
                        if let w = it.whereLocation {
                            EmbeddedAcademyBadge(text: w, style: .copper)
                        }
                    }
                    if let desc = it.desc {
                        Text(desc)
                            .font(.system(size: 13.5))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(EmbeddedAcademyPalette.surfaceSubtle))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    private func termsCard(_ block: EmbeddedAcademyBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
            ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, it in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(it.code ?? "")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(EmbeddedAcademyPalette.pine)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 7).fill(EmbeddedAcademyPalette.pineSoft))
                        Text(it.title ?? "")
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                    }
                    if let def = it.def {
                        Text(def)
                            .font(.system(size: 13.5))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(EmbeddedAcademyPalette.surfaceSubtle))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    private func scenariosCard(_ block: EmbeddedAcademyBlock) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
            ForEach(Array((block.items ?? []).enumerated()), id: \.offset) { _, sc in
                VStack(alignment: .leading, spacing: 8) {
                    if let tag = sc.tag {
                        EmbeddedAcademyBadge(text: tag, style: .copper)
                    }
                    Text(sc.title ?? "")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)
                    ForEach(Array((sc.steps ?? []).enumerated()), id: \.offset) { sIdx, line in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(sIdx + 1).")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundStyle(EmbeddedAcademyPalette.pine)
                            Text(line)
                                .font(.system(size: 13.5))
                                .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(EmbeddedAcademyPalette.surfaceSubtle))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    private func tableCard(_ block: EmbeddedAcademyBlock) -> some View {
        let headers = block.headers ?? []
        let rows = block.rows ?? []
        return VStack(alignment: .leading, spacing: 10) {
            if let heading = block.heading {
                Text(heading)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(row.enumerated()), id: \.offset) { cIdx, cell in
                        HStack(alignment: .top, spacing: 6) {
                            if cIdx < headers.count {
                                Text("\(headers[cIdx]) :")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(EmbeddedAcademyPalette.pine)
                            }
                            Text(cell)
                                .font(.system(size: 13.5, weight: cIdx == 0 ? .bold : .regular))
                                .foregroundStyle(EmbeddedAcademyPalette.ink)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(EmbeddedAcademyPalette.surfaceSubtle))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
    }

    // MARK: - Section Pédagogique (« Ré-expliquer plus simplement » & « Pas 100 % clair »)

    private func pedagogicalSupportSection(part: EmbeddedAcademyPart) -> some View {
        let isExpanded = expandedReexplainPartIds.contains(part.id)
        let isUnclear = unclearPartIds.contains(part.id)

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if part.reexplain != nil {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            if isExpanded {
                                expandedReexplainPartIds.remove(part.id)
                            } else {
                                expandedReexplainPartIds.insert(part.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.max.fill")
                                .foregroundStyle(EmbeddedAcademyPalette.gold)
                            Text("Ré-expliquer plus simplement")
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(EmbeddedAcademyPalette.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(EmbeddedAcademyPalette.surface))
                        .overlay(Capsule().stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
                    }
                }

                Button {
                    if isUnclear {
                        unclearPartIds.remove(part.id)
                    } else {
                        unclearPartIds.insert(part.id)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: isUnclear ? "hand.raised.fill" : "hand.raised")
                        Text(isUnclear ? "À revoir en fin de cours" : "Pas 100 % clair")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isUnclear ? EmbeddedAcademyPalette.copper : EmbeddedAcademyPalette.inkSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(isUnclear ? EmbeddedAcademyPalette.copperSoft : EmbeddedAcademyPalette.surfaceSubtle))
                }
            }

            if isExpanded, let rx = part.reexplain {
                VStack(alignment: .leading, spacing: 10) {
                    if let a = rx.analogy {
                        reexplainRow(label: "Analogie du quotidien", text: a, icon: "sparkles")
                    }
                    if let s = rx.simple {
                        reexplainRow(label: "En une phrase toute simple", text: s, icon: "quote.bubble.fill")
                    }
                    if let e = rx.example {
                        reexplainRow(label: "Exemple concret", text: e, icon: "checkmark.seal.fill")
                    }
                    if let es = rx.essential {
                        reexplainRow(label: "L'unique réflexe à garder", text: es, icon: "star.fill")
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(EmbeddedAcademyPalette.copperSoft))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(EmbeddedAcademyPalette.copperBorder, lineWidth: 1))
            }
        }
    }

    private func reexplainRow(label: String, text: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundStyle(EmbeddedAcademyPalette.copper)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(EmbeddedAcademyPalette.ink)
        }
    }

    // MARK: - Barre d'Action Inférieure Cenelis Academy (+25 XP)

    private func readerStickyBottomBar(course: EmbeddedAcademyCourse, part: EmbeddedAcademyPart) -> some View {
        let isLastLesson = activeStepIndex == course.parts.count - 1
        let alreadyDone = completedPartIds.contains(part.id)

        return HStack(spacing: 10) {
            Button {
                if activeStepIndex > 0 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        activeStepIndex -= 1
                    }
                } else {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                        isOverviewMode = true
                    }
                }
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EmbeddedAcademyPalette.ink)
                    .frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(EmbeddedAcademyPalette.surfaceSubtle))
            }

            Button {
                if !alreadyDone {
                    completedPartIds.insert(part.id)
                    xpPoints += 25
                    persistProgress()
                    triggerXpToast("+25 XP • Page assimilée !")
                }
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    activeStepIndex += 1
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: isLastLesson ? "medal.fill" : "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text(isLastLesson
                         ? "Passer au Grand Quiz Final"
                         : (alreadyDone ? "Page suivante" : "J'ai compris · Suivant (+25 XP)"))
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(isLastLesson
                              ? EmbeddedAcademyPalette.copperGradient
                              : LinearGradient(colors: [EmbeddedAcademyPalette.pineSolid, EmbeddedAcademyPalette.pineDeep], startPoint: .leading, endPoint: .trailing))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(EmbeddedAcademyPalette.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(EmbeddedAcademyPalette.border).frame(height: 1)
        }
    }

    // MARK: - Évaluation 4 Onglets Cenelis Academy (Quiz Final + Lacunes -> 100 % + Points flous)

    private func evaluationFourTabsView(course: EmbeddedAcademyCourse) -> some View {
        let totalQ = max(1, course.quiz.count)
        let directCorrect = course.quiz.enumerated().filter { selectedQuizAnswers[$0.offset] == $0.element.correct }.count
        let consolidated = course.quiz.enumerated().filter {
            selectedQuizAnswers[$0.offset] == $0.element.correct || remediatedQuestionIndices.contains($0.offset)
        }.count
        let consolidatedPct = Int((Double(consolidated) / Double(totalQ) * 100.0).rounded())
        let threshold = course.passThresholdPct ?? 75

        return VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    evalTabPill(0, "1. Quiz Final")
                    evalTabPill(1, "2. Lacunes → 100%")
                    evalTabPill(2, "3. Points flous (\(unclearPartIds.count))")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(EmbeddedAcademyPalette.surface)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if quizSubmitted {
                        HStack(spacing: 16) {
                            EmbeddedMasteryRing(
                                percent: Double(consolidatedPct),
                                size: 68,
                                ringColor: consolidatedPct >= threshold ? EmbeddedAcademyPalette.gold : EmbeddedAcademyPalette.copperSolid
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(consolidatedPct == 100
                                     ? "MAÎTRISE INTÉGRALE 100 % VALIDÉE"
                                     : (consolidatedPct >= threshold ? "PARCOURS VALIDÉ (≥ \(threshold) %)" : "CONSOLIDATION EN COURS"))
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .foregroundStyle(EmbeddedAcademyPalette.gold)
                                Text("\(consolidated) / \(totalQ) acquis consolidés (Score initial : \(directCorrect)/\(totalQ))")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                        }
                        .padding(18)
                        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(EmbeddedAcademyPalette.heroGradient))
                    }

                    if evalTab == 0 {
                        quizMainTab(course: course, threshold: threshold)
                    } else if evalTab == 1 {
                        gapsRemediationTab(course: course)
                    } else {
                        unclearPointsTab(course: course)
                    }
                }
                .padding(16)
                .padding(.bottom, 28)
            }
        }
    }

    private func evalTabPill(_ idx: Int, _ label: String) -> some View {
        let active = evalTab == idx
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                evalTab = idx
            }
        } label: {
            Text(label)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundStyle(active ? .white : EmbeddedAcademyPalette.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Capsule().fill(active ? EmbeddedAcademyPalette.pineSolid : EmbeddedAcademyPalette.surfaceSubtle))
        }
    }

    private func quizMainTab(course: EmbeddedAcademyCourse, threshold: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(selectedQuizAnswers.count)/\(course.quiz.count) sélectionnées • Seuil \(threshold)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                Spacer()
                Button {
                    activeStepIndex = max(0, course.parts.count - 1)
                } label: {
                    Label("Cours", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.pine)
                }
            }

            ForEach(Array(course.quiz.enumerated()), id: \.offset) { qIdx, q in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        EmbeddedAcademyBadge(text: "Question \(qIdx + 1)/\(course.quiz.count)", style: .pine)
                        if let topic = q.topic {
                            EmbeddedAcademyBadge(text: topic, style: .copper)
                        }
                    }

                    Text(q.q)
                        .font(.system(size: 15.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)

                    ForEach(Array(q.options.enumerated()), id: \.offset) { optIdx, optText in
                        let isSelected = selectedQuizAnswers[qIdx] == optIdx
                        let isCorrectOpt = q.correct == optIdx
                        Button {
                            selectedQuizAnswers[qIdx] = optIdx
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: quizSubmitted
                                      ? (isCorrectOpt ? "checkmark.circle.fill" : (isSelected ? "xmark.circle.fill" : "circle"))
                                      : (isSelected ? "largecircle.fill.circle" : "circle"))
                                    .foregroundStyle(quizSubmitted
                                                     ? (isCorrectOpt ? EmbeddedAcademyPalette.success : (isSelected ? EmbeddedAcademyPalette.danger : EmbeddedAcademyPalette.inkMuted))
                                                     : (isSelected ? EmbeddedAcademyPalette.pine : EmbeddedAcademyPalette.inkMuted))
                                Text(optText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(EmbeddedAcademyPalette.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(isSelected ? EmbeddedAcademyPalette.pineSoft : EmbeddedAcademyPalette.surfaceSubtle)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(isSelected ? EmbeddedAcademyPalette.pine : EmbeddedAcademyPalette.border, lineWidth: isSelected ? 1.4 : 1)
                            )
                        }
                    }

                    if quizSubmitted, let explain = q.explain {
                        Text(explain)
                            .font(.system(size: 13))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                            .padding(11)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(EmbeddedAcademyPalette.pineSoft))
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(EmbeddedAcademyPalette.border, lineWidth: 1))
            }

            Button {
                let firstSubmit = !quizSubmitted
                quizSubmitted = true
                let correctCount = course.quiz.enumerated().filter { selectedQuizAnswers[$0.offset] == $0.element.correct }.count
                let pct = Int((Double(correctCount) / Double(max(1, course.quiz.count)) * 100.0).rounded())
                if firstSubmit {
                    xpPoints += 150
                    persistProgress()
                }
                if pct >= threshold {
                    burstConfetti()
                    triggerXpToast("🎉 Quiz validé (\(pct)%) • +150 XP !")
                } else {
                    withAnimation { evalTab = 1 }
                }
            } label: {
                Text("Valider mon évaluation et calculer mon score")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(colors: [EmbeddedAcademyPalette.pineSolid, EmbeddedAcademyPalette.pineDeep], startPoint: .leading, endPoint: .trailing))
                    )
            }
            .disabled(selectedQuizAnswers.count < course.quiz.count)
            .opacity(selectedQuizAnswers.count < course.quiz.count ? 0.55 : 1.0)
        }
    }

    private func gapsRemediationTab(course: EmbeddedAcademyCourse) -> some View {
        let missed = course.quiz.enumerated().filter { selectedQuizAnswers[$0.offset] != $0.element.correct }
        return VStack(alignment: .leading, spacing: 14) {
            if !quizSubmitted {
                Text("Validez d'abord le Quiz Final dans l'onglet 1 pour identifier vos éventuelles lacunes à consolider vers 100 %.")
                    .font(.system(size: 14))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(EmbeddedAcademyPalette.surface))
            } else if missed.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(EmbeddedAcademyPalette.success)
                    Text("Aucune lacune détectée : vous avez réussi 100 % des questions du premier coup !")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 20).fill(EmbeddedAcademyPalette.successSoft))
            } else {
                ForEach(missed, id: \.offset) { qIdx, q in
                    let done = remediatedQuestionIndices.contains(qIdx)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            EmbeddedAcademyBadge(text: done ? "Lacune comblée ✓" : "Lacune à consolider", style: done ? .success : .copper)
                            Spacer()
                            if let pIdx = q.partIdx, pIdx < course.parts.count {
                                Button("Relire page \(pIdx + 1)") {
                                    activeStepIndex = pIdx
                                }
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(EmbeddedAcademyPalette.pine)
                            }
                        }
                        Text(q.q)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                        if let why = q.whyWrong {
                            Text("Piège fréquent : \(why)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(EmbeddedAcademyPalette.copper)
                        }
                        if let exp = q.explain {
                            Text(exp)
                                .font(.system(size: 13.5))
                                .foregroundStyle(EmbeddedAcademyPalette.ink)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(EmbeddedAcademyPalette.pineSoft))
                        }

                        if let rem = q.remediation, !done {
                            Divider()
                            Text("VÉRIFICATION DE RATTRAPAGE (+40 XP)")
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(EmbeddedAcademyPalette.pine)
                            Text(rem.q)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(EmbeddedAcademyPalette.ink)
                            ForEach(Array(rem.options.enumerated()), id: \.offset) { rOptIdx, rOptText in
                                Button {
                                    remediationSelectedOption[qIdx] = rOptIdx
                                    if rOptIdx == rem.correct {
                                        remediatedQuestionIndices.insert(qIdx)
                                        xpPoints += 40
                                        persistProgress()
                                        triggerXpToast("+40 XP • Lacune consolidée !")
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: remediationSelectedOption[qIdx] == rOptIdx ? "largecircle.fill.circle" : "circle")
                                        Text(rOptText)
                                            .font(.system(size: 13.5))
                                        Spacer()
                                    }
                                    .foregroundStyle(EmbeddedAcademyPalette.ink)
                                    .padding(10)
                                    .background(RoundedRectangle(cornerRadius: 11).fill(EmbeddedAcademyPalette.surfaceSubtle))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(EmbeddedAcademyPalette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(done ? EmbeddedAcademyPalette.success : EmbeddedAcademyPalette.copperBorder, lineWidth: 1.2))
                }
            }
        }
    }

    private func unclearPointsTab(course: EmbeddedAcademyCourse) -> some View {
        let unclearParts = course.parts.filter { unclearPartIds.contains($0.id) }
        return VStack(alignment: .leading, spacing: 12) {
            if unclearParts.isEmpty {
                Text("Aucune page marquée « Pas 100 % clair ». Vous pouvez marquer n'importe quelle leçon pendant votre lecture pour la retrouver résumée ici.")
                    .font(.system(size: 14))
                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(EmbeddedAcademyPalette.surface))
            } else {
                ForEach(unclearParts) { p in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(p.title)
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                        if let s = p.reexplain?.simple ?? p.summary {
                            Text(s)
                                .font(.system(size: 13.5))
                                .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                        }
                        Button("C'est limpide maintenant ✓") {
                            unclearPartIds.remove(p.id)
                        }
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.success)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(EmbeddedAcademyPalette.surface))
                }
            }
        }
    }

    // MARK: - Sommaire TOC & Modale Bulle de Vulgarisation

    private func tocDrawerSheet(course: EmbeddedAcademyCourse) -> some View {
        NavigationStack {
            List {
                ForEach(course.chapters ?? []) { ch in
                    Section(ch.title) {
                        let startIdx = ch.range.first ?? 0
                        let endIdx = min(course.parts.count - 1, ch.range.last ?? startIdx)
                        if startIdx <= endIdx {
                            ForEach(startIdx...endIdx, id: \.self) { idx in
                                let part = course.parts[idx]
                                Button {
                                    activeStepIndex = idx
                                    isOverviewMode = false
                                    isShowingTocSheet = false
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: completedPartIds.contains(part.id)
                                              ? "checkmark.circle.fill"
                                              : (activeStepIndex == idx ? "play.circle.fill" : "circle"))
                                            .foregroundStyle(completedPartIds.contains(part.id)
                                                             ? EmbeddedAcademyPalette.success
                                                             : (activeStepIndex == idx ? EmbeddedAcademyPalette.pine : EmbeddedAcademyPalette.inkMuted))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(idx + 1). \(part.title)")
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundStyle(EmbeddedAcademyPalette.ink)
                                            Text(part.duration ?? "2 min")
                                                .font(.system(size: 11.5))
                                                .foregroundStyle(EmbeddedAcademyPalette.inkMuted)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Validation & Maîtrise") {
                    Button {
                        activeStepIndex = course.parts.count
                        isOverviewMode = false
                        isShowingTocSheet = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "medal.fill")
                                .foregroundStyle(EmbeddedAcademyPalette.gold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Grand Quiz Final & Rattrapage 100 %")
                                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(EmbeddedAcademyPalette.ink)
                                Text("\(course.quiz.count) questions • Seuil \(course.passThresholdPct ?? 75)%")
                                    .font(.system(size: 12))
                                    .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sommaire du cours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { isShowingTocSheet = false }
                }
            }
        }
    }

    private func bubbleExplainerModal(_ bubble: EmbeddedAcademyBubble) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EmbeddedAcademyBadge(text: "Explication 100 % vulgarisée", icon: "questionmark.bubble.fill", style: .copper)
                    Text(bubble.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(EmbeddedAcademyPalette.ink)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("EN IMAGE DU QUOTIDIEN")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.copper)
                        Text(bubble.analogy)
                            .font(.system(size: 14.5))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(EmbeddedAcademyPalette.copperSoft))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("CONCRÈTEMENT DANS VIPLE MAIL")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.pine)
                        Text(formatAcademyInlineMarkdown(bubble.def))
                            .font(.system(size: 14.5))
                            .foregroundStyle(EmbeddedAcademyPalette.ink)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(EmbeddedAcademyPalette.pineSoft))

                    VStack(alignment: .leading, spacing: 6) {
                        Text("POURQUOI C'EST UTILE POUR VOUS")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                        Text(bubble.why)
                            .font(.system(size: 14))
                            .foregroundStyle(EmbeddedAcademyPalette.inkSecondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(EmbeddedAcademyPalette.surfaceSubtle))
                }
                .padding(20)
            }
            .background(EmbeddedAcademyPalette.background)
            .navigationTitle(bubble.q)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Compris") { activeBubbleSheet = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Chargement API Cenelis Academy + Formatage Markdown / Bulles

    private func loadCourseFromAcademyApi() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        guard let url = URL(string: "https://academy.prod.cenelis.com/api/mobile/v1/public/courses/bienvenue-viple-mail-visio-mailrte") else {
            loadError = "URL Cenelis Academy invalide."
            return
        }

        do {
            var req = URLRequest(url: url)
            req.timeoutInterval = 15
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                loadError = "Serveur Cenelis Academy momentanément indisponible."
                return
            }
            let decoded = try JSONDecoder().decode(AcademyPublicCourseEnvelope.self, from: data)
            if decoded.ok, let fetchedCourse = decoded.course {
                self.course = fetchedCourse
                self.bubbles = decoded.bubbles ?? [:]
            } else {
                loadError = "Cours introuvable sur Cenelis Academy."
            }
        } catch {
            loadError = "Connexion à Cenelis Academy impossible (\(error.localizedDescription))."
        }
    }

    private func extractBubbleKeys(from text: String) -> [(key: String, label: String)] {
        guard let rx = try? NSRegularExpression(pattern: "\\{\\{([a-zA-Z0-9_\\-]+)\\|([^}]+)\\}\\}") else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var out: [(String, String)] = []
        var seen: Set<String> = []
        for m in rx.matches(in: text, range: nsRange) {
            guard m.numberOfRanges > 2,
                  let rk = Range(m.range(at: 1), in: text),
                  let rl = Range(m.range(at: 2), in: text) else { continue }
            let key = String(text[rk])
            let lbl = String(text[rl])
            if !seen.contains(key) {
                seen.insert(key)
                out.append((key, lbl))
            }
        }
        return out
    }

    private func formatAcademyInlineMarkdown(_ raw: String) -> AttributedString {
        var cleaned = raw
        if let rx = try? NSRegularExpression(pattern: "\\{\\{[a-zA-Z0-9_\\-]+\\|([^}]+)\\}\\}") {
            let ns = NSRange(cleaned.startIndex..<cleaned.endIndex, in: cleaned)
            cleaned = rx.stringByReplacingMatches(in: cleaned, range: ns, withTemplate: "**$1 ⓘ**")
        }
        if let attr = try? AttributedString(markdown: cleaned) {
            return attr
        }
        return AttributedString(cleaned)
    }

    private func restoreSavedProgress() {
        let savedIds = UserDefaults.standard.stringArray(forKey: progressDefaultsKey) ?? []
        completedPartIds = Set(savedIds)
        xpPoints = UserDefaults.standard.integer(forKey: xpDefaultsKey)
    }

    private func persistProgress() {
        UserDefaults.standard.set(Array(completedPartIds), forKey: progressDefaultsKey)
        UserDefaults.standard.set(xpPoints, forKey: xpDefaultsKey)
    }

    private func triggerXpToast(_ text: String) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
            xpToastText = text
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_300_000_000)
            if xpToastText == text {
                withAnimation { xpToastText = nil }
            }
        }
    }

    private func burstConfetti() {
        showConfetti = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            showConfetti = false
        }
    }
}

private struct EmbeddedConfettiOverlay: View {
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                let elapsed = tl.date.timeIntervalSince(startDate)
                let colors: [Color] = [
                    EmbeddedAcademyPalette.gold,
                    EmbeddedAcademyPalette.pineSolid,
                    EmbeddedAcademyPalette.copperSolid,
                    Color.mint
                ]
                for i in 0..<42 {
                    let seed = Double(i * 73 + 19)
                    let x = CGFloat(sin(seed) * 0.45 + 0.5) * size.width + CGFloat(cos(elapsed * 2.5 + seed) * 24.0)
                    let speed = 130.0 + Double(i % 6) * 38.0
                    let y = CGFloat(elapsed * speed - Double(i % 10) * 18.0)
                    guard y >= -20 && y <= size.height + 20 else { continue }
                    let rect = CGRect(x: x, y: y, width: 8, height: 12)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(colors[i % colors.count]))
                }
            }
        }
        .ignoresSafeArea()
    }
}
