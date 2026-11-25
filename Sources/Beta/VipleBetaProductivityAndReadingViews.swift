import Foundation
import SwiftUI
import NaturalLanguage
#if canImport(UIKit)
import UIKit
@preconcurrency import AVFAudio
#endif

// MARK: - Moteur TTS Podcast Natif (#011)

@MainActor
public final class BetaMailPodcastEngine: NSObject, ObservableObject, @preconcurrency AVSpeechSynthesizerDelegate {
    public static let shared = BetaMailPodcastEngine()

    @Published public private(set) var isSpeaking: Bool = false
    @Published public private(set) var isPaused: Bool = false
    @Published public private(set) var currentTitle: String = ""
    @Published public private(set) var queue: [VipleMailMessage] = []
    @Published public private(set) var queueIndex: Int = 0
    @Published public var speechRateMultiplier: Float = 1.0

    #if canImport(UIKit)
    private let synthesizer = AVSpeechSynthesizer()
    #endif

    private override init() {
        super.init()
        #if canImport(UIKit)
        synthesizer.delegate = self
        #endif
    }

    public func speakSingle(_ message: VipleMailMessage) {
        queue = [message]
        queueIndex = 0
        startCurrentItem()
    }

    public func speakQueue(_ messages: [VipleMailMessage]) {
        guard !messages.isEmpty else { return }
        queue = Array(messages.prefix(20))
        queueIndex = 0
        startCurrentItem()
    }

    public func togglePlayPause() {
        #if canImport(UIKit)
        if isSpeaking && !isPaused {
            synthesizer.pauseSpeaking(at: .word)
            isPaused = true
        } else if isPaused {
            synthesizer.continueSpeaking()
            isPaused = false
        } else if !queue.isEmpty {
            startCurrentItem()
        }
        #endif
    }

    public func nextTrack() {
        guard queueIndex + 1 < queue.count else {
            stop()
            return
        }
        queueIndex += 1
        startCurrentItem()
    }

    public func previousTrack() {
        guard queueIndex > 0 else {
            startCurrentItem()
            return
        }
        queueIndex -= 1
        startCurrentItem()
    }

    public func cycleRate() {
        let rates: [Float] = [0.85, 1.0, 1.25, 1.5, 1.85]
        if let idx = rates.firstIndex(where: { abs($0 - speechRateMultiplier) < 0.05 }) {
            speechRateMultiplier = rates[(idx + 1) % rates.count]
        } else {
            speechRateMultiplier = 1.0
        }
        if isSpeaking {
            startCurrentItem()
        }
    }

    public func stop() {
        #if canImport(UIKit)
        synthesizer.stopSpeaking(at: .immediate)
        #endif
        isSpeaking = false
        isPaused = false
        currentTitle = ""
    }

    private func startCurrentItem() {
        guard queueIndex >= 0 && queueIndex < queue.count else { return }
        let msg = queue[queueIndex]
        currentTitle = msg.subject
        let textToSpeak = "Courrier de \(msg.senderName.isEmpty ? msg.senderEmail : msg.senderName). Objet : \(msg.subject). \(String(msg.plainBodyText.prefix(2600)))"

        #if canImport(UIKit)
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(msg.plainBodyText)
        let langCode = recognizer.dominantLanguage == .english ? "en-US" : "fr-FR"

        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: langCode)
        let baseRate = AVSpeechUtteranceDefaultSpeechRate
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, baseRate * speechRateMultiplier))
        isSpeaking = true
        isPaused = false
        synthesizer.speak(utterance)
        #endif
    }

    #if canImport(UIKit)
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            BetaMailPodcastEngine.shared.handleUtteranceDidFinish()
        }
    }

    private func handleUtteranceDidFinish() {
        if queueIndex + 1 < queue.count {
            queueIndex += 1
            startCurrentItem()
        } else {
            isSpeaking = false
            isPaused = false
        }
    }
    #endif
}

// MARK: - Logique & Helpers Lots 1 & 2 (001..020)

public enum BetaProductivityEngine {
    /// Réveille les courriers dont le Snooze est arrivé à échéance (#001)
    @MainActor
    public static func pruneExpiredSnoozes(store: VipleBetaStore) -> [BetaSnoozedMail] {
        let now = Date()
        var awakened: [BetaSnoozedMail] = []
        for (mid, item) in store.snoozedMails where item.wakeAt <= now {
            awakened.append(item)
            store.snoozedMails.removeValue(forKey: mid)
        }
        if !awakened.isEmpty {
            store.saveState()
        }
        return awakened
    }

    /// Filtre complet appliqué à la boîte de réception selon les fonctions Beta actives (#001, #004, #006, #008, #009, #092)
    @MainActor
    public static func applyInboxBetaFilters(
        messages: [VipleMailMessage],
        vm: VipleMailViewModel,
        store: VipleBetaStore
    ) -> [VipleMailMessage] {
        var result = messages
        let now = Date()

        // #001 : Masquer les courriers actuellement en sommeil (Snooze)
        if store.isEnabled(.f001) {
            result = result.filter { msg in
                if let snooze = store.snoozedMails[msg.id], snooze.wakeAt > now {
                    return false
                }
                return true
            }
        }

        // #045 : Purger les courriers éphémères arrivés à expiration
        if store.isEnabled(.f045) {
            result = result.filter { msg in
                if let exp = store.ephemeralExpiryByMessageId[msg.id], exp <= now {
                    return false
                }
                if let tagExp = parseEphemeralDeadline(in: msg.plainBodyText), tagExp <= now {
                    return false
                }
                return true
            }
        }

        // #004 : Bloquer les expéditeurs rejetés dans le Screener
        if store.isEnabled(.f004) && !store.blockedScreenerSenders.isEmpty {
            result = result.filter { !store.blockedScreenerSenders.contains($0.senderEmail.lowercased()) }
        }

        // #006 : Masquer les domaines désabonnés via le Centre Newsletters
        if store.isEnabled(.f006) && !store.unsubscribedDomains.isEmpty {
            result = result.filter { msg in
                let dom = senderDomain(of: msg.senderEmail)
                return !store.unsubscribedDomains.contains(dom)
            }
        }

        // #008 : Vue dynamique active (Smart Folder)
        if store.isEnabled(.f008),
           let svId = store.activeSmartViewId,
           let sv = store.smartDynamicViews.first(where: { $0.id == svId }) {
            result = filterBySmartView(result, view: sv)
        }

        // #009 : Mode Concentration Batch Delivery (retient les mails non-VIP reçus depuis moins de 3h hors bypass)
        if store.isEnabled(.f009), vm.activeFolderId == "Inbox" {
            let bypassed = (store.batchBypassUntil ?? .distantPast) > now
            let currentHour = Calendar.current.component(.hour, from: now)
            let isDeliveryWindow = store.batchDeliveryHours.contains(currentHour)
            if !bypassed && !isDeliveryWindow {
                let iso = ISO8601DateFormatter()
                result = result.filter { msg in
                    if msg.isVipSender || msg.isHighPriority || msg.isPinned || msg.isRead {
                        return true
                    }
                    if let d = iso.date(from: msg.receivedAt), now.timeIntervalSince(d) < 3 * 3600 {
                        return false
                    }
                    return true
                }
            }
        }

        return result
    }

    public static func filterBySmartView(_ list: [VipleMailMessage], view: BetaSmartDynamicView) -> [VipleMailMessage] {
        list.filter { m in
            if view.unreadOnly && m.isRead { return false }
            if view.attachmentsOnly && !m.hasAttachments { return false }
            if view.vipOnly && !m.isVipSender { return false }
            let dom = view.domainFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !dom.isEmpty && !m.senderEmail.lowercased().contains(dom) { return false }
            let kw = view.keywordFilter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !kw.isEmpty {
                let hay = "\(m.subject) \(m.snippet) \(m.plainBodyText)".lowercased()
                if !hay.contains(kw) { return false }
            }
            return true
        }
    }

    public static func senderDomain(of email: String) -> String {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let at = clean.lastIndex(of: "@") else { return clean }
        return String(clean[clean.index(after: at)...])
    }

    public static func parseEphemeralDeadline(in body: String) -> Date? {
        guard let r = body.range(of: #"#vipleephemere\[([^\]]+)\]"#, options: .regularExpression) else {
            return nil
        }
        let match = String(body[r])
        guard let open = match.firstIndex(of: "["), let close = match.lastIndex(of: "]") else { return nil }
        let isoStr = String(match[match.index(after: open)..<close])
        return VipleCalendarParser.parseISODate(isoStr)
    }

