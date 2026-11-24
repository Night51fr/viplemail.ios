import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

// MARK: - 1. Studio WebRTC Embarqué « Viple Visio » (Appel Classique Audio & Appel Vidéo HD)

#if canImport(UIKit)
private struct VipleVisioWebViewRepresentable: UIViewRepresentable {
    let joinUrlString: String
    let onHangup: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onHangup: onHangup)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.userContentController.add(context.coordinator, name: "vipleVisio")

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.uiDelegate = context.coordinator
        wv.navigationDelegate = context.coordinator
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)
        wv.scrollView.backgroundColor = UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        if let url = URL(string: joinUrlString) {
            wv.load(URLRequest(url: url))
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onHangup = onHangup
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "vipleVisio")
        uiView.evaluateJavaScript("try { document.getElementById('ctl-leave')?.click(); } catch(e) {}", completionHandler: nil)
        uiView.loadHTMLString("", baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, WKScriptMessageHandler {
        var onHangup: () -> Void

        init(onHangup: @escaping () -> Void) {
            self.onHangup = onHangup
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "vipleVisio" {
                onHangup()
            }
        }

        @available(iOS 15.0, *)
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            let host = origin.host.lowercased()
            if host.hasSuffix("viple.digital") || host.hasSuffix("viplemail.fr") || host.hasSuffix("cenelis.com") {
                decisionHandler(.grant)
            } else {
                decisionHandler(.prompt)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url,
               url.host?.lowercased() == "visio.prod.viple.digital",
               (url.path == "" || url.path == "/") {
                decisionHandler(.cancel)
                onHangup()
                return
            }
            decisionHandler(.allow)
        }
    }
}
#endif

public struct VipleVisioWebRTCStudioView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let session: VipleVisioRoomPresentation

    public var body: some View {
        ZStack(alignment: .top) {
            Color(red: 0.04, green: 0.06, blue: 0.10)
                .ignoresSafeArea()

            #if canImport(UIKit)
            VipleVisioWebViewRepresentable(joinUrlString: session.joinUrl) {
                Task {
                    await vm.closeActiveVisioRoom()
                }
            }
            .ignoresSafeArea(edges: .bottom)
            .padding(.top, 56)
            #endif

            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: session.isAudioOnly ? "phone.waveform.fill" : "video.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(red: 0.22, green: 0.85, blue: 0.62))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.title)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("\(session.peerName) • Chiffré DTLS-SRTP")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    Task {
                        await vm.closeActiveVisioRoom()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Quitter")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color(red: 0.90, green: 0.20, blue: 0.22)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.75))
        }
        .onAppear {
            #if canImport(UIKit)
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
            try? audioSession.setActive(true)
            #endif
        }
    }
}

// MARK: - 2. Superposition Globale d'Appels Entrants / Sortants « Viple Visio »

