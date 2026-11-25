import SwiftUI
#if canImport(UIKit)
import UIKit
import AVFoundation
#endif

// MARK: - 1. Studio d'Appel Audio & Vidéo 100 % Natif iOS « Viple Visio » (Zéro WebView)

public struct NativeVipleVisioCallStudioView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let session: VipleVisioRoomPresentation

    @StateObject private var engine: NativeVipleVisioEngine
    @State private var pipOffset: CGSize = .zero
    @State private var pipSavedOffset: CGSize = .zero

    public init(
        session: VipleVisioRoomPresentation,
        localEmail: String,
        localDisplayName: String
    ) {
        self.session = session
        _engine = StateObject(
            wrappedValue: NativeVipleVisioEngine(
                roomCode: session.roomCode,
                localEmail: localEmail,
                localDisplayName: localDisplayName,
                initialAudioOnly: session.isAudioOnly,
                isDirectOneToOneCall: session.activeCallId != nil
            )
        )
    }

    private var isCompactScreen: Bool {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width <= 385 || UIScreen.main.bounds.height <= 700
        #else
        return false
        #endif
    }

    private var isShowingVideoStage: Bool {
        engine.isVideoEnabled || engine.peers.contains(where: { $0.videoEnabled })
    }

    private var primaryPeer: NativeVisioPeer? {
        engine.peers.first
    }

    private var resolvedPeerName: String {
        if let p = primaryPeer, !p.displayName.isEmpty {
            return p.displayName
        }
        return session.peerName
    }

    private var resolvedPeerEmail: String {
        if let p = primaryPeer, !p.email.isEmpty {
            return p.email
        }
        return session.peerEmail ?? ""
    }

    private var resolvedPeerAvatarUrl: String? {
        if let p = primaryPeer, let av = p.avatarUrl, !av.isEmpty {
            return av
        }
        return session.peerAvatarUrl
    }

    private var statusSubtitle: String {
        switch engine.phase {
        case .connecting:
            return "Connexion native sécurisée…"
        case .reconnecting:
            return "Reconnexion temps réel…"
        case .ended:
            return "Appel terminé"
        case .connected:
            if engine.peers.isEmpty {
                return session.activeCallId != nil
                    ? "En attente du correspondant…"
                    : "Salon prêt • En attente des participants"
            }
            return engine.formattedDuration
        }
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.03, green: 0.06, blue: 0.14),
                        Color(red: 0.05, green: 0.13, blue: 0.27),
                        Color(red: 0.02, green: 0.04, blue: 0.09)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if isShowingVideoStage {
                    videoCallStage(in: geo.size)
                } else {
                    classicAudioCallStage
                }

                VStack(spacing: 0) {
                    topNativeCallHeader
                    if engine.micPermissionDenied || engine.cameraPermissionDenied {
                        permissionWarningBanner
                            .padding(.top, 6)
                    }
                    Spacer()
                    bottomNativeControlDock
                }
                .padding(.horizontal, isCompactScreen ? 12 : 18)
                .padding(.top, isCompactScreen ? 8 : 12)
                .padding(.bottom, isCompactScreen ? 16 : 28)

                #if canImport(UIKit)
                if engine.isVideoEnabled {
                    let pipW: CGFloat = isCompactScreen ? 92 : 110
                    let pipH: CGFloat = isCompactScreen ? 128 : 154
                    VStack {
                        HStack {
                            Spacer()
                            ZStack(alignment: .bottomTrailing) {
                                NativeCameraPreviewView(session: engine.localCaptureSession)
                                    .frame(width: pipW, height: pipH)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(
                                                engine.localVoiceLevel > 0.08
                                                    ? Color(red: 0.22, green: 0.90, blue: 0.62)
                                                    : Color.white.opacity(0.28),
                                                lineWidth: engine.localVoiceLevel > 0.08 ? 2.2 : 1.2
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 6)

                                Button {
                                    engine.flipCamera()
                                } label: {
                                    Image(systemName: "camera.rotate.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 26, height: 26)
                                        .background(Circle().fill(Color.black.opacity(0.62)))
                                }
                                .padding(6)
                            }
                            .offset(pipOffset)
                            .gesture(
                                DragGesture()
                                    .onChanged { val in
                                        pipOffset = CGSize(
                                            width: pipSavedOffset.width + val.translation.width,
                                            height: pipSavedOffset.height + val.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        pipSavedOffset = pipOffset
                                    }
                            )
                        }
                        Spacer()
                    }
                    .padding(.top, isCompactScreen ? 64 : 74)
                    .padding(.horizontal, isCompactScreen ? 12 : 16)
                }
                #endif
            }
        }
        .task {
            engine.onRemotePeerHangup = {
                Task { @MainActor in
                    await vm.closeActiveVisioRoom()
                }
            }
            await engine.start()
        }
        .onDisappear {
            engine.disconnect(sendHangupSignal: true)
        }
    }

    // MARK: - Barre Supérieure Native

    private var topNativeCallHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(engine.phase == .connected
                          ? Color(red: 0.20, green: 0.90, blue: 0.58)
                          : Color.orange)
                    .frame(width: 7, height: 7)

                Image(systemName: isShowingVideoStage ? "video.fill" : "phone.waveform.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.38, green: 0.86, blue: 1.0))

                Text(isShowingVideoStage ? "Viple Visio Natif" : "Appel Viple Natif")
                    .font(.system(size: isCompactScreen ? 12 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.black.opacity(0.42)))
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 0.8))

            Spacer(minLength: 4)

            if session.activeCallId == nil {
                Text("#\(session.roomCode)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.10)))
            }

            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Color(red: 0.25, green: 0.90, blue: 0.65))
                Text("TLS 1.3")
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.black.opacity(0.38)))
        }
    }

    private var permissionWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .font(.system(size: 13, weight: .bold))
            Text(engine.micPermissionDenied
                 ? "Accès micro désactivé dans Réglages iOS > Viple Mail."
                 : "Accès caméra désactivé dans Réglages iOS > Viple Mail.")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.red.opacity(0.38)))
    }

    // MARK: - Scène Appel Classique Audio (100 % Natif style Téléphone / FaceTime Audio)

    private var classicAudioCallStage: some View {
        let avatarSize: CGFloat = isCompactScreen ? 96 : 118
        let remoteSpeaking = primaryPeer?.isSpeaking == true
        let activeLevel = max(engine.localVoiceLevel, remoteSpeaking ? 0.65 : 0.0)

        return VStack(spacing: isCompactScreen ? 16 : 24) {
            Spacer(minLength: isCompactScreen ? 54 : 72)

            ZStack {
                Circle()
                    .stroke(Color.cyan.opacity(0.18 + Double(activeLevel) * 0.35), lineWidth: 2)
                    .frame(
                        width: avatarSize + 44 + activeLevel * 28,
                        height: avatarSize + 44 + activeLevel * 28
                    )
                    .animation(.easeOut(duration: 0.16), value: activeLevel)

                Circle()
                    .fill(Color(red: 0.16, green: 0.62, blue: 0.98).opacity(0.14 + Double(activeLevel) * 0.22))
                    .frame(
                        width: avatarSize + 20 + activeLevel * 16,
                        height: avatarSize + 20 + activeLevel * 16
                    )
                    .animation(.easeOut(duration: 0.16), value: activeLevel)

                VipleMailAvatarView(
                    name: resolvedPeerName,
                    email: resolvedPeerEmail,
                    avatarUrl: resolvedPeerAvatarUrl,
                    size: avatarSize,
                    isVip: true
                )
            }

            VStack(spacing: 5) {
                Text(resolvedPeerName)
                    .font(.system(size: isCompactScreen ? 23 : 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                if !resolvedPeerEmail.isEmpty {
                    Text(resolvedPeerEmail)
                        .font(.system(size: isCompactScreen ? 12.5 : 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Text(statusSubtitle)
                    .font(.system(size: isCompactScreen ? 14 : 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color(red: 0.38, green: 0.88, blue: 1.0))
                    .padding(.top, 4)

                if let peer = primaryPeer, peer.audioMuted {
                    Label("Micro coupé par le correspondant", systemImage: "mic.slash.fill")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 16)

            if engine.peers.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(engine.peers) { peer in
                            VStack(spacing: 4) {
                                VipleMailAvatarView(
                                    name: peer.displayName,
                                    email: peer.email,
                                    avatarUrl: peer.avatarUrl,
                                    size: 46,
                                    isVip: false
                                )
                                .overlay(
                                    Circle()
                                        .stroke(peer.isSpeaking ? Color.green : Color.clear, lineWidth: 2.5)
                                )
                                Text(peer.displayName)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .frame(maxWidth: 72)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer(minLength: isCompactScreen ? 86 : 110)
        }
    }

    // MARK: - Scène Appel Vidéo Temps Réel (100 % Natif iOS)

    @ViewBuilder
    private func videoCallStage(in size: CGSize) -> some View {
        if engine.peers.isEmpty {
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text(session.title)
                    .font(.system(size: isCompactScreen ? 18 : 21, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(statusSubtitle)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.76))
            }
            .padding(.horizontal, 24)
        } else if engine.peers.count == 1, let peer = engine.peers.first {
            ZStack {
                #if canImport(UIKit)
                if peer.videoEnabled, let frame = peer.latestVideoFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    remoteAudioOnlyFallbackTile(peer)
                }
                #else
                remoteAudioOnlyFallbackTile(peer)
                #endif

                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        if peer.audioMuted {
                            Image(systemName: "mic.slash.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        Text(peer.displayName)
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text("• \(engine.formattedDuration)")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.50)))
                    .padding(.bottom, isCompactScreen ? 96 : 114)
                }
            }
        } else {
            let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(engine.peers) { peer in
                        ZStack(alignment: .bottomLeading) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.07))

                            #if canImport(UIKit)
                            if peer.videoEnabled, let frame = peer.latestVideoFrame {
                                Image(uiImage: frame)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: isCompactScreen ? 185 : 225)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            } else {
                                VStack(spacing: 8) {
                                    VipleMailAvatarView(
                                        name: peer.displayName,
                                        email: peer.email,
                                        avatarUrl: peer.avatarUrl,
                                        size: 56
                                    )
                                    Text(peer.displayName)
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: isCompactScreen ? 185 : 225)
                            }
                            #endif

                            HStack(spacing: 4) {
                                if peer.audioMuted {
                                    Image(systemName: "mic.slash.fill")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.red)
                                }
                                Text(peer.displayName)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .padding(8)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(peer.isSpeaking ? Color.green : Color.white.opacity(0.14), lineWidth: peer.isSpeaking ? 2.2 : 1)
                        )
                    }
                }
                .padding(.top, isCompactScreen ? 62 : 74)
                .padding(.bottom, isCompactScreen ? 100 : 120)
                .padding(.horizontal, 12)
            }
        }
    }

    private func remoteAudioOnlyFallbackTile(_ peer: NativeVisioPeer) -> some View {
        VStack(spacing: 14) {
            VipleMailAvatarView(
                name: peer.displayName,
                email: peer.email,
                avatarUrl: peer.avatarUrl,
                size: isCompactScreen ? 88 : 108,
                isVip: true
            )
            .overlay(
                Circle()
                    .stroke(peer.isSpeaking ? Color(red: 0.22, green: 0.90, blue: 0.62) : Color.clear, lineWidth: 3)
                    .scaleEffect(peer.isSpeaking ? 1.08 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: peer.isSpeaking)
            )

            Text(peer.displayName)
                .font(.system(size: isCompactScreen ? 21 : 25, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text("Caméra désactivée • Audio actif")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    // MARK: - Dock Inférieur de Contrôles Natifs (Optimisé iPhone SE 375pt)

    private var bottomNativeControlDock: some View {
        let btnSize: CGFloat = isCompactScreen ? 48 : 54
        let spacing: CGFloat = isCompactScreen ? 10 : 16

        return HStack(spacing: spacing) {
            callControlButton(
                icon: engine.isMuted ? "mic.slash.fill" : "mic.fill",
                label: engine.isMuted ? "Réactiver" : "Muet",
                isActive: engine.isMuted,
                activeColor: .white,
                activeForeground: .black,
                size: btnSize
            ) {
                engine.toggleMute()
            }

            callControlButton(
                icon: engine.isSpeakerphoneOn ? "speaker.wave.3.fill" : "ear",
                label: engine.isSpeakerphoneOn ? "Haut-parl." : "Écouteur",
                isActive: engine.isSpeakerphoneOn,
                activeColor: Color.white.opacity(0.26),
                activeForeground: .white,
                size: btnSize
            ) {
                engine.toggleSpeakerphone()
            }

            callControlButton(
                icon: engine.isVideoEnabled ? "video.fill" : "video.slash.fill",
                label: engine.isVideoEnabled ? "Caméra" : "Visio",
                isActive: engine.isVideoEnabled,
                activeColor: Color(red: 0.12, green: 0.56, blue: 0.98),
                activeForeground: .white,
                size: btnSize
            ) {
                Task {
                    await engine.toggleVideo()
                }
            }

            if engine.isVideoEnabled {
                callControlButton(
                    icon: "camera.rotate.fill",
                    label: "Tourner",
                    isActive: false,
                    activeColor: .clear,
                    activeForeground: .white,
                    size: btnSize
                ) {
                    engine.flipCamera()
                }
            }

            Button {
                engine.disconnect(sendHangupSignal: true)
                Task {
                    await vm.closeActiveVisioRoom()
                }
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.92, green: 0.20, blue: 0.23))
                            .frame(width: btnSize, height: btnSize)
                            .shadow(color: Color.red.opacity(0.38), radius: 8, x: 0, y: 4)
                        Image(systemName: "phone.down.fill")
                            .font(.system(size: isCompactScreen ? 18 : 20, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text("Quitter")
                        .font(.system(size: isCompactScreen ? 9.5 : 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, isCompactScreen ? 14 : 20)
        .padding(.vertical, isCompactScreen ? 10 : 13)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.56))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
    }

    private func callControlButton(
        icon: String,
        label: String,
        isActive: Bool,
        activeColor: Color,
        activeForeground: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isActive ? activeColor : Color.white.opacity(0.14))
                        .frame(width: size, height: size)
                    Image(systemName: icon)
                        .font(.system(size: isCompactScreen ? 17 : 19, weight: .semibold))
                        .foregroundStyle(isActive ? activeForeground : .white)
                }
                Text(label)
                    .font(.system(size: isCompactScreen ? 9.5 : 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}

// MARK: - 2. Superposition Globale d'Appels Entrants / Sortants « Viple Visio »

public struct VipleVisioGlobalCallOverlay: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var pulseRing: Bool = false

    public init() {}

    private var isCompactScreen: Bool {
        #if canImport(UIKit)
        return UIScreen.main.bounds.width <= 385 || UIScreen.main.bounds.height <= 700
        #else
        return false
        #endif
    }

    public var body: some View {
        ZStack {
            if let roomSession = vm.activeVisioRoomSession {
                NativeVipleVisioCallStudioView(
                    session: roomSession,
                    localEmail: vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail,
                    localDisplayName: vm.currentUser?.displayName ?? vm.primaryHostedEmail
                )
                .id(roomSession.id)
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

            VStack(spacing: isCompactScreen ? 16 : 24) {
                Spacer()

                HStack(spacing: 6) {
                    Image(systemName: call.isAudioOnly ? "phone.fill" : "video.fill")
                    Text(call.isAudioOnly ? "VIPLE VISIO • APPEL AUDIO ENTRANT" : "VIPLE VISIO • APPEL VIDÉO ENTRANT")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .font(.system(size: isCompactScreen ? 10.5 : 11.5, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(Color(red: 0.35, green: 0.85, blue: 1.0))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.10)))

                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(pulseRing ? 0.05 : 0.38), lineWidth: 2.5)
                        .frame(width: pulseRing ? (isCompactScreen ? 156 : 190) : 114,
                               height: pulseRing ? (isCompactScreen ? 156 : 190) : 114)
                    Circle()
                        .stroke(Color.blue.opacity(pulseRing ? 0.12 : 0.45), lineWidth: 2)
                        .frame(width: pulseRing ? (isCompactScreen ? 132 : 156) : 106,
                               height: pulseRing ? (isCompactScreen ? 132 : 156) : 106)

                    VipleMailAvatarView(
                        name: call.callerName,
                        email: call.callerEmail,
                        avatarUrl: call.callerAvatarUrl,
                        size: isCompactScreen ? 92 : 106,
                        isVip: true
                    )
                }
                .onAppear {
                    pulseRing = false
                    withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) {
                        pulseRing = true
                    }
                }

                VStack(spacing: 5) {
                    Text(call.callerName)
                        .font(.system(size: isCompactScreen ? 23 : 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(call.callerEmail)
                        .font(.system(size: isCompactScreen ? 13 : 14.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Ami Viple Live ID vérifié")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.90, blue: 0.65))
                        .padding(.top, 2)
                }

                Spacer()

                HStack(spacing: isCompactScreen ? 40 : 52) {
                    Button {
                        Task {
                            await vm.declineOrEndVisioCall(call, action: "decline")
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.92, green: 0.22, blue: 0.24))
                                    .frame(width: isCompactScreen ? 64 : 72, height: isCompactScreen ? 64 : 72)
                                Image(systemName: "phone.down.fill")
                                    .font(.system(size: isCompactScreen ? 22 : 26, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text("Refuser")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }

                    Button {
                        Task {
                            await vm.answerIncomingVisioCall(call)
                        }
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.12, green: 0.78, blue: 0.46))
                                    .frame(width: isCompactScreen ? 64 : 72, height: isCompactScreen ? 64 : 72)
                                Image(systemName: call.isAudioOnly ? "phone.fill" : "video.fill")
                                    .font(.system(size: isCompactScreen ? 22 : 26, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text("Accepter")
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.bottom, isCompactScreen ? 32 : 54)
            }
            .padding(.horizontal, isCompactScreen ? 18 : 24)
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

            VStack(spacing: isCompactScreen ? 16 : 22) {
                Spacer()

                Text(call.isAudioOnly ? "APPEL CLASSIQUE AUDIO EN COURS…" : "APPEL VIPLE VISIO EN COURS…")
                    .font(.system(size: isCompactScreen ? 11 : 12, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(Color.cyan)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                VipleMailAvatarView(
                    name: call.calleeName,
                    email: call.calleeEmail,
                    avatarUrl: call.calleeAvatarUrl,
                    size: isCompactScreen ? 92 : 104,
                    isVip: true
                )

                VStack(spacing: 6) {
                    Text(call.calleeName)
                        .font(.system(size: isCompactScreen ? 22 : 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("Sonnerie sur son Viple Mail…")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Button {
                    Task {
                        await vm.declineOrEndVisioCall(call, action: "hangup")
                    }
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.92, green: 0.22, blue: 0.24))
                                .frame(width: isCompactScreen ? 64 : 72, height: isCompactScreen ? 64 : 72)
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: isCompactScreen ? 22 : 26, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        Text("Annuler l'appel")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.bottom, isCompactScreen ? 32 : 54)
            }
            .padding(.horizontal, isCompactScreen ? 18 : 24)
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
                        Label("Rejoindre Visio", systemImage: "video.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(VipleMailPalette.indigo))
                    }

                    Button {
                        eventForGuestLinkSheet = ev
                    } label: {
                        Label("Lien par mail", systemImage: "paperplane.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.horizontal, 11)
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
                        vm.activeVisioRoomSession = VipleVisioRoomPresentation(
                            id: invite.id,
                            title: invite.title,
                            peerName: "Salon Viple Visio",
                            peerEmail: invite.organizerEmail,
                            peerAvatarUrl: vm.resolveAvatarUrl(for: invite.organizerEmail),
                            joinUrl: visioUrl,
                            isAudioOnly: false
                        )
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "video.fill")
                            Text("Rejoindre Visio")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
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