    public static func isLikelyNewsletter(_ msg: VipleMailMessage) -> Bool {
        let lower = "\(msg.senderEmail) \(msg.subject) \(msg.bodyHtml.prefix(4000))".lowercased()
        return lower.contains("unsubscribe")
            || lower.contains("désabonner")
            || lower.contains("se désinscrire")
            || lower.contains("newsletter")
            || lower.contains("no-reply@")
            || lower.contains("noreply@")
    }

    public static func extractUnsubscribeURL(from html: String, senderEmail: String) -> URL? {
        let pattern = #"https?://[^\s"'<>]*(?:unsubscribe|desabon|optout|preferences)[^\s"'<>]*"#
        if let r = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
           let url = URL(string: String(html[r])) {
            return url
        }
        return URL(string: "mailto:\(senderEmail)?subject=Unsubscribe")
    }

    // MARK: - Extraction Synthèse (#012) & Entités (#013)

    public struct ExecutiveDigest {
        public let keyBullets: [String]
        public let questions: [String]
        public let amounts: [String]
        public let datesFound: [String]
    }

    public static func buildExecutiveDigest(for msg: VipleMailMessage) -> ExecutiveDigest {
        let raw = msg.plainBodyText
        let lines = raw
            .components(separatedBy: CharacterSet(charactersIn: ".\n!"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 24 && $0.count <= 220 }

        let bullets = Array(lines.prefix(3))
        let questions = raw
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains("?") && $0.count >= 12 && $0.count <= 180 }

        let amounts = regexMatches(in: raw, pattern: #"\b\d{1,6}(?:[.,]\d{2})?\s?(?:€|EUR|\$|USD|TTC)\b"#)
        let dates = regexMatches(in: raw, pattern: #"\b(?:\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?|\d{1,2}\s+(?:janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre))\b"#)

        return ExecutiveDigest(
            keyBullets: bullets.isEmpty ? [msg.snippet] : bullets,
            questions: Array(questions.prefix(3)),
            amounts: Array(Set(amounts)).sorted(),
            datesFound: Array(Set(dates)).sorted()
        )
    }

    public struct DetectedSmartEntity: Identifiable, Equatable {
        public let id = UUID().uuidString
        public let kindLabel: String
        public let value: String
        public let icon: String
        public let actionUrl: URL?
    }

    public static func extractSmartEntities(from msg: VipleMailMessage) -> [DetectedSmartEntity] {
        let text = msg.plainBodyText
        var items: [DetectedSmartEntity] = []

        for otp in Set(regexMatches(in: text, pattern: #"(?:code|pin|otp|vérification|validation)[^\d]{0,18}(\d{6})"#, captureGroup: 1)) {
            items.append(.init(kindLabel: "Code OTP", value: otp, icon: "key.horizontal.fill", actionUrl: nil))
        }
        for iban in Set(regexMatches(in: text, pattern: #"\b[A-Z]{2}\d{2}[A-Z0-9 ]{12,30}\b"#)) where iban.filter({ !$0.isWhitespace }).count >= 16 {
            items.append(.init(kindLabel: "IBAN", value: iban.trimmingCharacters(in: .whitespaces), icon: "building.columns.fill", actionUrl: nil))
        }
        for parcel in Set(regexMatches(in: text, pattern: #"\b(?:1Z[0-9A-Z]{16}|[689][A-Z0-9]{10,13})\b"#)) {
            let trackUrl = URL(string: "https://www.laposte.fr/outils/suivre-vos-envois?code=\(parcel)")
            items.append(.init(kindLabel: "Colis", value: parcel, icon: "shippingbox.fill", actionUrl: trackUrl))
        }
        for phone in Set(regexMatches(in: text, pattern: #"(?:\+33|0)[1-9](?:[\s.-]?\d{2}){4}"#)) {
            let digits = phone.filter { $0.isNumber || $0 == "+" }
            items.append(.init(kindLabel: "Tél.", value: phone, icon: "phone.fill", actionUrl: URL(string: "tel:\(digits)")))
        }
        for rawUrl in Set(regexMatches(in: text, pattern: #"https?://[^\s<>")']+"#)).prefix(3) {
            items.append(.init(kindLabel: "Lien", value: rawUrl, icon: "safari.fill", actionUrl: URL(string: rawUrl)))
        }
        return Array(items.prefix(8))
    }

    public static func regexMatches(in text: String, pattern: String, captureGroup: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { m in
            guard captureGroup < m.numberOfRanges else { return nil }
            let r = m.range(at: captureGroup)
            guard r.location != NSNotFound else { return nil }
            return ns.substring(with: r)
        }
    }

    public static func makeBionicAttributedString(_ text: String, fontSize: CGFloat, dyslexiaMode: Bool) -> AttributedString {
        var result = AttributedString()
        let lines = text.components(separatedBy: .newlines)
        for (lineIdx, line) in lines.enumerated() {
            let words = line.split(separator: " ", omittingEmptySubsequences: false)
            for (wIdx, wordSub) in words.enumerated() {
                let word = String(wordSub)
                if word.count <= 1 {
                    var part = AttributedString(word)
                    part.font = .system(size: fontSize, weight: .regular, design: dyslexiaMode ? .rounded : .default)
                    result.append(part)
                } else {
                    let boldLen = max(1, Int(ceil(Double(word.count) * 0.45)))
                    let splitIdx = word.index(word.startIndex, offsetBy: min(word.count, boldLen))
                    var prefixAttr = AttributedString(String(word[..<splitIdx]))
                    prefixAttr.font = .system(size: fontSize, weight: .black, design: dyslexiaMode ? .rounded : .default)
                    var restAttr = AttributedString(String(word[splitIdx...]))
                    restAttr.font = .system(size: fontSize, weight: .regular, design: dyslexiaMode ? .rounded : .default)
                    result.append(prefixAttr)
                    result.append(restAttr)
                }
                if wIdx + 1 < words.count {
                    result.append(AttributedString(" "))
                }
            }
            if lineIdx + 1 < lines.count {
                result.append(AttributedString("\n"))
            }
        }
        return result
    }
}

// MARK: - Barre d'Outils Beta Contextuelle dans la Boîte de Réception (#001..#010, #011, #018)

public struct BetaInboxQuickStripView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var podcast = BetaMailPodcastEngine.shared

    @State private var activeSheet: VipleBetaFeatureID? = nil

    public init() {}

    private var hasAnyInboxBetaEnabled: Bool {
        let ids: [VipleBetaFeatureID] = [.f001, .f002, .f003, .f004, .f005, .f006, .f008, .f009, .f010, .f011, .f018, .f093, .f095, .f100]
        return ids.contains(where: { beta.isEnabled($0) })
    }

    private var unscreenedSendersCount: Int {
        guard beta.isEnabled(.f004) else { return 0 }
        let knownContacts = Set(vm.contacts.map { $0.contactEmail.lowercased() })
        let knownFriends = Set(vm.acceptedFriends.flatMap { $0.allKnownEmails })
        let uniqueUnknown = Set(
            vm.messages
                .filter { $0.folder == "Inbox" }
                .map { $0.senderEmail.lowercased() }
                .filter { !$0.isEmpty && !knownContacts.contains($0) && !knownFriends.contains($0) && !beta.approvedScreenerSenders.contains($0) && !beta.blockedScreenerSenders.contains($0) }
        )
        return uniqueUnknown.count
    }

    public var body: some View {
        if hasAnyInboxBetaEnabled {
            VStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if beta.isEnabled(.f100) {
                            stripPill("Viple Pulse", icon: "sun.max.trianglebadge.exclamationmark.fill", tint: .orange) {
                                beta.presentedFeatureWorkspace = .f100
                            }
                        }
                        if beta.isEnabled(.f002) {
                            stripPill("Triage Express", icon: "rectangle.stack.badge.checkmark", tint: VipleMailPalette.primary) {
                                activeSheet = .f002
                            }
                        }
                        if beta.isEnabled(.f003) {
                            stripPill("Kanban", icon: "square.split.3x1.fill", tint: VipleMailPalette.indigo) {
                                activeSheet = .f003
                            }
                        }
                        if beta.isEnabled(.f004) {
                            stripPill(
                                unscreenedSendersCount > 0 ? "Screener (\(unscreenedSendersCount))" : "Screener",
                                icon: "person.badge.shield.checkmark.fill",
                                tint: unscreenedSendersCount > 0 ? VipleMailPalette.warning : VipleMailPalette.success
                            ) {
                                activeSheet = .f004
                            }
                        }
                        if beta.isEnabled(.f001) {
                            let c = beta.snoozedMails.count
                            stripPill(c > 0 ? "Snooze (\(c))" : "Snooze", icon: "moon.zzz.fill", tint: .purple) {
                                activeSheet = .f001
                            }
                        }
                        if beta.isEnabled(.f005) {
                            let pending = beta.followUpItems.filter { !$0.completed }.count
                            stripPill(pending > 0 ? "Relances (\(pending))" : "Relances", icon: "arrow.uturn.forward.circle.fill", tint: .pink) {
                                activeSheet = .f005
                            }
                        }
                        if beta.isEnabled(.f006) {
                            stripPill("Newsletters", icon: "newspaper.fill", tint: .teal) {
                                activeSheet = .f006
                            }
                        }
                        if beta.isEnabled(.f009) {
                            stripPill("Batch Focus", icon: "bell.and.waves.left.and.right.fill", tint: .indigo) {
                                activeSheet = .f009
                            }
                        }
                        if beta.isEnabled(.f011) {
                            stripPill(podcast.isSpeaking ? "Podcast actif" : "Écouter non lus", icon: "headphones", tint: .mint) {
                                if podcast.isSpeaking {
                                    podcast.stop()
                                } else {
                                    let unread = vm.displayedMessages.filter { !$0.isRead }
                                    podcast.speakQueue(unread.isEmpty ? vm.displayedMessages : unread)
                                }
                            }
                        }
                        if beta.isEnabled(.f018) {
                            stripPill("Factures CSV", icon: "eurosign.circle.fill", tint: .green) {
                                activeSheet = .f018
                            }
                        }
                        if beta.isEnabled(.f010) {
                            stripPill("Analytique", icon: "chart.bar.xaxis", tint: .cyan) {
                                activeSheet = .f010
                            }
                        }
                        if beta.isEnabled(.f093) {
                            stripPill("Règles Si→Alors", icon: "gearshape.2.fill", tint: VipleMailPalette.primary) {
                                beta.presentedFeatureWorkspace = .f093
                            }
                        }
                        if beta.isEnabled(.f095) {
                            stripPill("Veille RSS", icon: "dot.radiowaves.up.forward", tint: .orange) {
                                beta.presentedFeatureWorkspace = .f095
                            }
                        }
                    }
                    .padding(.horizontal, VipleMailLayout.isCompactPhone ? 12 : 16)
                    .padding(.vertical, 6)
                }

                // #008 : Vues dynamiques intelligentes en 1 clic
                if beta.isEnabled(.f008) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Button {
                                withAnimation { beta.activeSmartViewId = nil }
                            } label: {
                                Text("Tous les flux")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(beta.activeSmartViewId == nil ? .white : VipleMailPalette.inkSecondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4.5)
                                    .background(Capsule().fill(beta.activeSmartViewId == nil ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle))
                            }
                            ForEach(beta.smartDynamicViews) { sv in
                                let active = beta.activeSmartViewId == sv.id
                                Button {
                                    withAnimation { beta.activeSmartViewId = active ? nil : sv.id }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 9.5, weight: .bold))
                                        Text(sv.name)
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                    }
                                    .foregroundStyle(active ? .white : VipleMailPalette.primary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4.5)
                                    .background(Capsule().fill(active ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.11)))
                                }
                            }
                            Button {
                                activeSheet = .f008
                            } label: {
                                Label("Nouvelle vue", systemImage: "plus.circle.fill")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.inkSecondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4.5)
                                    .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                            }
                        }
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 12 : 16)
                        .padding(.bottom, 4)
                    }
                }

                // #011 : Mini-lecteur Podcast actif
                if beta.isEnabled(.f011) && (podcast.isSpeaking || podcast.isPaused) {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform")
                            .foregroundStyle(.white)
                        Text(podcast.currentTitle)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            podcast.cycleRate()
                        } label: {
                            Text(String(format: "%.2gx", podcast.speechRateMultiplier))
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.white.opacity(0.2)))
                        }
                        Button { podcast.togglePlayPause() } label: {
                            Image(systemName: podcast.isPaused ? "play.fill" : "pause.fill")
                                .foregroundStyle(.white)
                        }
                        Button { podcast.nextTrack() } label: {
                            Image(systemName: "forward.fill")
                                .foregroundStyle(.white)
                        }
                        Button { podcast.stop() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VipleMailPalette.heroGradient))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                }
            }
            .background(VipleMailPalette.surface)
            .sheet(item: $activeSheet) { fid in
                VipleBetaWorkspaceRouterSheet(featureId: fid)
                    .environmentObject(vm)
                    .preferredColorScheme(vm.preferredColorSchemeOverride)
            }
            .task {
                let awakened = BetaProductivityEngine.pruneExpiredSnoozes(store: beta)
                if let first = awakened.first {
                    vm.showToast("⏰ Courrier réveillé : \(first.subject)")
                }
            }
        }
    }

    private func stripPill(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(tint.opacity(0.12))
                    .overlay(Capsule().stroke(tint.opacity(0.25), lineWidth: 0.8))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panneau d'Augmentation du Lecteur de Courrier (#001, #005, #007, #011..#020, #042..#049, #077, #094)

public struct BetaMessageReaderAugmentationView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var podcast = BetaMailPodcastEngine.shared

    public let message: VipleMailMessage

    @State private var showSnoozeDialog: Bool = false
    @State private var showStickyNoteSheet: Bool = false
    @State private var showBionicSheet: Bool = false
    @State private var showTranslatorPanel: Bool = false
    @State private var targetTranslationLang: String = "en"
    @State private var showInMailSearch: Bool = false
    @State private var inMailQuery: String = ""
    @State private var inMailMatchIndex: Int = 0
    @State private var showHighlighterSheet: Bool = false
    @State private var showTeleprompterSheet: Bool = false
    @State private var showRfcInspectorSheet: Bool = false
    @State private var showSealVaultSheet: Bool = false
    @State private var showExportStudioSheet: Bool = false

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var hasAnyReaderToolActive: Bool {
        let ids: [VipleBetaFeatureID] = [
            .f001, .f005, .f007, .f011, .f012, .f013, .f014, .f015, .f016, .f017, .f019, .f020,
            .f026, .f042, .f043, .f044, .f045, .f046, .f049, .f077, .f094
        ]
        return ids.contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyReaderToolActive && !message.isLockedByCenelisPin {
            VStack(alignment: .leading, spacing: 10) {
                // 1. Ruban d'actions rapides Beta dans le lecteur
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if beta.isEnabled(.f011) {
                            readerActionChip("Écouter", icon: "speaker.wave.2.fill", tint: .mint) {
                                if podcast.isSpeaking && podcast.currentTitle == message.subject {
                                    podcast.stop()
                                } else {
                                    podcast.speakSingle(message)
                                }
                            }
                        }
                        if beta.isEnabled(.f014) {
                            readerActionChip("Lecture Bionic", icon: "book.pages.fill", tint: .teal) {
                                showBionicSheet = true
                            }
                        }
                        if beta.isEnabled(.f015) {
                            readerActionChip("Traduire", icon: "character.bubble.fill", tint: .indigo) {
                                withAnimation { showTranslatorPanel.toggle() }
                            }
                        }
                        if beta.isEnabled(.f017) {
                            readerActionChip("Chercher", icon: "doc.text.magnifyingglass", tint: VipleMailPalette.primary) {
                                withAnimation { showInMailSearch.toggle() }
                            }
                        }
                        if beta.isEnabled(.f001) {
                            readerActionChip("Snooze", icon: "moon.zzz.fill", tint: .purple) {
                                showSnoozeDialog = true
                            }
                        }
                        if beta.isEnabled(.f007) {
                            readerActionChip("Post-it", icon: "note.text", tint: .orange) {
                                showStickyNoteSheet = true
                            }
                        }
                        if beta.isEnabled(.f005) {
                            readerActionChip("Relance J+3", icon: "arrow.uturn.forward.circle.fill", tint: .pink) {
                                let item = BetaFollowUpItem(
                                    id: UUID().uuidString,
                                    messageId: message.id,
                                    subject: message.subject,
                                    recipientOrSenderEmail: message.senderEmail,
                                    recipientOrSenderName: message.senderName,
                                    dueAt: Date().addingTimeInterval(3 * 86400),
                                    completed: false
                                )
                                beta.followUpItems.insert(item, at: 0)
                                beta.saveState()
                                vm.showToast("📌 Suivi de réponse programmé à J+3")
                            }
                        }
                        if beta.isEnabled(.f016) {
                            readerActionChip("Surligner", icon: "highlighter", tint: .yellow) {
                                showHighlighterSheet = true
                            }
                        }
                        if beta.isEnabled(.f019) {
                            readerActionChip("Téléprompteur", icon: "arrow.down.doc.fill", tint: .cyan) {
                                showTeleprompterSheet = true
                            }
                        }
                        if beta.isEnabled(.f020) {
                            let isRef = beta.pinnedReferenceMessage?.id == message.id
                            readerActionChip(isRef ? "Réf. active" : "Épingler Réf.", icon: "pip.enter", tint: .blue) {
                                beta.pinnedReferenceMessage = isRef ? nil : message
                                vm.showToast(isRef ? "Tiroir de référence fermé" : "📌 Courrier épinglé en fenêtre flottante")
                            }
                        }
                        if beta.isEnabled(.f077) {
                            readerActionChip("Créer Tâche", icon: "checkmark.circle.fill", tint: .green) {
                                let t = BetaActionTaskItem(
                                    id: UUID().uuidString,
                                    title: message.subject,
                                    notes: "De : \(message.senderName) <\(message.senderEmail)>",
                                    dueAt: Date().addingTimeInterval(86400),
                                    priority: message.isHighPriority ? "Haute" : "Normale",
                                    isDone: false,
                                    sourceMessageId: message.id,
                                    subtasks: ["Répondre à \(message.senderName.isEmpty ? message.senderEmail : message.senderName)"],
                                    completedSubtasks: []
                                )
                                beta.actionTasks.insert(t, at: 0)
                                beta.saveState()
                                vm.showToast("✅ Courrier converti en tâche dans l'Agenda !")
                            }
                        }
                        if beta.isEnabled(.f044) {
                            readerActionChip("Coffre AES", icon: "lock.doc.fill", tint: VipleMailPalette.success) {
                                showSealVaultSheet = true
                            }
                        }
                        if beta.isEnabled(.f043) {
                            readerActionChip("En-têtes RFC", icon: "network.badge.shield.half.filled", tint: .secondary) {
                                showRfcInspectorSheet = true
                            }
                        }
                        if beta.isEnabled(.f094) {
                            readerActionChip("Exporter .eml/PDF", icon: "square.and.arrow.up", tint: VipleMailPalette.primary) {
                                showExportStudioSheet = true
                            }
                        }
                    }
                }

                // 2. #042 + #046 : Score de confiance anti-phishing & Pixels espions neutralisés
                if beta.isEnabled(.f042) || beta.isEnabled(.f046) {
                    BetaSecurityTrustInlineBanner(message: message)
                }

                // 3. #045 : Compte à rebours courrier éphémère si présent
                if beta.isEnabled(.f045),
                   let exp = beta.ephemeralExpiryByMessageId[message.id] ?? BetaProductivityEngine.parseEphemeralDeadline(in: message.plainBodyText) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("Courrier éphémère • Auto-destruction le \(exp.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
                }

                // 4. #007 : Note Post-it privée attachée à ce courrier
                if beta.isEnabled(.f007), let note = beta.stickyNotesByMessage[message.id] {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "note.text")
                            .foregroundStyle(stickyColor(note.colorName))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.text)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)
                            if !note.tags.isEmpty {
                                HStack(spacing: 5) {
                                    ForEach(note.tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 10.5, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(stickyColor(note.colorName).opacity(0.22)))
                                    }
                                }
                            }
                        }
                        Spacer()
                        Button {
                            showStickyNoteSheet = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundStyle(stickyColor(note.colorName))
                        }
                    }
                    .padding(11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(stickyColor(note.colorName).opacity(0.14))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(stickyColor(note.colorName).opacity(0.45), lineWidth: 1))
                    )
                }

                // 5. #017 : Barre de recherche intra-courrier avec saut 1/N
                if beta.isEnabled(.f017) && showInMailSearch {
                    inMailSearchWidget
                }

                // 6. #012 : Synthèse Exécutive Structurée (TL;DR)
                if beta.isEnabled(.f012) && message.plainBodyText.count > 120 {
                    let digest = BetaProductivityEngine.buildExecutiveDigest(for: message)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(VipleMailPalette.primary)
                            Text("SYNTHÈSE EXÉCUTIVE (TL;DR)")
                                .font(.system(size: 10.5, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.primary)
                            Spacer()
                            if !digest.amounts.isEmpty {
                                Text(digest.amounts.joined(separator: " • "))
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .foregroundStyle(.green)
                            }
                        }
                        ForEach(digest.keyBullets, id: \.self) { b in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").fontWeight(.black).foregroundStyle(VipleMailPalette.primary)
                                Text(b).font(.system(size: 12.5)).foregroundStyle(VipleMailPalette.ink)
                            }
                        }
                        if !digest.questions.isEmpty {
                            Text("❓ Question détectée : \(digest.questions[0])")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.indigo)
                                .padding(.top, 2)
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VipleMailPalette.surfaceSubtle))
                }

                // 7. #013 : Entités intelligentes détectées (OTP, Colis, IBAN, Tél, Liens)
                if beta.isEnabled(.f013) {
                    let entities = BetaProductivityEngine.extractSmartEntities(from: message)
                    if !entities.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(entities) { ent in
                                    Button {
                                        if let url = ent.actionUrl {
                                            #if canImport(UIKit)
                                            UIApplication.shared.open(url)
                                            #endif
                                        } else {
                                            #if canImport(UIKit)
                                            UIPasteboard.general.string = ent.value
                                            #endif
                                            vm.showToast("\(ent.kindLabel) copié : \(ent.value)")
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: ent.icon)
                                                .font(.system(size: 11, weight: .bold))
                                            Text("\(ent.kindLabel) : \(String(ent.value.prefix(24)))")
                                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                                .lineLimit(1)
                                            Image(systemName: ent.actionUrl != nil ? "arrow.up.right" : "doc.on.doc")
                                                .font(.system(size: 9.5, weight: .bold))
                                        }
                                        .foregroundStyle(VipleMailPalette.primary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.11)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                // 8. #015 : Panneau Traducteur Bilingue Côte-à-Côte
                if beta.isEnabled(.f015) && showTranslatorPanel {
                    BetaInlineTranslatorCard(text: message.plainBodyText, targetLang: $targetTranslationLang)
                }

                // 9. #016 : Citations surlignées sur ce courrier
                if beta.isEnabled(.f016) {
                    let quotes = beta.highlightQuotes.filter { $0.messageId == message.id }
                    if !quotes.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("PASSAGES SURLIGNÉS (\(quotes.count))")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                            ForEach(quotes) { q in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(VipleMailPalette.colorFromHex(q.colorHex))
                                        .frame(width: 4, height: 26)
                                    Text("« \(q.excerpt) »")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(VipleMailPalette.ink)
                                    Spacer()
                                }
                            }
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.yellow.opacity(0.08)))
                    }
                }

                // 10. #026 : Sondage interactif #viplesondage détecté dans le mail
                if beta.isEnabled(.f026), let poll = BetaMailPollParser.extract(from: message.plainBodyText, messageId: message.id) {
                    BetaInteractiveMailPollCardView(poll: poll)
                }
            }
            .padding(.horizontal, VipleMailLayout.isCompactPhone ? 12 : 16)
            .padding(.vertical, 10)
            .confirmationDialog("Mettre ce courrier en sommeil (Snooze)", isPresented: $showSnoozeDialog, titleVisibility: .visible) {
                Button("Ce soir (19h00)") { snoozeUntil(hoursFromNow: 4) }
                Button("Demain matin (09h00)") { snoozeTomorrowMorning() }
                Button("Dans 3 jours") { snoozeUntil(hoursFromNow: 72) }
                Button("La semaine prochaine") { snoozeUntil(hoursFromNow: 168) }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showStickyNoteSheet) {
                BetaStickyNoteEditorSheet(message: message)
            }
            .sheet(isPresented: $showBionicSheet) {
                BetaBionicComfortReaderSheet(message: message)
            }
            .sheet(isPresented: $showHighlighterSheet) {
                BetaHighlighterSheet(message: message)
            }
            .sheet(isPresented: $showTeleprompterSheet) {
                BetaTeleprompterReaderSheet(message: message)
            }
            .sheet(isPresented: $showRfcInspectorSheet) {
                BetaRfcHeaderInspectorSheet(message: message)
            }
            .sheet(isPresented: $showSealVaultSheet) {
                BetaVaultSealMessageSheet(message: message)
            }
            .sheet(isPresented: $showExportStudioSheet) {
                BetaSovereignExportSheet(message: message)
                    .environmentObject(vm)
            }
        }
    }

    private var inMailSearchWidget: some View {
        let matches = computeInMailExcerpts()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VipleMailPalette.primary)
                TextField("Rechercher un terme dans ce courrier…", text: $inMailQuery)
                    .font(.system(size: 13.5))
                    .textInputAutocapitalization(.never)
                if !matches.isEmpty {
                    Text("\(min(inMailMatchIndex + 1, matches.count))/\(matches.count)")
                        .font(.system(size: 11.5, weight: .black, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.primary)
                    Button {
                        inMailMatchIndex = (inMailMatchIndex - 1 + matches.count) % matches.count
                    } label: { Image(systemName: "chevron.up") }
                    Button {
                        inMailMatchIndex = (inMailMatchIndex + 1) % matches.count
                    } label: { Image(systemName: "chevron.down") }
                }
                Button {
                    showInMailSearch = false
                    inMailQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
            if !inMailQuery.isEmpty {
                if matches.isEmpty {
                    Text("Aucune occurrence trouvée dans ce courrier.")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                } else {
                    let safeIdx = min(inMailMatchIndex, matches.count - 1)
                    Text("…\(matches[safeIdx])…")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.ink)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.22)))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
    }

    private func computeInMailExcerpts() -> [String] {
        let q = inMailQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else { return [] }
        let body = message.plainBodyText
        var results: [String] = []
        var searchStart = body.startIndex
        while let r = body.range(of: q, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<body.endIndex) {
            let lo = body.index(r.lowerBound, offsetBy: -36, limitedBy: body.startIndex) ?? body.startIndex
            let hi = body.index(r.upperBound, offsetBy: 48, limitedBy: body.endIndex) ?? body.endIndex
            results.append(String(body[lo..<hi]).replacingOccurrences(of: "\n", with: " "))
            searchStart = r.upperBound
            if results.count >= 30 { break }
        }
        return results
    }

    private func snoozeUntil(hoursFromNow: Double) {
        let wake = Date().addingTimeInterval(hoursFromNow * 3600)
        beta.snoozedMails[message.id] = BetaSnoozedMail(
            messageId: message.id,
            subject: message.subject,
            senderName: message.senderName.isEmpty ? message.senderEmail : message.senderName,
            wakeAt: wake
        )
        beta.saveState()
        vm.showToast("😴 Courrier mis en sommeil jusqu'au \(wake.formatted(date: .abbreviated, time: .shortened))")
        vm.closeMessage()
    }

    private func snoozeTomorrowMorning() {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86400)
        let wake = cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
        beta.snoozedMails[message.id] = BetaSnoozedMail(
            messageId: message.id,
            subject: message.subject,
            senderName: message.senderName.isEmpty ? message.senderEmail : message.senderName,
            wakeAt: wake
        )
        beta.saveState()
        vm.showToast("🌅 Rappel programmé demain à 09h00")
        vm.closeMessage()
    }

    private func stickyColor(_ name: String) -> Color {
        switch name {
        case "blue": return .blue
        case "mint": return .teal
        case "coral": return .red
        default: return .orange
        }
    }

    private func readerActionChip(_ label: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(label)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5.5)
            .background(Capsule().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vues Complètes Dédiées aux Fonctions #001..#020

public struct BetaTriageExpressDeckView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var processedIds: Set<String> = []
    @State private var dragOffset: CGSize = .zero

    public init() {}

    private var remainingQueue: [VipleMailMessage] {
        vm.displayedMessages.filter { !processedIds.contains($0.id) }
    }

    public var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Triage Express « Inbox Zero »")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Text("\(processedIds.count) traité(s) • \(remainingQueue.count) restant(s)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer()
                Button("Terminer") { dismiss() }
                    .fontWeight(.bold)
            }

            if let topMail = remainingQueue.first {
                Spacer(minLength: 4)
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        VipleMailAvatarView(name: topMail.senderName, email: topMail.senderEmail, size: 42, isVip: topMail.isVipSender)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(topMail.senderName.isEmpty ? topMail.senderEmail : topMail.senderName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(topMail.formattedRelativeDate)
                                .font(.system(size: 12))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Spacer()
                    }
                    Text(topMail.subject)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Divider()
                    ScrollView {
                        Text(topMail.plainBodyText)
                            .font(.system(size: 14))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 260)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(VipleMailPalette.surface))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(VipleMailPalette.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 18)))
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = $0.translation }
                        .onEnded { val in
                            if val.translation.width > 95 {
                                handleCardAction(topMail, action: "archive")
                            } else if val.translation.width < -95 {
                                handleCardAction(topMail, action: "snooze")
                            } else if val.translation.height < -95 {
                                handleCardAction(topMail, action: "star")
                            } else if val.translation.height > 95 {
                                handleCardAction(topMail, action: "trash")
                            }
                            withAnimation(.spring()) { dragOffset = .zero }
                        }
                )

                Spacer(minLength: 4)

                HStack(spacing: 14) {
                    triageCircleBtn(icon: "moon.zzz.fill", label: "Snooze", color: .purple) {
                        handleCardAction(topMail, action: "snooze")
                    }
                    triageCircleBtn(icon: "trash.fill", label: "Suppr.", color: VipleMailPalette.danger) {
                        handleCardAction(topMail, action: "trash")
                    }
                    triageCircleBtn(icon: "star.fill", label: "Favori", color: .orange) {
                        handleCardAction(topMail, action: "star")
                    }
                    triageCircleBtn(icon: "archivebox.fill", label: "Archiver", color: VipleMailPalette.success) {
                        handleCardAction(topMail, action: "archive")
                    }
                }
            } else {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(VipleMailPalette.success)
                Text("Bravo — Inbox Zero atteint !")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                Button("Revenir à la boîte") {
                    beta.triggerCelebrationParticles()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
        .padding(18)
    }

    private func triageCircleBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: icon).font(.system(size: 19, weight: .bold)).foregroundStyle(color))
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func handleCardAction(_ msg: VipleMailMessage, action: String) {
        processedIds.insert(msg.id)
        switch action {
        case "archive":
            Task { await vm.performMessageAction(messageIds: [msg.id], action: "archive") }
        case "trash":
            Task { await vm.performMessageAction(messageIds: [msg.id], action: "trash") }
        case "star":
            Task { await vm.performMessageAction(messageIds: [msg.id], action: "toggle_star") }
        case "snooze":
            beta.snoozedMails[msg.id] = BetaSnoozedMail(
                messageId: msg.id,
                subject: msg.subject,
                senderName: msg.senderName,
                wakeAt: Date().addingTimeInterval(14 * 3600)
            )
            beta.saveState()
        default:
            break
        }
    }
}