public struct VipleVisioGlobalCallOverlay: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var pulseRing: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            if let roomSession = vm.activeVisioRoomSession {
                VipleVisioWebRTCStudioView(session: roomSession)
                    .environmentObject(vm)
                    .transition(.opacity)
                    .zIndex(210)
            } else if let incoming = vm.incomingVisioCall {
                incomingCallCard(incoming)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(205)
            } else if let outgoing = vm.outgoingVisioCall {
                outgoingCallCard(outgoing)
                    .transition(.opacity)
                    .zIndex(204)
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: vm.activeVisioRoomSession?.id)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: vm.incomingVisioCall?.callId)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: vm.outgoingVisioCall?.callId)
    }

    private func incomingCallCard(_ call: VipleVisioCall) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.08, blue: 0.18),
                    Color(red: 0.06, green: 0.18, blue: 0.36),
                    Color(red: 0.02, green: 0.05, blue: 0.11)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: call.isAudioOnly ? "phone.fill" : "video.fill")
                    Text(call.isAudioOnly ? "VIPLE VISIO • APPEL CLASSIQUE ENTRANT" : "VIPLE VISIO • APPEL VIDÉO ENTRANT")
                }
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 1.0))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.10)))

                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(pulseRing ? 0.05 : 0.38), lineWidth: 2.5)
                        .frame(width: pulseRing ? 190 : 124, height: pulseRing ? 190 : 124)
                    Circle()
                        .stroke(Color.blue.opacity(pulseRing ? 0.12 : 0.45), lineWidth: 2)
                        .frame(width: pulseRing ? 156 : 116, height: pulseRing ? 156 : 116)

                    VipleMailAvatarView(
                        name: call.callerName,
                        email: call.callerEmail,
                        avatarUrl: call.callerAvatarUrl,
                        size: 106,
                        isVip: true
                    )
                }
                .onAppear {
                    pulseRing = false
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                        pulseRing = true
                    }
                }

                VStack(spacing: 6) {
                    Text(call.callerName)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(call.callerEmail)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Text("Ami Viple Live ID vérifié")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.90, blue: 0.65))
                        .padding(.top, 2)
                }

                Spacer()

                HStack(spacing: 52) {
                    Button {
                        Task {
                            await vm.declineOrEndVisioCall(call, action: "decline")
                        }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.92, green: 0.22, blue: 0.24))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text("Refuser")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }

                    Button {
                        Task {
                            await vm.answerIncomingVisioCall(call)
                        }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.78, blue: 0.46))
                                    .frame(width: 72, height: 72)
                                Image(systemName: call.isAudioOnly ? "phone.fill" : "video.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text("Accepter")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.bottom, 54)
            }
            .padding(.horizontal, 24)
        }
    }

    private func outgoingCallCard(_ call: VipleVisioCall) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.04, green: 0.09, blue: 0.20),
                    Color(red: 0.08, green: 0.16, blue: 0.34),
                    Color(red: 0.03, green: 0.06, blue: 0.13)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                Text(call.isAudioOnly ? "APPEL CLASSIQUE AUDIO EN COURS…" : "APPEL VIPLE VISIO EN COURS…")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color.cyan)

                VipleMailAvatarView(
                    name: call.calleeName,
                    email: call.calleeEmail,
                    avatarUrl: call.calleeAvatarUrl,
                    size: 104,
                    isVip: true
                )

                VStack(spacing: 6) {
                    Text(call.calleeName)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Sonnerie sur son Viple Mail…")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Button {
                    Task {
                        await vm.declineOrEndVisioCall(call, action: "hangup")
                    }
                } label: {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.92, green: 0.22, blue: 0.24))
                                .frame(width: 72, height: 72)
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("Annuler l'appel")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, 54)
            }
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - 3. Onglet « Agenda » Intégré & Sessions Viple Visio

