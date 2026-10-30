import Foundation
import SwiftUI

// MARK: - ViewModel Principal « Viple Mail » (100 % connecté au SSO Viple Live ID & SQL Server VipleLive)

@MainActor
public final class VipleMailViewModel: ObservableObject {
    // Navigation & Onglets
    @Published public var selectedTab: Int = 0 // 0: Boîte, 1: Dossiers, 2: Contacts VIP, 3: Réglages
    @Published public var activeFolderId: String = "Inbox"
    @Published public var focusedInboxSegment: Int = 0 // 0: Prioritaire (Focused), 1: Autres
    @Published public var searchQuery: String = ""
    @Published public var activeFilterChip: MailFilterChip = .all

    // Mode Sélection Multiple
    @Published public var isSelectionMode: Bool = false
    @Published public var selectedMessageIds: Set<String> = []

    // Compositeur & Feuilles Modales
    @Published public var activeComposeMode: MailComposeMode? = nil
    @Published public var isShowingComposeSheet: Bool = false
    @Published public var isShowingCreateFolderSheet: Bool = false
    @Published public var isShowingAddContactSheet: Bool = false

    // État Réseau & Notifications UI
    @Published public var isInitialBootstrapping: Bool = true
    @Published public var isLoading: Bool = false
    @Published public var isSendingMail: Bool = false
    @Published public var activeToastMessage: String? = nil
    @Published public var authErrorMessage: String? = nil
    @Published public var applePasswordSetupNotice: String? = nil

    // Onboarding Sign in with Apple (@viplemail.fr obligatoire)
    @Published public var pendingAppleOnboardingUserId: String? = nil
    @Published public var pendingAppleOnboardingEmail: String? = nil
    @Published public var pendingAppleSuggestedFirstName: String = ""
    @Published public var pendingAppleSuggestedLastName: String = ""

    // SSO Inter-Applications (Partagé avec Livria Store, Livria Social, Livria Marketplace & Viple & Moi)
    @Published public var detectedCrossAppAccount: VipleCrossAppAccount? = nil
    @Published public var isShowingCrossAppSSOPrompt: Bool = false
    @Published public var isAcceptingCrossAppSSO: Bool = false

    // Données Réelles Synchronisées (Zéro Donnée de Démo)
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: VipleMailUser? = nil
    @Published public var mailboxQuota: VipleMailboxQuota? = nil
    @Published public var folders: [VipleMailFolderSummary] = []
    @Published public var messages: [VipleMailMessage] = []
    @Published public var contacts: [VipleMailContact] = []
    @Published public var settings: VipleMailSettings = VipleMailSettings()
    @Published public var lastDiagnosticsPing: VipleMailDiagnosticsPing? = nil

    // Conversation ouverte
    @Published public var activeThreadMessages: [VipleMailMessage] = []
    @Published public var isReadingMessage: Bool = false
    @Published public var openedMessage: VipleMailMessage? = nil