public struct BetaMailKanbanBoardView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedColumn: BetaKanbanColumn = .todo

    public init() {}

    private func messages(in col: BetaKanbanColumn) -> [VipleMailMessage] {
        vm.displayedMessages.filter { msg in
            let assigned = beta.kanbanAssignments[msg.id] ?? (msg.isRead ? .inProgress : .todo)
            return assigned == col
        }
    }

    public var body: some View {
        VStack(spacing: 12) {
            Picker("Colonne", selection: $selectedColumn) {
                ForEach(BetaKanbanColumn.allCases) { col in
                    Text("\(col.rawValue) (\(messages(in: col).count))").tag(col)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)

            List {
                ForEach(messages(in: selectedColumn)) { msg in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(msg.senderName.isEmpty ? msg.senderEmail : msg.senderName)
                                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            Spacer()
                            Text(msg.formattedRelativeDate)
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Text(msg.subject)
                            .font(.system(size: 14.5, weight: .semibold))
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            ForEach(BetaKanbanColumn.allCases.filter { $0 != selectedColumn }) { targetCol in
                                Button {
                                    beta.kanbanAssignments[msg.id] = targetCol
                                    beta.saveState()
                                } label: {
                                    Text("→ \(targetCol.rawValue)")
                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(targetCol.color)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(targetCol.color.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                            Button("Ouvrir") {
                                dismiss()
                                vm.openMessage(msg)
                            }
                            .font(.system(size: 11.5, weight: .bold))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
        }
    }
}

public struct BetaStickyNoteEditorSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    @State private var noteText: String = ""
    @State private var colorName: String = "yellow"
    @State private var tagsRaw: String = ""

    public init(message: VipleMailMessage) {
        self.message = message
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Note Post-it privée (invisible pour l'expéditeur)") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 90)
                    Picker("Couleur", selection: $colorName) {
                        Text("🟡 Jaune Solaire").tag("yellow")
                        Text("🔵 Azur").tag("blue")
                        Text("🟢 Menthe").tag("mint")
                        Text("🔴 Corail").tag("coral")
                    }
                }
                Section("Étiquettes (séparées par virgule)") {
                    TextField("urgent, compta, contrat", text: $tagsRaw)
                }
                if beta.stickyNotesByMessage[message.id] != nil {
                    Section {
                        Button("Supprimer ce Post-it", role: .destructive) {
                            beta.stickyNotesByMessage.removeValue(forKey: message.id)
                            beta.saveState()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Post-it & Étiquettes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let tags = tagsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        beta.stickyNotesByMessage[message.id] = BetaStickyNote(
                            messageId: message.id,
                            text: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
                            colorName: colorName,
                            tags: tags,
                            updatedAt: Date()
                        )
                        beta.saveState()
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let existing = beta.stickyNotesByMessage[message.id] {
                    noteText = existing.text
                    colorName = existing.colorName
                    tagsRaw = existing.tags.joined(separator: ", ")
                }
            }
        }
    }
}

public struct BetaBionicComfortReaderSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var paperBackground: Color {
        switch beta.bionicPaperTint {
        case "sepia": return Color(red: 0.97, green: 0.94, blue: 0.87)
        case "night": return Color(red: 0.08, green: 0.10, blue: 0.14)
        default: return Color.white
        }
    }

    private var paperForeground: Color {
        beta.bionicPaperTint == "night" ? Color(red: 0.92, green: 0.94, blue: 0.97) : Color(red: 0.12, green: 0.12, blue: 0.14)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Picker("Teinte", selection: $beta.bionicPaperTint) {
                        Text("Blanc").tag("clean")
                        Text("Sépia").tag("sepia")
                        Text("Nuit").tag("night")
                    }
                    .pickerStyle(.segmented)

                    Toggle("Dyslexie", isOn: $beta.bionicDyslexiaFriendly)
                        .labelsHidden()
                        .tint(VipleMailPalette.primary)

                    Stepper("", value: $beta.bionicFontScale, in: 0.85...1.60, step: 0.1)
                        .labelsHidden()
                }
                .padding(12)
                .background(VipleMailPalette.surface)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(message.subject)
                            .font(.system(size: 21 * beta.bionicFontScale, weight: .black, design: .rounded))
                            .foregroundStyle(paperForeground)

                        Text(BetaProductivityEngine.makeBionicAttributedString(
                            message.plainBodyText,
                            fontSize: 16 * beta.bionicFontScale,
                            dyslexiaMode: beta.bionicDyslexiaFriendly
                        ))
                        .foregroundStyle(paperForeground)
                        .lineSpacing(beta.bionicLineSpacing)
                    }
                    .padding(20)
                }
                .background(paperBackground.ignoresSafeArea())
            }
            .navigationTitle("Lecture Bionic & Confort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        beta.saveState()
                        dismiss()
                    }
                }
            }
        }
    }
}