public struct MailAgendaView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedDate: Date = Date()
    @State private var eventForGuestLinkSheet: VipleAgendaEvent? = nil
    @State private var isShowingStandaloneLinkSheet: Bool = false

    public init() {}

    private var weekDaysWindow: [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        return (-2...11).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var eventsOnSelectedDay: [VipleAgendaEvent] {
        let cal = Calendar.current
        return vm.agendaEvents.filter { cal.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var upcomingEvents: [VipleAgendaEvent] {
        let now = Date().addingTimeInterval(-1800)
        return vm.agendaEvents.filter { $0.endDate >= now }
            .sorted { $0.startDate < $1.startDate }
    }

    public var body: some View {
        VStack(spacing: 0) {
            agendaHeader

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    quickActionsBanner

                    daySection

                    if !upcomingEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Tous vos prochains rendez-vous & sessions Visio")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)

                            ForEach(upcomingEvents.prefix(15)) { ev in
                                agendaEventCard(ev, showFullDate: true)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(VipleMailPalette.background)
        .task {
            await vm.refreshAgendaAndFriends()
        }
        .sheet(isPresented: $vm.isShowingCreateAgendaSheet) {
            CreateAgendaOrVisioSheet(defaultIsVisio: vm.createAgendaDefaultVisio, initialDate: selectedDate)
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(item: $eventForGuestLinkSheet) { ev in
            SendVisioLinkByMailSheet(existingEvent: ev)
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $isShowingStandaloneLinkSheet) {
            SendVisioLinkByMailSheet(existingEvent: nil)
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
    }

    private var agendaHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Agenda & Viple Visio")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Rendez-vous #viplecalandar & salons vidéo")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }

                Spacer()

                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .tint(VipleMailPalette.primary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(weekDaysWindow, id: \.self) { day in
                        let isSel = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                        let hasEvent = vm.agendaEvents.contains { Calendar.current.isDate($0.startDate, inSameDayAs: day) }
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                selectedDate = day
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(day.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "fr_FR"))).uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(isSel ? .white.opacity(0.88) : VipleMailPalette.inkMuted)
                                Text(day.formatted(.dateTime.day()))
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundStyle(isSel ? .white : VipleMailPalette.ink)
                                Circle()
                                    .fill(hasEvent ? (isSel ? .white : VipleMailPalette.primary) : .clear)
                                    .frame(width: 5, height: 5)
                            }
                            .frame(width: 48, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(isSel ? AnyShapeStyle(VipleMailPalette.heroGradient) : AnyShapeStyle(VipleMailPalette.surfaceSubtle))
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VipleMailPalette.surface)
    }

    private var quickActionsBanner: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    vm.createAgendaDefaultVisio = false
                    vm.isShowingCreateAgendaSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Nouveau RDV")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VipleMailPalette.primary)
                    )
                }

                Button {
                    vm.createAgendaDefaultVisio = true
                    vm.isShowingCreateAgendaSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 16, weight: .bold))
                        Text("Session Visio")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.31, green: 0.27, blue: 0.90), Color(red: 0.02, green: 0.52, blue: 0.85)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                    )
                }
            }

            Button {
                isShowingStandaloneLinkSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "envelope.badge.shield.half.filled.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VipleMailPalette.indigo)
                    Text("Envoyer un lien de salon Viple Visio par mail à un invité…")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(VipleMailPalette.border, lineWidth: 1)
                        )
                )
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))).capitalized)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            if eventsOnSelectedDay.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    Text("Aucun rendez-vous prévu à cette date")
                        .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Text("Planifiez une session Viple Visio ou importez un courrier contenant #viplecalandar.")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 16)
                .vipleMailCard(cornerRadius: 18, padding: 0)
            } else {
                ForEach(eventsOnSelectedDay) { ev in
                    agendaEventCard(ev, showFullDate: false)
                }
            }
        }
    }

    private func agendaEventCard(_ ev: VipleAgendaEvent, showFullDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ev.isVisioSession ? VipleMailPalette.indigo : VipleMailPalette.primary)
                    .frame(width: 5, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if ev.isVisioSession {
                            Label("Viple Visio", systemImage: "video.fill")
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(VipleMailPalette.indigo))
                        }
                        Text(ev.title)
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                    }

                    let datePrefix = showFullDate
                        ? ev.startDate.formatted(.dateTime.day().month(.abbreviated).locale(Locale(identifier: "fr_FR"))) + " • "
                        : ""
                    Text("\(datePrefix)\(ev.startDate.formatted(date: .omitted, time: .shortened)) – \(ev.endDate.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)

                    if !ev.location.isEmpty {
                        Label(ev.location, systemImage: "mappin.and.ellipse")
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                    }
                    if !ev.description.isEmpty {
                        Text(ev.description)
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Menu {
                    if ev.isVisioSession {
                        Button {
                            vm.openAgendaVisioRoom(ev, audioOnly: false)
                        } label: {
                            Label("Rejoindre en Visio", systemImage: "video.fill")
                        }
                        Button {
                            vm.openAgendaVisioRoom(ev, audioOnly: true)
                        } label: {
                            Label("Rejoindre en Audio seul", systemImage: "phone.fill")
                        }
                        Button {
                            eventForGuestLinkSheet = ev
                        } label: {
                            Label("Envoyer un lien par mail…", systemImage: "envelope.fill")
                        }
                        Divider()
                    }
                    Button(role: .destructive) {
                        Task {
                            await vm.deleteAgendaEvent(ev)
                        }
                    } label: {
                        Label("Supprimer de l'Agenda", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }

            if ev.isVisioSession {
                HStack(spacing: 8) {
                    Button {
                        vm.openAgendaVisioRoom(ev, audioOnly: false)
                    } label: {
                        Label("Rejoindre le salon Visio", systemImage: "video.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(VipleMailPalette.indigo))
                    }

                    Button {
                        eventForGuestLinkSheet = ev
                    } label: {
                        Label("Envoyer un lien par mail", systemImage: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                    }
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }
}

// MARK: - 4. Feuille de Création d'un Rendez-vous ou d'une Session Viple Visio

public struct CreateAgendaOrVisioSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var isVisioSession: Bool
    @State private var title: String = ""
    @State private var startDate: Date
    @State private var durationMinutes: Int = 60
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var selectedFriendEmails: Set<String> = []
    @State private var externalGuestsRaw: String = ""
    @State private var isSubmitting: Bool = false

    public init(defaultIsVisio: Bool = false, initialDate: Date = Date()) {
        _isVisioSession = State(initialValue: defaultIsVisio)
        let roundedStart = Calendar.current.date(byAdding: .hour, value: 1, to: initialDate) ?? Date()
        _startDate = State(initialValue: roundedStart)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $isVisioSession) {
                        Text("📅 Rendez-vous").tag(false)
                        Text("📹 Session Viple Visio").tag(true)
                    }
                    .pickerStyle(.segmented)

                    TextField("Titre (ex: Point d'équipe, Réunion client…)", text: $title)
                        .vipleMailTextInput()

                    DatePicker("Début", selection: $startDate)
                    Picker("Durée", selection: $durationMinutes) {
                        Text("30 minutes").tag(30)
                        Text("45 minutes").tag(45)
                        Text("1 heure").tag(60)
                        Text("1h30").tag(90)
                        Text("2 heures").tag(120)
                    }

                    if !isVisioSession {
                        TextField("Lieu ou adresse", text: $location)
                            .vipleMailTextInput()
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VipleMailPalette.success)
                            Text("Un salon Viple Visio dédié est généré et ajouté automatiquement à votre Agenda.")
                                .font(.system(size: 12.5))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                        }
                    }

                    TextField("Notes ou ordre du jour (optionnel)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text(isVisioSession ? "Détails de la session Viple Visio" : "Détails du rendez-vous")
                }

                Section {
                    if vm.acceptedFriends.isEmpty {
                        Text("Aucun ami Viple Live ID accepté pour l'instant. Ajoutez vos collègues ou proches dans Contacts > Amis.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    } else {
                        ForEach(vm.acceptedFriends) { friend in
                            let selected = selectedFriendEmails.contains(friend.email.lowercased())
                            Button {
                                let key = friend.email.lowercased()
                                if selected {
                                    selectedFriendEmails.remove(key)
                                } else {
                                    selectedFriendEmails.insert(key)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                                    VipleMailAvatarView(name: friend.displayName, email: friend.email, avatarUrl: friend.avatarUrl, size: 32)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(friend.displayName)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(VipleMailPalette.ink)
                                        Text(friend.email)
                                            .font(.system(size: 11.5))
                                            .foregroundStyle(VipleMailPalette.inkSecondary)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                } header: {
                    Text("1. Inviter des Amis Viple Live ID")
                } footer: {
                    Text("Vos amis sélectionnés recevront automatiquement la session dans leur Agenda Viple Mail.")
                }

                Section {
                    TextField("invite1@domaine.com, invite2@entreprise.fr", text: $externalGuestsRaw)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()
                } header: {
                    Text("2. Autres invités — Envoyer un lien par mail")
                } footer: {
                    Text("Génère un lien d'accès au salon Viple Visio + la formule #viplecalandar et l'envoie immédiatement par e-mail à ces invités.")
                }
            }
            .navigationTitle(isVisioSession ? "Nouvelle session Visio" : "Nouveau rendez-vous")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createNow() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Enregistrer")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private func createNow() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let owner = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
        let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let guestEmails = externalGuestsRaw
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.contains("@") }

        let effTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (isVisioSession ? "Session Viple Visio" : "Rendez-vous Viple")
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let res = try await VipleMailAPIClient.shared.createAgendaEvent(
                email: owner,
                cid: vm.currentCid,
                title: effTitle,
                description: notes,
                location: location,
                startUtc: VipleCalendarParser.formatISOUtc(startDate),
                endUtc: VipleCalendarParser.formatISOUtc(endDate),
                colorHex: isVisioSession ? "#4F46E5" : "#0078D4",
                isVisioSession: isVisioSession,
                invitedFriends: Array(selectedFriendEmails),
                invitedGuests: guestEmails,
                sendGuestMail: true
            )
            if res.ok {
                if let evs = res.events {
                    vm.agendaEvents = evs
                }
                let sentInfo = (res.emailsSent ?? 0) > 0 ? " (\(res.emailsSent!) invitation(s) envoyée(s) par mail)" : ""
                vm.showToast("📅 Ajouté à votre Agenda\(sentInfo)")
                dismiss()
            } else {
                vm.showToast(res.error ?? "Impossible d'enregistrer cet événement.")
            }
        } catch {
            vm.showToast(error.localizedDescription)
        }
    }
}

// MARK: - 5. Feuille « Envoyer un lien de salon Viple Visio par mail »

public struct SendVisioLinkByMailSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss

    public let existingEvent: VipleAgendaEvent?
    @State private var customTitle: String = ""
    @State private var recipientsText: String = ""
    @State private var personalNote: String = ""
    @State private var isSending: Bool = false

    public init(existingEvent: VipleAgendaEvent?) {
        self.existingEvent = existingEvent
        _customTitle = State(initialValue: existingEvent?.title ?? "Réunion Viple Visio")
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Salon Viple Visio") {
                    TextField("Objet de la session Visio", text: $customTitle)
                        .vipleMailTextInput()
                    if let gUrl = existingEvent?.visioGuestJoinUrl, !gUrl.isEmpty {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(VipleMailPalette.indigo)
                            Text(gUrl)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .lineLimit(1)
                        }
                    }
                }

                Section {
                    TextField("client@exemple.com, partenaire@domaine.fr", text: $recipientsText)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()

                    TextField("Message d'accompagnement (optionnel)", text: $personalNote, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Destinataires du lien par mail")
                } footer: {
                    Text("Un lien direct vers le salon Viple Visio (accessible sans compte) ainsi qu'une carte #viplecalandar seront envoyés immédiatement.")
                }
            }
            .navigationTitle("Envoyer un lien par mail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await sendNow() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Envoyer le lien")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isSending || recipientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func sendNow() async {
        let emails = recipientsText
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0 == " " })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { $0.contains("@") }
        guard !emails.isEmpty else { return }

        isSending = true
        defer { isSending = false }

        let owner = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
        do {
            let res = try await VipleMailAPIClient.shared.sendVisioGuestLinkByMail(
                email: owner,
                cid: vm.currentCid,
                eventId: existingEvent?.eventId,
                title: customTitle,
                recipientEmails: emails,
                note: personalNote
            )
            if res.ok {
                vm.showToast(res.message ?? "✉️ Lien du salon Viple Visio envoyé par mail !")
                dismiss()
            } else {
                vm.showToast(res.error ?? "Échec d'envoi du lien.")
            }
        } catch {
            vm.showToast(error.localizedDescription)
        }
    }
}

