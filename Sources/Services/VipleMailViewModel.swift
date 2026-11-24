import Foundation
import SwiftUI
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

// MARK: - ViewModel Principal « Viple Mail » (100 % connecté aux serveurs Stalwart mail.viplemail.fr, SSO Viple Live ID & Cenelis Connect)

@MainActor
public final class VipleMailViewModel: ObservableObject {
    // Navigation & Onglets
    @Published public var selectedTab: Int = 0 // 0: Boîte, 1: Chat, 2: Dossiers, 3: Contacts VIP, 4: Réglages
    @Published public var activeFolderId: String = "Inbox" {
        didSet {
            guard oldValue != activeFolderId, isAuthenticated else { return }
            Task {
                await refreshBootstrap()
            }
        }
    }
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
    @Published public var isShowingAddExternalAccountSheet: Bool = false
    @Published public var editingExternalAccount: ExternalMailAccount? = nil

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

    // SSO Inter-Applications (Partagé avec Livria Store, Livria Social, Livria Marketplace, Cenelis Workspace & Viple & Moi)
    @Published public var detectedCrossAppAccount: VipleCrossAppAccount? = nil
    @Published public var detectedWorkspaceEmailHint: String? = nil
    @Published public var isShowingCrossAppSSOPrompt: Bool = false
    @Published public var isAcceptingCrossAppSSO: Bool = false

    // Données Réelles Synchronisées (Zéro Donnée de Démo)
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: VipleMailUser? = nil
    @Published public var isApprovedCenelisAgent: Bool = false
    @Published public var isClaimingCenelisMailbox: Bool = false
    @Published public var hasDismissedCenelisInboxBanner: Bool = false
    @Published public var activeMailboxAddress: String = ""
    @Published public var availableMailboxes: [String] = []
    @Published public var externalAccounts: [ExternalMailAccount] = []
    @Published public var isExternalMailboxActive: Bool = false
    @Published public var activeExternalProviderName: String? = nil
    @Published public var isUnifiedInboxActive: Bool = false
    @Published public var isSwitchingMailbox: Bool = false
    @Published public var mailboxQuota: VipleMailboxQuota? = nil
    @Published public var folders: [VipleMailFolderSummary] = []
    @Published public var messages: [VipleMailMessage] = []
    @Published public var contacts: [VipleMailContact] = []
    @Published public var chatSessions: [VipleChatSession] = []
    @Published public var chatUnreadCount: Int = 0
    @Published public var settings: VipleMailSettings = VipleMailSettings()
    @Published public var lastDiagnosticsPing: VipleMailDiagnosticsPing? = nil
    @Published public var connectedDevices: [VipleConnectedDeviceDto] = []
    @Published public var isLoadingConnectedDevices: Bool = false
    @Published public var isShowingConnectedDevicesSheet: Bool = false
    @Published public var blockedSenders: [String] = []
    @Published public var isDeletingAccount: Bool = false

    // Accès Invité Temporaire (1h, 8h, 24h, 48h) & Intégration iMessage
    @Published public var sharedGuestMailboxes: [GuestMailboxGrant] = []
    @Published public var outgoingGuestGrants: [GuestMailboxGrant] = []
    @Published public var isGuestMailboxActive: Bool = false
    @Published public var activeGuestGrant: GuestMailboxGrant? = nil
    @Published public var isShowingGuestAccessSheet: Bool = false
    @Published public var activeIMessagePayload: IMessageComposePayload? = nil
    @Published public var lastSentDirectMailLink: DirectMailShareLink? = nil
    @Published public var pendingGuestClaimToken: String? = nil
    @Published public var pendingDirectMailToken: String? = nil
    @Published public var isCreatingIMessageLink: Bool = false
    @Published public var isProcessingGuestAction: Bool = false

    // Apparence & Mode Sombre (Automatique iOS / Clair / Sombre OLED + Rendu adaptatif des e-mails HTML)
    @Published public var appearanceMode: VipleMailAppearanceMode = .system {
        didSet {
            defaults.set(appearanceMode.rawValue, forKey: savedAppearanceModeKey)
            applyWindowInterfaceStyle()
        }
    }
    @Published public var adaptHtmlEmailsInDarkMode: Bool = true {
        didSet {
            defaults.set(adaptHtmlEmailsInDarkMode, forKey: savedAdaptHtmlDarkModeKey)
        }
    }

    public var preferredColorSchemeOverride: ColorScheme? {
        appearanceMode.preferredColorScheme
    }