public struct BetaInlineTranslatorCard: View {
    public let text: String
    @Binding public var targetLang: String

    private var detectedLanguageLabel: String {
        let rec = NLLanguageRecognizer()
        rec.processString(text)
        switch rec.dominantLanguage {
        case .french: return "Français détecté"
        case .english: return "Anglais détecté"
        case .spanish: return "Espagnol détecté"
        case .german: return "Allemand détecté"
        default: return "Langue auto-détectée"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(detectedLanguageLabel, systemImage: "character.bubble.fill")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.indigo)
                Spacer()
                Picker("Cible", selection: $targetLang) {
                    Text("→ FR").tag("fr")
                    Text("→ EN").tag("en")
                    Text("→ ES").tag("es")
                    Text("→ DE").tag("de")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 190)
            }

            let paragraphs = text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.prefix(6)
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, para in
                VStack(alignment: .leading, spacing: 4) {
                    Text(para)
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    Text(BetaLocalPhrasebookTranslator.translateParagraph(para, to: targetLang))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.ink)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(VipleMailPalette.surface))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.indigo.opacity(0.09)))
    }
}

public enum BetaLocalPhrasebookTranslator {
    public static func translateParagraph(_ raw: String, to target: String) -> String {
        var out = raw
        let frToEn: [(String, String)] = [
            ("Bonjour", "Hello"), ("Bonsoir", "Good evening"), ("Merci beaucoup", "Thank you very much"),
            ("Merci", "Thank you"), ("Cordialement", "Best regards"), ("Bien cordialement", "Kind regards"),
            ("Veuillez trouver ci-joint", "Please find attached"), ("pièce jointe", "attachment"),
            ("rendez-vous", "meeting"), ("facture", "invoice"), ("urgent", "urgent"),
            ("demain", "tomorrow"), ("aujourd'hui", "today"), ("semaine prochaine", "next week")
        ]
        let enToFr: [(String, String)] = [
            ("Hello", "Bonjour"), ("Hi ", "Bonjour "), ("Thank you", "Merci"),
            ("Best regards", "Cordialement"), ("Kind regards", "Bien cordialement"),
            ("Please find attached", "Veuillez trouver ci-joint"), ("meeting", "rendez-vous"),
            ("invoice", "facture"), ("tomorrow", "demain"), ("today", "aujourd'hui"), ("schedule", "planifier")
        ]
        let pairs: [(String, String)]
        switch target {
        case "fr": pairs = enToFr
        case "es": pairs = [("Bonjour", "Hola"), ("Merci", "Gracias"), ("Cordialement", "Saludos cordiales"), ("Hello", "Hola"), ("Thank you", "Gracias")]
        case "de": pairs = [("Bonjour", "Guten Tag"), ("Merci", "Vielen Dank"), ("Cordialement", "Mit freundlichen Grüßen"), ("Hello", "Hallo")]
        default: pairs = frToEn
        }
        for (src, dst) in pairs {
            out = out.replacingOccurrences(of: src, with: dst, options: .caseInsensitive)
        }
        return "[\(target.uppercased())] \(out)"
    }
}