// MARK: - 6. Assistant Compositeur « #viplecalandar » (Inséré dans un Courrier)

public struct VipleCalendarComposerSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss

    public let defaultTitle: String
    public let onInsertFormula: (String, String) -> Void

    @State private var title: String
    @State private var startDate: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    @State private var durationMinutes: Int = 60
    @State private var includeVisioRoom: Bool = false
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var alsoSaveToMyAgenda: Bool = true
    @State private var isGenerating: Bool = false

    public init(defaultTitle: String, onInsertFormula: @escaping (String, String) -> Void) {
        self.defaultTitle = defaultTitle
        self.onInsertFormula = onInsertFormula
        _title = State(initialValue: defaultTitle)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Rendez-vous #viplecalandar") {
                    TextField("Objet du rendez-vous", text: $title)
                        .vipleMailTextInput()
                    DatePicker("Date & heure", selection: $startDate)
                    Picker("Durée", selection: $durationMinutes) {
                        Text("30 min").tag(30)
                        Text("1 heure").tag(60)
                        Text("1h30").tag(90)
                        Text("2 heures").tag(120)
                    }
                    Toggle("Associer un salon Viple Visio", isOn: $includeVisioRoom)
                        .tint(VipleMailPalette.indigo)

                    if !includeVisioRoom {
                        TextField("Lieu (optionnel)", text: $location)
                            .vipleMailTextInput()
                    }
                    TextField("Précisions (optionnel)", text: $notes)
                        .vipleMailTextInput()
                }

                Section {
                    Toggle("Ajouter aussi à mon Agenda Viple Mail", isOn: $alsoSaveToMyAgenda)
                        .tint(VipleMailPalette.primary)
                } footer: {
                    Text("Insère la formule #viplecalandar dans votre mail : le destinataire verra directement le bouton « Ajouter à l'agenda ».")
                }
            }
            .navigationTitle("Insérer #viplecalandar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await buildAndInsert() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Text("Insérer")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(isGenerating)
                }
            }
        }
    }

    private func buildAndInsert() async {
        isGenerating = true
        defer { isGenerating = false }

        let effTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Rendez-vous"
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        let endDate = startDate.addingTimeInterval(TimeInterval(durationMinutes * 60))
        let effLoc = includeVisioRoom ? "Salon Viple Visio" : location

        var visioGuestUrl: String? = nil

        if alsoSaveToMyAgenda || includeVisioRoom {
            let owner = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
            if !owner.isEmpty, owner != "__all__",
               let res = try? await VipleMailAPIClient.shared.createAgendaEvent(
                   email: owner,
                   cid: vm.currentCid,
                   title: effTitle,
                   description: notes,
                   location: effLoc,
                   startUtc: VipleCalendarParser.formatISOUtc(startDate),
                   endUtc: VipleCalendarParser.formatISOUtc(endDate),
                   colorHex: includeVisioRoom ? "#4F46E5" : "#0078D4",
                   isVisioSession: includeVisioRoom,
                   invitedFriends: [],
                   invitedGuests: [],
                   sendGuestMail: false
               ), res.ok {
                if let evs = res.events {
                    vm.agendaEvents = evs
                }
                visioGuestUrl = res.eventItem?.visioGuestJoinUrl
            }
        }

        if includeVisioRoom && visioGuestUrl == nil {
            let slug = "vis-\(UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased().prefix(8))"
            visioGuestUrl = "https://visio.prod.viple.digital/r/\(slug)?guest=1"
        }

        let formula = VipleCalendarParser.buildFormulaTag(
            title: effTitle,
            start: startDate,
            end: endDate,
            location: effLoc,
            visioUrl: visioGuestUrl,
            notes: notes
        )
        onInsertFormula(effTitle, formula)
        dismiss()
    }
}

