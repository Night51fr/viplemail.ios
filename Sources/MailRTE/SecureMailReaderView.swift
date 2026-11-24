import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Conteneur UIKit Anti-Capture d'Écran Matériel (DLP Secure Enclave Compositor)

#if canImport(UIKit)
private struct DlpScreenshotShieldRepresentable<Content: View>: UIViewRepresentable {
    let preventScreenshot: Bool
    let colorScheme: ColorScheme
    let content: Content

    func makeUIView(context: Context) -> UIView {
        let wrapper = UIView()
        wrapper.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: content)
        hostingController.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.hostingController = hostingController

        if preventScreenshot {
            // Astuce officielle du compositeur iOS : l'insertion dans la sous-couche d'un UITextField
            // isSecureTextEntry masque automatiquement le rendu lors des captures d'écran et AirPlay/ScreenRecording.
            let secureField = UITextField()
            secureField.isSecureTextEntry = true
            secureField.isUserInteractionEnabled = false
            secureField.backgroundColor = .clear
            secureField.translatesAutoresizingMaskIntoConstraints = false
            wrapper.addSubview(secureField)

            NSLayoutConstraint.activate([
                secureField.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                secureField.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                secureField.topAnchor.constraint(equalTo: wrapper.topAnchor),
                secureField.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
            ])

            if let secureCanvas = secureField.subviews.first {
                secureCanvas.isUserInteractionEnabled = true
                secureCanvas.addSubview(hostingController.view)
                NSLayoutConstraint.activate([
                    hostingController.view.leadingAnchor.constraint(equalTo: secureCanvas.leadingAnchor),
                    hostingController.view.trailingAnchor.constraint(equalTo: secureCanvas.trailingAnchor),
                    hostingController.view.topAnchor.constraint(equalTo: secureCanvas.topAnchor),
                    hostingController.view.bottomAnchor.constraint(equalTo: secureCanvas.bottomAnchor)
                ])
                return wrapper
            }
        }

        wrapper.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: wrapper.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        return wrapper
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hostingController?.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
        context.coordinator.hostingController?.rootView = content
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostingController: UIHostingController<Content>?
    }
}
#endif

// MARK: - Vue SwiftUI de Lecture Protégée Cenelis MailRTE (Purge RAM Automatique sur scenePhase)

@MainActor
public struct SecureMailReaderView: View {
    public let container: MailRteClientContainer
    public let mailRteMimeHeader: String
    public let accessToken: String
    public let senderVerifiedOrganization: String? // Ex: "Cenelis SA" uniquement si @cenelis.com ou @viplenetwork.com

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @State private var volatileSession: VolatileDecryptedEmailSession?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isScreenCaptured = false

    public init(
        container: MailRteClientContainer,
        mailRteMimeHeader: String,
        accessToken: String,
        senderVerifiedOrganization: String? = nil
    ) {
        self.container = container
        self.mailRteMimeHeader = mailRteMimeHeader
        self.accessToken = accessToken
        self.senderVerifiedOrganization = senderVerifiedOrganization
    }