public struct BetaHighlighterSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage
    @State private var customExcerpt: String = ""
    @State private var chosenColorHex: String = "#FACC15"

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var candidateSentences: [String] {
        message.plainBodyText
            .components(separatedBy: CharacterSet(charactersIn: ".\n!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 15 }
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Couleur du surligneur") {
                    Picker("Couleur", selection: $chosenColorHex) {
                        Text("🟡 Jaune").tag("#FACC15")
                        Text("🟢 Émeraude").tag("#34D399")
                        Text("🔵 Azur").tag("#38BDF8")
                        Text("🩷 Rose").tag("#F472B6")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Saisir ou toucher une phrase du courrier à surligner") {
                    TextField("Extrait à retenir…", text: $customExcerpt)
                    ForEach(candidateSentences.prefix(12), id: \.self) { sent in
                        Button {
                            saveQuote(sent)
                        } label: {
                            Text(sent)
                                .font(.system(size: 13))
                                .foregroundStyle(VipleMailPalette.ink)
                        }
                    }
                }
                if !beta.highlightQuotes.isEmpty {
                    Section("Carnet centralisé (\(beta.highlightQuotes.count) citation(s))") {
                        NavigationLink("Ouvrir tout mon Carnet de Citations") {
                            BetaHighlightQuotesNotebookView()
                        }
                    }
                }
            }
            .navigationTitle("Surligneur & Citations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Surligner") { saveQuote(customExcerpt) }
                        .disabled(customExcerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveQuote(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        beta.highlightQuotes.insert(
            BetaHighlightQuote(
                id: UUID().uuidString,
                messageId: message.id,
                messageSubject: message.subject,
                senderEmail: message.senderEmail,
                excerpt: clean,
                colorHex: chosenColorHex,
                createdAt: Date()
            ),
            at: 0
        )
        beta.saveState()
        dismiss()
    }
}

public struct BetaHighlightQuotesNotebookView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    private var markdownExport: String {
        var lines = ["# Carnet de Citations Viple Mail\n"]
        for q in beta.highlightQuotes {
            lines.append("> \(q.excerpt)")
            lines.append("— *\(q.messageSubject)* (\(q.senderEmail), \(q.createdAt.formatted(date: .abbreviated, time: .shortened)))\n")
        }
        return lines.joined(separator: "\n")
    }

    public var body: some View {
        List {
            if !beta.highlightQuotes.isEmpty {
                Section {
                    ShareLink(item: markdownExport, preview: SharePreview("Citations_VipleMail.md")) {
                        Label("Exporter toutes mes citations en Markdown", systemImage: "square.and.arrow.up")
                    }
                }
            }
            Section("Passages surlignés (\(beta.highlightQuotes.count))") {
                if beta.highlightQuotes.isEmpty {
                    Text("Aucune citation enregistrée. Ouvrez un courrier et touchez « Surligner » (#016).")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(beta.highlightQuotes) { q in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VipleMailPalette.colorFromHex(q.colorHex))
                                    .frame(width: 4, height: 28)
                                Text("« \(q.excerpt) »")
                                    .font(.system(size: 13.5, weight: .semibold))
                            }
                            HStack {
                                Text("\(q.messageSubject) • \(q.senderEmail)")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(VipleMailPalette.primary)
                                    .lineLimit(1)
                                Spacer()
                                if let src = vm.messages.first(where: { $0.id == q.messageId }) {
                                    Button("Ouvrir") {
                                        dismiss()
                                        vm.selectedTab = 0
                                        vm.openMessage(src)
                                    }
                                    .font(.system(size: 11.5, weight: .bold))
                                }
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .onDelete { offsets in
                        beta.highlightQuotes.remove(atOffsets: offsets)
                        beta.saveState()
                    }
                }
            }
        }
    }
}

public struct BetaTeleprompterReaderSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    @State private var isRolling: Bool = true
    @State private var scrollOffset: CGFloat = 0

    public init(message: VipleMailMessage) {
        self.message = message
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        isRolling.toggle()
                    } label: {
                        Label(isRolling ? "Pause" : "Défiler", systemImage: isRolling ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .buttonStyle(.borderedProminent)

                    Slider(value: $beta.teleprompterSpeedPtsPerSec, in: 12...75)
                    Text("\(Int(beta.teleprompterSpeedPtsPerSec)) pt/s")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                }
                .padding(12)
                .background(VipleMailPalette.surface)

                GeometryReader { _ in
                    ScrollView(showsIndicators: false) {
                        Text(message.plainBodyText)
                            .font(.system(size: 21, weight: .semibold, design: .rounded))
                            .lineSpacing(9)
                            .padding(22)
                            .offset(y: -scrollOffset)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isRolling.toggle() }
                }
            }
            .navigationTitle("Téléprompteur Mains-Libres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        beta.saveState()
                        dismiss()
                    }
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    if isRolling {
                        scrollOffset += CGFloat(beta.teleprompterSpeedPtsPerSec) * 0.05
                    }
                }
            }
        }
    }
}

