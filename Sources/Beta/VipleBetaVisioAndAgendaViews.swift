import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
@preconcurrency import EventKit
#endif

// MARK: - Lot 7 : Studio Pro Temps Réel « Viple Visio » (#061..#070)

public struct BetaVisioProStudioOverlayView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject public var engine: NativeVipleVisioEngine

    @State private var showWhiteboard: Bool = false
    @State private var currentStrokeX: [Double] = []
    @State private var currentStrokeY: [Double] = []
    @State private var whiteboardColorHex: String = "#38BDF8"

    @State private var showInCallChat: Bool = false
    @State private var chatInput: String = ""
    @State private var showNotesDrawer: Bool = false
    @State private var noteDraft: String = ""
    @State private var subtitleDraft: String = ""
    @State private var showSubtitleBar: Bool = false
    @State private var hasPassedGreenRoom: Bool = false

    public init(engine: NativeVipleVisioEngine) {
        self.engine = engine
    }

    private var hasAnyVisioBeta: Bool {
        [.f061, .f062, .f063, .f064, .f065, .f066, .f067, .f068, .f069, .f070].contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyVisioBeta {
            ZStack {
                // #070 : Sas Miroir Pré-Appel « Green Room » (uniquement pour les salons Agenda, avant entrée)
                if beta.isEnabled(.f070) && !engine.isDirectOneToOneCall && !hasPassedGreenRoom {
                    greenRoomMirrorCard
                        .zIndex(50)
                }

                // #063 : Pluie d'émojis flottants temps réel
                if beta.isEnabled(.f063) {
                    VStack(spacing: 6) {
                        if !engine.raisedHands.isEmpty {
                            Text("✋ Main levée : \(engine.raisedHands.sorted().joined(separator: ", "))")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.yellow))
                        }
                        ForEach(engine.floatingEmojis.suffix(5)) { item in
                            Text("\(item.emoji) \(item.senderName)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.black.opacity(0.55)))
                                .transition(.scale.combined(with: .opacity))
                        }
                        Spacer()
                    }
                    .padding(.top, 118)
                    .allowsHitTesting(false)
                }

                // #069 : Compte à rebours Timebox partagé + #067 HUD Réseau 3G/Train
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        if beta.isEnabled(.f069), let end = engine.sharedTimeboxEnd, end > Date() {
                            TimelineView(.periodic(from: .now, by: 1.0)) { tl in
                                let rem = max(0, Int(end.timeIntervalSince(tl.date)))
                                Text(String(format: "⏳ Timebox %02d:%02d", rem / 60, rem % 60))
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(rem < 60 ? Color.red : Color.purple.opacity(0.85)))
                            }
                        }

                        if beta.isEnabled(.f067) {
                            Text("\(engine.lowBandwidthEcoMode ? "ÉCO 3G" : "HD") • \(engine.estimatedBitrateKbps) kbps • \(engine.measuredRttMs) ms")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.black.opacity(0.55)))
                        }
                    }
                    .padding(.top, 52)

                    Spacer()

                    // #062 : Sous-titres synchronisés temps réel
                    if beta.isEnabled(.f062) && (!engine.liveSubtitleText.isEmpty || showSubtitleBar) {
                        VStack(spacing: 6) {
                            if !engine.liveSubtitleText.isEmpty {
                                Text(engine.liveSubtitleText)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.72)))
                            }
                            if showSubtitleBar {
                                HStack(spacing: 6) {
                                    Button {
                                        engine.toggleAutoSpeechCaptions()
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: engine.isAutoSpeechCaptionsActive ? "waveform.circle.fill" : "mic.fill")
                                            Text(engine.isAutoSpeechCaptionsActive ? "Auto ON" : "Speech")
                                        }
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(engine.isAutoSpeechCaptionsActive ? Color.red : VipleMailPalette.indigo))
                                    }
                                    TextField("Dicter ou saisir un sous-titre live…", text: $subtitleDraft)
                                        .font(.system(size: 12.5))
                                        .padding(7)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                                        .foregroundStyle(.black)
                                    Button("Diffuser") {
                                        guard !subtitleDraft.isEmpty else { return }
                                        engine.broadcastSubtitle(subtitleDraft)
                                        subtitleDraft = ""
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }

                    // Barre horizontale d'outils Visio Pro au-dessus du dock d'appel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 7) {
                            if beta.isEnabled(.f063) {
                                ForEach(["👍", "❤️", "👏", "🔥", "✋"], id: \.self) { em in
                                    Button {
                                        engine.sendFloatingReaction(em)
                                    } label: {
                                        Text(em)
                                            .font(.system(size: 15))
                                            .frame(width: 32, height: 32)
                                            .background(Circle().fill(Color.black.opacity(0.52)))
                                    }
                                }
                            }
                            if beta.isEnabled(.f061) {
                                visioToolChip("Tableau", icon: "pencil.and.scribble", active: showWhiteboard) {
                                    showWhiteboard.toggle()
                                }
                            }
                            if beta.isEnabled(.f062) {
                                visioToolChip("CC Live", icon: "captions.bubble.fill", active: showSubtitleBar) {
                                    showSubtitleBar.toggle()
                                }
                            }
                            if beta.isEnabled(.f064) {
                                visioToolChip("Chat (\(engine.inCallChatMessages.count))", icon: "text.bubble.fill", active: showInCallChat) {
                                    showInCallChat.toggle()
                                }
                            }
                            if beta.isEnabled(.f065) {
                                Menu {
                                    Button("Naturel") { engine.applyVideoFilterAndEco(filter: "none", eco: engine.lowBandwidthEcoMode) }
                                    Button("✨ Éclat Studio") { engine.applyVideoFilterAndEco(filter: "studio", eco: engine.lowBandwidthEcoMode) }
                                    Button("🌅 Cinéma Chaud") { engine.applyVideoFilterAndEco(filter: "warm", eco: engine.lowBandwidthEcoMode) }
                                    Button("🎞️ Monochrome") { engine.applyVideoFilterAndEco(filter: "mono", eco: engine.lowBandwidthEcoMode) }
                                    Button("🌫️ Flou Discrétion") { engine.applyVideoFilterAndEco(filter: "blur", eco: engine.lowBandwidthEcoMode) }
                                } label: {
                                    visioToolLabel("Filtre", icon: "camera.filters", active: engine.activeCameraFilter != "none")
                                }
                            }
                            if beta.isEnabled(.f066) {
                                visioToolChip("Notes CR", icon: "doc.append.fill", active: showNotesDrawer) {
                                    showNotesDrawer.toggle()
                                }
                            }
                            if beta.isEnabled(.f067) {
                                visioToolChip("Éco 3G", icon: "antenna.radiowaves.left.and.right", active: engine.lowBandwidthEcoMode) {
                                    engine.applyVideoFilterAndEco(filter: engine.activeCameraFilter, eco: !engine.lowBandwidthEcoMode)
                                }
                            }
                            if beta.isEnabled(.f068) {
                                visioToolChip("Voix EQ", icon: "waveform.badge.magnifyingglass", active: beta.visioVoiceClarityBoost) {
                                    beta.visioVoiceClarityBoost.toggle()
                                    engine.setVoiceClarityBoost(beta.visioVoiceClarityBoost)
                                    beta.saveState()
                                }
                            }
                            if beta.isEnabled(.f069) {
                                Menu {
                                    Button("Timebox 5 min") { engine.startSharedTimebox(minutes: 5) }
                                    Button("Timebox 15 min") { engine.startSharedTimebox(minutes: 15) }
                                    Button("Timebox 30 min") { engine.startSharedTimebox(minutes: 30) }
                                } label: {
                                    visioToolLabel("Timebox", icon: "hourglass", active: engine.sharedTimeboxEnd != nil)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                    .padding(.bottom, VipleMailLayout.isCompactPhone ? 88 : 104)
                }

                // #061 : Canevas Tableau Blanc Collaboratif Temps Réel
                if showWhiteboard {
                    whiteboardCollaborativeOverlay
                        .zIndex(30)
                }
            }
            .sheet(isPresented: $showInCallChat) {
                visioSideChatSheet
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showNotesDrawer) {
                visioMeetingNotesSheet
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private var greenRoomMirrorCard: some View {
        ZStack {
            Color(red: 0.03, green: 0.06, blue: 0.13).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("SAS PRÉ-APPEL « GREEN ROOM »")
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
                #if canImport(UIKit)
                if engine.isVideoEnabled {
                    NativeCameraPreviewView(session: engine.localCaptureSession)
                        .frame(width: 190, height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                #endif
                VStack(spacing: 6) {
                    Text("Test microphone temps réel")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.16))
                            Capsule()
                                .fill(Color.green)
                                .frame(width: max(8, geo.size.width * engine.localVoiceLevel))
                        }
                    }
                    .frame(width: 200, height: 8)
                }
                Button {
                    withAnimation { hasPassedGreenRoom = true }
                } label: {
                    Text("Entrer dans le salon Viple Visio")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 13)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }
            .padding(24)
        }
    }

    private var whiteboardCollaborativeOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Tableau Blanc Collaboratif Live")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                ForEach(["#38BDF8", "#FACC15", "#34D399", "#F43F5E"], id: \.self) { hex in
                    Button { whiteboardColorHex = hex } label: {
                        Circle()
                            .fill(VipleMailPalette.colorFromHex(hex))
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(Color.white, lineWidth: whiteboardColorHex == hex ? 2 : 0))
                    }
                }
                Button("Effacer") { engine.clearWhiteboard() }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.orange)
                Button { showWhiteboard = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            GeometryReader { geo in
                Canvas { ctx, size in
                    for st in engine.whiteboardStrokes {
                        guard st.pointsX.count > 1, st.pointsX.count == st.pointsY.count else { continue }
                        var p = Path()
                        p.move(to: CGPoint(x: st.pointsX[0] * size.width, y: st.pointsY[0] * size.height))
                        for idx in 1..<st.pointsX.count {
                            p.addLine(to: CGPoint(x: st.pointsX[idx] * size.width, y: st.pointsY[idx] * size.height))
                        }
                        ctx.stroke(p, with: .color(VipleMailPalette.colorFromHex(st.colorHex)), lineWidth: 3.2)
                    }
                    if currentStrokeX.count > 1 {
                        var cur = Path()
                        cur.move(to: CGPoint(x: currentStrokeX[0] * size.width, y: currentStrokeY[0] * size.height))
                        for idx in 1..<currentStrokeX.count {
                            cur.addLine(to: CGPoint(x: currentStrokeX[idx] * size.width, y: currentStrokeY[idx] * size.height))
                        }
                        ctx.stroke(cur, with: .color(VipleMailPalette.colorFromHex(whiteboardColorHex)), lineWidth: 3.2)
                    }
                }
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.75)))
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { val in
                            let nx = Double(max(0, min(1, val.location.x / max(1, geo.size.width))))
                            let ny = Double(max(0, min(1, val.location.y / max(1, geo.size.height))))
                            currentStrokeX.append(nx)
                            currentStrokeY.append(ny)
                        }
                        .onEnded { _ in
                            if currentStrokeX.count > 1 {
                                engine.addWhiteboardStroke(BetaVisioWhiteboardStroke(
                                    id: UUID().uuidString,
                                    colorHex: whiteboardColorHex,
                                    pointsX: currentStrokeX,
                                    pointsY: currentStrokeY
                                ))
                            }
                            currentStrokeX.removeAll()
                            currentStrokeY.removeAll()
                        }
                )
            }
            .frame(height: 250)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(RoundedRectangle(cornerRadius: 20).fill(Color.black.opacity(0.84)))
        .padding(14)
    }

    private var visioSideChatSheet: some View {
        NavigationStack {
            VStack(spacing: 8) {
                List(engine.inCallChatMessages) { m in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.senderName).font(.system(size: 11.5, weight: .bold)).foregroundStyle(VipleMailPalette.primary)
                        Text(m.text).font(.system(size: 14))
                    }
                }
                HStack(spacing: 8) {
                    TextField("Message au salon…", text: $chatInput)
                        .textFieldStyle(.roundedBorder)
                    Button("Envoyer") {
                        engine.sendInCallChat(chatInput)
                        chatInput = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
            }
            .navigationTitle("Chat du Salon Visio")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var visioMeetingNotesSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    TextField("Décision ou action prise…", text: $noteDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Horodater") {
                        guard !noteDraft.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        engine.callMeetingNotes.append("[\(engine.formattedDuration)] \(noteDraft)")
                        noteDraft = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)

                List(engine.callMeetingNotes, id: \.self) { line in
                    Text(line).font(.system(size: 13.5, design: .monospaced))
                }

                if !engine.callMeetingNotes.isEmpty {
                    Button("Préparer le courrier de compte-rendu") {
                        let cr = "Compte-rendu d'appel Viple Visio (#\(engine.roomCode)) :\n\n" + engine.callMeetingNotes.joined(separator: "\n")
                        showNotesDrawer = false
                        Task {
                            await vm.closeActiveVisioRoom()
                            vm.presentComposer(.newMail(subject: "Compte-rendu Viple Visio", body: cr, forceMail: true))
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Notes Horodatées & CR")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func visioToolChip(_ label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            visioToolLabel(label, icon: icon, active: active)
        }
        .buttonStyle(.plain)
    }

    private func visioToolLabel(_ label: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(active ? .black : .white)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Capsule().fill(active ? Color.cyan : Color.black.opacity(0.55)))
    }
}

// MARK: - Lot 8 : Agenda, Temps & Réunions #viplecalandar (#071..#080)

public enum BetaAgendaFreeSlotsHelper {
    public static func hasConflict(start: Date, end: Date, existing: [VipleAgendaEvent], excludingId: String? = nil) -> VipleAgendaEvent? {
        existing.first { ev in
            if let ex = excludingId, ev.eventId == ex { return false }
            return start < ev.endDate && end > ev.startDate
        }
    }

    public static func proposeThreeFreeSlotsText(existingEvents: [VipleAgendaEvent]) -> String {
        let cal = Calendar.current
        var proposals: [String] = []
        var cursor = cal.date(byAdding: .hour, value: 2, to: Date()) ?? Date()

        var safety = 0
        while proposals.count < 3 && safety < 96 {
            safety += 1
            let hour = cal.component(.hour, from: cursor)
            let weekday = cal.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 && hour >= 9 && hour <= 17 {
                let slotStart = cal.date(bySetting: .minute, value: 0, of: cursor) ?? cursor
                let slotEnd = slotStart.addingTimeInterval(45 * 60)
                if hasConflict(start: slotStart, end: slotEnd, existing: existingEvents) == nil {
                    let label = "\(slotStart.formatted(.dateTime.weekday(.wide).day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))).capitalized) de \(slotStart.formatted(date: .omitted, time: .shortened)) à \(slotEnd.formatted(date: .omitted, time: .shortened))"
                    if !proposals.contains(label) {
                        proposals.append("• \(label)")
                    }
                    cursor = cal.date(byAdding: .hour, value: 5, to: slotStart) ?? slotEnd
                    continue
                }
            }
            cursor = cal.date(byAdding: .hour, value: 1, to: cursor) ?? cursor.addingTimeInterval(3600)
        }

        return "Voici mes prochaines disponibilités :\n" + proposals.joined(separator: "\n")
    }

    public static func buildIcsContent(for event: VipleAgendaEvent) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Cenelis SA//Viple Mail iOS//FR
        BEGIN:VEVENT
        UID:\(event.eventId)@viplemail.fr
        DTSTART:\(df.string(from: event.startDate))
        DTEND:\(df.string(from: event.endDate))
        SUMMARY:\(event.title)
        LOCATION:\(event.location)
        DESCRIPTION:\(event.description)
        END:VEVENT
        END:VCALENDAR
        """
    }

    @MainActor
    public static func exportToNativeAppleCalendar(_ event: VipleAgendaEvent) async -> String {
        #if canImport(UIKit)
        let store = EKEventStore()
        do {
            let granted = try await store.requestWriteOnlyAccessToEvents()
            guard granted else { return "Accès au Calendrier iOS refusé." }
            let ek = EKEvent(eventStore: store)
            ek.title = event.title
            ek.startDate = event.startDate
            ek.endDate = event.endDate
            ek.location = event.location
            ek.notes = event.description
            ek.calendar = store.defaultCalendarForNewEvents
            try store.save(ek, span: .thisEvent)
            return "📅 Ajouté au Calendrier Apple iOS !"
        } catch {
            return "Erreur EventKit : \(error.localizedDescription)"
        }
        #else
        return "Export .ics prêt"
        #endif
    }
}

public struct BetaUpcomingVisioCountdownBanner: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    private var imminentVisioEvent: VipleAgendaEvent? {
        let now = Date()
        return vm.agendaEvents
            .filter { $0.isVisioSession && $0.endDate > now && $0.startDate.timeIntervalSince(now) <= 3600 }
            .sorted { $0.startDate < $1.startDate }
            .first
    }

    public var body: some View {
        if beta.isEnabled(.f076), let ev = imminentVisioEvent {
            HStack(spacing: 8) {
                Image(systemName: "video.badge.waveform.fill")
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ev.title)
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    let mins = max(0, Int(ev.startDate.timeIntervalSinceNow / 60))
                    Text(mins == 0 ? "En cours maintenant" : "Débute dans \(mins) min")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
                Spacer()
                Button {
                    vm.openAgendaVisioRoom(ev, audioOnly: false)
                } label: {
                    Text("Rejoindre")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.indigo)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(VipleMailPalette.indigo)
        }
    }
}

public struct BetaAgendaAugmentationStripView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Binding public var selectedDate: Date

    @State private var activeModal: VipleBetaFeatureID? = nil
    @State private var showMonthHeatmap: Bool = false
    @State private var showDayTimeline: Bool = false

    public init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
    }

    private var hasAnyAgendaBeta: Bool {
        [.f071, .f072, .f073, .f074, .f075, .f077, .f078, .f079, .f080].contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyAgendaBeta {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if beta.isEnabled(.f071) {
                            agendaPill("Grille Mois", icon: "calendar", active: showMonthHeatmap) {
                                withAnimation { showMonthHeatmap.toggle() }
                            }
                            agendaPill("Frise 24h", icon: "clock", active: showDayTimeline) {
                                withAnimation { showDayTimeline.toggle() }
                            }
                        }
                        if beta.isEnabled(.f075) {
                            agendaPill("Pomodoro (\(beta.completedPomodoroCountToday))", icon: "brain.head.profile", active: false) {
                                activeModal = .f075
                            }
                        }
                        if beta.isEnabled(.f077) {
                            let openTasks = beta.actionTasks.filter { !$0.isDone }.count
                            agendaPill("Tâches (\(openTasks))", icon: "checkmark.circle.fill", active: false) {
                                activeModal = .f077
                            }
                        }
                        if beta.isEnabled(.f078) {
                            agendaPill("Fuseaux", icon: "globe.americas.fill", active: false) {
                                activeModal = .f078
                            }
                        }
                        if beta.isEnabled(.f079) {
                            agendaPill("Récurrence", icon: "repeat.circle.fill", active: false) {
                                activeModal = .f079
                            }
                        }
                        if beta.isEnabled(.f080) {
                            agendaPill("Bilan Temps", icon: "chart.xyaxis.line", active: false) {
                                activeModal = .f080
                            }
                        }
                    }
                }

                // #071 : Grille mensuelle thermique
                if beta.isEnabled(.f071) && showMonthHeatmap {
                    monthlyHeatmapCard
                }

                // #071 : Frise horaire 07h–21h
                if beta.isEnabled(.f071) && showDayTimeline {
                    hourlyDayTimelineCard
                }

                // #072 : Détection automatique des chevauchements sur la journée sélectionnée
                if beta.isEnabled(.f072) {
                    let dayEvents = vm.agendaEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
                    let conflicts = dayEvents.filter { ev in
                        BetaAgendaFreeSlotsHelper.hasConflict(start: ev.startDate, end: ev.endDate, existing: dayEvents, excludingId: ev.eventId) != nil
                    }
                    if !conflicts.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text("Conflit d'horaires détecté sur \(conflicts.count) événement(s) ce jour !")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red.opacity(0.10)))
                    }
                }
            }
            .sheet(item: $activeModal) { fid in
                VipleBetaWorkspaceRouterSheet(featureId: fid)
                    .environmentObject(vm)
                    .preferredColorScheme(vm.preferredColorSchemeOverride)
            }
        }
    }

    private var monthlyHeatmapCard: some View {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: selectedDate)
        let firstOfMonth = cal.date(from: comps) ?? selectedDate
        let daysRange = cal.range(of: .day, in: .month, for: firstOfMonth) ?? 1..<31

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(firstOfMonth.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "fr_FR"))).capitalized)
                    .font(.system(size: 14.5, weight: .black, design: .rounded))
                Spacer()
                Button { selectedDate = cal.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.left") }
                Button { selectedDate = cal.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate } label: { Image(systemName: "chevron.right") }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 5) {
                ForEach(Array(daysRange), id: \.self) { dayNum in
                    let d = cal.date(byAdding: .day, value: dayNum - 1, to: firstOfMonth) ?? firstOfMonth
                    let count = vm.agendaEvents.filter { cal.isDate($0.startDate, inSameDayAs: d) }.count
                    let isSel = cal.isDate(d, inSameDayAs: selectedDate)
                    Button {
                        selectedDate = d
                    } label: {
                        Text("\(dayNum)")
                            .font(.system(size: 12, weight: isSel ? .black : .semibold, design: .rounded))
                            .foregroundStyle(isSel ? .white : VipleMailPalette.ink)
                            .frame(height: 30)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isSel ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(min(0.45, Double(count) * 0.16)))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .vipleMailCard(cornerRadius: 16, padding: 12)
    }

    private var hourlyDayTimelineCard: some View {
        let cal = Calendar.current
        let dayEvs = vm.agendaEvents.filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
        return VStack(alignment: .leading, spacing: 6) {
            Text("Frise horaire 08h00 – 20h00")
                .font(.system(size: 12.5, weight: .black, design: .rounded))
            ForEach(8...20, id: \.self) { hr in
                let matching = dayEvs.filter { cal.component(.hour, from: $0.startDate) == hr }
                HStack(alignment: .top, spacing: 10) {
                    Text(String(format: "%02d:00", hr))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .frame(width: 44, alignment: .leading)
                    if matching.isEmpty {
                        Rectangle().fill(VipleMailPalette.border).frame(height: 1).padding(.top, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(matching) { ev in
                                Text("• \(ev.title) (\(ev.startDate.formatted(date: .omitted, time: .shortened)))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                        }
                    }
                }
            }
        }
        .vipleMailCard(cornerRadius: 16, padding: 12)
    }

    private func agendaPill(_ label: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(label).font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(active ? .white : VipleMailPalette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(active ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.11)))
        }
        .buttonStyle(.plain)
    }
}

public struct BetaPomodoroStudioView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var remainingSeconds: Int = 25 * 60
    @State private var isRunning: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Text("Studio Deep Work & Pomodoro")
                .font(.system(size: 20, weight: .black, design: .rounded))

            ZStack {
                Circle().stroke(VipleMailPalette.surfaceSubtle, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: CGFloat(remainingSeconds) / CGFloat(25 * 60))
                    .stroke(VipleMailPalette.primary, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60))
                    .font(.system(size: 36, weight: .black, design: .monospaced))
            }
            .frame(width: 170, height: 170)

            HStack(spacing: 12) {
                Button(isRunning ? "Pause" : "Démarrer 25m") { isRunning.toggle() }
                    .buttonStyle(.borderedProminent)
                Button("Réinitialiser") { isRunning = false; remainingSeconds = 25 * 60 }
                    .buttonStyle(.bordered)
            }

            Text("Sessions accomplies aujourd'hui : \(beta.completedPomodoroCountToday)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(VipleMailPalette.success)
        }
        .padding(24)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if isRunning && remainingSeconds > 0 {
                    remainingSeconds -= 1
                    if remainingSeconds == 0 {
                        isRunning = false
                        beta.completedPomodoroCountToday += 1
                        beta.saveState()
                    }
                }
            }
        }
    }
}

public struct BetaActionTasksManagerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newTitle: String = ""
    @State private var newPriority: String = "Normale"

    public init() {}

    public var body: some View {
        List {
            Section("Nouvelle tâche") {
                TextField("Titre de la tâche…", text: $newTitle)
                Picker("Priorité", selection: $newPriority) {
                    Text("Haute").tag("Haute")
                    Text("Normale").tag("Normale")
                    Text("Basse").tag("Basse")
                }
                .pickerStyle(.segmented)
                Button("Ajouter") {
                    beta.actionTasks.insert(BetaActionTaskItem(id: UUID().uuidString, title: newTitle, notes: "", dueAt: Date().addingTimeInterval(86400), priority: newPriority, isDone: false, sourceMessageId: nil, subtasks: [], completedSubtasks: []), at: 0)
                    beta.saveState()
                    newTitle = ""
                }
                .disabled(newTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Section("Mes tâches (\(beta.actionTasks.count))") {
                ForEach(beta.actionTasks) { task in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Button {
                                if let idx = beta.actionTasks.firstIndex(where: { $0.id == task.id }) {
                                    beta.actionTasks[idx].isDone.toggle()
                                    beta.saveState()
                                }
                            } label: {
                                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isDone ? VipleMailPalette.success : VipleMailPalette.primary)
                            }
                            .buttonStyle(.plain)

                            Text(task.title)
                                .font(.system(size: 14, weight: .bold))
                                .strikethrough(task.isDone)
                            Spacer()
                            Text(task.priority)
                                .font(.system(size: 10.5, weight: .black))
                                .foregroundStyle(task.priority == "Haute" ? .red : VipleMailPalette.primary)
                        }
                        if let mid = task.sourceMessageId, let src = vm.messages.first(where: { $0.id == mid }) {
                            Button("Ouvrir le courrier source") {
                                dismiss()
                                vm.selectedTab = 0
                                vm.openMessage(src)
                            }
                            .font(.system(size: 11.5, weight: .bold))
                        }
                    }
                }
                .onDelete { offsets in
                    beta.actionTasks.remove(atOffsets: offsets)
                    beta.saveState()
                }
            }
        }
    }
}

public struct BetaWorldClockPlannerView: View {
    @State private var offsetHours: Double = 0

    public init() {}

    private let cities: [(name: String, tzId: String)] = [
        ("🇫🇷 Paris", "Europe/Paris"),
        ("🇬🇧 Londres", "Europe/London"),
        ("🇺🇸 New York", "America/New_York"),
        ("🇨🇦 Montréal", "America/Toronto"),
        ("🇦🇪 Dubaï", "Asia/Dubai"),
        ("🇯🇵 Tokyo", "Asia/Tokyo")
    ]

    public var body: some View {
        let refDate = Date().addingTimeInterval(offsetHours * 3600)
        Form {
            Section("Curseur de simulation horaire (+\(Int(offsetHours))h)") {
                Slider(value: $offsetHours, in: -12...24, step: 0.5)
            }
            Section("Heures locales simultanées") {
                ForEach(cities, id: \.tzId) { city in
                    let tz = TimeZone(identifier: city.tzId) ?? .current
                    let df: DateFormatter = {
                        let f = DateFormatter()
                        f.timeZone = tz
                        f.dateFormat = "EEE HH:mm"
                        f.locale = Locale(identifier: "fr_FR")
                        return f
                    }()
                    HStack {
                        Text(city.name).font(.system(size: 14.5, weight: .bold))
                        Spacer()
                        Text(df.string(from: refDate))
                            .font(.system(size: 14.5, weight: .black, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
            }
        }
    }
}

public struct BetaRecurringSeriesCreatorView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = "Point d'équipe Viple Visio"
    @State private var firstStart: Date = Date().addingTimeInterval(3600)
    @State private var cadence: String = "weekly"
    @State private var occurrences: Int = 4
    @State private var isVisio: Bool = true
    @State private var isCreating: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Section("Série récurrente (#079)") {
                TextField("Titre", text: $title)
                DatePicker("1re séance", selection: $firstStart)
                Picker("Cadence", selection: $cadence) {
                    Text("Quotidienne").tag("daily")
                    Text("Hebdomadaire").tag("weekly")
                    Text("Mensuelle").tag("monthly")
                }
                Stepper("Occurrences : \(occurrences)", value: $occurrences, in: 2...8)
                Toggle("Inclure un salon Viple Visio", isOn: $isVisio)

                Button {
                    Task { await createSeries() }
                } label: {
                    if isCreating { ProgressView() } else { Text("Générer les \(occurrences) séances").fontWeight(.bold) }
                }
                .disabled(isCreating || title.isEmpty)
            }
        }
    }

    private func createSeries() async {
        let owner = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
        guard !owner.isEmpty else { return }
        isCreating = true
        let cal = Calendar.current
        for i in 0..<occurrences {
            let start: Date
            switch cadence {
            case "daily": start = cal.date(byAdding: .day, value: i, to: firstStart) ?? firstStart
            case "monthly": start = cal.date(byAdding: .month, value: i, to: firstStart) ?? firstStart
            default: start = cal.date(byAdding: .day, value: i * 7, to: firstStart) ?? firstStart
            }
            let end = start.addingTimeInterval(3600)
            if let res = try? await VipleMailAPIClient.shared.createAgendaEvent(
                email: owner,
                cid: vm.currentCid,
                title: "\(title) (\(i + 1)/\(occurrences))",
                description: "Série récurrente Viple Agenda",
                location: isVisio ? "Salon Viple Visio" : "",
                startUtc: VipleCalendarParser.formatISOUtc(start),
                endUtc: VipleCalendarParser.formatISOUtc(end),
                colorHex: "#4F46E5",
                isVisioSession: isVisio,
                invitedFriends: [],
                invitedGuests: [],
                sendGuestMail: false
            ), let evs = res.events {
                vm.agendaEvents = evs
            }
        }
        isCreating = false
        vm.showToast("📅 Série de \(occurrences) rendez-vous créée !")
        dismiss()
    }
}

public struct BetaWeeklyTimeBalanceView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    public var body: some View {
        let now = Date()
        let weekEnd = now.addingTimeInterval(7 * 86400)
        let weekEvents = vm.agendaEvents.filter { $0.startDate >= now.addingTimeInterval(-86400) && $0.startDate <= weekEnd }
        let totalMinutes = weekEvents.reduce(0) { acc, ev in
            acc + max(15, Int(ev.endDate.timeIntervalSince(ev.startDate) / 60))
        }
        let hoursMeeting = Double(totalMinutes) / 60.0
        let deepWorkHours = max(0, 40.0 - hoursMeeting)

        List {
            Section("Bilan de vos 7 prochains jours (#080)") {
                HStack {
                    Text("Heures en réunion / RDV")
                    Spacer()
                    Text(String(format: "%.1f h", hoursMeeting)).fontWeight(.black).foregroundStyle(VipleMailPalette.indigo)
                }
                HStack {
                    Text("Temps calme Deep Work estimé")
                    Spacer()
                    Text(String(format: "%.1f h", deepWorkHours)).fontWeight(.black).foregroundStyle(VipleMailPalette.success)
                }
                HStack {
                    Text("Sessions Viple Visio prévues")
                    Spacer()
                    Text("\(weekEvents.filter(\.isVisioSession).count)").fontWeight(.black)
                }
            }
        }
    }
}
