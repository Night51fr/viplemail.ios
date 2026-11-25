import Foundation
import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
import LocalAuthentication
@preconcurrency import AVFAudio
#endif

// MARK: - Lot 5 : Sécurité Souveraine, Confidentialité & MailRTE+ (#041..#050)

public struct BetaBiometricPrivacyShieldOverlay: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var authError: String? = nil

    public init() {}

    public var body: some View {
        Group {
            if beta.isEnabled(.f041) && (scenePhase != .active || !beta.isBiometricAppUnlocked) {
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    Color.black.opacity(0.65)
                        .ignoresSafeArea()

                    VStack(spacing: 18) {
                        Image(systemName: "faceid")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(.cyan)

                        Text("Viple Mail Verrouillé")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Protection biométrique souveraine active (#041).")
                            .font(.system(size: 13.5))
                            .foregroundStyle(.white.opacity(0.8))
                            .multilineTextAlignment(.center)

                        if let err = authError {
                            Text(err)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                        }

                        Button {
                            authenticateNow()
                        } label: {
                            Label("Déverrouiller avec Face ID / Code", systemImage: "lock.open.fill")
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(VipleMailPalette.primary))
                        }
                    }
                    .padding(28)
                }
                .onAppear {
                    if scenePhase == .active && !beta.isBiometricAppUnlocked {
                        authenticateNow()
                    }
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if beta.isEnabled(.f041) && newPhase == .background {
                beta.isBiometricAppUnlocked = false
            }
        }
    }

    private func authenticateNow() {
        #if canImport(UIKit)
        let ctx = LAContext()
        var err: NSError?
        if ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err) {
            ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Déverrouillez votre messagerie Viple Mail") { success, evalError in
                Task { @MainActor in
                    if success {
                        authError = nil
                        beta.isBiometricAppUnlocked = true
                        beta.recordAudit(category: "Face ID", summary: "Déverrouillage biométrique réussi")
                    } else {
                        authError = evalError?.localizedDescription
                    }
                }
            }
        } else {
            beta.isBiometricAppUnlocked = true
        }
        #else
        beta.isBiometricAppUnlocked = true
        #endif
    }
}

public enum BetaSecurityInspector {
    public struct TrustAnalysis {
        public let score: Int
        public let verdict: String
        public let findings: [String]
        public let blockedTrackersInMail: Int
    }

    public static func evaluate(message: VipleMailMessage) -> TrustAnalysis {
        var score = 70
        var findings: [String] = []

        if let org = message.effectiveVerifiedOrganization {
            score += 22
            findings.append("Entité authentifiée : \(org) (DKIM/SPF/DMARC)")
        }
        if message.effectiveIsMailRteSecurity {
            score += 15
            findings.append("Conteneur post-quantique hybride Cenelis MailRTE vérifié")
        }
        if message.isTransportUnencrypted == true {
            score -= 28
            findings.append("⚠️ Transport entrant non chiffré")
        }

        let senderLower = message.senderEmail.lowercased()
        if senderLower.contains("xn--") {
            score -= 35
            findings.append("🚨 Domaine internationalisé Punycode (risque d'homoglyphe IDN)")
        }
        if message.senderName.contains("@") && !message.senderName.lowercased().contains(senderLower) {
            score -= 32
            findings.append("🚨 Le nom affiché contient une autre adresse e-mail que l'expéditeur réel")
        }

        let lowerText = "\(message.subject) \(message.plainBodyText)".lowercased()
        let fraudSignals = ["changement de rib", "nouvel iban", "virement urgent", "mot de passe a expiré", "cliquez immédiatement"]
        if fraudSignals.contains(where: { lowerText.contains($0) }) && message.effectiveVerifiedOrganization == nil {
            score -= 26
            findings.append("⚠️ Formulation sensible détectée (virement / IBAN / urgence)")
        }

        let trackers = countTrackingPixels(in: message.bodyHtml)
        let clamped = min(100, max(5, score))
        let verdict: String
        if clamped >= 80 { verdict = "Confiance Élevée" }
        else if clamped >= 55 { verdict = "Vigilance Standard" }
        else { verdict = "Risque Suspect — Vérifier l'expéditeur" }

        return TrustAnalysis(score: clamped, verdict: verdict, findings: findings, blockedTrackersInMail: trackers)
    }

