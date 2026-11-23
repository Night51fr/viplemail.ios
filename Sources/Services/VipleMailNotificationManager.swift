import Foundation
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
import BackgroundTasks
#endif

// MARK: - Gestionnaire Natif de Notifications « Viple Mail » (Premier Plan, Arrière-Plan BGTaskScheduler + Grace Window & APNs iOS 18+)

private final class BGTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var didComplete = false
    private let completeBlock: (Bool) -> Void

    init(_ complete: @escaping (Bool) -> Void) {
        self.completeBlock = complete
    }

    func complete(_ ok: Bool) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()
        completeBlock(ok)
    }
}

#if canImport(UIKit)
/// Pont strictement `nonisolated` pour `BGTaskScheduler` (Swift 6 / iOS 18-27+).
/// Garantit qu'aucune fermeture exécutée sur les files d'attente d'arrière-plan Apple (`com.apple.BGTaskScheduler`)
/// n'hérite d'une assertion d'isolation `@MainActor` (`_swift_task_checkIsolatedSwift` / `_dispatch_assert_queue_fail`).
private enum VipleMailBackgroundRuntime {
    static let refreshIdentifier = "com.viplenetwork.viplemail.refresh"
    static let processingIdentifier = "com.viplenetwork.viplemail.processing"

    static func scheduleAll() {
        let refreshReq = BGAppRefreshTaskRequest(identifier: refreshIdentifier)
        refreshReq.earliestBeginDate = Date(timeIntervalSinceNow: 60)
        try? BGTaskScheduler.shared.submit(refreshReq)

        let procReq = BGProcessingTaskRequest(identifier: processingIdentifier)
        procReq.requiresNetworkConnectivity = true
        procReq.requiresExternalPower = false
        procReq.earliestBeginDate = Date(timeIntervalSinceNow: 180)
        try? BGTaskScheduler.shared.submit(procReq)
    }

    static func registerAll() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshIdentifier, using: nil) { task in
            let box = BGTaskBox { ok in task.setTaskCompleted(success: ok) }
            scheduleAll()
            let work = Task { @MainActor in
                let ok = await VipleMailNotificationManager.shared.performNotificationPollCycle(isBackground: true)
                box.complete(ok)
            }
            task.expirationHandler = {
                work.cancel()
                scheduleAll()
                box.complete(false)
            }
        }

        BGTaskScheduler.shared.register(forTaskWithIdentifier: processingIdentifier, using: nil) { task in
            let box = BGTaskBox { ok in task.setTaskCompleted(success: ok) }
            scheduleAll()
            let work = Task { @MainActor in
                let ok = await VipleMailNotificationManager.shared.performNotificationPollCycle(isBackground: true)
                box.complete(ok)
            }
            task.expirationHandler = {
                work.cancel()
                scheduleAll()
                box.complete(false)
            }
        }
    }
}
#endif