// MARK: - 7. Carte Interactive « Ajouter à l'agenda » Affichée dans un Courrier (#viplecalandar)

public struct VipleCalendarMailInviteCardView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let invite: ParsedVipleCalendarInvite
    @State private var isImporting: Bool = false

    public init(invite: ParsedVipleCalendarInvite) {
        self.invite = invite
    }

    public var body: some View {
        let alreadyAdded = vm.isInviteAlreadyInAgenda(invite)
        let hasVisio = !(invite.visioJoinUrl ?? "").isEmpty

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: hasVisio ? "video.badge.checkmark" : "calendar.badge.clock")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(hasVisio ? VipleMailPalette.indigo : VipleMailPalette.primary)
                Text(hasVisio ? "SESSION VIPLE VISIO & AGENDA (#viplecalandar)" : "PROPOSITION DE RENDEZ-VOUS (#viplecalandar)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(hasVisio ? VipleMailPalette.indigo : VipleMailPalette.primary)
                Spacer()
            }

            Text(invite.title)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            VStack(alignment: .leading, spacing: 4) {
                Label(
                    "\(invite.startDate.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "fr_FR"))).capitalized) • \(invite.startDate.formatted(date: .omitted, time: .shortened)) – \(invite.endDate.formatted(date: .omitted, time: .shortened))",
                    systemImage: "clock.fill"
                )
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VipleMailPalette.inkSecondary)

                if !invite.location.isEmpty {
                    Label(invite.location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 12.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                if !invite.notes.isEmpty {
                    Text(invite.notes)
                        .font(.system(size: 12.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            HStack(spacing: 10) {
                Button {
                    if alreadyAdded {
                        vm.closeMessage()
                        vm.selectedTab = 2 // Onglet Agenda
                    } else {
                        Task {
                            isImporting = true
                            await vm.addParsedMailInviteToAgenda(invite)
                            isImporting = false
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isImporting {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "calendar.badge.plus")
                        }
                        Text(alreadyAdded ? "Ajouté à l'agenda (Voir)" : "Ajouter à l'agenda")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(alreadyAdded ? VipleMailPalette.success : VipleMailPalette.primary)
                    )
                }
                .disabled(isImporting)

                if let visioUrl = invite.visioJoinUrl, !visioUrl.isEmpty {
                    Button {
                        var join = visioUrl
                        if !join.contains("embed=") {
                            join += (join.contains("?") ? "&" : "?") + "nosso=1&embed=1&autojoin=1"
                        }
                        if let myName = vm.currentUser?.displayName, !join.contains("name=") {
                            let enc = myName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? myName
                            join += "&name=\(enc)"
                        }
                        vm.activeVisioRoomSession = VipleVisioRoomPresentation(
                            id: invite.id,
                            title: invite.title,
                            peerName: "Salon Viple Visio",
                            joinUrl: join,
                            isAudioOnly: false
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                            Text("Rejoindre Visio")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(VipleMailPalette.indigo)
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VipleMailPalette.surfaceSubtle)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(hasVisio ? VipleMailPalette.indigo.opacity(0.45) : VipleMailPalette.primary.opacity(0.35), lineWidth: 1.4)
                )
        )
    }
}