    public func openMessage(_ msg: VipleMailMessage) {
        self.openedMessage = msg
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            self.isReadingMessage = true
        }
    }

    public func closeMessage() {
        self.openedMessage = nil
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            self.isReadingMessage = false
        }
    }

    public func resolveAvatarUrl(for email: String, explicitUrl: String? = nil) -> String? {
        if let exp = explicitUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty {
            return exp
        }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        if let u = currentUser,
           (u.email.lowercased() == clean || u.primaryAddress.lowercased() == clean),
           let uAv = u.avatarUrl, !uAv.isEmpty {
            return uAv
        }
        if let c = contacts.first(where: { $0.contactEmail.lowercased() == clean }),
           !c.avatarUrl.isEmpty {
            return c.avatarUrl
        }
        if let m = messages.first(where: { $0.senderEmail.lowercased() == clean && !($0.senderAvatarUrl ?? "").isEmpty }) {
            return m.senderAvatarUrl
        }
        return nil
    }

    private let defaults = UserDefaults.standard
    private let sharedGroupDefaults = UserDefaults(suiteName: "group.store.livria.shared")
    private let savedEmailKey = "viple.mail.ios.savedEmail.v1"
    private let savedCidKey = "viple.mail.ios.savedCid.v1"

    public init() {
        let savedEmail = defaults.string(forKey: savedEmailKey)
        let savedCid = defaults.string(forKey: savedCidKey)

        if let savedEmail, !savedEmail.isEmpty {
            self.isAuthenticated = true
        }

        Task {
            async let splashDelay: Void = {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
            }()
            if let savedEmail, !savedEmail.isEmpty {
                await refreshBootstrap(email: savedEmail, cid: savedCid)
            } else {
                await checkCrossAppVipleAccount()
            }
            _ = await splashDelay
            withAnimation(.easeInOut(duration: 0.4)) {
                self.isInitialBootstrapping = false
            }
        }
    }

    public var currentEmail: String {
        currentUser?.primaryAddress ?? defaults.string(forKey: savedEmailKey) ?? ""
    }

    public var currentCid: String? {
        currentUser?.cid ?? defaults.string(forKey: savedCidKey)
    }

    public var unreadInboxCount: Int {
        folders.first(where: { $0.id == "Inbox" })?.unreadCount
            ?? messages.filter { $0.folder == "Inbox" && !$0.isRead }.count
    }

    public var activeFolderTitle: String {
        if let found = folders.first(where: { $0.id.lowercased() == activeFolderId.lowercased() }) {
            return found.name
        }
        switch activeFolderId {
        case "Inbox": return "Boîte de réception"
        case "VIP": return "Contacts VIP"
        case "Starred": return "Favoris & Suivis"
        case "Unread": return "Non lus"
        case "Sent": return "Messages envoyés"
        case "Drafts": return "Brouillons"
        case "Archive": return "Archives"
        case "Spam": return "Indésirables"
        case "Trash": return "Corbeille"
        default: return activeFolderId
        }
    }

    /// Messages filtrés selon le dossier actif, l'onglet Prioritaire/Autres, les puces de filtre et la recherche
    public var displayedMessages: [VipleMailMessage] {
        var list: [VipleMailMessage]

        switch activeFolderId {
        case "Starred":
            list = messages.filter { $0.isStarred && $0.folder != "Trash" && $0.folder != "Spam" }
        case "Unread":
            list = messages.filter { !$0.isRead && $0.folder != "Trash" && $0.folder != "Spam" }
        case "VIP":
            list = messages.filter { $0.isVipSender && $0.folder != "Trash" && $0.folder != "Spam" }
        default:
            list = messages.filter { $0.folder.caseInsensitiveCompare(activeFolderId) == .orderedSame }
        }

        // Séparation Prioritaire / Autres uniquement dans la Boîte de réception lorsque Focused Inbox est activé
        if activeFolderId == "Inbox" && settings.focusedInboxEnabled && activeFilterChip == .all && searchQuery.isEmpty {
            if focusedInboxSegment == 0 {
                list = list.filter { $0.category.lowercased() == "focused" || $0.isVipSender || $0.isHighPriority || $0.isPinned }
            } else {
                list = list.filter { $0.category.lowercased() != "focused" && !$0.isVipSender && !$0.isHighPriority && !$0.isPinned }
            }
        }

        switch activeFilterChip {
        case .all:
            break
        case .unread:
            list = list.filter { !$0.isRead }
        case .starred:
            list = list.filter { $0.isStarred }
        case .vip:
            list = list.filter { $0.isVipSender }
        case .attachments:
            list = list.filter { $0.hasAttachments }
        case .highPriority:
            list = list.filter { $0.isHighPriority }
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !trimmedQuery.isEmpty {
            list = list.filter { m in
                m.subject.lowercased().contains(trimmedQuery) ||
                m.senderName.lowercased().contains(trimmedQuery) ||
                m.senderEmail.lowercased().contains(trimmedQuery) ||
                m.recipientEmail.lowercased().contains(trimmedQuery) ||
                m.snippet.lowercased().contains(trimmedQuery) ||
                m.plainBodyText.lowercased().contains(trimmedQuery)
            }
        }

        return list.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.receivedAt > rhs.receivedAt
        }
    }

    public var pinnedDisplayedMessages: [VipleMailMessage] {
        displayedMessages.filter { $0.isPinned }
    }

    public var unpinnedDisplayedMessages: [VipleMailMessage] {
        displayedMessages.filter { !$0.isPinned }
    }

    public func showToast(_ text: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            activeToastMessage = text
        }
        Task {
            try? await Task.sleep(nanoseconds: 3_200_000_000)
            if activeToastMessage == text {
                withAnimation {
                    activeToastMessage = nil
                }
            }
        }
    }

    // MARK: - 1. Synchronisation Bootstrap avec SQL Server VipleLive

    public func refreshBootstrap(email: String? = nil, cid: String? = nil) async {
        let targetEmail = email ?? defaults.string(forKey: savedEmailKey)
        let targetCid = cid ?? defaults.string(forKey: savedCidKey)
        guard let targetEmail, !targetEmail.isEmpty else {
            self.isAuthenticated = false
            return
        }

        do {
            let res = try await VipleMailAPIClient.shared.fetchBootstrap(
                email: targetEmail,
                cid: targetCid,
                folder: activeFolderId
            )
            if res.isAuthenticated, let user = res.user {
                self.isAuthenticated = true
                self.currentUser = user
                self.mailboxQuota = res.mailbox
                self.folders = res.folders ?? []
                self.messages = res.messages ?? []
                self.contacts = res.contacts ?? []
                if let srvSettings = res.settings {
                    self.settings = srvSettings
                }
                defaults.set(user.primaryAddress, forKey: savedEmailKey)
                if let c = user.cid, !c.isEmpty {
                    defaults.set(c, forKey: savedCidKey)
                }
                saveLocalCrossAppSession(user: user)
            } else {
                self.isAuthenticated = false
            }
        } catch {
            print("[VipleMail] Erreur bootstrap: \(error.localizedDescription)")
        }
    }

    // MARK: - 2. Connexion & Inscription Viple Live ID + Sign in with Apple + Cross-App SSO

    public func signIn(email: String, password: String) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }

        do {
            let res = try await VipleMailAPIClient.shared.loginVipleLiveID(email: email, password: password)
            if res.requiresApplePasswordSetup == true {
                applePasswordSetupNotice = res.error ?? "Vous vous êtes inscrit avec Apple. Un lien de création de mot de passe a été envoyé sur votre boîte iCloud (\(res.icloudEmail ?? "iCloud"))."
                return
            }
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Identifiant Viple Live ID ou mot de passe incorrect."
                return
            }
            await finalizeAuthenticatedSession(user: user, welcomeToast: "Connecté à votre boîte \(user.primaryAddress)")
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func registerAccount(
        emailMode: String,
        emailUser: String,
        customEmail: String,
        password: String,
        firstName: String,
        lastName: String,
        displayName: String
    ) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }

        do {
            let res = try await VipleMailAPIClient.shared.registerVipleLiveID(
                emailMode: emailMode,
                emailUser: emailUser,
                customEmail: customEmail,
                password: password,
                firstName: firstName,
                lastName: lastName,
                displayName: displayName
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Impossible de créer la boîte @viplemail.fr."
                return
            }
            await finalizeAuthenticatedSession(user: user, welcomeToast: "Bienvenue \(user.displayName) ! Votre boîte \(user.primaryAddress) est active.")
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func handleSignInWithApple(
        appleUserId: String,
        identityToken: String?,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async {
        isLoading = true
        authErrorMessage = nil
        applePasswordSetupNotice = nil
        defer { isLoading = false }

        do {
            let res = try await VipleMailAPIClient.shared.signInWithApple(
                appleUserId: appleUserId,
                identityToken: identityToken,
                email: email,
                firstName: firstName,
                lastName: lastName
            )
            if res.needsOnboarding == true {
                self.pendingAppleOnboardingUserId = res.appleUserId ?? appleUserId
                self.pendingAppleOnboardingEmail = res.appleEmail ?? email
                self.pendingAppleSuggestedFirstName = res.suggestedFirstName ?? firstName ?? ""
                self.pendingAppleSuggestedLastName = res.suggestedLastName ?? lastName ?? ""
                return
            }
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Connexion avec Apple indisponible."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            await finalizeAuthenticatedSession(user: user, welcomeToast: "Connecté avec Apple sur \(user.primaryAddress)")
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func completeAppleOnboarding(
        firstName: String,
        lastName: String,
        displayName: String,
        vipleMailUser: String
    ) async {
        guard let appleId = pendingAppleOnboardingUserId, !appleId.isEmpty else { return }
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }

        do {
            let res = try await VipleMailAPIClient.shared.completeAppleSignup(
                appleUserId: appleId,
                appleEmail: pendingAppleOnboardingEmail,
                firstName: firstName,
                lastName: lastName,
                displayName: displayName,
                vipleMailUser: vipleMailUser
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Impossible de finaliser la création de votre adresse @viplemail.fr."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            await finalizeAuthenticatedSession(user: user, welcomeToast: "Votre boîte \(user.primaryAddress) est créée et liée à Apple !")
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func linkAppleToExistingAccount(email: String, password: String) async {
        guard let appleId = pendingAppleOnboardingUserId, !appleId.isEmpty else { return }
        isLoading = true
        authErrorMessage = nil
        defer { isLoading = false }

        do {
            let res = try await VipleMailAPIClient.shared.linkAppleToExistingAccount(
                appleUserId: appleId,
                appleEmail: pendingAppleOnboardingEmail,
                email: email,
                password: password
            )
            guard res.ok, let user = res.user else {
                authErrorMessage = res.error ?? "Identifiant Viple Live ID ou mot de passe incorrect."
                return
            }
            self.pendingAppleOnboardingUserId = nil
            await finalizeAuthenticatedSession(user: user, welcomeToast: "Compte Viple Live ID (\(user.primaryAddress)) associé à Apple !")
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func finalizeAuthenticatedSession(user: VipleMailUser, welcomeToast: String) async {
        self.currentUser = user
        self.isAuthenticated = true
        defaults.set(user.primaryAddress, forKey: savedEmailKey)
        if let cid = user.cid, !cid.isEmpty {
            defaults.set(cid, forKey: savedCidKey)
        }
        saveLocalCrossAppSession(user: user)
        await VipleMailAPIClient.shared.announceCrossAppSession(email: user.primaryAddress, cid: user.cid)
        await refreshBootstrap(email: user.primaryAddress, cid: user.cid)
        showToast(welcomeToast)
    }

    public func signOut() {
        defaults.removeObject(forKey: savedEmailKey)
        defaults.removeObject(forKey: savedCidKey)
        sharedGroupDefaults?.removeObject(forKey: "viple.crossapp.mail.account")
        isAuthenticated = false
        currentUser = nil
        mailboxQuota = nil
        folders = []
        messages = []
        contacts = []
        selectedMessageIds.removeAll()
        isSelectionMode = false
        selectedTab = 0
        showToast("Vous êtes déconnecté de Viple Mail.")
        Task {
            await VipleMailAPIClient.shared.clearCrossAppSession()
            await checkCrossAppVipleAccount()
        }
    }

    // MARK: - 2b. SSO Automatique Inter-Applications (App Group + Serveur Viple)

    private func saveLocalCrossAppSession(user: VipleMailUser) {
        let snapshot = VipleCrossAppAccount(
            sourceApp: "Viple Mail",
            targetApp: "Viple Mail",
            userId: 1,
            email: user.primaryAddress,
            displayName: user.displayName,
            firstName: user.firstName,
            lastName: user.lastName,
            cid: user.cid,
            avatarUrl: user.avatarUrl,
            isLivriaPlus: false
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            sharedGroupDefaults?.set(data, forKey: "viple.crossapp.mail.account")
        }
    }

    public func checkCrossAppVipleAccount() async {
        var candidate: VipleCrossAppAccount? = await VipleMailAPIClient.shared.discoverCrossAppAccount()

        if candidate == nil {
            for key in ["viple.crossapp.store.account", "viple.crossapp.social.account", "viple.crossapp.marketplace.account"] {
                if let data = sharedGroupDefaults?.data(forKey: key),
                   let decoded = try? JSONDecoder().decode(VipleCrossAppAccount.self, from: data),
                   !decoded.email.isEmpty,
                   !decoded.email.lowercased().hasSuffix("@guest.livria.store") {
                    candidate = decoded
                    break
                }
            }
        }

        guard let found = candidate,
              !found.email.isEmpty,
              !found.email.lowercased().hasSuffix("@guest.livria.store") else {
            return
        }

        if isAuthenticated, let current = currentUser,
           current.primaryAddress.lowercased() == found.email.lowercased() {
            return
        }

        self.detectedCrossAppAccount = found
        if !isAuthenticated {
            self.isShowingCrossAppSSOPrompt = true
        }
    }

    public func acceptDetectedCrossAppAccount() async {
        guard let account = detectedCrossAppAccount else { return }
        isAcceptingCrossAppSSO = true
        defer { isAcceptingCrossAppSSO = false }

        do {
            let res = try await VipleMailAPIClient.shared.acceptCrossAppAccount(email: account.email, cid: account.cid)
            if res.ok, let user = res.user {
                self.isShowingCrossAppSSOPrompt = false
                await finalizeAuthenticatedSession(user: user, welcomeToast: "Connecté via SSO Viple Live ID (\(user.primaryAddress))")
            }
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    // MARK: - 3. Lecture de Message, Fil de Conversation & Actions Rapides

    public func openMessageAndLoadThread(_ message: VipleMailMessage) async {
        if !message.isRead {
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx].isRead = true
            }
        }
        self.activeThreadMessages = messages
            .filter { !$0.threadId.isEmpty && $0.threadId == message.threadId }
            .sorted { $0.receivedAt < $1.receivedAt }
        if self.activeThreadMessages.isEmpty {
            self.activeThreadMessages = [message]
        }

        guard !currentEmail.isEmpty else { return }
        do {
            let detail = try await VipleMailAPIClient.shared.fetchMessageDetail(
                messageId: message.id,
                email: currentEmail,
                cid: currentCid
            )
            if detail.ok {
                self.activeThreadMessages = detail.thread
                if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                    messages[idx] = detail.message
                }
            }
        } catch { }
    }

    public func performMessageAction(
        messageIds: [String],
        action: String,
        targetFolder: String? = nil,
        targetCategory: String? = nil,
        toast: String? = nil
    ) async {
        guard !currentEmail.isEmpty, !messageIds.isEmpty else { return }

        // Mise à jour optimiste instantanée
        let idSet = Set(messageIds)
        for idx in messages.indices where idSet.contains(messages[idx].id) {
            switch action {
            case "mark_read":
                messages[idx].isRead = true
            case "mark_unread":
                messages[idx].isRead = false
            case "toggle_read":
                messages[idx].isRead.toggle()
            case "star":
                messages[idx].isStarred = true
            case "unstar":
                messages[idx].isStarred = false
            case "toggle_star":
                messages[idx].isStarred.toggle()
            case "toggle_pin":
                messages[idx].isPinned.toggle()
            case "archive":
                messages[idx].folder = "Archive"
            case "spam":
                messages[idx].folder = "Spam"
            case "trash":
                if messages[idx].folder == "Trash" {
                    messages[idx].folder = "__DELETED__"
                } else {
                    messages[idx].folder = "Trash"
                }
            case "move":
                if let targetFolder {
                    messages[idx].folder = targetFolder
                }
            case "category":
                if let targetCategory {
                    messages[idx].category = targetCategory
                }
            case "delete", "delete_permanent":
                messages[idx].folder = "__DELETED__"
            default:
                break
            }
        }
        messages.removeAll { $0.folder == "__DELETED__" }

        if isSelectionMode {
            selectedMessageIds.removeAll()
            isSelectionMode = false
        }
        if let toast {
            showToast(toast)
        }

        do {
            var payload: [String: Any] = [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "messageIds": messageIds,
                "action": action
            ]
            if let targetFolder { payload["targetFolder"] = targetFolder }
            if let targetCategory { payload["targetCategory"] = targetCategory }
            _ = try await VipleMailAPIClient.shared.postRaw("/messages/action", body: payload)
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func executeConfiguredSwipe(for message: VipleMailMessage, isRightSwipe: Bool) async {
        let actionCode = isRightSwipe ? settings.swipeRightAction : settings.swipeLeftAction
        switch actionCode {
        case "ToggleRead":
            await performMessageAction(
                messageIds: [message.id],
                action: "toggle_read",
                toast: message.isRead ? "Marqué comme non lu" : "Marqué comme lu"
            )
        case "Star":
            await performMessageAction(
                messageIds: [message.id],
                action: "toggle_star",
                toast: message.isStarred ? "Retiré des favoris" : "Ajouté aux favoris ⭐"
            )
        case "Pin":
            await performMessageAction(
                messageIds: [message.id],
                action: "toggle_pin",
                toast: message.isPinned ? "Désépinglé" : "Message épinglé 📌"
            )
        case "Archive":
            await performMessageAction(
                messageIds: [message.id],
                action: "archive",
                toast: "Message archivé"
            )
        case "Spam":
            await performMessageAction(
                messageIds: [message.id],
                action: "spam",
                toast: "Déplacé dans Indésirables"
            )
        default:
            await performMessageAction(
                messageIds: [message.id],
                action: "trash",
                toast: "Déplacé dans la Corbeille"
            )
        }
    }

    public func emptyFolder(_ folderId: String) async {
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/folders/empty", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "folder": folderId
            ])
            showToast((res["message"] as? String) ?? "Dossier vidé.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func markCurrentFolderAllRead() async {
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/folders/mark-all-read", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "folder": activeFolderId
            ])
            showToast((res["message"] as? String) ?? "Tous les messages ont été marqués comme lus.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 4. Envoi de Courrier, Brouillons & Upload de Pièces Jointes

    public func presentComposer(_ mode: MailComposeMode) {
        self.activeComposeMode = mode
        self.isShowingComposeSheet = true
    }

    public func sendOrSaveMail(
        to: String,
        cc: String,
        bcc: String,
        subject: String,
        bodyText: String,
        bodyHtml: String?,
        priority: String,
        threadId: String?,
        replyToMessageId: String?,
        draftId: String?,
        isDraft: Bool,
        attachments: [VipleMailAttachment]
    ) async -> Bool {
        guard !currentEmail.isEmpty else { return false }
        isSendingMail = true
        defer { isSendingMail = false }

        let encodedAttachments: [[String: Any]] = attachments.map { att in
            [
                "id": att.id,
                "fileName": att.fileName,
                "mimeType": att.mimeType,
                "sizeBytes": att.sizeBytes,
                "url": att.url
            ]
        }

        var payload: [String: Any] = [
            "senderEmail": currentEmail,
            "senderCid": currentCid ?? "",
            "to": to,
            "cc": cc,
            "bcc": bcc,
            "subject": subject,
            "bodyText": bodyText,
            "priority": priority,
            "isDraft": isDraft,
            "attachments": encodedAttachments
        ]
        if let bodyHtml, !bodyHtml.isEmpty { payload["bodyHtml"] = bodyHtml }
        if let threadId, !threadId.isEmpty { payload["threadId"] = threadId }
        if let replyToMessageId, !replyToMessageId.isEmpty { payload["replyToMessageId"] = replyToMessageId }
        if let draftId, !draftId.isEmpty { payload["draftId"] = draftId }

        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/send", body: payload)
            let msg = (res["message"] as? String) ?? (isDraft ? "Brouillon enregistré." : "Courrier envoyé !")
            showToast(msg)
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func uploadAttachment(fileName: String, mimeType: String, data: Data) async -> VipleMailAttachment? {
        guard !currentEmail.isEmpty else { return nil }
        do {
            let b64 = data.base64EncodedString()
            let res = try await VipleMailAPIClient.shared.postRaw("/attachments/upload", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "fileName": fileName,
                "mimeType": mimeType,
                "base64Data": b64
            ])
            if let attDict = res["attachment"] as? [String: Any] {
                let id = (attDict["id"] as? String) ?? UUID().uuidString
                let fn = (attDict["fileName"] as? String) ?? fileName
                let mime = (attDict["mimeType"] as? String) ?? mimeType
                let sz = (attDict["sizeBytes"] as? Int64) ?? Int64(data.count)
                let url = (attDict["url"] as? String) ?? ""
                return VipleMailAttachment(id: id, fileName: fn, mimeType: mime, sizeBytes: sz, url: url)
            }
        } catch {
            showToast("Erreur d'envoi de pièce jointe : \(error.localizedDescription)")
        }
        return nil
    }

    // MARK: - 5. Dossiers Personnalisés, Contacts VIP & Préférences

    public func createCustomFolder(name: String) async -> Bool {
        guard !currentEmail.isEmpty else { return false }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/folders/create", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "folderName": name
            ])
            showToast((res["message"] as? String) ?? "Dossier créé.")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func deleteCustomFolder(name: String) async {
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/folders/delete", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "folderName": name
            ])
            if activeFolderId == name {
                activeFolderId = "Inbox"
            }
            showToast((res["message"] as? String) ?? "Dossier supprimé.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func saveContact(
        contactId: String? = nil,
        email: String,
        displayName: String,
        groupName: String,
        isFavorite: Bool,
        phone: String,
        company: String,
        jobTitle: String,
        notes: String
    ) async -> Bool {
        guard !currentEmail.isEmpty else { return false }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/contacts/save", body: [
                "ownerEmail": currentEmail,
                "ownerCid": currentCid ?? "",
                "contactId": contactId ?? "",
                "contactEmail": email,
                "displayName": displayName,
                "groupName": groupName,
                "isFavorite": isFavorite,
                "phone": phone,
                "company": company,
                "jobTitle": jobTitle,
                "notes": notes
            ])
            showToast((res["message"] as? String) ?? "Contact enregistré.")
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func toggleContactVip(_ contact: VipleMailContact) async {
        guard !currentEmail.isEmpty else { return }
        do {
            _ = try await VipleMailAPIClient.shared.postRaw("/contacts/toggle-vip", body: [
                "ownerEmail": currentEmail,
                "ownerCid": currentCid ?? "",
                "contactId": contact.id,
                "contactEmail": contact.contactEmail
            ])
            showToast(contact.isFavorite ? "\(contact.displayName) retiré des VIP" : "\(contact.displayName) ajouté aux Contacts VIP 👑")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func deleteContact(_ contact: VipleMailContact) async {
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/contacts/delete", body: [
                "ownerEmail": currentEmail,
                "ownerCid": currentCid ?? "",
                "contactId": contact.id,
                "contactEmail": contact.contactEmail
            ])
            showToast((res["message"] as? String) ?? "Contact supprimé.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func saveMailSettings(displayName: String? = nil, personalMessage: String? = nil) async {
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/settings/save", body: [
                "email": currentEmail,
                "cid": currentCid ?? "",
                "displayName": displayName ?? currentUser?.displayName ?? "",
                "personalMessage": personalMessage ?? currentUser?.personalMessage ?? "",
                "signatureHtml": settings.signatureHtml,
                "signatureEnabled": settings.signatureEnabled,
                "focusedInboxEnabled": settings.focusedInboxEnabled,
                "vacationEnabled": settings.vacationEnabled,
                "vacationSubject": settings.vacationSubject,
                "vacationBody": settings.vacationBody,
                "swipeRightAction": settings.swipeRightAction,
                "swipeLeftAction": settings.swipeLeftAction,
                "readReceiptsEnabled": settings.readReceiptsEnabled,
                "pushNotificationsEnabled": settings.pushNotificationsEnabled,
                "vipNotificationsOnly": settings.vipNotificationsOnly
            ])
            showToast((res["message"] as? String) ?? "Préférences enregistrées.")
            await refreshBootstrap()
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func runDiagnosticsPing() async {
        do {
            let ping = try await VipleMailAPIClient.shared.checkDiagnosticsPing()
            self.lastDiagnosticsPing = ping
            showToast("Serveur \(ping.host) opérationnel (\(ping.version))")
        } catch {
            showToast("Erreur diagnostic : \(error.localizedDescription)")
        }
    }
}