    public static func countTrackingPixels(in html: String) -> Int {
        let lower = html.lowercased()
        var count = 0
        for token in ["width=\"1\"", "width='1'", "height=\"1\"", "1x1", "pixel", "utm_medium=", "open?id="] {
            if lower.contains(token) { count += 1 }
        }
        return count
    }

    public static func sanitizeHtmlTrackers(_ html: String) -> String {
        guard VipleBetaStore.shared.isEnabled(.f046) else { return html }
        return html.replacingOccurrences(
            of: #"<img[^>]*(?:width=['"]?1['"]?|height=['"]?1['"]?|1x1|pixel)[^>]*>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    public static func stripTrackingParams(from rawUrl: String) -> String {
        guard var comps = URLComponents(string: rawUrl), let items = comps.queryItems else { return rawUrl }
        let blockedPrefixes = ["utm_", "fbclid", "gclid", "mc_eid", "mkt_tok", "_hsenc"]
        comps.queryItems = items.filter { item in
            let n = item.name.lowercased()
            return !blockedPrefixes.contains(where: { n.hasPrefix($0) })
        }
        if comps.queryItems?.isEmpty == true { comps.queryItems = nil }
        return comps.url?.absoluteString ?? rawUrl
    }
}

public struct BetaSecurityTrustInlineBanner: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    public let message: VipleMailMessage
    @State private var expanded: Bool = false