// MARK: - #020 Fenêtre Flottante de Référence (Lecture Croisée)

public struct BetaPinnedReferenceDrawerOverlay: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var isExpanded: Bool = false

    public init() {}

    public var body: some View {
        if beta.isEnabled(.f020), let refMsg = beta.pinnedReferenceMessage {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "pip.fill")
                        .foregroundStyle(VipleMailPalette.primary)
                    Text("Réf. : \(refMsg.subject)")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Button {
                        beta.pinnedReferenceMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }

                if isExpanded {
                    Divider()
                    Text("De : \(refMsg.senderName) <\(refMsg.senderEmail)>")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    ScrollView {
                        Text(refMsg.plainBodyText)
                            .font(.system(size: 12.5))
                            .foregroundStyle(VipleMailPalette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 165)
                }
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VipleMailPalette.surface)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(VipleMailPalette.primary.opacity(0.45), lineWidth: 1.3))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            )
            .padding(.horizontal, 14)
        }
    }
}


// MARK: - Vues Complètes Complémentaires du Lot 1 & Lot 2 (#001, #004, #005, #006, #008, #009, #010, #018)

public struct BetaSnoozeQueueView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    private var sortedSnoozes: [BetaSnoozedMail] {
        beta.snoozedMails.values.sorted { $0.wakeAt < $1.wakeAt }
    }

    public var body: some View {
        List {
            if sortedSnoozes.isEmpty {
                Section {
                    Text("Aucun courrier en sommeil actuellement. Utilisez le bouton « Snooze » depuis un courrier ou Triage Express.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            } else {
                Section("Courriers en sommeil (\(sortedSnoozes.count))") {
                    ForEach(sortedSnoozes) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.subject)
                                    .font(.system(size: 14, weight: .bold))
                                Text("\(item.senderName) • Réveil : \(item.wakeAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                            Spacer()
                            Button("Réveiller") {
                                beta.snoozedMails.removeValue(forKey: item.messageId)
                                beta.saveState()
                                vm.showToast("⏰ Courrier remis en boîte de réception")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

public struct BetaScreenerQuarantineView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    private var unknownSenderMessages: [VipleMailMessage] {
        let knownContacts = Set(vm.contacts.map { $0.contactEmail.lowercased() })
        let knownFriends = Set(vm.acceptedFriends.flatMap { $0.allKnownEmails })
        var seen = Set<String>()
        var out: [VipleMailMessage] = []
        for m in vm.messages where m.folder == "Inbox" {
            let em = m.senderEmail.lowercased()
            guard !em.isEmpty,
                  !knownContacts.contains(em),
                  !knownFriends.contains(em),
                  !beta.approvedScreenerSenders.contains(em),
                  !beta.blockedScreenerSenders.contains(em),
                  !seen.contains(em) else { continue }
            seen.insert(em)
            out.append(m)
        }
        return out
    }

    public var body: some View {
        List {
            Section("Nouveaux expéditeurs en attente (\(unknownSenderMessages.count))") {
                if unknownSenderMessages.isEmpty {
                    Text("Tous les expéditeurs récents sont déjà validés ou dans votre carnet.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(unknownSenderMessages) { msg in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(msg.senderName.isEmpty ? msg.senderEmail : msg.senderName)
                                .font(.system(size: 14.5, weight: .bold))
                            Text(msg.senderEmail)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.primary)
                            Text("Objet : \(msg.subject)")
                                .font(.system(size: 12.5))
                                .foregroundStyle(VipleMailPalette.inkSecondary)

                            HStack(spacing: 10) {
                                Button {
                                    beta.approvedScreenerSenders.insert(msg.senderEmail.lowercased())
                                    beta.saveState()
                                    vm.showToast("✅ \(msg.senderEmail) autorisé")
                                } label: {
                                    Label("Autoriser", systemImage: "checkmark.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(VipleMailPalette.success)
                                .controlSize(.small)

                                Button(role: .destructive) {
                                    beta.blockedScreenerSenders.insert(msg.senderEmail.lowercased())
                                    beta.saveState()
                                    Task { await vm.blockSenderAddress(msg.senderEmail) }
                                } label: {
                                    Label("Bloquer", systemImage: "hand.raised.fill")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            if !beta.blockedScreenerSenders.isEmpty {
                Section("Expéditeurs rejetés (\(beta.blockedScreenerSenders.count))") {
                    ForEach(Array(beta.blockedScreenerSenders).sorted(), id: \.self) { em in
                        HStack {
                            Text(em).font(.system(size: 13))
                            Spacer()
                            Button("Débloquer") {
                                beta.blockedScreenerSenders.remove(em)
                                beta.saveState()
                            }
                            .font(.system(size: 12, weight: .bold))
                        }
                    }
                }
            }
        }
    }
}

public struct BetaFollowUpCenterView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        List {
            if beta.followUpItems.isEmpty {
                Section {
                    Text("Aucune relance programmée. Touchez « Relance J+3 » dans un courrier ouvert pour suivre une réponse attendue.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            } else {
                ForEach(beta.followUpItems) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.subject)
                                .font(.system(size: 14, weight: .bold))
                                .strikethrough(item.completed)
                            Spacer()
                            Text(item.dueAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(item.dueAt < Date() && !item.completed ? VipleMailPalette.danger : VipleMailPalette.primary)
                        }
                        Text(item.recipientOrSenderEmail)
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        HStack(spacing: 8) {
                            Button("Générer relance") {
                                dismiss()
                                vm.presentComposer(.newMail(
                                    to: item.recipientOrSenderEmail,
                                    subject: "Relance : \(item.subject)",
                                    body: "Bonjour \(item.recipientOrSenderName),\n\nJe me permets de revenir vers vous concernant mon précédent courrier au sujet de « \(item.subject) ».\n\nAvez-vous eu l'occasion d'en prendre connaissance ?\n\nBien cordialement,",
                                    forceMail: true
                                ))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)

                            Button(item.completed ? "Rouvrir" : "Marquer répondu") {
                                if let idx = beta.followUpItems.firstIndex(where: { $0.id == item.id }) {
                                    beta.followUpItems[idx].completed.toggle()
                                    beta.saveState()
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { offsets in
                    beta.followUpItems.remove(atOffsets: offsets)
                    beta.saveState()
                }
            }
        }
    }
}

public struct BetaNewsletterUnsubscribeView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    private var groupedNewsletters: [(domain: String, sample: VipleMailMessage, count: Int)] {
        let news = vm.messages.filter { BetaProductivityEngine.isLikelyNewsletter($0) }
        let grouped = Dictionary(grouping: news) { BetaProductivityEngine.senderDomain(of: $0.senderEmail) }
        return grouped.compactMap { dom, list in
            guard let first = list.first else { return nil }
            return (dom, first, list.count)
        }
        .sorted { $0.count > $1.count }
    }

    public var body: some View {
        List {
            Section("Flux commerciaux & Newsletters détectés (\(groupedNewsletters.count))") {
                if groupedNewsletters.isEmpty {
                    Text("Aucune newsletter récurrente détectée dans votre boîte actuelle.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(groupedNewsletters, id: \.domain) { entry in
                        let isMuted = beta.unsubscribedDomains.contains(entry.domain)
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.sample.senderName.isEmpty ? entry.domain : entry.sample.senderName)
                                    .font(.system(size: 14.5, weight: .bold))
                                Spacer()
                                Text("\(entry.count) mail(s)")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                            Text("@\(entry.domain)")
                                .font(.system(size: 12))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                            HStack(spacing: 8) {
                                Button(isMuted ? "Réactiver l'affichage" : "Se désabonner en 1 clic") {
                                    if isMuted {
                                        beta.unsubscribedDomains.remove(entry.domain)
                                    } else {
                                        beta.unsubscribedDomains.insert(entry.domain)
                                        if let u = BetaProductivityEngine.extractUnsubscribeURL(from: entry.sample.bodyHtml, senderEmail: entry.sample.senderEmail) {
                                            #if canImport(UIKit)
                                            UIApplication.shared.open(u)
                                            #endif
                                        }
                                    }
                                    beta.saveState()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(isMuted ? .gray : VipleMailPalette.danger)
                                .controlSize(.small)

                                Button("Tout archiver") {
                                    let ids = vm.messages.filter { BetaProductivityEngine.senderDomain(of: $0.senderEmail) == entry.domain }.map(\.id)
                                    Task { await vm.performMessageAction(messageIds: ids, action: "archive", toast: "\(ids.count) newsletter(s) archivée(s)") }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}

public struct BetaSmartViewBuilderView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var name: String = ""
    @State private var domain: String = ""
    @State private var keyword: String = ""
    @State private var unreadOnly: Bool = false
    @State private var attachmentsOnly: Bool = false
    @State private var vipOnly: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Section("Nouvelle vue intelligente dynamique") {
                TextField("Nom de la vue (ex: Contrats PDF)", text: $name)
                TextField("Domaine expéditeur (optionnel)", text: $domain)
                    .textInputAutocapitalization(.never)
                TextField("Mot-clé sujet/corps (optionnel)", text: $keyword)
                Toggle("Uniquement non lus", isOn: $unreadOnly)
                Toggle("Uniquement avec pièce jointe", isOn: $attachmentsOnly)
                Toggle("Uniquement contacts VIP", isOn: $vipOnly)
                Button("Créer cette vue dynamique") {
                    let v = BetaSmartDynamicView(
                        id: UUID().uuidString,
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        domain: domain,
                        keyword: keyword,
                        unread: unreadOnly,
                        attachments: attachmentsOnly,
                        vip: vipOnly
                    )
                    beta.smartDynamicViews.append(v)
                    beta.activeSmartViewId = v.id
                    beta.saveState()
                    name = ""; domain = ""; keyword = ""
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Vues intelligentes enregistrées (\(beta.smartDynamicViews.count))") {
                ForEach(beta.smartDynamicViews) { sv in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(sv.name).font(.system(size: 14, weight: .bold))
                            Text("Domaine: \(sv.domainFilter.isEmpty ? "tous" : sv.domainFilter) • Mot-clé: \(sv.keywordFilter.isEmpty ? "aucun" : sv.keywordFilter)")
                                .font(.system(size: 11.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Spacer()
                        if beta.activeSmartViewId == sv.id {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(VipleMailPalette.success)
                        }
                    }
                }
                .onDelete { offsets in
                    beta.smartDynamicViews.remove(atOffsets: offsets)
                    beta.saveState()
                }
            }
        }
    }
}

extension BetaSmartDynamicView {
    init(id: String, name: String, domain: String, keyword: String, unread: Bool, attachments: Bool, vip: Bool) {
        self.init(
            id: id,
            name: name,
            domainFilter: domain,
            keywordFilter: keyword,
            unreadOnly: unread,
            attachmentsOnly: attachments,
            vipOnly: vip
        )
    }
}

public struct BetaBatchFocusConfigView: View {
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Créneaux de livraison groupée (Batch Inbox)") {
                ForEach([8, 9, 12, 13, 16, 18, 20], id: \.self) { hour in
                    let on = beta.batchDeliveryHours.contains(hour)
                    Toggle("Livraison à \(String(format: "%02dh00", hour))", isOn: Binding(
                        get: { on },
                        set: { newVal in
                            if newVal {
                                if !beta.batchDeliveryHours.contains(hour) { beta.batchDeliveryHours.append(hour) }
                            } else {
                                beta.batchDeliveryHours.removeAll { $0 == hour }
                            }
                            beta.batchDeliveryHours.sort()
                            beta.saveState()
                        }
                    ))
                }
            }
            Section("Déverrouillage temporaire") {
                Button("Débloquer tous les courriers pendant 1 heure") {
                    beta.batchBypassUntil = Date().addingTimeInterval(3600)
                }
                if let until = beta.batchBypassUntil, until > Date() {
                    Text("Mode libre actif jusqu'à \(until.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.success)
                }
            }
        }
    }
}

public struct BetaMailAnalyticsDashboardView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    public var body: some View {
        let all = vm.messages
        let total = max(1, all.count)
        let readCount = all.filter(\.isRead).count
        let unreadCount = all.count - readCount
        let withAtt = all.filter(\.hasAttachments).count
        let mailRteCount = all.filter { $0.effectiveIsMailRteSecurity }.count
        let hygieneScore = min(100, max(10, Int(Double(readCount) / Double(total) * 100.0)))

        let bySender = Dictionary(grouping: all) { $0.senderEmail.lowercased() }
            .map { (email: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(8)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    metricCard(title: "Score Inbox", value: "\(hygieneScore)/100", icon: "sparkles", color: VipleMailPalette.success)
                    metricCard(title: "Non lus", value: "\(unreadCount)", icon: "envelope.badge.fill", color: VipleMailPalette.primary)
                }
                HStack(spacing: 12) {
                    metricCard(title: "Avec PJ", value: "\(withAtt)", icon: "paperclip", color: .orange)
                    metricCard(title: "MailRTE", value: "\(mailRteCount)", icon: "lock.shield.fill", color: VipleMailPalette.indigo)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Top Expéditeurs (\(all.count) courriers analysés)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    ForEach(Array(bySender), id: \.email) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.email).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                                Spacer()
                                Text("\(row.count)").font(.system(size: 12, weight: .black))
                            }
                            GeometryReader { geo in
                                Capsule()
                                    .fill(VipleMailPalette.primary.opacity(0.85))
                                    .frame(width: max(12, geo.size.width * CGFloat(row.count) / CGFloat(max(1, bySender.first?.count ?? 1))), height: 7)
                            }
                            .frame(height: 7)
                        }
                    }
                }
                .vipleMailCard(cornerRadius: 18, padding: 14)
            }
            .padding(16)
        }
    }

    private func metricCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 24, weight: .black, design: .rounded))
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(VipleMailPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vipleMailCard(cornerRadius: 16, padding: 14)
    }
}

public struct BetaInvoiceCsvAccountingView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    public struct InvoiceRow: Identifiable {
        public let id: String
        public let date: String
        public let sender: String
        public let subject: String
        public let amount: String
    }

    private var detectedInvoices: [InvoiceRow] {
        vm.messages.compactMap { m in
            let hay = "\(m.subject) \(m.plainBodyText)".lowercased()
            guard hay.contains("facture") || hay.contains("invoice") || hay.contains("reçu") || hay.contains("paiement") || hay.contains("commande") else {
                return nil
            }
            let amounts = BetaProductivityEngine.regexMatches(in: "\(m.subject) \(m.plainBodyText)", pattern: #"\b\d{1,6}(?:[.,]\d{2})?\s?(?:€|EUR|\$|USD)\b"#)
            return InvoiceRow(
                id: m.id,
                date: String(m.receivedAt.prefix(10)),
                sender: m.senderEmail,
                subject: m.subject,
                amount: amounts.first ?? "À vérifier"
            )
        }
    }

    private var csvExportString: String {
        var lines = ["Date;Emetteur;Objet;Montant_Detecte"]
        for row in detectedInvoices {
            let safeSub = row.subject.replacingOccurrences(of: ";", with: ",")
            lines.append("\(row.date);\(row.sender);\(safeSub);\(row.amount)")
        }
        return lines.joined(separator: "\n")
    }

    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(detectedInvoices.count) justificatif(s) détecté(s)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                ShareLink(item: csvExportString, preview: SharePreview("Factures_VipleMail.csv")) {
                    Label("Exporter CSV", systemImage: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            List(detectedInvoices) { inv in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(inv.subject).font(.system(size: 13.5, weight: .bold)).lineLimit(1)
                        Text("\(inv.date) • \(inv.sender)").font(.system(size: 11.5)).foregroundStyle(VipleMailPalette.inkSecondary)
                    }
                    Spacer()
                    Text(inv.amount)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.success)
                }
            }
            .listStyle(.plain)
        }
    }
}