@MainActor
public final class VipleMailNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    public static let shared = VipleMailNotificationManager()

    public static let refreshTaskIdentifier = "com.viplenetwork.viplemail.refresh"
    public static let processingTaskIdentifier = "com.viplenetwork.viplemail.processing"
    public static let messageCategoryIdentifier = "VIPLE_MAIL_MESSAGE"

    public static let actionReply = "REPLY_ACTION"
    public static let actionMarkRead = "MARK_READ_ACTION"
    public static let actionArchive = "ARCHIVE_ACTION"
    public static let actionTrash = "TRASH_ACTION"

    @Published public private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published public var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: soundPrefKey) }
    }
    @Published public var badgeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(badgeEnabled, forKey: badgePrefKey)
            if !badgeEnabled {
                Task { await applyAppBadgeCount(0) }
            }
        }
    }
    @Published public private(set) var apnsDeviceTokenHex: String? = nil
    @Published public private(set) var lastBackgroundSyncDate: Date? = nil

    /// Référence faible au ViewModel actif pour navigation directe et rafraîchissement temps réel
    public weak var attachedViewModel: VipleMailViewModel?

    private let defaults = UserDefaults.standard
    private let soundPrefKey = "viple.mail.ios.notif.sound.v1"
    private let badgePrefKey = "viple.mail.ios.notif.badge.v1"
    private let savedEmailKey = "viple.mail.ios.savedEmail.v1"
    private let savedOwnerEmailKey = "viple.mail.ios.savedOwnerEmail.v1"
    private let savedCidKey = "viple.mail.ios.savedCid.v1"
    private let savedTokenKey = "viple.mail.ios.savedToken.v1"
    private let savedApnsTokenKey = "viple.mail.ios.apnsTokenHex.v1"

    private var foregroundPollingTask: Task<Void, Never>? = nil
    private var backgroundGraceLoopTask: Task<Void, Never>? = nil
    #if canImport(UIKit)
    private var backgroundGraceTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif
    private var didRegisterBackgroundTasks: Bool = false

    private override init() {
        self.soundEnabled = UserDefaults.standard.object(forKey: "viple.mail.ios.notif.sound.v1") as? Bool ?? true
        self.badgeEnabled = UserDefaults.standard.object(forKey: "viple.mail.ios.notif.badge.v1") as? Bool ?? true
        self.apnsDeviceTokenHex = UserDefaults.standard.string(forKey: "viple.mail.ios.apnsTokenHex.v1")
        super.init()
    }

    public var isOsAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    public var osStatusLabel: String {
        switch authorizationStatus {
        case .authorized: return "Autorisées"
        case .provisional: return "Silencieuses"
        case .ephemeral: return "Temporaires"
        case .denied: return "Désactivées dans iOS"
        case .notDetermined: return "Non configurées"
        @unknown default: return "Actives"
        }
    }

    // MARK: - 1. Initialisation Catégories Interactives, Permission, Clé DPoP Arrière-Plan & BGTaskScheduler

    public func configureOnLaunch() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerInteractiveCategories()
        registerBackgroundTasksIfNeeded()
        scheduleBackgroundTasks()

        #if canImport(UIKit)
        UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
        let isForegroundLaunch = UIApplication.shared.applicationState != .background
        #else
        let isForegroundLaunch = true
        #endif

        Task {
            if isForegroundLaunch {
                await AppAttestManager.shared.ensureBackgroundDpopKeyMigrated()
            }
            await refreshAuthorizationStatus()
            if isOsAuthorized {
                registerForRemoteNotificationsOnSystem()
            }
        }
    }

    private func registerInteractiveCategories() {
        let replyAction = UNTextInputNotificationAction(
            identifier: Self.actionReply,
            title: "Répondre",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "arrowshape.turn.up.left.fill"),
            textInputButtonTitle: "Envoyer",
            textInputPlaceholder: "Votre réponse Viple Mail…"
        )

        let markReadAction = UNNotificationAction(
            identifier: Self.actionMarkRead,
            title: "Marquer comme lu",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "envelope.open.fill")
        )

        let archiveAction = UNNotificationAction(
            identifier: Self.actionArchive,
            title: "Archiver",
            options: [],
            icon: UNNotificationActionIcon(systemImageName: "archivebox.fill")
        )

        let trashAction = UNNotificationAction(
            identifier: Self.actionTrash,
            title: "Supprimer",
            options: [.destructive],
            icon: UNNotificationActionIcon(systemImageName: "trash.fill")
        )

        let mailCategory = UNNotificationCategory(
            identifier: Self.messageCategoryIdentifier,
            actions: [replyAction, markReadAction, archiveAction, trashAction],
            intentIdentifiers: [],
            hiddenPreviewsBodyPlaceholder: "Nouveau courrier Viple Mail",
            categorySummaryFormat: "%u nouveaux courriers de %@ sur Viple Mail",
            options: [.customDismissAction]
        )

        UNUserNotificationCenter.current().setNotificationCategories([mailCategory])
    }

    public func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    public func requestPermissionIfNeeded(promptIfNotDetermined: Bool = true) async -> Bool {
        await refreshAuthorizationStatus()

        if authorizationStatus == .notDetermined && promptIfNotDetermined {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .sound, .badge, .providesAppNotificationSettings]
                )
                await refreshAuthorizationStatus()
                if granted {
                    registerForRemoteNotificationsOnSystem()
                }
                return granted
            } catch {
                return false
            }
        }

        if isOsAuthorized {
            registerForRemoteNotificationsOnSystem()
            return true
        }
        return false
    }

    public func registerForRemoteNotificationsOnSystem() {
        #if canImport(UIKit)
        UIApplication.shared.registerForRemoteNotifications()
        #endif
    }

    public func openSystemNotificationSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }

    public func handleRegisteredDeviceToken(_ deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        self.apnsDeviceTokenHex = hex
        defaults.set(hex, forKey: savedApnsTokenKey)

        let ownerEmail = resolvedOwnerMailboxEmail()
        let cid = attachedViewModel?.currentCid ?? defaults.string(forKey: savedCidKey)
        let pushEnabled = attachedViewModel?.settings.pushNotificationsEnabled ?? true
        let vipOnly = attachedViewModel?.settings.vipNotificationsOnly ?? false

        guard !ownerEmail.isEmpty else { return }
        Task {
            await VipleMailAPIClient.shared.registerDeviceForPush(
                email: ownerEmail,
                cid: cid,
                apnsToken: hex,
                notificationsEnabled: pushEnabled,
                vipOnly: vipOnly
            )
        }
    }

    // MARK: - 2. Synchronisation Premier Plan, Fenêtre d'Exécution Arrière-Plan iOS & BGTaskScheduler

    public func enterForegroundMode() {
        endBackgroundGraceExecution()
        startForegroundSyncLoop()
        Task {
            await AppAttestManager.shared.ensureBackgroundDpopKeyMigrated()
            await refreshAuthorizationStatus()
            if isOsAuthorized {
                registerForRemoteNotificationsOnSystem()
            }
        }
    }

    public func enterBackgroundMode() {
        stopForegroundSyncLoop()
        scheduleBackgroundTasks()
        startBackgroundGraceExecution()
    }

    public func startForegroundSyncLoop() {
        foregroundPollingTask?.cancel()
        foregroundPollingTask = Task { [weak self] in
            guard let self else { return }
            await self.performNotificationPollCycle(isBackground: false)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 12_000_000_000) // Sondage toutes les 12 secondes au premier plan
                if Task.isCancelled { break }
                await self.performNotificationPollCycle(isBackground: false)
            }
        }
    }

    public func stopForegroundSyncLoop() {
        foregroundPollingTask?.cancel()
        foregroundPollingTask = nil
    }

    private func startBackgroundGraceExecution() {
        #if canImport(UIKit)
        endBackgroundGraceExecution()

        let app = UIApplication.shared
        var bgId: UIBackgroundTaskIdentifier = .invalid
        bgId = app.beginBackgroundTask(withName: "com.viplenetwork.viplemail.bg-sync") { [weak self] in
            VipleMailBackgroundRuntime.scheduleAll()
            if Thread.isMainThread {
                MainActor.assumeIsolated {
                    self?.endBackgroundGraceExecution()
                }
            } else {
                Task { @MainActor in
                    self?.endBackgroundGraceExecution()
                }
            }
        }
        guard bgId != .invalid else { return }
        self.backgroundGraceTaskId = bgId

        backgroundGraceLoopTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.performNotificationPollCycle(isBackground: true)

            // Tant qu'iOS accorde du temps d'exécution en arrière-plan après verrouillage ou retour à l'accueil,
            // on continue de vérifier les nouveaux courriers toutes les 6 secondes puis on rend la main proprement.
            while !Task.isCancelled {
                let remaining = UIApplication.shared.backgroundTimeRemaining
                if remaining != .greatestFiniteMagnitude && remaining < 5.5 {
                    break
                }
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if Task.isCancelled { break }
                let remAfterSleep = UIApplication.shared.backgroundTimeRemaining
                if remAfterSleep != .greatestFiniteMagnitude && remAfterSleep < 4.0 {
                    break
                }
                _ = await self.performNotificationPollCycle(isBackground: true)
            }

            self.scheduleBackgroundTasks()
            self.endBackgroundGraceExecution()
        }
        #endif
    }

    private func endBackgroundGraceExecution() {
        backgroundGraceLoopTask?.cancel()
        backgroundGraceLoopTask = nil
        #if canImport(UIKit)
        if backgroundGraceTaskId != .invalid {
            let idToEnd = backgroundGraceTaskId
            backgroundGraceTaskId = .invalid
            UIApplication.shared.endBackgroundTask(idToEnd)
        }
        #endif
    }

    private func registerBackgroundTasksIfNeeded() {
        guard !didRegisterBackgroundTasks else { return }
        didRegisterBackgroundTasks = true

        #if canImport(UIKit)
        VipleMailBackgroundRuntime.registerAll()
        #endif
    }

    nonisolated public func scheduleBackgroundTasks() {
        #if canImport(UIKit)
        VipleMailBackgroundRuntime.scheduleAll()
        #endif
    }

    // MARK: - 3. Moteur de Détection Multi-Boîtes, Bannières Riches & Badge Icône

    private func resolvedOwnerMailboxEmail() -> String {
        if let vm = attachedViewModel, !vm.primaryHostedEmail.isEmpty {
            return vm.primaryHostedEmail.lowercased()
        }
        if let savedOwner = defaults.string(forKey: savedOwnerEmailKey)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !savedOwner.isEmpty,
           savedOwner != "__all__" {
            return savedOwner
        }
        if let saved = defaults.string(forKey: savedEmailKey)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !saved.isEmpty,
           saved != "__all__" {
            return saved
        }
        return ""
    }

    private func seenIdsStorageKey(for ownerMailbox: String) -> String {
        "viple.mail.notif.seenIds.\(ownerMailbox.lowercased())"
    }

    private func baselineDoneStorageKey(for ownerMailbox: String) -> String {
        "viple.mail.notif.baselineDone.\(ownerMailbox.lowercased())"
    }

    private func loadSeenMessageIds(for ownerMailbox: String) -> Set<String> {
        let arr = defaults.stringArray(forKey: seenIdsStorageKey(for: ownerMailbox)) ?? []
        return Set(arr)
    }

    private func saveSeenMessageIds(_ ids: Set<String>, for ownerMailbox: String) {
        let capped = Array(ids.suffix(500))
        defaults.set(capped, forKey: seenIdsStorageKey(for: ownerMailbox))
    }

    private static func isRecentArrival(_ isoDateString: String, maxMinutesAgo: Double = 15) -> Bool {
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: isoDateString) ?? isoFrac.date(from: isoDateString) else {
            return true
        }
        return Date().timeIntervalSince(date) <= (maxMinutesAgo * 60)
    }

    /// Synchronise l'état de référence à partir d'un bootstrap complet au premier plan
    public func ingestBootstrapSnapshot(
        mailboxEmail: String,
        unreadCount: Int,
        messages: [VipleMailMessage],
        settings: VipleMailSettings
    ) async {
        let ownerKey = resolvedOwnerMailboxEmail().isEmpty
            ? mailboxEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            : resolvedOwnerMailboxEmail()
        guard !ownerKey.isEmpty, ownerKey != "__all__" else { return }

        await applyAppBadgeCount(settings.pushNotificationsEnabled && badgeEnabled ? unreadCount : 0)

        let baselineKey = baselineDoneStorageKey(for: ownerKey)
        var seen = loadSeenMessageIds(for: ownerKey)
        let isFirstBaseline = !defaults.bool(forKey: baselineKey)

        if isFirstBaseline {
            for m in messages {
                let mBox = m.effectiveMailboxEmail(fallback: ownerKey)
                seen.insert("\(mBox)|\(m.id)")
                seen.insert(m.id)
            }
            saveSeenMessageIds(seen, for: ownerKey)
            defaults.set(true, forKey: baselineKey)
            return
        }

        guard settings.pushNotificationsEnabled, isOsAuthorized else {
            for m in messages where !m.isRead && m.folder.caseInsensitiveCompare("Inbox") == .orderedSame {
                let mBox = m.effectiveMailboxEmail(fallback: ownerKey)
                seen.insert("\(mBox)|\(m.id)")
                seen.insert(m.id)
            }
            saveSeenMessageIds(seen, for: ownerKey)
            return
        }

        let unseenInbox = messages.filter { !$0.isRead && $0.folder.caseInsensitiveCompare("Inbox") == .orderedSame }
        var newlyArrived: [(item: VipleMailNotificationItem, targetMbx: String)] = []

        for msg in unseenInbox {
            let mBox = msg.effectiveMailboxEmail(fallback: ownerKey)
            let compKey = "\(mBox)|\(msg.id)"
            guard !seen.contains(compKey), !seen.contains(msg.id) else { continue }

            seen.insert(compKey)
            seen.insert(msg.id)
            if settings.vipNotificationsOnly && !msg.isVipSender {
                continue
            }
            if attachedViewModel?.openedMessage?.id == msg.id {
                continue
            }
            newlyArrived.append((
                VipleMailNotificationItem(
                    id: msg.id,
                    threadId: msg.threadId,
                    senderName: msg.senderName,
                    senderEmail: msg.senderEmail,
                    senderAvatarUrl: msg.senderAvatarUrl,
                    subject: msg.subject,
                    snippet: msg.snippet.isEmpty ? msg.plainBodyText : msg.snippet,
                    isVipSender: msg.isVipSender,
                    priority: msg.priority,
                    hasAttachments: msg.hasAttachments,
                    receivedAt: msg.receivedAt,
                    mailboxEmail: mBox
                ),
                mBox
            ))
        }

        saveSeenMessageIds(seen, for: ownerKey)

        for entry in newlyArrived.prefix(5) {
            await scheduleRichMailNotification(for: entry.item, mailboxEmail: entry.targetMbx)
        }
    }

    @discardableResult
    public func performNotificationPollCycle(isBackground: Bool) async -> Bool {
        let ownerEmail = resolvedOwnerMailboxEmail()
        let cid = attachedViewModel?.currentCid ?? defaults.string(forKey: savedCidKey)

        if VipleMailAPIClient.shared.authToken == nil,
           let savedTok = defaults.string(forKey: savedTokenKey),
           !savedTok.isEmpty {
            VipleMailAPIClient.shared.authToken = savedTok
        }

        guard !ownerEmail.isEmpty else { return true }

        do {
            let poll = try await VipleMailAPIClient.shared.pollNotifications(
                email: ownerEmail,
                cid: cid,
                limit: 15,
                allMailboxes: true
            )
            guard poll.ok else { return false }

            self.lastBackgroundSyncDate = Date()
            await refreshAuthorizationStatus()

            let effectivePushEnabled = poll.pushNotificationsEnabled
            let totalUnread = poll.inboxUnreadCount + (poll.chatUnreadCount ?? 0)
            await applyAppBadgeCount(effectivePushEnabled && badgeEnabled ? totalUnread : 0)

            let baselineKey = baselineDoneStorageKey(for: ownerEmail)
            var seen = loadSeenMessageIds(for: ownerEmail)
            let isFirstBaseline = !defaults.bool(forKey: baselineKey)

            // Récupère les notifications déjà affichées dans le centre iOS (ex. poussées en direct via APNs) pour éviter tout doublon
            let deliveredNotifs = await UNUserNotificationCenter.current().deliveredNotifications()
            let alreadyDeliveredIds = Set(deliveredNotifs.compactMap { $0.request.content.userInfo["messageId"] as? String })

            if isFirstBaseline && !isBackground {
                for item in poll.recentUnseen {
                    let itemMbx = (item.mailboxEmail ?? ownerEmail).lowercased()
                    seen.insert("\(itemMbx)|\(item.id)")
                    seen.insert(item.id)
                }
                saveSeenMessageIds(seen, for: ownerEmail)
                defaults.set(true, forKey: baselineKey)
                return true
            }

            if isFirstBaseline {
                defaults.set(true, forKey: baselineKey)
            }

            var hasNewChanges = false
            var toNotify: [(item: VipleMailNotificationItem, targetMbx: String)] = []

            for item in poll.recentUnseen {
                let itemMbx = (item.mailboxEmail ?? ownerEmail).lowercased()
                let compKey = "\(itemMbx)|\(item.id)"

                if !seen.contains(compKey) && !seen.contains(item.id) {
                    seen.insert(compKey)
                    seen.insert(item.id)
                    hasNewChanges = true

                    if isFirstBaseline && !Self.isRecentArrival(item.receivedAt, maxMinutesAgo: 15) {
                        continue
                    }
                    if alreadyDeliveredIds.contains(item.id) {
                        continue
                    }
                    if effectivePushEnabled && isOsAuthorized {
                        if poll.vipNotificationsOnly && !item.isVipSender {
                            continue
                        }
                        if !isBackground, attachedViewModel?.openedMessage?.id == item.id {
                            continue
                        }
                        if !isBackground,
                           let chatSid = item.chatSessionId, !chatSid.isEmpty,
                           attachedViewModel?.openedChatSession?.id == chatSid {
                            continue
                        }
                        toNotify.append((item, itemMbx))
                    }
                }
            }

            saveSeenMessageIds(seen, for: ownerEmail)

            if !isBackground,
               let vm = attachedViewModel,
               (hasNewChanges || vm.unreadInboxCount != poll.inboxUnreadCount || vm.chatUnreadCount != (poll.chatUnreadCount ?? 0)) {
                await vm.refreshBootstrap()
                if vm.openedChatSession != nil {
                    await vm.reloadActiveChatMessages(silent: true)
                }
            }

            for entry in toNotify.prefix(5) {
                await scheduleRichMailNotification(for: entry.item, mailboxEmail: entry.targetMbx)
            }

            return true
        } catch {
            return false
        }
    }

    public func scheduleRichMailNotification(for item: VipleMailNotificationItem, mailboxEmail: String) async {
        let content = UNMutableNotificationContent()
        let vipPrefix = item.isVipSender ? "👑 " : ""
        let urgentPrefix = (item.priority.lowercased() == "high" || item.priority.lowercased() == "haute") ? "❗ " : ""

        content.title = "\(vipPrefix)\(urgentPrefix)\(item.senderName)"
        content.subtitle = item.hasAttachments ? "📎 \(item.subject)" : item.subject
        let cleanSnippet = item.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        content.body = cleanSnippet.isEmpty ? "Nouveau courrier reçu sur \(mailboxEmail)" : cleanSnippet
        content.categoryIdentifier = Self.messageCategoryIdentifier
        content.threadIdentifier = item.threadId.isEmpty ? "viplemail-\(mailboxEmail)" : item.threadId
        content.interruptionLevel = .active
        content.relevanceScore = item.isVipSender ? 1.0 : 0.85

        if soundEnabled {
            content.sound = .default
        }

        content.userInfo = [
            "messageId": item.id,
            "threadId": item.threadId,
            "senderName": item.senderName,
            "senderEmail": item.senderEmail,
            "subject": item.subject,
            "mailboxEmail": mailboxEmail,
            "isChatMessage": item.isChatMessage == true,
            "chatSessionId": item.chatSessionId ?? ""
        ]

        if let avatarAttachment = await buildAvatarAttachment(
            senderName: item.senderName,
            senderEmail: item.senderEmail,
            avatarUrl: item.senderAvatarUrl,
            isVip: item.isVipSender
        ) {
            content.attachments = [avatarAttachment]
        }

        let req = UNNotificationRequest(
            identifier: "viplemail.msg.\(item.id)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(req)
    }

    public func sendTestNotification(mailboxEmail: String) async -> Bool {
        let granted = await requestPermissionIfNeeded(promptIfNotDetermined: true)
        guard granted else { return false }

        let sample = VipleMailNotificationItem(
            id: "test-\(UUID().uuidString.prefix(8))",
            threadId: "thr-viplemail-test",
            senderName: "Viple Mail • Test de Notification",
            senderEmail: "securite@cenelis.com",
            senderAvatarUrl: nil,
            subject: "Notifications arrière-plan & push activées ✅",
            snippet: "Vos bannières riches, badges et synchronisations en arrière-plan (écran verrouillé & multitâche) sont opérationnels.",
            isVipSender: true,
            priority: "High",
            hasAttachments: false,
            receivedAt: ISO8601DateFormatter().string(from: Date()),
            mailboxEmail: mailboxEmail
        )
        await scheduleRichMailNotification(for: sample, mailboxEmail: mailboxEmail.isEmpty ? "viplemail.fr" : mailboxEmail)
        return true
    }

    public func applyAppBadgeCount(_ count: Int) async {
        let safeCount = badgeEnabled ? max(0, count) : 0
        try? await UNUserNotificationCenter.current().setBadgeCount(safeCount)
    }

    public func clearNotificationsOnSignOut(email: String?) async {
        stopForegroundSyncLoop()
        endBackgroundGraceExecution()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
        await VipleMailAPIClient.shared.unregisterDeviceForPush(email: email)
    }

    // MARK: - 4. Génération d'Avatar Riche Rapide (< 2s max en Arrière-Plan)

    private func buildAvatarAttachment(
        senderName: String,
        senderEmail: String,
        avatarUrl: String?,
        isVip: Bool
    ) async -> UNNotificationAttachment? {
        #if canImport(UIKit)
        var renderedImage: UIImage? = nil

        if let rawUrl = avatarUrl, let url = URL(string: rawUrl) {
            var avatarReq = URLRequest(url: url)
            avatarReq.timeoutInterval = 2.0 // Timeout court pour ne jamais bloquer BGAppRefreshTask
            if let (data, resp) = try? await URLSession.shared.data(for: avatarReq),
               let http = resp as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let downloaded = UIImage(data: data) {
                renderedImage = downloaded
            }
        }

        if renderedImage == nil {
            let size = CGSize(width: 128, height: 128)
            let renderer = UIGraphicsImageRenderer(size: size)
            let clean = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
            let src = clean.isEmpty ? senderEmail : clean
            let parts = src.split(separator: " ").filter { !$0.isEmpty }
            let initials = parts.count >= 2
                ? "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
                : String(src.prefix(2)).uppercased()

            renderedImage = renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size)
                let bg = isVip
                    ? UIColor(red: 0.85, green: 0.47, blue: 0.02, alpha: 1.0)
                    : UIColor(red: 0.08, green: 0.34, blue: 0.88, alpha: 1.0)
                bg.setFill()
                UIBezierPath(ovalIn: rect).fill()

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 48, weight: .heavy),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let textSize = initials.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: 0,
                    y: (size.height - textSize.height) / 2.0,
                    width: size.width,
                    height: textSize.height
                )
                initials.draw(in: textRect, withAttributes: attrs)
            }
        }

        guard let pngData = renderedImage?.pngData() else { return nil }
        let fileUrl = FileManager.default.temporaryDirectory
            .appendingPathComponent("vm-avatar-\(UUID().uuidString.prefix(10)).png")
        do {
            try pngData.write(to: fileUrl, options: .atomic)
            return try UNNotificationAttachment(identifier: "avatar", url: fileUrl, options: nil)
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    // MARK: - 5. UNUserNotificationCenterDelegate (Swift 6 Strict Concurrency Safe)

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let messageId = notification.request.content.userInfo["messageId"] as? String
        let chatSessionId = notification.request.content.userInfo["chatSessionId"] as? String
        return await MainActor.run {
            if let messageId,
               !messageId.hasPrefix("test-"),
               self.attachedViewModel?.openedMessage?.id == messageId {
                return []
            }
            if let chatSessionId,
               !chatSessionId.isEmpty,
               self.attachedViewModel?.openedChatSession?.id == chatSessionId {
                return []
            }
            var opts: UNNotificationPresentationOptions = [.banner, .list]
            if self.soundEnabled {
                opts.insert(.sound)
            }
            if self.badgeEnabled {
                opts.insert(.badge)
            }
            return opts
        }
    }

    nonisolated public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionId = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        let messageId = (userInfo["messageId"] as? String) ?? ""
        let senderEmail = (userInfo["senderEmail"] as? String) ?? ""
        let subject = (userInfo["subject"] as? String) ?? ""
        let threadId = (userInfo["threadId"] as? String) ?? ""
        let mailboxEmail = (userInfo["mailboxEmail"] as? String) ?? ""
        let isChatMessage = (userInfo["isChatMessage"] as? Bool) ?? false
        let chatSessionId = (userInfo["chatSessionId"] as? String) ?? ""
        let replyText = (response as? UNTextInputNotificationResponse)?.userText

        await handleNotificationInteraction(
            actionIdentifier: actionId,
            messageId: messageId,
            senderEmail: senderEmail,
            subject: subject,
            threadId: threadId,
            mailboxEmail: mailboxEmail,
            isChatMessage: isChatMessage,
            chatSessionId: chatSessionId,
            replyText: replyText
        )
    }

    private func handleNotificationInteraction(
        actionIdentifier: String,
        messageId: String,
        senderEmail: String,
        subject: String,
        threadId: String,
        mailboxEmail: String,
        isChatMessage: Bool = false,
        chatSessionId: String = "",
        replyText: String?
    ) async {
        guard !messageId.isEmpty, !messageId.hasPrefix("test-") else { return }

        await AppAttestManager.shared.ensureBackgroundDpopKeyMigrated()
        if VipleMailAPIClient.shared.authToken == nil,
           let savedTok = defaults.string(forKey: savedTokenKey),
           !savedTok.isEmpty {
            VipleMailAPIClient.shared.authToken = savedTok
        }

        let targetEmail = !mailboxEmail.isEmpty
            ? mailboxEmail
            : resolvedOwnerMailboxEmail()
        let targetCid = attachedViewModel?.currentCid ?? defaults.string(forKey: savedCidKey)

        if isChatMessage || !chatSessionId.isEmpty {
            let sid = !chatSessionId.isEmpty ? chatSessionId : threadId
            switch actionIdentifier {
            case Self.actionMarkRead:
                if !targetEmail.isEmpty, !sid.isEmpty {
                    await VipleMailAPIClient.shared.markChatSessionRead(sessionId: sid, email: targetEmail, cid: targetCid)
                    await attachedViewModel?.refreshChatSessions()
                }
            case Self.actionReply:
                let cleanReply = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanReply.isEmpty, !senderEmail.isEmpty, !targetEmail.isEmpty {
                    _ = try? await VipleMailAPIClient.shared.sendChatMessage(
                        senderEmail: targetEmail,
                        senderCid: targetCid,
                        recipientEmail: senderEmail,
                        bodyText: cleanReply,
                        attachments: []
                    )
                    if !sid.isEmpty {
                        await VipleMailAPIClient.shared.markChatSessionRead(sessionId: sid, email: targetEmail, cid: targetCid)
                    }
                    if let vm = attachedViewModel {
                        vm.showToast("Réponse envoyée dans le Chat à \(senderEmail)")
                        await vm.refreshChatSessions()
                        if vm.openedChatSession?.id == sid {
                            await vm.reloadActiveChatMessages(silent: true)
                        }
                    }
                } else if let vm = attachedViewModel, !sid.isEmpty {
                    await vm.openChatSessionFromNotification(sessionId: sid, peerEmail: senderEmail)
                }
            case Self.actionTrash:
                if !targetEmail.isEmpty, !sid.isEmpty {
                    try? await VipleMailAPIClient.shared.deleteChatSession(sessionId: sid, email: targetEmail, cid: targetCid)
                    await attachedViewModel?.refreshChatSessions()
                }
            default:
                if let vm = attachedViewModel, !sid.isEmpty {
                    await vm.openChatSessionFromNotification(sessionId: sid, peerEmail: senderEmail)
                }
            }
            return
        }

        switch actionIdentifier {
        case Self.actionMarkRead:
            if let vm = attachedViewModel {
                await vm.performMessageAction(messageIds: [messageId], action: "mark_read")
            } else if !targetEmail.isEmpty {
                _ = try? await VipleMailAPIClient.shared.postRaw("/messages/action", body: [
                    "email": targetEmail,
                    "cid": targetCid ?? "",
                    "messageIds": [messageId],
                    "action": "mark_read"
                ])
                _ = await performNotificationPollCycle(isBackground: true)
            }

        case Self.actionArchive:
            if let vm = attachedViewModel {
                await vm.performMessageAction(messageIds: [messageId], action: "archive", toast: "Courrier archivé")
            } else if !targetEmail.isEmpty {
                _ = try? await VipleMailAPIClient.shared.postRaw("/messages/action", body: [
                    "email": targetEmail,
                    "cid": targetCid ?? "",
                    "messageIds": [messageId],
                    "action": "archive"
                ])
                _ = await performNotificationPollCycle(isBackground: true)
            }

        case Self.actionTrash:
            if let vm = attachedViewModel {
                await vm.performMessageAction(messageIds: [messageId], action: "trash", toast: "Courrier déplacé dans la Corbeille")
            } else if !targetEmail.isEmpty {
                _ = try? await VipleMailAPIClient.shared.postRaw("/messages/action", body: [
                    "email": targetEmail,
                    "cid": targetCid ?? "",
                    "messageIds": [messageId],
                    "action": "trash"
                ])
                _ = await performNotificationPollCycle(isBackground: true)
            }

        case Self.actionReply:
            let cleanReply = (replyText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanReply.isEmpty, !senderEmail.isEmpty, !targetEmail.isEmpty {
                let reSubj = subject.lowercased().hasPrefix("re:") ? subject : "Re: \(subject)"
                _ = try? await VipleMailAPIClient.shared.postRaw("/send", body: [
                    "senderEmail": targetEmail,
                    "senderCid": targetCid ?? "",
                    "to": senderEmail,
                    "cc": "",
                    "bcc": "",
                    "subject": reSubj,
                    "bodyText": cleanReply,
                    "priority": "Normal",
                    "threadId": threadId,
                    "isDraft": false,
                    "attachments": []
                ])
                _ = try? await VipleMailAPIClient.shared.postRaw("/messages/action", body: [
                    "email": targetEmail,
                    "cid": targetCid ?? "",
                    "messageIds": [messageId],
                    "action": "mark_read"
                ])
                if let vm = attachedViewModel {
                    vm.showToast("Réponse envoyée à \(senderEmail)")
                    await vm.refreshBootstrap()
                }
            } else if let vm = attachedViewModel {
                await vm.openMessageByIdFromNotification(messageId, presentReplyComposer: true)
            }

        case UNNotificationDefaultActionIdentifier:
            if let vm = attachedViewModel {
                await vm.openMessageByIdFromNotification(messageId, presentReplyComposer: false)
            } else {
                defaults.set(messageId, forKey: "viple.mail.ios.pendingOpenMsgId")
            }

        default:
            break
        }
    }
}
