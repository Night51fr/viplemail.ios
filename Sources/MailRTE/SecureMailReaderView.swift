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
        guard raw.contains("<") && raw.contains(">") else { return raw }
        return raw
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