    public func applyWindowInterfaceStyle() {
        #if canImport(UIKit)
        let targetStyle: UIUserInterfaceStyle
        switch appearanceMode {
        case .system: targetStyle = .unspecified
        case .light: targetStyle = .light
        case .dark: targetStyle = .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                if window.overrideUserInterfaceStyle != targetStyle {
                    UIView.transition(with: window, duration: 0.22, options: .transitionCrossDissolve) {
                        window.overrideUserInterfaceStyle = targetStyle
                    }
                }
            }
        }
        #endif
    }

    // Courrier ouvert & Discussion Chat ouverte
    @Published public var activeThreadMessages: [VipleMailMessage] = []
    @Published public var isReadingMessage: Bool = false
    @Published public var openedMessage: VipleMailMessage? = nil

    @Published public var openedChatSession: VipleChatSession? = nil
    @Published public var activeChatMessages: [VipleChatMessage] = []
    @Published public var isChatConversationOpen: Bool = false
    @Published public var isSendingChatMessage: Bool = false

    public func openMessage(_ msg: VipleMailMessage) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            self.openedMessage = msg
            self.isReadingMessage = true
        }
    }

    public func closeMessage() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            self.openedMessage = nil
            self.isReadingMessage = false
        }
    }

    public func openChatSession(_ session: VipleChatSession) {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            self.openedChatSession = session
            self.isChatConversationOpen = true
        }
    }

    public func closeChatSession() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.88)) {
            self.openedChatSession = nil
            self.activeChatMessages = []
            self.isChatConversationOpen = false
        }
    }

    public func resolveAvatarUrl(for email: String, explicitUrl: String? = nil) -> String? {
        if let exp = explicitUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !exp.isEmpty {
            return exp
        }
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty else { return nil }
        if let u = currentUser,
           (u.email.lowercased() == clean
            || u.primaryAddress.lowercased() == clean
            || (u.cenelisMailAddress?.lowercased() == clean)
            || activeMailboxAddress.lowercased() == clean),
           let uAv = u.avatarUrl, !uAv.isEmpty {
            return uAv
        }
        if let c = contacts.first(where: { $0.contactEmail.lowercased() == clean }),
           !c.avatarUrl.isEmpty {
            return c.avatarUrl
        }
        if let cs = chatSessions.first(where: { $0.peerEmail.lowercased() == clean }),
           let csAv = cs.peerAvatarUrl, !csAv.isEmpty {
            return csAv
        }
        if let m = messages.first(where: { $0.senderEmail.lowercased() == clean && !($0.senderAvatarUrl ?? "").isEmpty }) {
            return m.senderAvatarUrl
        }
        return nil
    }

    private let defaults = UserDefaults.standard
    private let sharedGroupDefaults = UserDefaults(suiteName: "group.store.livria.shared")
    private let sharedCenelisGroupDefaults = UserDefaults(suiteName: "group.com.viplenetwork.shared")
    private let savedEmailKey = "viple.mail.ios.savedEmail.v1"
    private let savedOwnerEmailKey = "viple.mail.ios.savedOwnerEmail.v1"
    private let savedCidKey = "viple.mail.ios.savedCid.v1"
    private let savedTokenKey = "viple.mail.ios.savedToken.v1"
    private let savedAppearanceModeKey = "viple.mail.ios.appearanceMode.v1"
    private let savedAdaptHtmlDarkModeKey = "viple.mail.ios.adaptHtmlDarkMode.v1"

    public init() {
        if let rawAppearance = defaults.string(forKey: savedAppearanceModeKey),
           let parsedAppearance = VipleMailAppearanceMode(rawValue: rawAppearance) {
            self.appearanceMode = parsedAppearance
        }
        if defaults.object(forKey: savedAdaptHtmlDarkModeKey) != nil {
            self.adaptHtmlEmailsInDarkMode = defaults.bool(forKey: savedAdaptHtmlDarkModeKey)
        }

        let savedEmail = defaults.string(forKey: savedEmailKey)
        let savedCid = defaults.string(forKey: savedCidKey)
        let savedToken = defaults.string(forKey: savedTokenKey)
        if let savedToken, !savedToken.isEmpty {
            VipleMailAPIClient.shared.authToken = savedToken
        }

        if let savedEmail, !savedEmail.isEmpty {
            self.activeMailboxAddress = savedEmail.lowercased()
            self.isUnifiedInboxActive = (savedEmail.lowercased() == "__all__")
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
        if !activeMailboxAddress.isEmpty {
            return activeMailboxAddress
        }
        if let mbx = mailboxQuota?.emailAddress, !mbx.isEmpty {
            return mbx
        }
        return currentUser?.primaryAddress ?? defaults.string(forKey: savedEmailKey) ?? ""
    }

    /// Adresse principale interne Viple / Cenelis du titulaire (toujours une vraie boîte hébergée, jamais `__all__` ni une boîte externe)
    public var primaryHostedEmail: String {
        if let u = currentUser {
            return u.primaryAddress.lowercased()
        }
        if let savedOwner = defaults.string(forKey: savedOwnerEmailKey), !savedOwner.isEmpty {
            return savedOwner.lowercased()
        }
        let cur = currentEmail.lowercased()
        return cur == "__all__" ? "" : cur
    }

    /// Boîtes hébergées Viple / Cenelis rattachées au compte (hors boîtes partagées en mode invité temporaire)
    public var hostedMailboxes: [String] {
        let extSet = Set(externalAccounts.map { $0.email.lowercased() })
        let guestSet = Set(sharedGuestMailboxes.map { $0.ownerMailbox.lowercased() })
        let activeGuestLower = isGuestMailboxActive ? activeMailboxAddress.lowercased() : ""
        let merged = deduplicatedMailboxes(
            [currentUser?.cenelisMailAddress, currentUser?.vipleMailAddress]
            + availableMailboxes.map { Optional($0) }
        ).filter {
            let low = $0.lowercased()
            return !extSet.contains(low) && !guestSet.contains(low) && low != activeGuestLower && low != "__all__"
        }
        if !merged.isEmpty { return merged }
        let p = primaryHostedEmail
        return p.isEmpty ? [] : [p]
    }

    /// Adresse professionnelle officielle @cenelis.com de l'agent habilité (si déjà rattachée)
    public var cenelisMailboxAddress: String? {
        if let cm = currentUser?.cenelisMailAddress?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !cm.isEmpty,
           cm.hasSuffix("@cenelis.com") {
            return cm
        }
        return hostedMailboxes.first(where: { $0.lowercased().hasSuffix("@cenelis.com") })?.lowercased()
    }

    /// Adresse @viplemail.fr rattachée au compte
    public var viplePersonalMailboxAddress: String? {
        if let vm = currentUser?.vipleMailAddress?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !vm.isEmpty,
           vm.hasSuffix("@viplemail.fr") {
            return vm
        }
        return hostedMailboxes.first(where: { $0.lowercased().hasSuffix("@viplemail.fr") })?.lowercased()
    }

    /// Identifiant local suggéré pour l'adresse @cenelis.com de l'agent
    public var suggestedCenelisLocalPart: String {
        let source = cenelisMailboxAddress ?? viplePersonalMailboxAddress ?? currentUser?.email ?? currentEmail
        let rawLocal = source.split(separator: "@").first.map(String.init) ?? ""
        let cleaned = rawLocal.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
        return cleaned.count >= 2 ? cleaned : "agent"
    }

    /// Indique s'il faut proposer le bandeau @cenelis.com en haut de la boîte de réception pour un agent Cenelis
    public var shouldShowCenelisInboxProposalBanner: Bool {
        guard isAuthenticated, isApprovedCenelisAgent, !hasDismissedCenelisInboxBanner else { return false }
        if isUnifiedInboxActive { return false }
        return !currentEmail.lowercased().hasSuffix("@cenelis.com")
    }

    public func dismissCenelisInboxProposalBanner() {
        let key = cenelisBannerDismissKey(for: primaryHostedEmail)
        defaults.set(true, forKey: key)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            hasDismissedCenelisInboxBanner = true
        }
    }

    private func cenelisBannerDismissKey(for ownerEmail: String) -> String {
        let norm = ownerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "viple.mail.ios.dismissedCenelisBanner.\(norm.isEmpty ? "default" : norm)"
    }

    /// Boîtes pouvant émettre des courriers (toutes les boîtes Viple/Cenelis + boîtes externes SMTP + boîte invitée si autorisée)
    public var sendCapableMailboxes: [String] {
        var result: [String] = []
        if isGuestMailboxActive, let grant = activeGuestGrant, grant.allowSend, !grant.isExpired() {
            let gm = grant.ownerMailbox.lowercased()
            if !gm.isEmpty {
                result.append(gm)
            }
        }
        for h in hostedMailboxes where !result.contains(h.lowercased()) {
            result.append(h.lowercased())
        }
        for ext in externalAccounts where ext.canSendSmtp && !ext.smtpHost.isEmpty {
            let em = ext.email.lowercased()
            if !result.contains(em) {
                result.append(em)
            }
        }
        return result
    }

    /// Boîte d'expédition par défaut lors de l'ouverture du compositeur
    public var defaultSendingMailbox: String {
        let cur = currentEmail.lowercased()
        if isUnifiedInboxActive || cur == "__all__" || cur.isEmpty {
            return primaryHostedEmail
        }
        if isGuestMailboxActive {
            if let grant = activeGuestGrant, grant.allowSend, !grant.isExpired() {
                return grant.ownerMailbox.lowercased()
            }
            return primaryHostedEmail
        }
        if let ext = externalAccounts.first(where: { $0.email.lowercased() == cur }) {
            return (ext.canSendSmtp && !ext.smtpHost.isEmpty) ? ext.email.lowercased() : primaryHostedEmail
        }
        return cur
    }

    public var activeMailboxDisplayLabel: String {
        if isUnifiedInboxActive || currentEmail.lowercased() == "__all__" {
            return "Toutes les boîtes"
        }
        return currentEmail
    }

    public func isInternalMailbox(_ email: String) -> Bool {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return clean.hasSuffix("@viplemail.fr")
            || clean.hasSuffix("@cenelis.com")
            || clean.hasSuffix("@viplenetwork.com")
    }

    public var isCurrentMailboxInternal: Bool {
        !isUnifiedInboxActive && !isExternalMailboxActive && isInternalMailbox(currentEmail)
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
        case "Starred", "Flagged": return "Favoris & Suivis"
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
        case "Starred", "Flagged":
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
        case .verified:
            list = list.filter { $0.shouldShowVerifiedSenderBadge }
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
                (m.effectiveVerifiedOrganization?.lowercased().contains(trimmedQuery) == true) ||
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

    // MARK: - 1. Synchronisation Bootstrap avec Stalwart Mail Server (mail.viplemail.fr)

    private func deduplicatedMailboxes(_ list: [String?]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in list {
            guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  !trimmed.isEmpty,
                  trimmed.contains("@"),
                  !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }
        return result
    }

    public func refreshBootstrap(email: String? = nil, cid: String? = nil) async {
        let targetEmail = email ?? (!activeMailboxAddress.isEmpty ? activeMailboxAddress : defaults.string(forKey: savedEmailKey))
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
            if res.sessionRevoked == true {
                handleRemoteSessionRevoked()
                return
            }
            if res.isAuthenticated, let user = res.user {
                let unified = (res.isUnifiedInbox == true) || (res.mailbox?.emailAddress.lowercased() == "__all__")
                let resolvedMailbox = unified
                    ? "__all__"
                    : ((res.mailbox?.emailAddress.isEmpty == false)
                        ? res.mailbox!.emailAddress
                        : user.primaryAddress).lowercased()

                self.isAuthenticated = true
                self.currentUser = user
                let approvedCenelis = (res.isApprovedCenelisAgent == true)
                    || (user.isApprovedCenelisAgent == true)
                    || (user.accountType?.lowercased() == "cenelis")
                    || ((user.cenelisMailAddress ?? "").lowercased().hasSuffix("@cenelis.com"))
                self.isApprovedCenelisAgent = approvedCenelis
                self.isUnifiedInboxActive = unified
                self.isExternalMailboxActive = (res.isExternalMailbox == true)
                self.isGuestMailboxActive = (res.isGuestMailbox == true)
                self.activeGuestGrant = res.activeGuestGrant
                self.activeExternalProviderName = res.externalProviderName
                self.activeMailboxAddress = resolvedMailbox
                self.mailboxQuota = res.mailbox
                self.folders = res.folders ?? []
                self.messages = res.messages ?? []
                self.contacts = res.contacts ?? []
                if let srvGuests = res.sharedGuestMailboxes {
                    self.sharedGuestMailboxes = srvGuests.filter { !$0.isExpired() }
                }
                if let srvOutGuests = res.outgoingGuestGrants {
                    self.outgoingGuestGrants = srvOutGuests.filter { !$0.isExpired() }
                }
                if let srvExternals = res.externalAccounts {
                    self.externalAccounts = srvExternals
                }
                if let srvChats = res.chatSessions {
                    self.chatSessions = srvChats
                }
                if let srvChatUnread = res.chatUnreadCount {
                    self.chatUnreadCount = srvChatUnread
                } else {
                    self.chatUnreadCount = self.chatSessions.reduce(0) { $0 + $1.unreadCount }
                }
                let extEmails = self.externalAccounts.map { Optional($0.email) }
                let ownActive = (unified || self.isGuestMailboxActive) ? nil : resolvedMailbox
                if let srvMailboxes = res.availableMailboxes, !srvMailboxes.isEmpty {
                    self.availableMailboxes = deduplicatedMailboxes(
                        srvMailboxes.map { Optional($0) } + [ownActive, user.vipleMailAddress, user.cenelisMailAddress] + extEmails
                    )
                } else {
                    self.availableMailboxes = deduplicatedMailboxes(
                        [ownActive, user.vipleMailAddress, user.cenelisMailAddress] + extEmails
                    )
                }
                if let srvSettings = res.settings {
                    self.settings = srvSettings
                }
                let ownerPrimary = user.primaryAddress.lowercased()
                self.hasDismissedCenelisInboxBanner = defaults.bool(forKey: cenelisBannerDismissKey(for: ownerPrimary))
                defaults.set(ownerPrimary, forKey: savedOwnerEmailKey)
                defaults.set(resolvedMailbox, forKey: savedEmailKey)
                if let c = user.cid, !c.isEmpty {
                    defaults.set(c, forKey: savedCidKey)
                }
                saveLocalCrossAppSession(user: user, activeEmail: ownerPrimary)
                await VipleMailNotificationManager.shared.ingestBootstrapSnapshot(
                    mailboxEmail: unified ? ownerPrimary : resolvedMailbox,
                    unreadCount: self.unreadInboxCount + self.chatUnreadCount,
                    messages: self.messages,
                    settings: self.settings
                )
                await syncDevicePushRegistration(promptIfNotDetermined: self.settings.pushNotificationsEnabled)
                if let pendingId = defaults.string(forKey: "viple.mail.ios.pendingOpenMsgId"), !pendingId.isEmpty {
                    defaults.removeObject(forKey: "viple.mail.ios.pendingOpenMsgId")
                    await openMessageByIdFromNotification(pendingId, presentReplyComposer: false)
                }
                if let pendingGuest = pendingGuestClaimToken, !pendingGuest.isEmpty {
                    pendingGuestClaimToken = nil
                    await claimAndOpenGuestMailboxFromToken(pendingGuest)
                }
                if let pendingMail = pendingDirectMailToken, !pendingMail.isEmpty {
                    pendingDirectMailToken = nil
                    await openDirectMailFromToken(pendingMail)
                }
            } else {
                self.isAuthenticated = false
            }
        } catch {
            if VipleMailAPIClient.isSessionRevokedError(error) {
                handleRemoteSessionRevoked()
                return
            }
            print("[VipleMail] Erreur bootstrap: \(error.localizedDescription)")
        }
    }

    public func switchActiveMailbox(to targetMailbox: String) async {
        let cleanTarget = targetMailbox.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTarget.isEmpty, cleanTarget != currentEmail.lowercased(), !isSwitchingMailbox else { return }

        isSwitchingMailbox = true
        defer { isSwitchingMailbox = false }

        do {
            let res = try await VipleMailAPIClient.shared.switchMailbox(
                to: cleanTarget,
                currentEmail: primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail,
                cid: currentCid
            )
            guard res.ok else {
                showToast(res.error ?? "Impossible de basculer sur la boîte \(cleanTarget).")
                return
            }

            let switchedAddress = (res.mailbox ?? res.vipleMailAddress ?? cleanTarget).lowercased()
            if let tok = res.token, !tok.isEmpty {
                defaults.set(tok, forKey: savedTokenKey)
                VipleMailAPIClient.shared.authToken = tok
            }
            if let u = res.user {
                self.currentUser = u
            }
            if let agentFlag = res.isApprovedCenelisAgent {
                self.isApprovedCenelisAgent = agentFlag
            }
            if let extList = res.externalAccounts {
                self.externalAccounts = extList
            }
            if let srvGuests = res.sharedGuestMailboxes {
                self.sharedGuestMailboxes = srvGuests.filter { !$0.isExpired() }
            }
            if let srvOutGuests = res.outgoingGuestGrants {
                self.outgoingGuestGrants = srvOutGuests.filter { !$0.isExpired() }
            }
            let guestActive = (res.isGuestMailbox == true)
            self.isGuestMailboxActive = guestActive
            self.activeGuestGrant = res.activeGuestGrant
            if let list = res.availableMailboxes, !list.isEmpty {
                let extraOwn = (switchedAddress == "__all__" || guestActive) ? nil : switchedAddress
                self.availableMailboxes = deduplicatedMailboxes(list.map { Optional($0) } + [extraOwn])
            }
            self.isUnifiedInboxActive = (res.isUnifiedInbox == true) || (switchedAddress == "__all__")
            self.isExternalMailboxActive = (res.isExternalMailbox == true)
            self.activeExternalProviderName = res.externalProviderName
            self.activeMailboxAddress = switchedAddress
            defaults.set(switchedAddress, forKey: savedEmailKey)
            self.openedMessage = nil
            self.isReadingMessage = false
            self.openedChatSession = nil
            self.activeChatMessages = []
            self.isChatConversationOpen = false
            self.selectedMessageIds.removeAll()
            self.isSelectionMode = false

            await refreshBootstrap(email: switchedAddress, cid: currentCid)
            showToast(switchedAddress == "__all__" ? "Boîte active : Toutes les boîtes" : "Boîte active : \(switchedAddress)")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    @discardableResult
    public func claimOrCustomizeCenelisMailbox(
        desiredLocalPart: String? = nil,
        switchImmediately: Bool = true
    ) async -> Bool {
        guard !isClaimingCenelisMailbox else { return false }
        isClaimingCenelisMailbox = true
        defer { isClaimingCenelisMailbox = false }

        do {
            let res = try await VipleMailAPIClient.shared.claimCenelisMailbox(
                desiredLocalPart: desiredLocalPart,
                switchActive: switchImmediately,
                ownerEmail: primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail,
                cid: currentCid
            )
            guard res.ok else {
                showToast(res.error ?? "Impossible d'activer l'adresse @cenelis.com.")
                return false
            }

            if let tok = res.token, !tok.isEmpty {
                defaults.set(tok, forKey: savedTokenKey)
                VipleMailAPIClient.shared.authToken = tok
            }
            if let u = res.user {
                self.currentUser = u
            }
            self.isApprovedCenelisAgent = true
            if let extList = res.externalAccounts {
                self.externalAccounts = extList
            }
            let claimedCenelis = (res.cenelisMailAddress ?? res.mailbox ?? "").lowercased()
            let nextActive = switchImmediately && !claimedCenelis.isEmpty
                ? claimedCenelis
                : (res.mailbox?.lowercased() ?? currentEmail.lowercased())

            if let list = res.availableMailboxes, !list.isEmpty {
                self.availableMailboxes = deduplicatedMailboxes(
                    list.map { Optional($0) } + [claimedCenelis.isEmpty ? nil : claimedCenelis]
                )
            }
            if switchImmediately && !claimedCenelis.isEmpty {
                self.isUnifiedInboxActive = false
                self.isExternalMailboxActive = false
                self.activeExternalProviderName = nil
                self.activeMailboxAddress = nextActive
                defaults.set(nextActive, forKey: savedEmailKey)
            }
            await refreshBootstrap(email: nextActive, cid: currentCid)
            showToast(res.message ?? "Votre boîte officielle \(claimedCenelis) est active.")
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
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
                authErrorMessage = res.error ?? "Identifiant Viple Live ID / Cenelis Connect ou mot de passe incorrect."
                return
            }
            let activeMbx = (res.vipleMailAddress ?? user.primaryAddress).lowercased()
            await finalizeAuthenticatedSession(
                user: user,
                token: res.token,
                preferredMailbox: activeMbx,
                availableMailboxes: res.availableMailboxes,
                welcomeToast: "Connecté à votre boîte \(activeMbx)"
            )
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
            await finalizeAuthenticatedSession(
                user: user,
                token: res.token,
                preferredMailbox: res.vipleMailAddress ?? user.primaryAddress,
                availableMailboxes: res.availableMailboxes,
                welcomeToast: "Bienvenue \(user.displayName) ! Votre boîte \(res.vipleMailAddress ?? user.primaryAddress) est active."
            )
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
            let activeMbx = (res.vipleMailAddress ?? user.primaryAddress).lowercased()
            await finalizeAuthenticatedSession(
                user: user,
                token: res.token,
                preferredMailbox: activeMbx,
                availableMailboxes: res.availableMailboxes,
                welcomeToast: "Connecté avec Apple sur \(activeMbx)"
            )
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
            let activeMbx = (res.vipleMailAddress ?? user.primaryAddress).lowercased()
            await finalizeAuthenticatedSession(
                user: user,
                token: res.token,
                preferredMailbox: activeMbx,
                availableMailboxes: res.availableMailboxes,
                welcomeToast: "Votre boîte \(activeMbx) est créée et liée à Apple !"
            )
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
            let activeMbx = (res.vipleMailAddress ?? user.primaryAddress).lowercased()
            await finalizeAuthenticatedSession(
                user: user,
                token: res.token,
                preferredMailbox: activeMbx,
                availableMailboxes: res.availableMailboxes,
                welcomeToast: "Compte Viple Live ID (\(activeMbx)) associé à Apple !"
            )
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    public func syncDevicePushRegistration(promptIfNotDetermined: Bool = false) async {
        let owner = primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return }
        await VipleMailNotificationManager.shared.syncDevicePushRegistration(
            email: owner,
            cid: currentCid,
            notificationsEnabled: settings.pushNotificationsEnabled,
            vipOnly: settings.vipNotificationsOnly,
            promptIfNotDetermined: promptIfNotDetermined
        )
    }

    private func finalizeAuthenticatedSession(
        user: VipleMailUser,
        token: String?,
        preferredMailbox: String? = nil,
        availableMailboxes: [String]? = nil,
        welcomeToast: String
    ) async {
        let previousOwner = primaryHostedEmail
        let ownerPrimary = user.primaryAddress.lowercased()
        let resolvedMbx = (preferredMailbox?.isEmpty == false ? preferredMailbox! : user.primaryAddress).lowercased()

        if !previousOwner.isEmpty && previousOwner != ownerPrimary {
            #if canImport(UIKit)
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
            #endif
        }

        self.currentUser = user
        self.isApprovedCenelisAgent = (user.isApprovedCenelisAgent == true)
            || (user.accountType?.lowercased() == "cenelis")
            || ((user.cenelisMailAddress ?? "").lowercased().hasSuffix("@cenelis.com"))
        self.activeMailboxAddress = resolvedMbx
        if let availableMailboxes, !availableMailboxes.isEmpty {
            self.availableMailboxes = deduplicatedMailboxes(availableMailboxes.map { Optional($0) } + [resolvedMbx, user.vipleMailAddress, user.cenelisMailAddress])
        } else {
            self.availableMailboxes = deduplicatedMailboxes([resolvedMbx, user.vipleMailAddress, user.cenelisMailAddress])
        }
        self.isAuthenticated = true
        self.detectedCrossAppAccount = nil
        self.isShowingCrossAppSSOPrompt = false
        defaults.set(ownerPrimary, forKey: savedOwnerEmailKey)
        defaults.set(resolvedMbx, forKey: savedEmailKey)
        if let cid = user.cid, !cid.isEmpty {
            defaults.set(cid, forKey: savedCidKey)
        }
        if let token, !token.isEmpty {
            defaults.set(token, forKey: savedTokenKey)
            VipleMailAPIClient.shared.authToken = token
        }
        saveLocalCrossAppSession(user: user, activeEmail: ownerPrimary)
        VipleMailNotificationManager.shared.attachedViewModel = self
        VipleMailNotificationManager.shared.scheduleBackgroundTasks()
        VipleMailNotificationManager.shared.startForegroundSyncLoop()
        await syncDevicePushRegistration(promptIfNotDetermined: true)
        await VipleMailAPIClient.shared.announceCrossAppSession(email: ownerPrimary, cid: user.cid)
        await refreshBootstrap(email: resolvedMbx, cid: user.cid)
        showToast(welcomeToast)
    }

    public func handleRemoteSessionRevoked() {
        let hasPersistedSession = !(defaults.string(forKey: savedEmailKey) ?? "").isEmpty
            || !(defaults.string(forKey: savedOwnerEmailKey) ?? "").isEmpty
        guard isAuthenticated || hasPersistedSession else { return }
        signOut(toastMessage: "Cet appareil a été déconnecté à distance.")
    }

    public func signOut(toastMessage: String? = nil) {
        // 1. Capture stricte de l'email propriétaire et du CID AVANT toute purge d'état
        let capturedOwner = primaryHostedEmail
        let fallbackCurrent = currentEmail.lowercased() == "__all__" ? "" : currentEmail.lowercased()
        let previousEmail = !capturedOwner.isEmpty
            ? capturedOwner
            : (!fallbackCurrent.isEmpty
                ? fallbackCurrent
                : (defaults.string(forKey: savedOwnerEmailKey) ?? defaults.string(forKey: savedEmailKey) ?? ""))
        let previousCid = currentUser?.cid ?? defaults.string(forKey: savedCidKey)

        // 2. Arrêt synchrone immédiat du polling et purge des clés background UserDefaults
        VipleMailNotificationManager.shared.purgePersistedSessionAndStopSyncImmediately()
        defaults.removeObject(forKey: savedEmailKey)
        defaults.removeObject(forKey: savedOwnerEmailKey)
        defaults.removeObject(forKey: savedCidKey)
        defaults.removeObject(forKey: savedTokenKey)
        VipleMailAPIClient.shared.authToken = nil
        sharedGroupDefaults?.removeObject(forKey: "viple.crossapp.mail.account")
        sharedCenelisGroupDefaults?.removeObject(forKey: "viple.crossapp.mail.account")

        // 3. Réinitialisation complète de la session locale
        isAuthenticated = false
        currentUser = nil
        isApprovedCenelisAgent = false
        isClaimingCenelisMailbox = false
        hasDismissedCenelisInboxBanner = false
        activeMailboxAddress = ""
        availableMailboxes = []
        externalAccounts = []
        connectedDevices = []
        sharedGuestMailboxes = []
        outgoingGuestGrants = []
        isGuestMailboxActive = false
        activeGuestGrant = nil
        isShowingGuestAccessSheet = false
        activeIMessagePayload = nil
        lastSentDirectMailLink = nil
        isExternalMailboxActive = false
        activeExternalProviderName = nil
        isUnifiedInboxActive = false
        mailboxQuota = nil
        folders = []
        messages = []
        contacts = []
        chatSessions = []
        chatUnreadCount = 0
        openedMessage = nil
        isReadingMessage = false
        openedChatSession = nil
        activeChatMessages = []
        isChatConversationOpen = false
        selectedMessageIds.removeAll()
        isSelectionMode = false
        selectedTab = 0
        showToast(toastMessage ?? "Vous êtes déconnecté de Viple Mail.")

        // 4. Désinscription push serveur, remise à zéro du badge et nettoyage SSO inter-apps
        Task {
            await VipleMailNotificationManager.shared.handleUserSignedOut(
                previousEmail: previousEmail,
                previousCid: previousCid
            )
            await VipleMailAPIClient.shared.clearCrossAppSession()
            await checkCrossAppVipleAccount()
        }
    }

    // MARK: - 2b. SSO Automatique Inter-Applications (App Group + Serveur Viple)

    private func saveLocalCrossAppSession(user: VipleMailUser, activeEmail: String? = nil) {
        let snapshot = VipleCrossAppAccount(
            sourceApp: "Viple Mail",
            targetApp: "Viple Mail",
            userId: 1,
            email: activeEmail ?? user.primaryAddress,
            displayName: user.displayName,
            firstName: user.firstName,
            lastName: user.lastName,
            cid: user.cid,
            avatarUrl: user.avatarUrl,
            isLivriaPlus: false
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            sharedGroupDefaults?.set(data, forKey: "viple.crossapp.mail.account")
            sharedCenelisGroupDefaults?.set(data, forKey: "viple.crossapp.mail.account")
        }
    }

    public func checkCrossAppVipleAccount() async {
        // Si l'application est déjà connectée à un compte, ne JAMAIS proposer de connexion automatique
        if isAuthenticated {
            self.detectedCrossAppAccount = nil
            self.detectedWorkspaceEmailHint = nil
            self.isShowingCrossAppSSOPrompt = false
            return
        }

        self.detectedWorkspaceEmailHint = VipleMailAPIClient.shared.sharedCenelisWorkspaceEmail()

        // Recherche uniquement par concordance stricte (identifiant du téléphone + adresse IP simultanément)
        let candidate: VipleCrossAppAccount? = await VipleMailAPIClient.shared.discoverCrossAppAccount()

        guard let found = candidate,
              !found.email.isEmpty,
              !found.email.lowercased().hasSuffix("@guest.livria.store") else {
            self.detectedCrossAppAccount = nil
            self.isShowingCrossAppSSOPrompt = false
            return
        }

        self.detectedCrossAppAccount = found
        self.isShowingCrossAppSSOPrompt = true
    }

    public func acceptDetectedCrossAppAccount() async {
        guard let account = detectedCrossAppAccount else { return }
        isAcceptingCrossAppSSO = true
        defer { isAcceptingCrossAppSSO = false }

        do {
            let res = try await VipleMailAPIClient.shared.acceptCrossAppAccount(email: account.email, cid: account.cid)
            if res.ok, let user = res.user {
                self.isShowingCrossAppSSOPrompt = false
                let activeMbx = (res.vipleMailAddress ?? user.primaryAddress).lowercased()
                await finalizeAuthenticatedSession(
                    user: user,
                    token: res.token,
                    preferredMailbox: activeMbx,
                    availableMailboxes: res.availableMailboxes,
                    welcomeToast: "Connecté via SSO Viple Live ID (\(activeMbx))"
                )
            }
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    // MARK: - 3. Lecture de Message, Fil de Conversation & Actions Rapides

    public func openMessageByIdFromNotification(_ messageId: String, presentReplyComposer: Bool) async {
        guard !messageId.isEmpty else { return }
        self.selectedTab = 0
        if self.activeFolderId != "Inbox" {
            self.activeFolderId = "Inbox"
        }

        if let existing = messages.first(where: { $0.id == messageId }) {
            if presentReplyComposer {
                presentComposer(.reply(existing))
            } else {
                openMessage(existing)
            }
            return
        }

        guard !currentEmail.isEmpty else { return }
        do {
            let detail = try await VipleMailAPIClient.shared.fetchMessageDetail(
                messageId: messageId,
                email: currentEmail,
                cid: currentCid
            )
            if detail.ok {
                if !messages.contains(where: { $0.id == detail.message.id }) {
                    messages.insert(detail.message, at: 0)
                }
                if presentReplyComposer {
                    presentComposer(.reply(detail.message))
                } else {
                    openMessage(detail.message)
                }
                await VipleMailNotificationManager.shared.applyAppBadgeCount(
                    settings.pushNotificationsEnabled ? unreadInboxCount : 0
                )
            }
        } catch {
            await refreshBootstrap()
        }
    }

    public func openMessageAndLoadThread(_ message: VipleMailMessage) async {
        if !message.isRead {
            if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                messages[idx].isRead = true
            }
            if let fIdx = folders.firstIndex(where: { $0.id == "Inbox" && $0.unreadCount > 0 }) {
                folders[fIdx].unreadCount = max(0, folders[fIdx].unreadCount - 1)
            }
            await VipleMailNotificationManager.shared.applyAppBadgeCount(
                settings.pushNotificationsEnabled ? unreadInboxCount : 0
            )
        }
        self.activeThreadMessages = messages
            .filter { !$0.threadId.isEmpty && $0.threadId == message.threadId }
            .sorted { $0.receivedAt < $1.receivedAt }
        if self.activeThreadMessages.isEmpty {
            self.activeThreadMessages = [message]
        }

        let msgMailbox = message.effectiveMailboxEmail(fallback: defaultSendingMailbox)
        guard !msgMailbox.isEmpty else { return }
        do {
            let detail = try await VipleMailAPIClient.shared.fetchMessageDetail(
                messageId: message.id,
                email: msgMailbox,
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

        // Regrouper les messages par boîte aux lettres source (indispensable en mode « Toutes les boîtes »)
        let idSet = Set(messageIds)
        var idsByMailbox: [String: [String]] = [:]
        let fallbackMbx = defaultSendingMailbox
        for m in messages where idSet.contains(m.id) {
            let mbx = m.effectiveMailboxEmail(fallback: fallbackMbx)
            idsByMailbox[mbx, default: []].append(m.id)
        }
        if idsByMailbox.isEmpty, !fallbackMbx.isEmpty {
            idsByMailbox[fallbackMbx] = messageIds
        }

        // Mise à jour optimiste instantanée
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
            for (mbx, idsForMbx) in idsByMailbox {
                var payload: [String: Any] = [
                    "email": mbx,
                    "cid": currentCid ?? "",
                    "messageIds": idsForMbx,
                    "action": action
                ]
                if let targetFolder { payload["targetFolder"] = targetFolder }
                if let targetCategory { payload["targetCategory"] = targetCategory }
                _ = try await VipleMailAPIClient.shared.postRaw("/messages/action", body: payload)
            }
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
        attachments: [VipleMailAttachment],
        deliveryMode: String = "mail",
        fromMailbox: String? = nil,
        disableMailRte: Bool = false
    ) async -> Bool {
        let senderMailbox = (fromMailbox?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()).flatMap { $0.isEmpty ? nil : $0 } ?? defaultSendingMailbox
        guard !senderMailbox.isEmpty else { return false }
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
            "senderEmail": senderMailbox,
            "senderCid": currentCid ?? "",
            "to": to,
            "cc": cc,
            "bcc": bcc,
            "subject": subject,
            "bodyText": bodyText,
            "priority": priority,
            "deliveryMode": deliveryMode,
            "disableMailRte": disableMailRte,
            "isDraft": isDraft,
            "attachments": encodedAttachments
        ]
        if let bodyHtml, !bodyHtml.isEmpty { payload["bodyHtml"] = bodyHtml }
        if let threadId, !threadId.isEmpty { payload["threadId"] = threadId }
        if let replyToMessageId, !replyToMessageId.isEmpty { payload["replyToMessageId"] = replyToMessageId }
        if let draftId, !draftId.isEmpty { payload["draftId"] = draftId }

        do {
            let sendRes: VipleMailSendResponse = try await VipleMailAPIClient.shared.postJSON("/send", body: payload)
            guard sendRes.ok else {
                showToast(sendRes.error ?? "Impossible d'envoyer ce courrier.")
                return false
            }
            self.lastSentDirectMailLink = sendRes.directMailLink
            let msg = sendRes.message ?? (isDraft ? "Brouillon enregistré." : "Courrier envoyé !")
            showToast(msg)
            await refreshBootstrap()
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - 4b. Sessions de Discussion Instantanée « Chat @viplemail.fr & @cenelis.com »

    public var effectiveChatMailboxEmail: String {
        let cur = currentEmail.lowercased()
        if !isUnifiedInboxActive && !isExternalMailboxActive && isInternalMailbox(cur) {
            return cur
        }
        return primaryHostedEmail
    }

    public func refreshChatSessions() async {
        let chatMbx = effectiveChatMailboxEmail
        guard !chatMbx.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.fetchChatSessions(email: chatMbx, cid: currentCid)
            if res.ok {
                self.chatSessions = res.sessions ?? []
                self.chatUnreadCount = res.chatUnreadCount ?? self.chatSessions.reduce(0) { $0 + $1.unreadCount }
                await VipleMailNotificationManager.shared.applyAppBadgeCount(
                    settings.pushNotificationsEnabled ? (unreadInboxCount + chatUnreadCount) : 0
                )
            }
        } catch { }
    }

    public func startOrOpenChat(with peerEmail: String) async {
        let cleanPeer = peerEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chatMbx = effectiveChatMailboxEmail
        guard !cleanPeer.isEmpty, !chatMbx.isEmpty else { return }

        if let existing = chatSessions.first(where: { $0.peerEmail.lowercased() == cleanPeer }) {
            self.selectedTab = 1
            openChatSession(existing)
            await reloadActiveChatMessages(silent: false)
            return
        }

        do {
            let res = try await VipleMailAPIClient.shared.fetchChatMessages(
                sessionId: nil,
                peerEmail: cleanPeer,
                email: chatMbx,
                cid: currentCid
            )
            if res.ok, let session = res.session {
                if !chatSessions.contains(where: { $0.id == session.id }) {
                    chatSessions.insert(session, at: 0)
                }
                self.activeChatMessages = res.messages ?? []
                self.selectedTab = 1
                openChatSession(session)
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func openChatSessionFromNotification(sessionId: String, peerEmail: String?) async {
        self.closeMessage()
        self.selectedTab = 1
        if let existing = chatSessions.first(where: { $0.id == sessionId }) {
            openChatSession(existing)
            await reloadActiveChatMessages(silent: false)
            return
        }
        guard !currentEmail.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.fetchChatMessages(
                sessionId: sessionId,
                peerEmail: peerEmail,
                email: currentEmail,
                cid: currentCid
            )
            if res.ok, let session = res.session {
                if !chatSessions.contains(where: { $0.id == session.id }) {
                    chatSessions.insert(session, at: 0)
                }
                self.activeChatMessages = res.messages ?? []
                openChatSession(session)
                await refreshChatSessions()
            }
        } catch { }
    }

    public func reloadActiveChatMessages(silent: Bool = false) async {
        let chatMbx = effectiveChatMailboxEmail
        guard let active = openedChatSession, !chatMbx.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.fetchChatMessages(
                sessionId: active.id,
                peerEmail: active.peerEmail,
                email: chatMbx,
                cid: currentCid
            )
            if res.ok {
                if let updatedSession = res.session {
                    self.openedChatSession = updatedSession
                    if let idx = chatSessions.firstIndex(where: { $0.id == updatedSession.id }) {
                        chatSessions[idx] = updatedSession
                    } else {
                        chatSessions.insert(updatedSession, at: 0)
                    }
                }
                if let msgs = res.messages, msgs != self.activeChatMessages {
                    self.activeChatMessages = msgs
                }
                self.chatUnreadCount = self.chatSessions.reduce(0) { $0 + $1.unreadCount }
                await VipleMailNotificationManager.shared.applyAppBadgeCount(
                    settings.pushNotificationsEnabled ? (unreadInboxCount + chatUnreadCount) : 0
                )
            }
        } catch {
            if !silent {
                showToast(error.localizedDescription)
            }
        }
    }

    @discardableResult
    public func sendChatMessage(
        to recipientEmail: String,
        text: String,
        attachments: [VipleMailAttachment] = [],
        fromMailbox: String? = nil
    ) async -> VipleChatSession? {
        let cleanRecipient = recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let explicitSender = fromMailbox?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let resolvedSender = (!explicitSender.isEmpty && isInternalMailbox(explicitSender))
            ? explicitSender
            : effectiveChatMailboxEmail
        guard !resolvedSender.isEmpty, !cleanRecipient.isEmpty, (!cleanText.isEmpty || !attachments.isEmpty) else {
            return nil
        }

        isSendingChatMessage = true
        defer { isSendingChatMessage = false }

        do {
            let res = try await VipleMailAPIClient.shared.sendChatMessage(
                senderEmail: resolvedSender,
                senderCid: currentCid,
                recipientEmail: cleanRecipient,
                bodyText: cleanText,
                attachments: attachments
            )
            guard res.ok, let session = res.session, let newMsg = res.message else {
                showToast(res.error ?? "Impossible d'envoyer le message de chat.")
                return nil
            }

            if let idx = chatSessions.firstIndex(where: { $0.id == session.id }) {
                chatSessions.remove(at: idx)
            }
            chatSessions.insert(session, at: 0)

            if openedChatSession?.id == session.id {
                self.openedChatSession = session
                if !activeChatMessages.contains(where: { $0.id == newMsg.id }) {
                    activeChatMessages.append(newMsg)
                }
            }
            return session
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    public func deleteChatSession(_ session: VipleChatSession) async {
        guard !currentEmail.isEmpty else { return }
        chatSessions.removeAll { $0.id == session.id }
        if openedChatSession?.id == session.id {
            closeChatSession()
        }
        chatUnreadCount = chatSessions.reduce(0) { $0 + $1.unreadCount }
        do {
            try await VipleMailAPIClient.shared.deleteChatSession(
                sessionId: session.id,
                email: currentEmail,
                cid: currentCid
            )
            showToast("Discussion supprimée.")
        } catch {
            showToast(error.localizedDescription)
            await refreshChatSessions()
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
        let ownerEmail = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !ownerEmail.isEmpty, ownerEmail != "__all__" else { return }
        do {
            let res = try await VipleMailAPIClient.shared.postRaw("/settings/save", body: [
                "email": ownerEmail,
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
            await VipleMailAPIClient.shared.registerDeviceForPush(
                email: ownerEmail,
                cid: currentCid,
                apnsToken: VipleMailNotificationManager.shared.apnsDeviceTokenHex,
                notificationsEnabled: settings.pushNotificationsEnabled,
                vipOnly: settings.vipNotificationsOnly
            )
            await VipleMailNotificationManager.shared.applyAppBadgeCount(
                settings.pushNotificationsEnabled ? unreadInboxCount : 0
            )
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

    public func updatePersonalImapPassword(_ newPassword: String) async -> Bool {
        let trimmed = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8 else {
            showToast("Le mot de passe IMAP/SMTP doit contenir au moins 8 caractères.")
            return false
        }
        do {
            let msg = try await VipleMailAPIClient.shared.updateImapPassword(
                password: trimmed,
                email: primaryHostedEmail,
                cid: currentCid
            )
            showToast(msg)
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - 6. Comptes E-Mail Externes (IMAP / SMTP : Gmail, Outlook, iCloud, Orange, OVH, Pro...)

    public func presentAddExternalAccountSheet(editing: ExternalMailAccount? = nil) {
        self.editingExternalAccount = editing
        self.isShowingAddExternalAccountSheet = true
    }

    public func autodiscoverExternalMail(email: String) async -> ExternalMailAutodiscoverResponse? {
        let clean = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard clean.contains("@") else { return nil }
        return try? await VipleMailAPIClient.shared.autodiscoverExternalAccount(email: clean)
    }

    public func testExternalMailConnection(
        externalEmail: String,
        imapHost: String,
        imapPort: Int,
        imapSecurity: String,
        imapUsername: String,
        imapPassword: String,
        canSendSmtp: Bool,
        smtpHost: String,
        smtpPort: Int,
        smtpSecurity: String,
        smtpUsername: String,
        smtpPassword: String
    ) async -> (ok: Bool, message: String) {
        do {
            let res = try await VipleMailAPIClient.shared.testExternalAccount(
                externalEmail: externalEmail,
                imapHost: imapHost,
                imapPort: imapPort,
                imapSecurity: imapSecurity,
                imapUsername: imapUsername,
                imapPassword: imapPassword,
                canSendSmtp: canSendSmtp,
                smtpHost: smtpHost,
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                smtpUsername: smtpUsername,
                smtpPassword: smtpPassword
            )
            if res.ok {
                return (true, res.message ?? "Connexion IMAP/SMTP vérifiée avec succès.")
            }
            return (false, res.error ?? "Échec de vérification de la boîte externe.")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func addOrUpdateExternalAccount(
        externalEmail: String,
        displayName: String,
        providerName: String?,
        colorHex: String?,
        imapHost: String,
        imapPort: Int,
        imapSecurity: String,
        imapUsername: String,
        imapPassword: String,
        canSendSmtp: Bool,
        smtpHost: String,
        smtpPort: Int,
        smtpSecurity: String,
        smtpUsername: String,
        smtpPassword: String,
        openImmediately: Bool = true
    ) async -> (ok: Bool, error: String?) {
        let owner = primaryHostedEmail
        guard !owner.isEmpty else {
            return (false, "Session Viple Mail non initialisée.")
        }

        do {
            let res = try await VipleMailAPIClient.shared.addExternalAccount(
                ownerEmail: owner,
                cid: currentCid,
                externalEmail: externalEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                providerName: providerName,
                colorHex: colorHex,
                imapHost: imapHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                imapPort: imapPort,
                imapSecurity: imapSecurity,
                imapUsername: imapUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                imapPassword: imapPassword,
                canSendSmtp: canSendSmtp,
                smtpHost: smtpHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                smtpPort: smtpPort,
                smtpSecurity: smtpSecurity,
                smtpUsername: smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines),
                smtpPassword: smtpPassword
            )

            guard res.ok else {
                return (false, res.error ?? "Impossible d'ajouter cette boîte e-mail externe.")
            }

            if let extList = res.externalAccounts {
                self.externalAccounts = extList
            }
            if let allMbx = res.availableMailboxes {
                self.availableMailboxes = deduplicatedMailboxes(allMbx.map { Optional($0) })
            }

            let target = (res.account?.email ?? externalEmail).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if openImmediately {
                self.selectedTab = 0
                self.activeFolderId = "Inbox"
                await switchActiveMailbox(to: target)
            } else {
                await refreshBootstrap()
            }
            showToast(res.message ?? "Boîte externe \(target) connectée !")
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func removeExternalAccount(_ account: ExternalMailAccount) async {
        let owner = primaryHostedEmail
        guard !owner.isEmpty else { return }

        do {
            let res = try await VipleMailAPIClient.shared.deleteExternalAccount(
                ownerEmail: owner,
                cid: currentCid,
                accountId: account.id,
                externalEmail: account.email
            )
            if res.ok {
                if let extList = res.externalAccounts {
                    self.externalAccounts = extList
                } else {
                    self.externalAccounts.removeAll { $0.id == account.id }
                }
                if let allMbx = res.availableMailboxes {
                    self.availableMailboxes = deduplicatedMailboxes(allMbx.map { Optional($0) })
                }

                let wasActive = currentEmail.lowercased() == account.email.lowercased()
                if wasActive {
                    let fallback = (res.fallbackMailbox ?? primaryHostedEmail).lowercased()
                    if let tok = res.token, !tok.isEmpty {
                        defaults.set(tok, forKey: savedTokenKey)
                        VipleMailAPIClient.shared.authToken = tok
                    }
                    self.isExternalMailboxActive = false
                    self.activeExternalProviderName = nil
                    self.isUnifiedInboxActive = false
                    self.activeMailboxAddress = fallback
                    defaults.set(fallback, forKey: savedEmailKey)
                    await refreshBootstrap(email: fallback, cid: currentCid)
                } else if isUnifiedInboxActive {
                    await refreshBootstrap(email: "__all__", cid: currentCid)
                }
                showToast(res.message ?? "Boîte externe retirée.")
            } else {
                showToast(res.error ?? "Impossible de retirer cette boîte externe.")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 7. Gestionnaire d'Appareils Connectés & Sessions Actives (Écosystème Cenelis × Viple)

    public func refreshConnectedDevices(silent: Bool = false) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return }
        if !silent {
            isLoadingConnectedDevices = true
        }
        defer {
            if !silent {
                isLoadingConnectedDevices = false
            }
        }

        do {
            let res = try await VipleMailAPIClient.shared.fetchConnectedDevices(
                email: owner,
                cid: currentCid
            )
            if res.ok {
                self.connectedDevices = res.devices.sorted { lhs, rhs in
                    if lhs.isCurrentDevice != rhs.isCurrentDevice {
                        return lhs.isCurrentDevice && !rhs.isCurrentDevice
                    }
                    if lhs.effectiveIsConnected != rhs.effectiveIsConnected {
                        return lhs.effectiveIsConnected && !rhs.effectiveIsConnected
                    }
                    return (lhs.lastSeenAtUtc ?? lhs.connectedAtUtc ?? "") > (rhs.lastSeenAtUtc ?? rhs.connectedAtUtc ?? "")
                }
            } else if !silent, let err = res.error {
                showToast(err)
            }
        } catch {
            if VipleMailAPIClient.isSessionRevokedError(error) {
                handleRemoteSessionRevoked()
                return
            }
            if !silent {
                showToast(error.localizedDescription)
            }
        }
    }

    /// Révoque à distance un appareil complet (`targetAppId == "*"`) ou une application précise de l'écosystème.
    /// Retourne `true` si la session locale Viple Mail de cet appareil vient d'être fermée.
    @discardableResult
    public func revokeDeviceSession(
        device: VipleConnectedDeviceDto,
        targetAppId: String = "*",
        appDisplayName: String? = nil
    ) async -> Bool {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return false }

        let normalizedApp = targetAppId.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveAppId = normalizedApp.isEmpty ? "*" : normalizedApp
        let lowerApp = effectiveAppId.lowercased()
        let revokesLocalVipleMail = device.isCurrentDevice && (
            lowerApp == "*"
            || lowerApp == "viple-mail"
            || lowerApp == "viplemail"
            || lowerApp == "com.viplenetwork.viplemail"
        )

        do {
            let res = try await VipleMailAPIClient.shared.revokeConnectedDevice(
                email: owner,
                cid: currentCid,
                targetDeviceId: device.deviceId,
                targetAppId: effectiveAppId
            )
            guard res.ok else {
                showToast(res.error ?? "Impossible de révoquer la session distante.")
                return false
            }

            if revokesLocalVipleMail || res.revokedCurrentDevice == true && lowerApp == "*" {
                signOut(toastMessage: "Cet appareil a été déconnecté de votre compte.")
                return true
            }

            await refreshConnectedDevices(silent: true)
            if effectiveAppId == "*" {
                showToast(res.message ?? "\(device.resolvedModelDisplayName) a été déconnecté à distance.")
            } else {
                let label = appDisplayName ?? effectiveAppId
                showToast(res.message ?? "\(label) a été déconnecté sur \(device.resolvedModelDisplayName).")
            }
            return false
        } catch {
            if VipleMailAPIClient.isSessionRevokedError(error) {
                handleRemoteSessionRevoked()
                return true
            }
            showToast(error.localizedDescription)
            return false
        }
    }

    // MARK: - 8. Conformité App Store : Suppression Définitive du Compte & Sécurité Anti-Abus

    public func deleteMyVipleAccount(confirmation: String) async -> (ok: Bool, error: String?) {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else {
            return (false, "Aucun compte actif détecté.")
        }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            let res = try await VipleMailAPIClient.shared.deleteVipleAccount(
                email: owner,
                cid: currentCid,
                confirmation: confirmation
            )
            if res.ok {
                signOut(toastMessage: res.message ?? "Votre compte Viple Live ID a été définitivement supprimé.")
                return (true, nil)
            }
            return (false, res.error ?? "Impossible de supprimer ce compte.")
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func refreshBlockedSenders() async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return }
        if let res = try? await VipleMailAPIClient.shared.fetchBlockedSenders(email: owner, cid: currentCid),
           let list = res.blockedSenders {
            self.blockedSenders = list
        }
    }

    public func reportMessageAbuse(
        senderEmail: String,
        messageId: String?,
        category: String = "spam_phishing",
        details: String = "",
        alsoBlock: Bool = false
    ) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return }
        do {
            let res = try await VipleMailAPIClient.shared.reportMessageAbuse(
                email: owner,
                cid: currentCid,
                senderEmail: senderEmail,
                messageId: messageId,
                category: category,
                details: details,
                blockSender: alsoBlock
            )
            if alsoBlock {
                await refreshBlockedSenders()
            }
            if let mid = messageId, !mid.isEmpty {
                await performMessageAction(
                    messageIds: [mid],
                    action: "spam",
                    toast: res.message ?? "Message signalé et déplacé dans Indésirables."
                )
                if openedMessage?.id == mid {
                    closeMessage()
                }
            } else {
                showToast(res.message ?? "Signalement envoyé à l'équipe Sécurité Cenelis.")
            }
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func blockSenderAddress(_ senderEmail: String) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        let target = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !owner.isEmpty, !target.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.blockSender(email: owner, cid: currentCid, senderEmail: target)
            if let list = res.blockedSenders {
                self.blockedSenders = list
            }
            showToast(res.message ?? "\(target) est désormais bloqué.")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func unblockSenderAddress(_ senderEmail: String) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        let target = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !owner.isEmpty, !target.isEmpty else { return }
        do {
            let res = try await VipleMailAPIClient.shared.unblockSender(email: owner, cid: currentCid, senderEmail: target)
            if let list = res.blockedSenders {
                self.blockedSenders = list
            } else {
                self.blockedSenders.removeAll { $0.lowercased() == target }
            }
            showToast(res.message ?? "\(target) a été débloqué.")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    // MARK: - 9. Accès Invité Temporaire (1h, 8h, 24h, 48h) & Intégration iMessage

    public func presentIMessageComposer(
        recipients: [String] = [],
        body: String,
        shareUrl: String? = nil,
        subjectLabel: String? = nil
    ) {
        self.activeIMessagePayload = IMessageComposePayload(
            recipients: recipients,
            body: body,
            shareUrl: shareUrl,
            subjectLabel: subjectLabel
        )
    }

    /// Résout le meilleur destinataire iMessage (numéro de téléphone enregistré dans Contacts Viple Mail, sinon vide pour laisser l'utilisateur choisir dans Messages).
    public func preferredIMessageRecipients(for rawEmails: String) -> [String] {
        let emails = rawEmails
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { part -> String in
                let trimmed = String(part).trimmingCharacters(in: .whitespacesAndNewlines)
                if let open = trimmed.firstIndex(of: "<"),
                   let close = trimmed.firstIndex(of: ">"),
                   open < close {
                    return String(trimmed[trimmed.index(after: open)..<close]).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                }
                return trimmed.lowercased()
            }
            .filter { !$0.isEmpty }

        var phones: [String] = []
        for em in emails {
            if let match = contacts.first(where: { $0.contactEmail.lowercased() == em }) {
                let ph = match.phone.trimmingCharacters(in: .whitespacesAndNewlines)
                if !ph.isEmpty && !phones.contains(ph) {
                    phones.append(ph)
                }
            }
        }
        return phones
    }

    public func shareMessageViaIMessage(_ message: VipleMailMessage) async {
        guard !isCreatingIMessageLink else { return }
        if message.isLockedByCenelisPin {
            showToast("Ce courrier interne protégé par code PIN Cenelis Connect ne peut pas être partagé par lien externe.")
            return
        }
        isCreatingIMessageLink = true
        defer { isCreatingIMessageLink = false }

        let mbx = message.effectiveMailboxEmail(fallback: primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail)
        do {
            let res = try await VipleMailAPIClient.shared.createDirectMailIMessageLink(
                messageId: message.id,
                email: mbx,
                cid: currentCid
            )
            guard res.ok, let shareUrl = res.shareUrl ?? res.directMailLink?.shareUrl, !shareUrl.isEmpty else {
                showToast(res.error ?? "Impossible de générer le lien direct iMessage.")
                return
            }
            let text = res.imessageText
                ?? res.directMailLink?.imessagePreviewText
                ?? "✉️ Je t'ai envoyé un courrier sur Viple Mail (« \(message.subject) »). Ouvre-le directement ici :\n\(shareUrl)"
            let targetEmail = message.senderEmail.lowercased() == mbx.lowercased()
                ? message.recipientEmail
                : message.senderEmail
            let recipients = preferredIMessageRecipients(for: targetEmail)
            presentIMessageComposer(
                recipients: recipients,
                body: text,
                shareUrl: shareUrl,
                subjectLabel: message.subject
            )
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func refreshGuestAccessGrants(silent: Bool = true) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return }
        do {
            let res = try await VipleMailAPIClient.shared.fetchGuestMailboxAccessList(
                email: owner,
                cid: currentCid
            )
            if res.ok {
                self.sharedGuestMailboxes = (res.sharedGuestMailboxes ?? []).filter { !$0.isExpired() }
                self.outgoingGuestGrants = (res.outgoingGuestGrants ?? []).filter { !$0.isExpired() }
            } else if !silent, let err = res.error {
                showToast(err)
            }
        } catch {
            if !silent {
                showToast(error.localizedDescription)
            }
        }
    }

    public func createGuestAccessGrant(
        mailbox: String,
        durationHours: Int,
        guestEmail: String?,
        allowSend: Bool,
        labelNote: String? = nil
    ) async -> GuestMailboxCreateResponse? {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else {
            showToast("Aucune boîte hébergée principale détectée.")
            return nil
        }
        isProcessingGuestAction = true
        defer { isProcessingGuestAction = false }

        do {
            let res = try await VipleMailAPIClient.shared.createGuestMailboxGrant(
                ownerEmail: owner,
                cid: currentCid,
                mailbox: mailbox,
                durationHours: durationHours,
                guestEmail: guestEmail,
                allowSend: allowSend,
                labelNote: labelNote
            )
            guard res.ok else {
                showToast(res.error ?? "Impossible de créer l'accès invité.")
                return nil
            }
            if let out = res.outgoingGuestGrants {
                self.outgoingGuestGrants = out.filter { !$0.isExpired() }
            } else {
                await refreshGuestAccessGrants(silent: true)
            }
            if let msg = res.message {
                showToast(msg)
            }
            return res
        } catch {
            showToast(error.localizedDescription)
            return nil
        }
    }

    @discardableResult
    public func revokeGuestAccessGrant(_ grantId: String) async -> Bool {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else { return false }
        isProcessingGuestAction = true
        defer { isProcessingGuestAction = false }

        do {
            let res = try await VipleMailAPIClient.shared.revokeGuestMailboxGrant(
                grantId: grantId,
                email: owner,
                cid: currentCid
            )
            guard res.ok else {
                showToast(res.error ?? "Impossible de révoquer cet accès invité.")
                return false
            }
            if let inc = res.sharedGuestMailboxes {
                self.sharedGuestMailboxes = inc.filter { !$0.isExpired() }
            }
            if let out = res.outgoingGuestGrants {
                self.outgoingGuestGrants = out.filter { !$0.isExpired() }
            }
            if isGuestMailboxActive,
               let revokedMbx = res.revokedMailbox?.lowercased(),
               currentEmail.lowercased() == revokedMbx {
                let fallback = primaryHostedEmail
                if !fallback.isEmpty {
                    await switchActiveMailbox(to: fallback)
                }
            }
            showToast(res.message ?? "Accès invité révoqué.")
            return true
        } catch {
            showToast(error.localizedDescription)
            return false
        }
    }

    public func pruneAndExitExpiredGuestMailboxes() {
        let now = Date()
        let beforeCount = sharedGuestMailboxes.count
        sharedGuestMailboxes.removeAll { $0.isExpired(at: now) }
        outgoingGuestGrants.removeAll { $0.isExpired(at: now) }

        if isGuestMailboxActive {
            let activeExpired = activeGuestGrant?.isExpired(at: now) ?? !sharedGuestMailboxes.contains(where: {
                $0.ownerMailbox.lowercased() == currentEmail.lowercased()
            })
            if activeExpired {
                let expiredMbx = currentEmail
                isGuestMailboxActive = false
                activeGuestGrant = nil
                let fallback = primaryHostedEmail
                if !fallback.isEmpty {
                    Task {
                        await switchActiveMailbox(to: fallback)
                        showToast("⏱ L'accès invité temporaire à \(expiredMbx) a expiré.")
                    }
                }
            }
        } else if sharedGuestMailboxes.count < beforeCount {
            showToast("⏱ Un accès invité temporaire à une boîte partagée a expiré.")
        }
    }

    public func handleIncomingURL(_ url: URL) async {
        let scheme = (url.scheme ?? "").lowercased()
        let host = (url.host ?? "").lowercased()
        let pathParts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        var guestToken: String? = nil
        var mailToken: String? = nil

        if scheme == "viplemail" {
            if host == "guest", let first = pathParts.first {
                guestToken = first
            } else if host == "mail", let first = pathParts.first {
                mailToken = first
            } else if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                if host == "open-shared-mail" {
                    mailToken = comps.queryItems?.first(where: { $0.name == "token" })?.value
                } else if host == "claim-guest" {
                    guestToken = comps.queryItems?.first(where: { $0.name == "token" })?.value
                }
            }
        } else if scheme == "https" || scheme == "http" {
            if pathParts.count >= 2 && pathParts[0].lowercased() == "guest" {
                guestToken = pathParts[1]
            } else if pathParts.count >= 2 && pathParts[0].lowercased() == "m" {
                mailToken = pathParts[1]
            } else if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                guestToken = comps.queryItems?.first(where: { $0.name == "claimGuestToken" })?.value
                mailToken = comps.queryItems?.first(where: { $0.name == "openMailToken" })?.value
            }
        }

        if let gt = guestToken?.trimmingCharacters(in: .whitespacesAndNewlines), !gt.isEmpty {
            if isAuthenticated && !primaryHostedEmail.isEmpty {
                await claimAndOpenGuestMailboxFromToken(gt)
            } else {
                pendingGuestClaimToken = gt
                showToast("Connectez-vous à votre Viple Live ID pour activer la boîte partagée.")
            }
        } else if let mt = mailToken?.trimmingCharacters(in: .whitespacesAndNewlines), !mt.isEmpty {
            if isAuthenticated && !primaryHostedEmail.isEmpty {
                await openDirectMailFromToken(mt)
            } else {
                pendingDirectMailToken = mt
                showToast("Connectez-vous à Viple Mail pour ouvrir directement ce courrier.")
            }
        }
    }

    public func claimAndOpenGuestMailboxFromToken(_ token: String) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else {
            pendingGuestClaimToken = token
            return
        }
        do {
            let res = try await VipleMailAPIClient.shared.claimGuestMailboxGrant(
                token: token,
                email: owner,
                cid: currentCid
            )
            guard res.ok, let targetMbx = res.mailbox ?? res.grant?.ownerMailbox, !targetMbx.isEmpty else {
                showToast(res.error ?? "Cette invitation d'accès temporaire a expiré.")
                return
            }
            if let inc = res.sharedGuestMailboxes {
                self.sharedGuestMailboxes = inc.filter { !$0.isExpired() }
            }
            self.selectedTab = 0
            self.activeFolderId = "Inbox"
            await switchActiveMailbox(to: targetMbx)
            showToast(res.message ?? "🔑 Boîte partagée \(targetMbx) ouverte en accès invité !")
        } catch {
            showToast(error.localizedDescription)
        }
    }

    public func openDirectMailFromToken(_ token: String) async {
        let owner = primaryHostedEmail.isEmpty ? currentEmail : primaryHostedEmail
        guard !owner.isEmpty, owner != "__all__" else {
            pendingDirectMailToken = token
            return
        }
        do {
            let res = try await VipleMailAPIClient.shared.resolveDirectMailIMessageLink(
                token: token,
                email: owner,
                cid: currentCid
            )
            guard res.ok, let msg = res.message else {
                showToast(res.error ?? "Ce lien direct Viple Mail est introuvable ou expiré.")
                return
            }
            if res.foundInMailbox == true,
               let targetMbx = res.mailbox?.lowercased(),
               !targetMbx.isEmpty,
               !isUnifiedInboxActive,
               currentEmail.lowercased() != targetMbx {
                await switchActiveMailbox(to: targetMbx)
            }
            self.closeChatSession()
            self.selectedTab = 0
            self.activeThreadMessages = [msg]
            self.openMessage(msg)
            showToast("✉️ Courrier ouvert directement depuis iMessage")
        } catch {
            showToast(error.localizedDescription)
        }
    }
}