    public var body: some View {
        let report = BetaSecurityInspector.evaluate(message: message)
        let badgeColor: Color = report.score >= 80 ? VipleMailPalette.success : (report.score >= 55 ? VipleMailPalette.primary : VipleMailPalette.danger)

        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: report.score >= 55 ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(badgeColor)
                    if beta.isEnabled(.f042) {
                        Text("Confiance \(report.score)/100 • \(report.verdict)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(badgeColor)
                    }
                    Spacer()
                    if beta.isEnabled(.f046) && report.blockedTrackersInMail > 0 {
                        Text("🛡️ \(report.blockedTrackersInMail) traceur(s)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.teal)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                ForEach(report.findings, id: \.self) { line in
                    Text("• \(line)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(badgeColor.opacity(0.09))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(badgeColor.opacity(0.28), lineWidth: 1))
        )
    }
}

public struct BetaConfidentialWatermarkOverlay: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    public let viewerEmail: String

    public init(viewerEmail: String) {
        self.viewerEmail = viewerEmail
    }

    public var body: some View {
        if beta.isEnabled(.f048) {
            GeometryReader { _ in
                VStack(spacing: 68) {
                    ForEach(0..<6, id: \.self) { _ in
                        Text("CONFIDENTIEL • \(viewerEmail.uppercased()) • \(Date().formatted(date: .numeric, time: .shortened))")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.inkMuted.opacity(0.14))
                            .rotationEffect(.degrees(-22))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .allowsHitTesting(false)
        }
    }
}

public struct BetaRfcHeaderInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var rfcEnvelopeDump: String {
        let sha = SHA256.hash(data: Data("\(message.id)|\(message.subject)|\(message.plainBodyText)".utf8)).map { String(format: "%02x", $0) }.joined()
        return """
        Return-Path: <\(message.senderEmail)>
        Received: from mail.viplemail.fr (Stalwart JMAP/IMAP TLS 1.3)
        Message-ID: <\(message.id)@viplemail.fr>
        Thread-Index: \(message.threadId)
        From: \(message.senderName) <\(message.senderEmail)>
        To: \(message.recipientEmail)
        Date: \(message.receivedAt)
        Subject: \(message.subject)
        X-Viple-Security: \(message.effectiveEncryptionLabel)
        X-Viple-Verified-Entity: \(message.effectiveVerifiedOrganization ?? "none")
        X-Viple-SHA256-Body: \(sha)
        MIME-Size-Bytes: \(message.sizeBytes)
        """
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(rfcEnvelopeDump)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                        .textSelection(.enabled)

                    ShareLink(item: rfcEnvelopeDump) {
                        Label("Copier / Partager le rapport RFC & SHA-256", systemImage: "doc.on.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(16)
            }
            .navigationTitle("Inspecteur RFC & Crypto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaVaultSealMessageSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    @State private var passphrase: String = ""
    @State private var statusError: String? = nil

    public init(message: VipleMailMessage) {
        self.message = message
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Sceller une copie AES-256-GCM hors-ligne") {
                    Text(message.subject).font(.system(size: 14, weight: .bold))
                    SecureField("Phrase secrète maître (min. 4 caractères)", text: $passphrase)
                    if let err = statusError {
                        Text(err).foregroundStyle(VipleMailPalette.danger).font(.system(size: 12))
                    }
                    Button("Chiffrer et archiver dans le Coffre") {
                        do {
                            try beta.sealMessageInVault(message, passphrase: passphrase)
                            dismiss()
                        } catch {
                            statusError = error.localizedDescription
                        }
                    }
                    .fontWeight(.bold)
                }
            }
            .navigationTitle("Coffre-Fort AES-256")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
            }
        }
    }
}

public struct BetaEncryptedVaultManagerView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var unlockPassphrase: String = ""
    @State private var decryptedContent: [String: String]? = nil
    @State private var errorMsg: String? = nil

    public init() {}

    public var body: some View {
        Form {
            Section("Déverrouillage CryptoKit (HKDF + AES-256-GCM)") {
                SecureField("Phrase secrète de déchiffrement", text: $unlockPassphrase)
                if let err = errorMsg {
                    Text(err).font(.system(size: 12)).foregroundStyle(VipleMailPalette.danger)
                }
            }
            if let clear = decryptedContent {
                Section("Courrier déchiffré en mémoire volatile") {
                    Text(clear["subject"] ?? "").font(.headline)
                    Text("De : \(clear["from"] ?? "") • \(clear["date"] ?? "")")
                        .font(.caption)
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Text(clear["body"] ?? "")
                        .font(.system(size: 13.5))
                        .textSelection(.enabled)
                    Button("Refermer l'enveloppe") { decryptedContent = nil }
                }
            }
            Section("Archives scellées hors-ligne (\(beta.encryptedVaultRecords.count))") {
                if beta.encryptedVaultRecords.isEmpty {
                    Text("Aucune archive scellée. Ouvrez un courrier et touchez « Coffre AES » pour en archiver un.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(beta.encryptedVaultRecords) { rec in
                        Button {
                            do {
                                errorMsg = nil
                                decryptedContent = try beta.unsealVaultRecord(rec, passphrase: unlockPassphrase)
                            } catch {
                                errorMsg = "Phrase secrète incorrecte ou déchiffrement refusé."
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(rec.subjectHint).font(.system(size: 14, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                Text("SHA-256 : \(rec.sha256Hex.prefix(20))… • \(rec.sealedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        beta.encryptedVaultRecords.remove(atOffsets: offsets)
                        beta.saveState()
                    }
                }
            }
        }
    }
}

public struct BetaCloakedAliasGeneratorView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var serviceName: String = ""

    public init() {}

    private var baseParts: (local: String, domain: String) {
        let base = vm.primaryHostedEmail.isEmpty ? "utilisateur@viplemail.fr" : vm.primaryHostedEmail
        let parts = base.split(separator: "@")
        return (String(parts.first ?? "user"), String(parts.last ?? "viplemail.fr"))
    }

    public var body: some View {
        Form {
            Section("Créer un alias cloisonné (+service)") {
                TextField("Nom du site ou marchand (ex: Amazon, SNCF)", text: $serviceName)
                let slug = serviceName.lowercased().filter { $0.isLetter || $0.isNumber }
                let preview = "\(baseParts.local)+\(slug.isEmpty ? "marchand" : slug)@\(baseParts.domain)"
                Text("Alias généré : \(preview)")
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(VipleMailPalette.primary)

                Button("Créer et copier cet alias") {
                    let entry = BetaAliasEntry(id: UUID().uuidString, serviceName: serviceName, aliasEmail: preview, isRevoked: false, createdAt: Date())
                    beta.generatedAliases.insert(entry, at: 0)
                    beta.saveState()
                    #if canImport(UIKit)
                    UIPasteboard.general.string = preview
                    #endif
                    serviceName = ""
                    vm.showToast("🛡️ Alias copié dans le presse-papiers !")
                }
                .disabled(serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Registre de mes alias actifs (\(beta.generatedAliases.count))") {
                ForEach(beta.generatedAliases) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.serviceName).font(.system(size: 14, weight: .bold)).strikethrough(item.isRevoked)
                            Text(item.aliasEmail).font(.system(size: 12, design: .monospaced)).foregroundStyle(VipleMailPalette.primary)
                        }
                        Spacer()
                        Button(item.isRevoked ? "Réactiver" : "Couper") {
                            if let idx = beta.generatedAliases.firstIndex(where: { $0.id == item.id }) {
                                beta.generatedAliases[idx].isRevoked.toggle()
                                beta.saveState()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

public struct BetaSecurityAuditLogView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var urlToClean: String = ""

    public init() {}

    public var body: some View {
        List {
            Section("Purificateur de lien anti-tracking (#046)") {
                TextField("Coller une URL avec ?utm_source=…", text: $urlToClean)
                    .textInputAutocapitalization(.never)
                if !urlToClean.isEmpty {
                    let cleaned = BetaSecurityInspector.stripTrackingParams(from: urlToClean)
                    Text("URL purifiée : \(cleaned)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.success)
                    Button("Copier le lien purifié") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = cleaned
                        #endif
                    }
                }
            }
            Section("Journal d'audit SHA-256 (\(beta.securityAuditLog.count))") {
                if beta.securityAuditLog.isEmpty {
                    Text("Aucun événement enregistré pour le moment.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(beta.securityAuditLog) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(item.category).font(.system(size: 11, weight: .black)).foregroundStyle(VipleMailPalette.primary)
                                Spacer()
                                Text(item.timestamp.formatted(date: .abbreviated, time: .standard)).font(.system(size: 11)).foregroundStyle(VipleMailPalette.inkMuted)
                            }
                            Text(item.summary).font(.system(size: 13.5, weight: .semibold))
                            Text("SHA-256: \(item.sha256Fingerprint.prefix(32))…")
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Lot 6 : Chat Instantané Augmenté @viplemail.fr (#051..#060)

@MainActor
public final class BetaChatVoiceRecorder: NSObject, ObservableObject {
    public static let shared = BetaChatVoiceRecorder()

    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var durationSeconds: Int = 0
    @Published public private(set) var playingAudioKey: String? = nil
    @Published public var playbackRate: Float = 1.0
    #if canImport(UIKit)
    private var recorder: AVAudioRecorder?
    private var activePlayer: AVAudioPlayer?
    #endif
    private var timerTask: Task<Void, Never>?
    private var recordedFileURL: URL?

    private override init() { super.init() }

    public func startRecording() async -> Bool {
        #if canImport(UIKit)
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard allowed else { return false }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("viple_voice_\(Int(Date().timeIntervalSince1970)).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.record()
            self.recorder = rec
            self.recordedFileURL = url
            self.durationSeconds = 0
            self.isRecording = true
            timerTask?.cancel()
            timerTask = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    guard let self, self.isRecording else { break }
                    self.durationSeconds += 1
                }
            }
            return true
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public func finishAndReadData() -> Data? {
        timerTask?.cancel()
        timerTask = nil
        #if canImport(UIKit)
        recorder?.stop()
        recorder = nil
        #endif
        isRecording = false
        guard let url = recordedFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    public func cyclePlaybackSpeed() {
        let speeds: [Float] = [1.0, 1.5, 2.0]
        if let idx = speeds.firstIndex(where: { abs($0 - playbackRate) < 0.05 }) {
            playbackRate = speeds[(idx + 1) % speeds.count]
        } else {
            playbackRate = 1.0
        }
        #if canImport(UIKit)
        activePlayer?.rate = playbackRate
        #endif
    }

    public func togglePlayAudio(key: String, url: URL) async {
        #if canImport(UIKit)
        if playingAudioKey == key, let player = activePlayer, player.isPlaying {
            player.stop()
            activePlayer = nil
            playingAudioKey = nil
            return
        }
        activePlayer?.stop()
        activePlayer = nil
        playingAudioKey = nil

        let audioData: Data?
        if url.isFileURL {
            audioData = try? Data(contentsOf: url)
        } else {
            audioData = (try? await URLSession.shared.data(from: url))?.0
        }
        guard let data = audioData else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        if let player = try? AVAudioPlayer(data: data) {
            player.enableRate = true
            player.rate = playbackRate
            player.prepareToPlay()
            player.play()
            activePlayer = player
            playingAudioKey = key
            let expectedSecs = max(1.0, player.duration / Double(max(0.5, playbackRate)))
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64((expectedSecs + 0.25) * 1_000_000_000))
                if self?.playingAudioKey == key && self?.activePlayer?.isPlaying != true {
                    self?.playingAudioKey = nil
                }
            }
        }
        #endif
    }
}

public struct BetaChatConversationTopAugmentationBar: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    public let session: VipleChatSession
    public let messages: [VipleChatMessage]
    public var onJumpToMessage: (String) -> Void

    @State private var showMediaGallery: Bool = false
    @State private var showEphemeralSheet: Bool = false

    public init(session: VipleChatSession, messages: [VipleChatMessage], onJumpToMessage: @escaping (String) -> Void) {
        self.session = session
        self.messages = messages
        self.onJumpToMessage = onJumpToMessage
    }

    public var body: some View {
        VStack(spacing: 4) {
            if beta.isEnabled(.f059) || beta.isEnabled(.f060) {
                HStack(spacing: 8) {
                    if beta.isEnabled(.f059) {
                        let secs = beta.chatEphemeralSecondsBySession[session.id] ?? 0
                        Button {
                            showEphemeralSheet = true
                        } label: {
                            Label(secs > 0 ? "Éphémère : \(secs / 60) min" : "Messages éphémères", systemImage: "timer")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(secs > 0 ? .orange : VipleMailPalette.inkSecondary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                        }
                    }
                    Spacer()
                    if beta.isEnabled(.f060) {
                        Button {
                            showMediaGallery = true
                        } label: {
                            Label("Médias & Liens", systemImage: "photo.on.rectangle.angled")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(VipleMailPalette.primary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(VipleMailPalette.primary.opacity(0.11)))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(VipleMailPalette.surface)
            }

            if beta.isEnabled(.f056),
               let pinnedIds = beta.chatPinnedMessageIdsBySession[session.id],
               let firstPinned = messages.first(where: { pinnedIds.contains($0.id) }) {
                Button {
                    onJumpToMessage(firstPinned.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                        Text("Épinglé : \(firstPinned.bodyText)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(VipleMailPalette.primary.opacity(0.09))
                }
                .buttonStyle(.plain)
            }
        }
        .confirmationDialog("Minuteur de messages éphémères (#059)", isPresented: $showEphemeralSheet, titleVisibility: .visible) {
            Button("Désactivé (permanent)") { beta.chatEphemeralSecondsBySession[session.id] = 0; beta.saveState() }
            Button("1 minute") { beta.chatEphemeralSecondsBySession[session.id] = 60; beta.saveState() }
            Button("1 heure") { beta.chatEphemeralSecondsBySession[session.id] = 3600; beta.saveState() }
            Button("24 heures") { beta.chatEphemeralSecondsBySession[session.id] = 86400; beta.saveState() }
            Button("Annuler", role: .cancel) {}
        }
        .sheet(isPresented: $showMediaGallery) {
            BetaChatMediaAndLinksInspector(messages: messages)
        }
    }
}

public struct BetaChatComposerExtrasBar: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var recorder = BetaChatVoiceRecorder.shared

    public let session: VipleChatSession
    @Binding public var draftText: String
    @Binding public var quotedMessagePreview: String?
    @Binding public var stagedAttachments: [VipleMailAttachment]

    @State private var showChatPollBuilder: Bool = false
    @State private var showChecklistBuilder: Bool = false
    @State private var showScheduleChatSheet: Bool = false
    @State private var showSnippetsSheet: Bool = false

    public init(
        session: VipleChatSession,
        draftText: Binding<String>,
        quotedMessagePreview: Binding<String?>,
        stagedAttachments: Binding<[VipleMailAttachment]>
    ) {
        self.session = session
        self._draftText = draftText
        self._quotedMessagePreview = quotedMessagePreview
        self._stagedAttachments = stagedAttachments
    }

    private var hasAnyChatInputBeta: Bool {
        [.f051, .f053, .f054, .f055, .f058, .f096].contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyChatInputBeta {
            VStack(spacing: 4) {
                if let quote = quotedMessagePreview {
                    HStack(spacing: 8) {
                        Rectangle().fill(VipleMailPalette.primary).frame(width: 3, height: 24)
                        Text("En réponse à : \(quote)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Spacer()
                        Button { quotedMessagePreview = nil } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(VipleMailPalette.surfaceSubtle)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if beta.isEnabled(.f051) {
                            Button {
                                Task {
                                    if recorder.isRecording {
                                        if let data = recorder.finishAndReadData(),
                                           let att = await vm.uploadAttachment(fileName: "vocal_\(Int(Date().timeIntervalSince1970)).m4a", mimeType: "audio/mp4", data: data) {
                                            stagedAttachments.append(att)
                                            if draftText.isEmpty { draftText = "🎙️ Note vocale (\(recorder.durationSeconds)s)" }
                                        }
                                    } else {
                                        let started = await recorder.startRecording()
                                        if !started { vm.showToast("Autorisez le microphone dans Réglages iOS") }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
                                    Text(recorder.isRecording ? "Stop (\(recorder.durationSeconds)s)" : "Vocal")
                                }
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .foregroundStyle(recorder.isRecording ? .white : .red)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(recorder.isRecording ? Color.red : Color.red.opacity(0.12)))
                            }
                        }

                        if beta.isEnabled(.f054) {
                            chatActionPill("Sondage", icon: "chart.bar.doc.horizontal.fill", tint: VipleMailPalette.indigo) {
                                showChatPollBuilder = true
                            }
                        }
                        if beta.isEnabled(.f055) {
                            chatActionPill("Cartes+", icon: "checklist", tint: .teal) {
                                showChecklistBuilder = true
                            }
                        }
                        if beta.isEnabled(.f058) {
                            chatActionPill("Programmer", icon: "clock.fill", tint: .purple) {
                                showScheduleChatSheet = true
                            }
                        }
                        if beta.isEnabled(.f096) {
                            chatActionPill("Snippets", icon: "doc.on.clipboard.fill", tint: VipleMailPalette.primary) {
                                showSnippetsSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
            .background(VipleMailPalette.surface)
            .sheet(isPresented: $showChatPollBuilder) {
                BetaMailPollComposerSheet { pollTag in
                    draftText = pollTag
                }
            }
            .sheet(isPresented: $showChecklistBuilder) {
                BetaChatChecklistBuilderSheet { checklistText in
                    draftText = checklistText
                }
            }
            .sheet(isPresented: $showScheduleChatSheet) {
                BetaScheduleChatMessageSheet(session: session, initialText: draftText) {
                    draftText = ""
                }
            }
            .sheet(isPresented: $showSnippetsSheet) {
                BetaClipboardSnippetsVaultView { snippet in
                    draftText += (draftText.isEmpty ? "" : " ") + snippet
                }
            }
        }
    }

    private func chatActionPill(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

public struct BetaChatBubbleFooterAugmentation: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var voiceRec = BetaChatVoiceRecorder.shared
    public let sessionId: String
    public let message: VipleChatMessage
    public var onSwipeReply: (String) -> Void

    @State private var showTranslated: Bool = false

    public init(sessionId: String, message: VipleChatMessage, onSwipeReply: @escaping (String) -> Void) {
        self.sessionId = sessionId
        self.message = message
        self.onSwipeReply = onSwipeReply
    }

    private var audioAttachments: [VipleMailAttachment] {
        message.attachments.filter { att in
            let fn = att.fileName.lowercased()
            let mime = att.mimeType.lowercased()
            return fn.hasSuffix(".m4a") || fn.hasSuffix(".mp3") || fn.hasSuffix(".wav") || mime.hasPrefix("audio/")
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Lecteur natif vitesse 1x–2x pour notes vocales (#051)
            if beta.isEnabled(.f051), !audioAttachments.isEmpty {
                ForEach(audioAttachments) { att in
                    if let url = URL(string: att.url), !att.url.isEmpty {
                        let isPlayingThis = voiceRec.playingAudioKey == att.id
                        HStack(spacing: 8) {
                            Button {
                                Task { await voiceRec.togglePlayAudio(key: att.id, url: url) }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 16, weight: .bold))
                                    Text(isPlayingThis ? "Arrêter l'écoute" : "Écouter vocal")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .foregroundStyle(VipleMailPalette.primary)
                            }
                            .buttonStyle(.plain)

                            Button {
                                voiceRec.cyclePlaybackSpeed()
                            } label: {
                                Text(String(format: "%.1fx", voiceRec.playbackRate))
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VipleMailPalette.primary))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                    }
                }
            }

            // Sondage interactif dans le chat (#054)
            if beta.isEnabled(.f054), let poll = BetaMailPollParser.extract(from: message.bodyText, messageId: message.id) {
                BetaInteractiveMailPollCardView(poll: poll)
            }

            // Cartes structurées : Checklist, Bloc de Code & Lieu (#055)
            if beta.isEnabled(.f055) {
                if message.bodyText.contains("[ ] ") || message.bodyText.contains("[x] ") {
                    let items = message.bodyText.components(separatedBy: .newlines).filter { $0.hasPrefix("[ ] ") || $0.hasPrefix("[x] ") }
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items, id: \.self) { line in
                            let clean = String(line.dropFirst(4))
                            let key = "\(message.id)|\(clean)"
                            let done = beta.chatChecklistDoneKeys.contains(key) || line.hasPrefix("[x] ")
                            Button {
                                if beta.chatChecklistDoneKeys.contains(key) {
                                    beta.chatChecklistDoneKeys.remove(key)
                                } else {
                                    beta.chatChecklistDoneKeys.insert(key)
                                }
                                beta.saveState()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: done ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(done ? VipleMailPalette.success : VipleMailPalette.primary)
                                    Text(clean)
                                        .font(.system(size: 13, weight: .semibold))
                                        .strikethrough(done)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.surfaceSubtle))
                }

                if let codeSnippet = extractFencedCode(from: message.bodyText) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Extrait de code", systemImage: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(.cyan)
                            Spacer()
                            Button("Copier") {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = codeSnippet
                                #endif
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.cyan)
                        }
                        Text(codeSnippet)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.08, green: 0.11, blue: 0.18)))
                }

                if let place = extractPlaceCard(from: message.bodyText) {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(place.title).font(.system(size: 12.5, weight: .bold))
                            Text(place.address).font(.system(size: 11)).foregroundStyle(VipleMailPalette.inkSecondary)
                        }
                        Spacer()
                        if let encoded = place.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                           let mapUrl = URL(string: "https://maps.apple.com/?q=\(encoded)") {
                            Link("Plans ↗", destination: mapUrl)
                                .font(.system(size: 11.5, weight: .bold))
                        }
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.surfaceSubtle))
                }
            }

            // Traduction sous la bulle (#057)
            if beta.isEnabled(.f057) && showTranslated {
                Text(BetaLocalPhrasebookTranslator.translateParagraph(message.bodyText, to: "en"))
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(VipleMailPalette.indigo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 8).fill(VipleMailPalette.indigo.opacity(0.10)))
            }

            // Réactions émojis (#052) + Actions rapides (#053, #056, #057)
            let reactions = beta.chatReactionsByMessageId[message.id] ?? []
            if beta.isEnabled(.f052) || beta.isEnabled(.f053) || beta.isEnabled(.f056) || beta.isEnabled(.f057) {
                HStack(spacing: 6) {
                    ForEach(reactions, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 12))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                    }

                    if beta.isEnabled(.f052) {
                        Menu {
                            ForEach(["👍", "❤️", "😂", "🔥", "👏", "✅"], id: \.self) { em in
                                Button(em) {
                                    var arr = beta.chatReactionsByMessageId[message.id] ?? []
                                    if arr.contains(em) { arr.removeAll { $0 == em } } else { arr.append(em) }
                                    beta.chatReactionsByMessageId[message.id] = arr
                                    beta.saveState()
                                }
                            }
                        } label: {
                            Image(systemName: "face.smiling")
                                .font(.system(size: 11.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }

                    if beta.isEnabled(.f053) {
                        Button {
                            onSwipeReply(String(message.bodyText.prefix(70)))
                        } label: {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }

                    if beta.isEnabled(.f056) {
                        Button {
                            var pins = beta.chatPinnedMessageIdsBySession[sessionId] ?? []
                            if pins.contains(message.id) { pins.removeAll { $0 == message.id } } else { pins.insert(message.id, at: 0) }
                            beta.chatPinnedMessageIdsBySession[sessionId] = pins
                            beta.saveState()
                        } label: {
                            Image(systemName: "pin")
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }

                    if beta.isEnabled(.f057) {
                        Button {
                            showTranslated.toggle()
                        } label: {
                            Image(systemName: "character.bubble")
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                }
            }
        }
    }

    private func extractFencedCode(from raw: String) -> String? {
        guard let first = raw.range(of: "```"),
              let second = raw.range(of: "```", range: first.upperBound..<raw.endIndex) else { return nil }
        let code = String(raw[first.upperBound..<second.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return code.isEmpty ? nil : code
    }

    private func extractPlaceCard(from raw: String) -> (title: String, address: String)? {
        guard let r = raw.range(of: #"#viplelieu\[([^\]]+)\]"#, options: .regularExpression) else { return nil }
        let tag = String(raw[r])
        guard let open = tag.firstIndex(of: "["), let close = tag.lastIndex(of: "]") else { return nil }
        let parts = String(tag[tag.index(after: open)..<close]).split(separator: "|").map(String.init)
        guard parts.count >= 2 else { return nil }
        return (parts[0], parts[1])
    }
}

public struct BetaChatChecklistBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var onBuild: (String) -> Void
    @State private var cardKind: Int = 0 // 0: Checklist, 1: Code, 2: Lieu
    @State private var title: String = "Points à valider"
    @State private var item1: String = ""
    @State private var item2: String = ""
    @State private var item3: String = ""
    @State private var codeContent: String = ""
    @State private var placeTitle: String = ""
    @State private var placeAddress: String = ""

    public var body: some View {
        NavigationStack {
            Form {
                Section("Type de carte structurée (#055)") {
                    Picker("Format", selection: $cardKind) {
                        Text("Checklist").tag(0)
                        Text("Bloc Code").tag(1)
                        Text("Fiche Lieu").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                if cardKind == 0 {
                    Section("Titre de la checklist") { TextField("Titre", text: $title) }
                    Section("Éléments cochables") {
                        TextField("Tâche 1", text: $item1)
                        TextField("Tâche 2", text: $item2)
                        TextField("Tâche 3", text: $item3)
                    }
                } else if cardKind == 1 {
                    Section("Code formaté copiable") {
                        TextEditor(text: $codeContent)
                            .font(.system(size: 13, design: .monospaced))
                            .frame(minHeight: 130)
                    }
                } else {
                    Section("Lieu ou adresse de rendez-vous") {
                        TextField("Nom du lieu (ex: Siège Cenelis SA)", text: $placeTitle)
                        TextField("Adresse complète ou ville", text: $placeAddress)
                    }
                }
            }
            .navigationTitle("Cartes Structurées Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insérer") {
                        if cardKind == 0 {
                            let tasks = [item1, item2, item3].filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { "[ ] \($0)" }
                            onBuild("📋 \(title)\n" + tasks.joined(separator: "\n"))
                        } else if cardKind == 1 {
                            onBuild("```\n\(codeContent)\n```")
                        } else {
                            let cleanT = placeTitle.isEmpty ? "Point de rendez-vous" : placeTitle.replacingOccurrences(of: "|", with: "-")
                            let cleanA = placeAddress.replacingOccurrences(of: "|", with: " ").replacingOccurrences(of: "]", with: "")
                            onBuild("📍 \(cleanT)\n#viplelieu[\(cleanT)|\(cleanA)]")
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}

public struct BetaScheduleChatMessageSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let session: VipleChatSession
    @State private var text: String
    @State private var sendAt: Date = Date().addingTimeInterval(1800)
    public var onScheduled: () -> Void

    public init(session: VipleChatSession, initialText: String, onScheduled: @escaping () -> Void) {
        self.session = session
        _text = State(initialValue: initialText)
        self.onScheduled = onScheduled
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Message Chat programmé pour \(session.peerDisplayName)") {
                    TextField("Votre message…", text: $text)
                    DatePicker("Heure d'envoi", selection: $sendAt, in: Date()...)
                    Button("Programmer") {
                        beta.scheduledChatMessages.append(BetaScheduledChatItem(id: UUID().uuidString, sessionId: session.id, peerEmail: session.peerEmail, text: text, sendAt: sendAt))
                        beta.saveState()
                        onScheduled()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Chat Programmé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaChatMediaAndLinksInspector: View {
    @Environment(\.dismiss) private var dismiss
    public let messages: [VipleChatMessage]

    private var allAttachments: [VipleMailAttachment] {
        messages.flatMap(\.attachments)
    }

    private var allLinks: [String] {
        Array(Set(messages.flatMap { BetaProductivityEngine.regexMatches(in: $0.bodyText, pattern: #"https?://[^\s<>")']+"#) })).sorted()
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Fichiers & Médias partagés (\(allAttachments.count))") {
                    if allAttachments.isEmpty {
                        Text("Aucun fichier partagé dans ce salon.").font(.caption).foregroundStyle(VipleMailPalette.inkMuted)
                    } else {
                        ForEach(allAttachments) { att in
                            HStack {
                                Image(systemName: att.iconName).foregroundStyle(VipleMailPalette.primary)
                                Text(att.fileName).font(.system(size: 13.5, weight: .semibold))
                                Spacer()
                                Text(att.formattedSize).font(.caption).foregroundStyle(VipleMailPalette.inkMuted)
                            }
                        }
                    }
                }
                Section("Liens Web partagés (\(allLinks.count))") {
                    ForEach(allLinks, id: \.self) { urlStr in
                        if let u = URL(string: urlStr) {
                            Link(urlStr, destination: u).font(.system(size: 12.5)).lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Médias, Fichiers & Liens")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}