    public var body: some View {
        ZStack {
            VipleMailPalette.surface.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(VipleMailPalette.primary)
                        .controlSize(.large)
                    Text("Vérification matérielle Secure Enclave & déchiffrement Cenelis MailRTE…")
                        .font(.subheadline)
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else if let errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(VipleMailPalette.danger)
                    Text("Lecture protégée indisponible")
                        .font(.headline)
                        .foregroundStyle(VipleMailPalette.ink)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button("Réessayer la vérification matérielle") {
                        Task { await performRealtimeDecryption() }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(VipleMailPalette.primary)
                }
            } else if let session = volatileSession {
                protectedReaderBody(session: session)
            }

            // Bouclier DLP immédiat en cas d'enregistrement vidéo d'écran / recopie AirPlay active
            if isScreenCaptured && (volatileSession?.dlpPolicy.preventScreenshot ?? true) {
                VStack(spacing: 12) {
                    Image(systemName: "eye.slash.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(VipleMailPalette.primary)
                    Text("Capture d'écran bloquée par Cenelis MailRTE")
                        .font(.headline)
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Désactivez l'enregistrement d'écran ou la recopie vidéo pour consulter ce message protégé.")
                        .font(.footnote)
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            updateScreenCaptureState()
            await performRealtimeDecryption()
        }
        .onDisappear {
            purgeVolatileMemoryImmediately()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active {
                // Dès que l'application passe en arrière-plan ou dans le sélecteur multitâche,
                // la DEK et le texte clair sont intégralement effacés de la RAM.
                purgeVolatileMemoryImmediately()
                errorMessage = "Session volatile effacée par sécurité lors de la mise en arrière-plan."
            }
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            updateScreenCaptureState()
        }
        #endif
    }

    @ViewBuilder
    private func protectedReaderBody(session: VolatileDecryptedEmailSession) -> some View {
        let content = ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Objet déchiffré en RAM
                Text(session.subjectText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VipleMailPalette.ink)

                // En-tête classique du lecteur Viple Mail avec badge sécurité MailRTE dédié
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("De :")
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Text(session.sender)
                            .fontWeight(.medium)
                            .foregroundStyle(VipleMailPalette.ink)
                        if let org = senderVerifiedOrganization {
                            Label("Vérifiée : \(org)", systemImage: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                    .font(.subheadline)

                    HStack(spacing: 6) {
                        Text("À :")
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Text(session.recipient)
                            .foregroundStyle(VipleMailPalette.ink)
                    }
                    .font(.subheadline)

                    // Ligne Sécurité : badge vérifié exclusivement affiché dans cette section pour Cenelis MailRTE
                    HStack(spacing: 6) {
                        Text("Sécurité :")
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(VipleMailPalette.success)
                        Text("Chiffrement Cenelis MailRTE")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(VipleMailPalette.ink)
                    }
                    .font(.subheadline)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(VipleMailPalette.surfaceSubtle)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(VipleMailPalette.border, lineWidth: 1)
                )

                Divider()

                // Corps du message (sélection/copie désactivée si politique DLP active)
                if session.dlpPolicy.preventCopy {
                    Text(Self.stripBasicHtmlIfNeeded(session.bodyText))
                        .font(.body)
                        .foregroundStyle(VipleMailPalette.ink)
                        .textSelection(.disabled)
                } else {
                    Text(Self.stripBasicHtmlIfNeeded(session.bodyText))
                        .font(.body)
                        .foregroundStyle(VipleMailPalette.ink)
                        .textSelection(.enabled)
                }

                // Pièces jointes déchiffrées en mémoire volatile uniquement
                let attachments = session.attachmentsMetadata
                if !attachments.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pièces jointes chiffrées (\(attachments.count))")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        ForEach(attachments, id: \.id) { item in
                            HStack(spacing: 10) {
                                Image(systemName: "lock.doc.fill")
                                    .foregroundStyle(VipleMailPalette.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.fileName)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(VipleMailPalette.ink)
                                    Text("\(item.contentType) • \(ByteCountFormatter.string(fromByteCount: Int64(item.size), countStyle: .file))")
                                        .font(.caption2)
                                        .foregroundStyle(VipleMailPalette.inkMuted)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(VipleMailPalette.surfaceSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(VipleMailPalette.border, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .padding(18)
        }

        #if canImport(UIKit)
        DlpScreenshotShieldRepresentable(
            preventScreenshot: session.dlpPolicy.preventScreenshot,
            colorScheme: colorScheme,
            content: content
        )
        #else
        content
        #endif
    }

    private func performRealtimeDecryption() async {
        isLoading = true
        errorMessage = nil
        purgeVolatileMemoryImmediately()

        do {
            let decrypted = try await MailRteClientService.shared.decryptEmailRealtime(
                container: container,
                mailRteMimeHeader: mailRteMimeHeader,
                vipleLiveIdAccessToken: accessToken
            )
            volatileSession = decrypted
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func purgeVolatileMemoryImmediately() {
        volatileSession?.wipeFromMemory()
        volatileSession = nil
    }

    private func updateScreenCaptureState() {
        #if canImport(UIKit)
        isScreenCaptured = UIScreen.main.isCaptured
        #endif
    }

    private static func stripBasicHtmlIfNeeded(_ raw: String) -> String {
        guard raw.contains("<") || raw.contains("&") else { return raw }
        return raw
            .replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</div>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&rsquo;", with: "’")
            .replacingOccurrences(of: "&lsquo;", with: "‘")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Portail Interactif Code PIN Cenelis Connect intégré à la Vue Sécurisée Cenelis MailRTE

@MainActor
public struct MailRteCenelisPinGateView: View {
    public let message: VipleMailMessage
    public let mailboxEmail: String
    public let cid: String?
    public let onUnlocked: (VipleMailMessage) -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var expectedPinLength: Int = 6
    @State private var enteredDigits: String = ""
    @State private var isCheckingInfo: Bool = true
    @State private var isVerifyingPin: Bool = false
    @State private var errorMessage: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var pulseShield: Bool = false

    public init(
        message: VipleMailMessage,
        mailboxEmail: String,
        cid: String?,
        onUnlocked: @escaping (VipleMailMessage) -> Void
    ) {
        self.message = message
        self.mailboxEmail = mailboxEmail
        self.cid = cid
        self.onUnlocked = onUnlocked
    }

    public var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.31, green: 0.27, blue: 0.90).opacity(0.22),
                                Color(red: 0.01, green: 0.52, blue: 0.78).opacity(0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 78, height: 78)
                    .scaleEffect(pulseShield ? 1.09 : 0.96)
                    .animation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true), value: pulseShield)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.31, green: 0.27, blue: 0.90),
                                Color(red: 0.01, green: 0.52, blue: 0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: Color(red: 0.31, green: 0.27, blue: 0.90).opacity(0.35), radius: 12, y: 5)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
            .padding(.top, 6)

            VStack(spacing: 6) {
                Text("CENELIS MAILRTE • DIFFUSION INTERNE")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(Color(red: 0.38, green: 0.35, blue: 0.96))

                Text("Code PIN Cenelis Connect requis")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                    .multilineTextAlignment(.center)

                Text("Ce courrier est réservé aux agents habilités du Groupe Cenelis. Saisissez votre code PIN à \(expectedPinLength) chiffres pour déchiffrer et afficher la vue MailRTE.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // Pastilles du code PIN
            HStack(spacing: 12) {
                ForEach(0..<expectedPinLength, id: \.self) { idx in
                    let isFilled = idx < enteredDigits.count
                    Circle()
                        .fill(isFilled ? VipleMailPalette.primary : VipleMailPalette.resolvedSurface(for: colorScheme))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(isFilled ? VipleMailPalette.primary : VipleMailPalette.borderStrong, lineWidth: 1.6)
                        )
                        .scaleEffect(isFilled ? 1.12 : 1.0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.7), value: enteredDigits.count)
                }
            }
            .offset(x: shakeOffset)
            .padding(.vertical, 4)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.danger)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            // Sélecteur 4 / 6 chiffres rapide si l'agent utilise l'autre longueur
            HStack(spacing: 8) {
                ForEach([4, 6], id: \.self) { len in
                    Button {
                        expectedPinLength = len
                        enteredDigits = String(enteredDigits.prefix(len))
                        errorMessage = nil
                    } label: {
                        Text("PIN \(len) chiffres")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(expectedPinLength == len ? .white : VipleMailPalette.inkSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(expectedPinLength == len ? VipleMailPalette.primary : VipleMailPalette.resolvedSurface(for: colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Pavé numérique tactile natif Cenelis Connect
            VStack(spacing: 10) {
                let keypadRows: [[Int]] = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
                ForEach(0..<keypadRows.count, id: \.self) { rowIdx in
                    HStack(spacing: 12) {
                        ForEach(keypadRows[rowIdx], id: \.self) { digit in
                            pinDigitButton("\(digit)") {
                                appendDigit("\(digit)")
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        enteredDigits = ""
                        errorMessage = nil
                    } label: {
                        Text("Effacer")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .frame(width: 76, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VipleMailPalette.resolvedSurface(for: colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerifyingPin || enteredDigits.isEmpty)

                    pinDigitButton("0") {
                        appendDigit("0")
                    }

                    Button {
                        if !enteredDigits.isEmpty {
                            enteredDigits.removeLast()
                        }
                    } label: {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .frame(width: 76, height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VipleMailPalette.resolvedSurface(for: colorScheme))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isVerifyingPin || enteredDigits.isEmpty)
                }
            }
            .padding(.top, 2)

            if isVerifyingPin {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Vérification Cenelis Connect & déchiffrement MailRTE…")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(red: 0.31, green: 0.27, blue: 0.90).opacity(0.32), lineWidth: 1.2)
                )
        )
        .task {
            pulseShield = true
            await loadAgentPinConfiguration()
        }
    }

    private func pinDigitButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
                .frame(width: 76, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.resolvedSurface(for: colorScheme))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(VipleMailPalette.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(isVerifyingPin)
    }

    private func appendDigit(_ digit: String) {
        guard !isVerifyingPin, enteredDigits.count < expectedPinLength else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
        errorMessage = nil
        enteredDigits.append(digit)
        if enteredDigits.count == expectedPinLength {
            let pinToVerify = enteredDigits
            Task {
                await submitPin(pinToVerify)
            }
        }
    }

    private func loadAgentPinConfiguration() async {
        defer { isCheckingInfo = false }
        let targetMbx = message.effectiveMailboxEmail(fallback: mailboxEmail)
        guard !targetMbx.isEmpty else { return }
        if let info = try? await VipleMailAPIClient.shared.fetchMailRtePinInfo(email: targetMbx, cid: cid) {
            if let len = info.pinLength, (len == 4 || len == 6) {
                expectedPinLength = len
            }
            if info.isAgent == false {
                errorMessage = info.error ?? "Accès réservé aux Agents Cenelis."
            } else if info.needsSetup == true || info.hasPin == false {
                errorMessage = info.error ?? "Configurez d'abord votre code PIN Cenelis Connect depuis la Console Admin ou Cenelis Connect."
            }
        }
    }

    private func submitPin(_ pin: String) async {
        isVerifyingPin = true
        defer { isVerifyingPin = false }

        let targetMbx = message.effectiveMailboxEmail(fallback: mailboxEmail)
        do {
            let res = try await VipleMailAPIClient.shared.unlockPinProtectedMail(
                mailboxEmail: targetMbx,
                cid: cid,
                messageId: message.id,
                pin: pin
            )
            if res.ok, let unlocked = res.message {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                #endif
                enteredDigits = ""
                onUnlocked(unlocked)
            } else {
                triggerErrorShake(res.error ?? "Code PIN Cenelis Connect incorrect.")
            }
        } catch {
            triggerErrorShake(error.localizedDescription)
        }
    }

    private func triggerErrorShake(_ msg: String) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
        errorMessage = msg
        enteredDigits = ""
        withAnimation(.default) { shakeOffset = -10 }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 70_000_000)
            withAnimation(.default) { shakeOffset = 10 }
            try? await Task.sleep(nanoseconds: 70_000_000)
            withAnimation(.default) { shakeOffset = -6 }
            try? await Task.sleep(nanoseconds: 70_000_000)
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { shakeOffset = 0 }
        }
    }
}
