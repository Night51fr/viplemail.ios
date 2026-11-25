import Foundation
import SwiftUI

// MARK: - Modèles de Données « Viple Mail » (100 % synchronisés avec Stalwart Mail Server mail.viplemail.fr, SSO Viple Live ID & Cenelis Connect — Zéro donnée de démo)

public struct VipleMailBootstrapResponse: Codable, Sendable {
    public let ok: Bool
    public let isAuthenticated: Bool
    public let serverTimeUtc: String?
    public let user: VipleMailUser?
    public let mailbox: VipleMailboxQuota?
    public let activeFolder: String?
    public let folders: [VipleMailFolderSummary]?
    public let messages: [VipleMailMessage]?
    public let contacts: [VipleMailContact]?
    public let settings: VipleMailSettings?
    public let availableMailboxes: [String]?
    public let chatSessions: [VipleChatSession]?
    public let chatUnreadCount: Int?
    public let externalAccounts: [ExternalMailAccount]?
    public let isExternalMailbox: Bool?
    public let externalProviderName: String?
    public let isUnifiedInbox: Bool?
    public let isApprovedCenelisAgent: Bool?
    public let sessionRevoked: Bool?
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
    public let isGuestMailbox: Bool?
    public let activeGuestGrant: GuestMailboxGrant?
    public let friends: [VipleFriend]?
    public let agendaEvents: [VipleAgendaEvent]?
    public let activeIncomingCall: VipleVisioCall?
}

public struct VipleMailAuthResponse: Codable, Sendable {
    public let ok: Bool
    public let token: String?
    public let accountType: String?
    public let isApprovedCenelisAgent: Bool?
    public let error: String?
    public let needsOnboarding: Bool?
    public let appleUserId: String?
    public let appleEmail: String?
    public let suggestedFirstName: String?
    public let suggestedLastName: String?
    public let requiresApplePasswordSetup: Bool?
    public let icloudEmail: String?
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let availableMailboxes: [String]?
    public let externalAccounts: [ExternalMailAccount]?
    public let user: VipleMailUser?
}

public struct VipleMailSwitchMailboxResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let mailbox: String?
    public let isUnifiedInbox: Bool?
    public let isExternalMailbox: Bool?
    public let externalProviderName: String?
    public let isApprovedCenelisAgent: Bool?
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let availableMailboxes: [String]?
    public let externalAccounts: [ExternalMailAccount]?
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
    public let isGuestMailbox: Bool?
    public let activeGuestGrant: GuestMailboxGrant?
    public let token: String?
    public let user: VipleMailUser?
}

public struct VipleMailClaimCenelisResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let message: String?
    public let mailbox: String?
    public let isUnifiedInbox: Bool?
    public let isApprovedCenelisAgent: Bool?
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let availableMailboxes: [String]?
    public let externalAccounts: [ExternalMailAccount]?
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
    public let isGuestMailbox: Bool?
    public let activeGuestGrant: GuestMailboxGrant?
    public let token: String?
    public let user: VipleMailUser?
}

// MARK: - Modèles des Comptes E-Mail Externes (IMAP / SMTP : Gmail, Outlook, iCloud, Orange, OVH, Pro...)

public struct ExternalMailAccount: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let email: String
    public let displayName: String
    public let providerName: String
    public let colorHex: String
    public let imapHost: String
    public let imapPort: Int
    public let imapSecurity: String
    public let imapUsername: String
    public let smtpHost: String
    public let smtpPort: Int
    public let smtpSecurity: String
    public let smtpUsername: String
    public let canSendSmtp: Bool
    public let createdAtUtc: String

    public var providerIcon: String {
        let p = providerName.lowercased()
        if p.contains("icloud") || p.contains("apple") { return "icloud.fill" }
        if p.contains("gmail") || p.contains("google") { return "envelope.badge.shield.half.filled.fill" }
        if p.contains("outlook") || p.contains("microsoft") || p.contains("365") { return "building.2.crop.circle.fill" }
        if p.contains("yahoo") { return "at.circle.fill" }
        if p.contains("ovh") || p.contains("ionos") || p.contains("infomaniak") || p.contains("gandi") { return "server.rack" }
        return "globe.europe.africa.fill"
    }
}

public struct ExternalMailAutodiscoverResponse: Codable, Sendable {
    public let ok: Bool
    public let email: String
    public let providerId: String
    public let providerName: String
    public let colorHex: String
    public let imapHost: String
    public let imapPort: Int
    public let imapSecurity: String
    public let imapUsername: String
    public let smtpHost: String
    public let smtpPort: Int
    public let smtpSecurity: String
    public let smtpUsername: String
    public let requiresAppPasswordHint: Bool
    public let helpHint: String?
}

public struct ExternalMailTestResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let message: String?
    public let inboxTotal: Int?
    public let inboxUnread: Int?
}

public struct ExternalMailAccountActionResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let message: String?
    public let fallbackMailbox: String?
    public let token: String?
    public let account: ExternalMailAccount?
    public let externalAccounts: [ExternalMailAccount]?
    public let availableMailboxes: [String]?
}

public struct ExternalMailAccountListResponse: Codable, Sendable {
    public let ok: Bool
    public let externalAccounts: [ExternalMailAccount]?
    public let availableMailboxes: [String]?
}

public struct VipleMailUser: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let accountType: String?
    public let isApprovedCenelisAgent: Bool?
    public var displayName: String
    public let firstName: String?
    public let lastName: String?
    public let cid: String?
    public let puid: String?
    public let avatarUrl: String?
    public let colorScheme: String?
    public var personalMessage: String?
    public let bio: String?
    public let location: String?

    enum CodingKeys: String, CodingKey {
        case id, email, vipleMailAddress, cenelisMailAddress, accountType, isApprovedCenelisAgent, displayName, firstName, lastName, cid, puid, avatarUrl, colorScheme, personalMessage, bio, location
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let strId = try? c.decode(String.self, forKey: .id) {
            self.id = strId
        } else if let intId = try? c.decode(Int.self, forKey: .id) {
            self.id = "usr-\(intId)"
        } else {
            self.id = UUID().uuidString
        }
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.vipleMailAddress = try? c.decode(String.self, forKey: .vipleMailAddress)
        self.cenelisMailAddress = try? c.decode(String.self, forKey: .cenelisMailAddress)
        self.accountType = try? c.decode(String.self, forKey: .accountType)
        self.isApprovedCenelisAgent = try? c.decode(Bool.self, forKey: .isApprovedCenelisAgent)
        self.displayName = (try? c.decode(String.self, forKey: .displayName)) ?? self.email
        self.firstName = try? c.decode(String.self, forKey: .firstName)
        self.lastName = try? c.decode(String.self, forKey: .lastName)
        self.cid = try? c.decode(String.self, forKey: .cid)
        self.puid = try? c.decode(String.self, forKey: .puid)
        self.avatarUrl = try? c.decode(String.self, forKey: .avatarUrl)
        self.colorScheme = try? c.decode(String.self, forKey: .colorScheme)
        self.personalMessage = try? c.decode(String.self, forKey: .personalMessage)
        self.bio = try? c.decode(String.self, forKey: .bio)
        self.location = try? c.decode(String.self, forKey: .location)
    }

    public var primaryAddress: String {
        if let vm = vipleMailAddress, !vm.isEmpty { return vm }
        if let cm = cenelisMailAddress, !cm.isEmpty { return cm }
        return email
    }

    public var initials: String {
        let parts = displayName.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

public struct VipleMailboxQuota: Codable, Equatable, Sendable {
    public let mailboxId: String
    public let emailAddress: String
    public let usedBytes: Int64
    public let quotaBytes: Int64

    public var usageFraction: Double {
        guard quotaBytes > 0 else { return 0 }
        return min(1.0, max(0.002, Double(usedBytes) / Double(quotaBytes)))
    }

    public var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }

    public var formattedQuota: String {
        ByteCountFormatter.string(fromByteCount: quotaBytes, countStyle: .file)
    }
}

public struct VipleMailAttachment: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let fileName: String
    public let mimeType: String
    public let sizeBytes: Int64
    public let url: String

    public init(id: String, fileName: String, mimeType: String, sizeBytes: Int64, url: String) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.sizeBytes = sizeBytes
        self.url = url
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: max(1, sizeBytes), countStyle: .file)
    }

    public var iconName: String {
        let lower = mimeType.lowercased()
        if lower.hasPrefix("image/") { return "photo.fill" }
        if lower.contains("pdf") { return "doc.richtext.fill" }
        if lower.contains("zip") || lower.contains("archive") { return "doc.zipper" }
        if lower.hasPrefix("audio/") { return "waveform" }
        if lower.hasPrefix("video/") { return "film.fill" }
        return "paperclip"
    }
}

public struct VipleMailMessage: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let mailboxId: String
    public var folder: String
    public let senderName: String
    public let senderEmail: String
    public let recipientEmail: String
    public let ccEmail: String
    public let bccEmail: String
    public let subject: String
    public let snippet: String
    public let bodyHtml: String
    public var isRead: Bool
    public var isStarred: Bool
    public var isPinned: Bool
    public var isVipSender: Bool
    public let priority: String
    public var category: String
    public let threadId: String
    public let replyToMessageId: String
    public let sizeBytes: Int
    public let receivedAt: String
    public let attachments: [VipleMailAttachment]
    public let senderAvatarUrl: String?
    public let recipientAvatarUrl: String?
    public let deliveryMode: String?
    public let isVerifiedSender: Bool?
    public let verifiedOrganization: String?
    public let encryptionLabel: String?
    public let isMailRteEncrypted: Bool?
    public let isTransportUnencrypted: Bool?
    public let mailboxEmail: String?
    public let isExternalMailbox: Bool?
    public let externalProviderName: String?
    public let requiresCenelisPin: Bool?
    public let mailRteId: String?

    public func effectiveMailboxEmail(fallback: String) -> String {
        if let mbx = mailboxEmail?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !mbx.isEmpty,
           mbx != "__all__" {
            return mbx
        }
        return fallback
    }

    /// Vrai tant que ce courrier Cenelis MailRTE exige la saisie du code PIN Cenelis Connect avant déchiffrement de sa vue.
    public var isLockedByCenelisPin: Bool {
        guard requiresCenelisPin == true else { return false }
        let trimmed = bodyHtml.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.contains("data-cenelis-pin-locked")
    }

    public var isChatDelivery: Bool {
        (deliveryMode ?? "mail").lowercased() == "chat"
    }

    private var normalizedSenderDomain: String {
        let clean = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let at = clean.lastIndex(of: "@") else { return "" }
        return String(clean[clean.index(after: at)...])
    }

    /// Badge expéditeur vérifié : attribué aux domaines internes Groupe Cenelis (@cenelis.com / @viplenetwork.com / @livria.store / @looby.fr)
    /// ainsi qu'aux grandes entreprises et institutions authentifiées cryptographiquement par DKIM / SPF / DMARC côté serveur. Jamais pour @viplemail.fr.
    public var effectiveVerifiedOrganization: String? {
        let dom = normalizedSenderDomain
        if dom == "viplemail.fr" || dom.hasSuffix(".viplemail.fr") {
            return nil
        }
        if let srvVerified = isVerifiedSender {
            guard srvVerified else { return nil }
            if let org = verifiedOrganization, !org.isEmpty {
                return org
            }
            if dom == "cenelis.com" || dom.hasSuffix(".cenelis.com") || dom == "cenelis.fr" || dom.hasSuffix(".cenelis.fr") || dom == "viplenetwork.com" || dom.hasSuffix(".viplenetwork.com") || dom == "viple.digital" || dom.hasSuffix(".viple.digital") {
                return "Cenelis SA"
            }
            if dom == "livria.store" || dom.hasSuffix(".livria.store") {
                return "Livria (Groupe Cenelis)"
            }
            if dom == "looby.fr" || dom.hasSuffix(".looby.fr") {
                return "Looby (Groupe Cenelis)"
            }
            return nil
        }
        if dom == "cenelis.com" || dom.hasSuffix(".cenelis.com") || dom == "cenelis.fr" || dom.hasSuffix(".cenelis.fr") || dom == "viplenetwork.com" || dom.hasSuffix(".viplenetwork.com") {
            return "Cenelis SA"
        }
        return nil
    }

    public var shouldShowVerifiedSenderBadge: Bool {
        effectiveVerifiedOrganization != nil
    }

    /// Sécurité MailRTE : uniquement vrai lorsque la signature hybride Ed25519+ML-DSA-65,
    /// la désencapsulation X25519+ML-KEM-768 et les tags AES-256-GCM du conteneur .mrte ont été vérifiés.
    public var effectiveIsMailRteSecurity: Bool {
        isMailRteEncrypted == true
    }

    public var effectiveEncryptionLabel: String {
        if let lbl = encryptionLabel, !lbl.isEmpty {
            return lbl
        }
        if effectiveIsMailRteSecurity {
            return "Chiffrement Cenelis MailRTE"
        }
        return "Transport SMTP standard"
    }

    public var hasAttachments: Bool {
        !attachments.isEmpty
    }

    public var isHighPriority: Bool {
        priority.lowercased() == "high" || priority.lowercased() == "haute"
    }

    public var isLowPriority: Bool {
        priority.lowercased() == "low" || priority.lowercased() == "basse"
    }

    public var senderInitials: String {
        let clean = senderName.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = clean.isEmpty ? senderEmail : clean
        let parts = source.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(source.prefix(2)).uppercased()
    }

    public var plainBodyText: String {
        if isLockedByCenelisPin {
            return "🔒 Contenu interne Agents Cenelis — Code PIN Cenelis Connect requis."
        }
        let withoutScriptsOrStyles = bodyHtml
            .replacingOccurrences(of: "(?is)<script\\b[^>]*>.*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<style\\b[^>]*>.*?</style>", with: "", options: .regularExpression)
        let withNewlines = withoutScriptsOrStyles
            .replacingOccurrences(of: "<br/>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<br>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</p>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</li>", with: "\n", options: .caseInsensitive)
            .replacingOccurrences(of: "<li>", with: "• ", options: .caseInsensitive)
            .replacingOccurrences(of: "</h2>", with: "\n\n", options: .caseInsensitive)
            .replacingOccurrences(of: "</h3>", with: "\n", options: .caseInsensitive)
        let stripped = withNewlines.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let decoded = stripped
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
        return decoded
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var formattedRelativeDate: String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: receivedAt) {
            let cal = Calendar.current
            if cal.isDateInToday(date) {
                let tf = DateFormatter()
                tf.locale = Locale(identifier: "fr_FR")
                tf.dateFormat = "HH:mm"
                return tf.string(from: date)
            } else if cal.isDateInYesterday(date) {
                return "Hier"
            } else {
                let df = DateFormatter()
                df.locale = Locale(identifier: "fr_FR")
                df.dateFormat = "d MMM"
                return df.string(from: date)
            }
        }
        return String(receivedAt.prefix(10))
    }

    public var formattedFullDate: String {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: receivedAt) {
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.dateFormat = "EEEE d MMMM yyyy 'à' HH:mm"
            return df.string(from: date).capitalized
        }
        return receivedAt
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(max(512, sizeBytes)), countStyle: .file)
    }
}

public struct VipleMailMessageDetailResponse: Codable, Sendable {
    public let ok: Bool
    public let message: VipleMailMessage
    public let thread: [VipleMailMessage]
}

public struct VipleMailFolderSummary: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let icon: String
    public let colorHex: String
    public let isSystem: Bool
    public var totalCount: Int
    public var unreadCount: Int
}

public struct VipleMailContact: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let contactEmail: String
    public let contactCid: String
    public var displayName: String
    public var groupName: String
    public var isFavorite: Bool
    public var phone: String
    public var company: String
    public var jobTitle: String
    public var notes: String
    public let avatarUrl: String
    public let createdAt: String

    public var initials: String {
        let parts = displayName.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

public struct VipleMailSettings: Codable, Equatable, Sendable {
    public var signatureHtml: String
    public var signatureEnabled: Bool
    public var focusedInboxEnabled: Bool
    public var vacationEnabled: Bool
    public var vacationSubject: String
    public var vacationBody: String
    public var swipeRightAction: String
    public var swipeLeftAction: String
    public var readReceiptsEnabled: Bool
    public var pushNotificationsEnabled: Bool
    public var vipNotificationsOnly: Bool
    public var customFolders: [String]

    public init(
        signatureHtml: String = "Envoyé depuis Viple Mail pour iOS",
        signatureEnabled: Bool = true,
        focusedInboxEnabled: Bool = true,
        vacationEnabled: Bool = false,
        vacationSubject: String = "",
        vacationBody: String = "",
        swipeRightAction: String = "ToggleRead",
        swipeLeftAction: String = "Trash",
        readReceiptsEnabled: Bool = true,
        pushNotificationsEnabled: Bool = true,
        vipNotificationsOnly: Bool = false,
        customFolders: [String] = []
    ) {
        self.signatureHtml = signatureHtml
        self.signatureEnabled = signatureEnabled
        self.focusedInboxEnabled = focusedInboxEnabled
        self.vacationEnabled = vacationEnabled
        self.vacationSubject = vacationSubject
        self.vacationBody = vacationBody
        self.swipeRightAction = swipeRightAction
        self.swipeLeftAction = swipeLeftAction
        self.readReceiptsEnabled = readReceiptsEnabled
        self.pushNotificationsEnabled = pushNotificationsEnabled
        self.vipNotificationsOnly = vipNotificationsOnly
        self.customFolders = customFolders
    }
}

// MARK: - Modèle SSO Inter-Applications (Partagé avec Livria Store, Livria Social & Viple)

public struct VipleCrossAppAccount: Codable, Equatable, Sendable {
    public let sourceApp: String?
    public let targetApp: String?
    public let userId: Int
    public let email: String
    public let displayName: String
    public let firstName: String?
    public let lastName: String?
    public let cid: String?
    public let avatarUrl: String?
    public let isLivriaPlus: Bool?

    public init(
        sourceApp: String?,
        targetApp: String? = "Viple Mail",
        userId: Int,
        email: String,
        displayName: String,
        firstName: String? = nil,
        lastName: String? = nil,
        cid: String? = nil,
        avatarUrl: String? = nil,
        isLivriaPlus: Bool? = nil
    ) {
        self.sourceApp = sourceApp
        self.targetApp = targetApp
        self.userId = userId
        self.email = email
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.cid = cid
        self.avatarUrl = avatarUrl
        self.isLivriaPlus = isLivriaPlus
    }
}

public struct VipleCrossAppDiscoverResponse: Codable, Sendable {
    public let ok: Bool
    public let hasDetectedAccount: Bool
    public let account: VipleCrossAppAccount?
}

public struct VipleMailDiagnosticsPing: Codable, Sendable {
    public let ok: Bool
    public let service: String
    public let domain: String
    public let domains: [String]?
    public let host: String
    public let imapHost: String?
    public let smtpHost: String?
    public let autodiscoverHost: String?
    public let ssoProvider: String
    public let cenelisSsoProvider: String?
    public let apnsConfigured: Bool?
    public let serverTimeUtc: String
    public let version: String
}

// MARK: - Modèles de Synchronisation & Notifications Temps Réel « Viple Mail »

public struct VipleMailNotificationItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let threadId: String
    public let senderName: String
    public let senderEmail: String
    public let senderAvatarUrl: String?
    public let subject: String
    public let snippet: String
    public let isVipSender: Bool
    public let priority: String
    public let hasAttachments: Bool
    public let receivedAt: String
    public let isChatMessage: Bool?
    public let chatSessionId: String?
    public let mailboxEmail: String?
    public let requiresCenelisPin: Bool?

    public init(
        id: String,
        threadId: String,
        senderName: String,
        senderEmail: String,
        senderAvatarUrl: String?,
        subject: String,
        snippet: String,
        isVipSender: Bool,
        priority: String,
        hasAttachments: Bool,
        receivedAt: String,
        isChatMessage: Bool? = false,
        chatSessionId: String? = nil,
        mailboxEmail: String? = nil,
        requiresCenelisPin: Bool? = false
    ) {
        self.id = id
        self.threadId = threadId
        self.senderName = senderName
        self.senderEmail = senderEmail
        self.senderAvatarUrl = senderAvatarUrl
        self.subject = subject
        self.snippet = snippet
        self.isVipSender = isVipSender
        self.priority = priority
        self.hasAttachments = hasAttachments
        self.receivedAt = receivedAt
        self.isChatMessage = isChatMessage
        self.chatSessionId = chatSessionId
        self.mailboxEmail = mailboxEmail
        self.requiresCenelisPin = requiresCenelisPin
    }
}

public struct VipleMailNotificationPollResponse: Codable, Sendable {
    public let ok: Bool
    public let serverTimeUtc: String?
    public let inboxUnreadCount: Int
    public let vipUnreadCount: Int
    public let pushNotificationsEnabled: Bool
    public let vipNotificationsOnly: Bool
    public let recentUnseen: [VipleMailNotificationItem]
    public let chatUnreadCount: Int?
    public let apnsServerConfigured: Bool?
    public let sessionRevoked: Bool?
    public var activeIncomingCall: VipleVisioCall? = nil
    public var pendingFriendRequestsCount: Int? = nil
}

public struct VipleMailApnsAdminDetails: Codable, Equatable, Sendable {
    public let configured: Bool
    public let teamId: String
    public let keyId: String
    public let bundleId: String
    public let preferSandbox: Bool
    public let registeredApnsDevices: Int
}

public struct VipleMailApnsStatusResponse: Codable, Sendable {
    public let ok: Bool
    public let configured: Bool
    public let hasUserDeviceToken: Bool?
    public let userDeviceCount: Int?
    public let canConfigure: Bool?
    public let apns: VipleMailApnsAdminDetails?
}

public struct VipleMailApnsTestResponse: Codable, Sendable {
    public let ok: Bool
    public let scheduled: Bool?
    public let delaySeconds: Int?
    public let sentCount: Int?
    public let apnsConfigured: Bool?
    public let deviceCount: Int?
    public let message: String?
}

public struct VipleMailApnsSaveResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let apns: VipleMailApnsAdminDetails?
}

public struct VipleMailPinInfoResponse: Codable, Sendable {
    public let ok: Bool
    public let isAgent: Bool?
    public let hasPin: Bool?
    public let needsSetup: Bool?
    public let pinLength: Int?
    public let lockedUntilUtc: String?
    public let agentEmail: String?
    public let error: String?
}

public struct VipleMailPinUnlockResponse: Codable, Sendable {
    public let ok: Bool
    public let needsSetup: Bool?
    public let locked: Bool?
    public let error: String?
    public let message: VipleMailMessage?
}

// MARK: - Modèles de Discussion Instantanée « Chat @viplemail.fr »

public struct VipleChatSession: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let peerEmail: String
    public let peerDisplayName: String
    public let peerAvatarUrl: String?
    public var lastMessageSnippet: String
    public var lastSenderEmail: String
    public var updatedAt: String
    public var unreadCount: Int
    public let isVipPeer: Bool

    public var formattedRelativeDate: String {
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: updatedAt) ?? isoFrac.date(from: updatedAt) {
            let cal = Calendar.current
            if cal.isDateInToday(date) {
                let tf = DateFormatter()
                tf.locale = Locale(identifier: "fr_FR")
                tf.dateFormat = "HH:mm"
                return tf.string(from: date)
            } else if cal.isDateInYesterday(date) {
                return "Hier"
            } else {
                let df = DateFormatter()
                df.locale = Locale(identifier: "fr_FR")
                df.dateFormat = "d MMM"
                return df.string(from: date)
            }
        }
        return String(updatedAt.prefix(10))
    }
}

public struct VipleChatMessage: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let sessionId: String
    public let senderEmail: String
    public let senderName: String
    public let senderAvatarUrl: String?
    public let recipientEmail: String
    public let bodyText: String
    public let bodyHtml: String
    public let attachments: [VipleMailAttachment]
    public var isRead: Bool
    public let createdAt: String

    public init(
        id: String,
        sessionId: String,
        senderEmail: String,
        senderName: String,
        senderAvatarUrl: String?,
        recipientEmail: String,
        bodyText: String,
        bodyHtml: String,
        attachments: [VipleMailAttachment],
        isRead: Bool,
        createdAt: String
    ) {
        self.id = id
        self.sessionId = sessionId
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.senderAvatarUrl = senderAvatarUrl
        self.recipientEmail = recipientEmail
        self.bodyText = bodyText
        self.bodyHtml = bodyHtml
        self.attachments = attachments
        self.isRead = isRead
        self.createdAt = createdAt
    }

    public var formattedTime: String {
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: createdAt) ?? isoFrac.date(from: createdAt) {
            let tf = DateFormatter()
            tf.locale = Locale(identifier: "fr_FR")
            tf.dateFormat = "HH:mm"
            return tf.string(from: date)
        }
        return String(createdAt.suffix(8).prefix(5))
    }

    public var formattedDayKey: String {
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: createdAt) ?? isoFrac.date(from: createdAt) {
            let cal = Calendar.current
            if cal.isDateInToday(date) { return "Aujourd'hui" }
            if cal.isDateInYesterday(date) { return "Hier" }
            let df = DateFormatter()
            df.locale = Locale(identifier: "fr_FR")
            df.dateFormat = "EEEE d MMMM"
            return df.string(from: date).capitalized
        }
        return String(createdAt.prefix(10))
    }
}

public struct VipleChatSessionsResponse: Codable, Sendable {
    public let ok: Bool
    public let chatUnreadCount: Int?
    public let sessions: [VipleChatSession]?
}

public struct VipleChatMessagesResponse: Codable, Sendable {
    public let ok: Bool
    public let session: VipleChatSession?
    public let messages: [VipleChatMessage]?
}

public struct VipleChatSendResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let session: VipleChatSession?
    public let message: VipleChatMessage?
}

// MARK: - État du Compositeur de Courrier / Chat

public enum ComposeDeliveryChannel: String, CaseIterable, Identifiable, Sendable {
    case chat = "Chat"
    case mail = "Mail"

    public var id: String { rawValue }
}

public enum MailComposeMode: Equatable, Sendable {
    case newMail(to: String = "", subject: String = "", body: String = "", forceMail: Bool = false, preferredFromMailbox: String? = nil)
    case reply(VipleMailMessage)
    case replyAll(VipleMailMessage)
    case forward(VipleMailMessage)
    case editDraft(VipleMailMessage)
}

public enum MailFilterChip: String, CaseIterable, Identifiable, Sendable {
    case all = "Tous"
    case unread = "Non lus"
    case verified = "Certifiés"
    case starred = "Favoris"
    case vip = "Contacts VIP"
    case attachments = "Pièces jointes"
    case highPriority = "Priorité Haute"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .unread: return "envelope.badge.fill"
        case .verified: return "checkmark.seal.fill"
        case .starred: return "star.fill"
        case .vip: return "crown.fill"
        case .attachments: return "paperclip"
        case .highPriority: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Gestionnaire d'Appareils Connectés & Sessions Écosystème Cenelis × Viple

public struct VipleConnectedAppBadgeDto: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let appId: String
    public let appName: String
    public let bundleId: String
    public let icon: String
    public let colorHex: String
    public let accountEmail: String
    public let appVersion: String
    public let notificationsEnabled: Bool
    public let lastSeenAtUtc: String?
    public let assetIconName: String?

    public var id: String {
        "\(appId.lowercased())|\(accountEmail.lowercased())|\(bundleId.lowercased())"
    }

    enum CodingKeys: String, CodingKey {
        case appId, appName, bundleId, icon, colorHex, accountEmail, appVersion, notificationsEnabled, lastSeenAtUtc, assetIconName
    }

    public init(
        appId: String,
        appName: String,
        bundleId: String,
        icon: String,
        colorHex: String,
        accountEmail: String,
        appVersion: String,
        notificationsEnabled: Bool,
        lastSeenAtUtc: String? = nil,
        assetIconName: String? = nil
    ) {
        self.appId = appId
        self.appName = appName
        self.bundleId = bundleId
        self.icon = icon
        self.colorHex = colorHex
        self.accountEmail = accountEmail
        self.appVersion = appVersion
        self.notificationsEnabled = notificationsEnabled
        self.lastSeenAtUtc = lastSeenAtUtc
        self.assetIconName = assetIconName
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.appId = (try? c.decode(String.self, forKey: .appId)) ?? "viple-app"
        self.appName = (try? c.decode(String.self, forKey: .appName)) ?? "Application Viple"
        self.bundleId = (try? c.decode(String.self, forKey: .bundleId)) ?? ""
        self.icon = (try? c.decode(String.self, forKey: .icon)) ?? ""
        self.colorHex = (try? c.decode(String.self, forKey: .colorHex)) ?? "#2563EB"
        self.accountEmail = (try? c.decode(String.self, forKey: .accountEmail)) ?? ""
        self.appVersion = (try? c.decode(String.self, forKey: .appVersion)) ?? ""
        self.notificationsEnabled = (try? c.decode(Bool.self, forKey: .notificationsEnabled)) ?? false
        self.lastSeenAtUtc = try? c.decode(String.self, forKey: .lastSeenAtUtc)
        self.assetIconName = try? c.decode(String.self, forKey: .assetIconName)
    }

    public var resolvedAssetIconName: String? {
        if let explicit = assetIconName?.trimmingCharacters(in: .whitespacesAndNewlines), !explicit.isEmpty {
            return explicit
        }
        let lowerId = appId.lowercased()
        let lowerBundle = bundleId.lowercased()
        let lowerName = appName.lowercased()
        if lowerId.contains("mail") || lowerBundle.contains("viplemail") || lowerName.contains("viple mail") {
            return "EcoIconVipleMail"
        }
        if lowerId.contains("livria-store") || lowerBundle == "com.viplenetwork.livria" || lowerName.contains("livria store") {
            return "EcoIconLivriaStore"
        }
        if lowerId.contains("livria-social") || lowerBundle.contains("social") || lowerName.contains("livria social") {
            return "EcoIconLivriaSocial"
        }
        if lowerId.contains("academy") || lowerBundle.contains("academy") || lowerName.contains("academy") {
            return "EcoIconCenelisAcademy"
        }
        if lowerId.contains("taker") || lowerBundle.contains("taker") || lowerName.contains("taker") {
            return "EcoIconLoobyTaker"
        }
        if lowerId.contains("looby") || lowerBundle.contains("looby") || lowerName.contains("looby") {
            return "EcoIconLooby"
        }
        if lowerId.contains("workspace") || lowerName.contains("workspace") {
            return "EcoIconCenelisWorkspace"
        }
        if lowerId.contains("viple-et-moi") || lowerName.contains("viple & moi") {
            return "EcoIconVipleEtMoi"
        }
        if lowerId.contains("marketplace") || lowerName.contains("marketplace") {
            return "EcoIconLivriaMarketplace"
        }
        return nil
    }

    public var resolvedSymbolName: String {
        let trimmed = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let lowerId = appId.lowercased()
        let lowerName = appName.lowercased()
        if lowerId.contains("mail") || lowerName.contains("mail") {
            return "envelope.fill"
        }
        if lowerId.contains("store") || lowerName.contains("store") {
            return "book.closed.fill"
        }
        if lowerId.contains("social") || lowerName.contains("social") {
            return "bubble.left.and.bubble.right.fill"
        }
        if lowerId.contains("academy") || lowerName.contains("academy") {
            return "graduationcap.fill"
        }
        if lowerId.contains("workspace") || lowerName.contains("workspace") {
            return "building.columns.fill"
        }
        if lowerId.contains("marketplace") || lowerName.contains("marketplace") {
            return "bag.fill"
        }
        return "app.badge.checkmark.fill"
    }

    public var resolvedColorHex: String {
        let trimmed = colorHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        let lowerId = appId.lowercased()
        if lowerId.contains("mail") { return "#2563EB" }
        if lowerId.contains("store") { return "#7C3AED" }
        if lowerId.contains("social") { return "#DB2777" }
        if lowerId.contains("academy") { return "#D97706" }
        return "#0078D4"
    }
}

public struct VipleConnectedDeviceDto: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let deviceId: String
    public let rawDeviceIds: [String]
    public let modelName: String
    public let modelCode: String
    public let platform: String
    public let osVersion: String
    public let isCurrentDevice: Bool
    public let pushActive: Bool
    public let connectedAtUtc: String?
    public let lastSeenAtUtc: String?
    public var connectedApps: [VipleConnectedAppBadgeDto]
    public let isConnected: Bool?
    public let status: String?
    public let statusLabel: String?

    public var id: String { deviceId }

    /// Un appareil est considéré « Connecté » tant qu'au moins une application y maintient une session active sur ce Viple Live ID.
    /// Dès que l'utilisateur se déconnecte de toutes les applications sur cet appareil, il passe à « Déconnecté ».
    public var effectiveIsConnected: Bool {
        if !connectedApps.isEmpty {
            return true
        }
        if let explicit = isConnected {
            return explicit && !connectedApps.isEmpty
        }
        return false
    }

    public var effectiveStatusLabel: String {
        effectiveIsConnected ? "Connecté" : "Déconnecté"
    }

    enum CodingKeys: String, CodingKey {
        case deviceId, rawDeviceIds, modelName, modelCode, platform, osVersion
        case isCurrentDevice, pushActive, connectedAtUtc, lastSeenAtUtc, connectedApps
        case isConnected, status, statusLabel
    }

    public init(
        deviceId: String,
        rawDeviceIds: [String] = [],
        modelName: String,
        modelCode: String,
        platform: String,
        osVersion: String,
        isCurrentDevice: Bool,
        pushActive: Bool,
        connectedAtUtc: String? = nil,
        lastSeenAtUtc: String? = nil,
        connectedApps: [VipleConnectedAppBadgeDto] = [],
        isConnected: Bool? = nil,
        status: String? = nil,
        statusLabel: String? = nil
    ) {
        self.deviceId = deviceId
        self.rawDeviceIds = rawDeviceIds
        self.modelName = modelName
        self.modelCode = modelCode
        self.platform = platform
        self.osVersion = osVersion
        self.isCurrentDevice = isCurrentDevice
        self.pushActive = pushActive
        self.connectedAtUtc = connectedAtUtc
        self.lastSeenAtUtc = lastSeenAtUtc
        self.connectedApps = connectedApps
        self.isConnected = isConnected ?? !connectedApps.isEmpty
        self.status = status ?? (!connectedApps.isEmpty ? "connected" : "disconnected")
        self.statusLabel = statusLabel ?? (!connectedApps.isEmpty ? "Connecté" : "Déconnecté")
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.deviceId = (try? c.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        self.rawDeviceIds = (try? c.decode([String].self, forKey: .rawDeviceIds)) ?? []
        self.modelName = (try? c.decode(String.self, forKey: .modelName)) ?? ""
        self.modelCode = (try? c.decode(String.self, forKey: .modelCode)) ?? ""
        self.platform = (try? c.decode(String.self, forKey: .platform)) ?? "iOS"
        self.osVersion = (try? c.decode(String.self, forKey: .osVersion)) ?? ""
        self.isCurrentDevice = (try? c.decode(Bool.self, forKey: .isCurrentDevice)) ?? false
        self.pushActive = (try? c.decode(Bool.self, forKey: .pushActive)) ?? false
        self.connectedAtUtc = try? c.decode(String.self, forKey: .connectedAtUtc)
        self.lastSeenAtUtc = try? c.decode(String.self, forKey: .lastSeenAtUtc)
        self.connectedApps = (try? c.decode([VipleConnectedAppBadgeDto].self, forKey: .connectedApps)) ?? []
        self.isConnected = try? c.decode(Bool.self, forKey: .isConnected)
        self.status = try? c.decode(String.self, forKey: .status)
        self.statusLabel = try? c.decode(String.self, forKey: .statusLabel)
    }

    public var resolvedModelDisplayName: String {
        let cleanName = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCode = modelCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let genericNames: Set<String> = ["", "iphone", "ipad", "ios", "appareil ios", "apple device", "unknown"]
        if !genericNames.contains(cleanName.lowercased()) {
            return cleanName
        }
        if !cleanCode.isEmpty {
            return CenelisDeviceIdentity.friendlyModelName(for: cleanCode)
        }
        return cleanName.isEmpty ? "Appareil Apple" : cleanName
    }

    public var resolvedOsDisplayLabel: String {
        let cleanOs = osVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanOs.isEmpty {
            return cleanOs
        }
        return platform.isEmpty ? "iOS" : platform
    }

    public var deviceSymbolName: String {
        let combined = "\(platform) \(modelCode) \(modelName)".lowercased()
        if combined.contains("ipad") {
            return "ipad"
        }
        if combined.contains("mac") || combined.contains("desktop") || combined.contains("windows") || combined.contains("linux") || combined.contains("web") {
            return "desktopcomputer"
        }
        return "iphone.gen3"
    }

    public var formattedRelativeLastSeen: String {
        guard let raw = lastSeenAtUtc ?? connectedAtUtc, !raw.isEmpty else {
            return isCurrentDevice ? "Actif maintenant" : "Activité récente"
        }
        let iso = ISO8601DateFormatter()
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = isoFrac.date(from: raw) ?? iso.date(from: raw) else {
            return String(raw.prefix(10))
        }
        let delta = max(0, Date().timeIntervalSince(date))
        if delta < 60 {
            return "À l'instant"
        }
        if delta < 3600 {
            let mins = max(1, Int(delta / 60))
            return "Il y a \(mins) min"
        }
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let hours = max(1, Int(delta / 3600))
            return "Il y a \(hours) h"
        }
        if cal.isDateInYesterday(date) {
            let tf = DateFormatter()
            tf.locale = Locale(identifier: "fr_FR")
            tf.dateFormat = "HH:mm"
            return "Hier à \(tf.string(from: date))"
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "d MMM 'à' HH:mm"
        return df.string(from: date)
    }
}

public struct VipleConnectedDevicesResponse: Codable, Sendable {
    public let ok: Bool
    public let devices: [VipleConnectedDeviceDto]
    public let error: String?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case ok, devices, error, message
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        self.devices = (try? c.decode([VipleConnectedDeviceDto].self, forKey: .devices)) ?? []
        self.error = try? c.decode(String.self, forKey: .error)
        self.message = try? c.decode(String.self, forKey: .message)
    }
}

public struct VipleDeviceRevokeResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let revokedCurrentDevice: Bool?
}

public struct VipleHandleCheckResponse: Codable, Sendable {
    public let ok: Bool
    public let available: Bool
    public let handle: String
    public let email: String
    public let reason: String?
    public let suggestions: [String]

    enum CodingKeys: String, CodingKey {
        case ok, available, handle, email, reason, suggestions
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.ok = (try? c.decode(Bool.self, forKey: .ok)) ?? false
        self.available = (try? c.decode(Bool.self, forKey: .available)) ?? false
        self.handle = (try? c.decode(String.self, forKey: .handle)) ?? ""
        self.email = (try? c.decode(String.self, forKey: .email)) ?? ""
        self.reason = try? c.decode(String.self, forKey: .reason)
        self.suggestions = (try? c.decode([String].self, forKey: .suggestions)) ?? []
    }
}

public struct VipleAccountDeletionResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
}

public struct VipleSecurityActionResponse: Codable, Sendable {
    public let ok: Bool
    public let reportId: String?
    public let blockedSenders: [String]?
    public let message: String?
    public let error: String?
}

// MARK: - Accès Invité Temporaire aux Boîtes Mail (1h, 8h, 24h, 48h) & Intégration iMessage

public enum GuestMailboxDuration: Int, CaseIterable, Identifiable, Sendable {
    case oneHour = 1
    case eightHours = 8
    case twentyFourHours = 24
    case fortyEightHours = 48

    public var id: Int { rawValue }

    public var shortLabel: String {
        "\(rawValue)h"
    }

    public var title: String {
        switch self {
        case .oneHour: return "1 heure"
        case .eightHours: return "8 heures"
        case .twentyFourHours: return "24 heures"
        case .fortyEightHours: return "48 heures"
        }
    }

    public var subtitle: String {
        switch self {
        case .oneHour: return "Consultation express"
        case .eightHours: return "Journée de travail"
        case .twentyFourHours: return "1 jour complet"
        case .fortyEightHours: return "2 jours / week-end"
        }
    }

    public var iconName: String {
        switch self {
        case .oneHour: return "bolt.badge.clock.fill"
        case .eightHours: return "clock.badge.checkmark.fill"
        case .twentyFourHours: return "sun.max.circle.fill"
        case .fortyEightHours: return "calendar.badge.clock"
        }
    }
}

public struct GuestMailboxGrant: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let grantId: String
    public let inviteToken: String
    public let ownerMailbox: String
    public let ownerDisplayName: String
    public let ownerAvatarUrl: String?
    public let guestEmail: String?
    public let guestDisplayName: String?
    public let durationHours: Int
    public let allowSend: Bool
    public let labelNote: String
    public let status: String
    public let createdAtUtc: String
    public let expiresAtUtc: String
    public let remainingSeconds: Int64
    public let inviteUrl: String
    public let deepLinkUrl: String

    public var id: String { grantId }

    enum CodingKeys: String, CodingKey {
        case grantId, inviteToken, ownerMailbox, ownerDisplayName, ownerAvatarUrl
        case guestEmail, guestDisplayName, durationHours, allowSend, labelNote
        case status, createdAtUtc, expiresAtUtc, remainingSeconds, inviteUrl, deepLinkUrl
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.grantId = (try? c.decode(String.self, forKey: .grantId)) ?? UUID().uuidString
        self.inviteToken = (try? c.decode(String.self, forKey: .inviteToken)) ?? ""
        self.ownerMailbox = (try? c.decode(String.self, forKey: .ownerMailbox)) ?? ""
        self.ownerDisplayName = (try? c.decode(String.self, forKey: .ownerDisplayName)) ?? self.ownerMailbox
        self.ownerAvatarUrl = try? c.decode(String.self, forKey: .ownerAvatarUrl)
        self.guestEmail = try? c.decode(String.self, forKey: .guestEmail)
        self.guestDisplayName = try? c.decode(String.self, forKey: .guestDisplayName)
        self.durationHours = (try? c.decode(Int.self, forKey: .durationHours)) ?? 8
        self.allowSend = (try? c.decode(Bool.self, forKey: .allowSend)) ?? false
        self.labelNote = (try? c.decode(String.self, forKey: .labelNote)) ?? ""
        self.status = (try? c.decode(String.self, forKey: .status)) ?? "active"
        self.createdAtUtc = (try? c.decode(String.self, forKey: .createdAtUtc)) ?? ""
        self.expiresAtUtc = (try? c.decode(String.self, forKey: .expiresAtUtc)) ?? ""
        self.remainingSeconds = (try? c.decode(Int64.self, forKey: .remainingSeconds)) ?? 0
        self.inviteUrl = (try? c.decode(String.self, forKey: .inviteUrl)) ?? ""
        self.deepLinkUrl = (try? c.decode(String.self, forKey: .deepLinkUrl)) ?? ""
    }

    public var expirationDate: Date? {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: expiresAtUtc) {
            return d
        }
        let iso = ISO8601DateFormatter()
        return iso.date(from: expiresAtUtc)
    }

    public func remainingTimeInterval(at now: Date = Date()) -> TimeInterval {
        guard let exp = expirationDate else {
            return max(0, TimeInterval(remainingSeconds))
        }
        return max(0, exp.timeIntervalSince(now))
    }

    public func isExpired(at now: Date = Date()) -> Bool {
        status.lowercased() == "revoked" || status.lowercased() == "expired" || remainingTimeInterval(at: now) <= 0
    }

    public func formattedCountdown(at now: Date = Date(), compact: Bool = false) -> String {
        let rem = Int(floor(remainingTimeInterval(at: now)))
        guard rem > 0 else { return "Expiré" }
        let hours = rem / 3600
        let mins = (rem % 3600) / 60
        let secs = rem % 60
        if compact {
            if hours > 0 {
                return "\(hours)h \(String(format: "%02d", mins))m"
            }
            if mins > 0 {
                return "\(mins)m \(String(format: "%02d", secs))s"
            }
            return "\(secs)s"
        }
        if hours > 0 {
            return "\(hours)h \(String(format: "%02d", mins))m \(String(format: "%02d", secs))s"
        }
        return "\(String(format: "%02d", mins))m \(String(format: "%02d", secs))s"
    }
}

public struct DirectMailShareLink: Codable, Equatable, Hashable, Sendable {
    public let token: String
    public let senderMailbox: String
    public let senderDisplayName: String
    public let recipientEmails: String
    public let subject: String
    public let snippet: String
    public let rfcMessageId: String
    public let sourceMessageId: String?
    public let createdAtUtc: String
    public let expiresAtUtc: String
    public let shareUrl: String
    public let deepLinkUrl: String
    public let imessagePreviewText: String

    enum CodingKeys: String, CodingKey {
        case token, senderMailbox, senderDisplayName, recipientEmails, subject, snippet
        case rfcMessageId, sourceMessageId, createdAtUtc, expiresAtUtc
        case shareUrl, deepLinkUrl, imessagePreviewText
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.token = (try? c.decode(String.self, forKey: .token)) ?? ""
        self.senderMailbox = (try? c.decode(String.self, forKey: .senderMailbox)) ?? ""
        self.senderDisplayName = (try? c.decode(String.self, forKey: .senderDisplayName)) ?? ""
        self.recipientEmails = (try? c.decode(String.self, forKey: .recipientEmails)) ?? ""
        self.subject = (try? c.decode(String.self, forKey: .subject)) ?? "(Sans objet)"
        self.snippet = (try? c.decode(String.self, forKey: .snippet)) ?? ""
        self.rfcMessageId = (try? c.decode(String.self, forKey: .rfcMessageId)) ?? ""
        self.sourceMessageId = try? c.decode(String.self, forKey: .sourceMessageId)
        self.createdAtUtc = (try? c.decode(String.self, forKey: .createdAtUtc)) ?? ""
        self.expiresAtUtc = (try? c.decode(String.self, forKey: .expiresAtUtc)) ?? ""
        self.shareUrl = (try? c.decode(String.self, forKey: .shareUrl)) ?? ""
        self.deepLinkUrl = (try? c.decode(String.self, forKey: .deepLinkUrl)) ?? ""
        self.imessagePreviewText = (try? c.decode(String.self, forKey: .imessagePreviewText)) ?? ""
    }
}

public struct GuestMailboxListResponse: Codable, Sendable {
    public let ok: Bool
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
    public let error: String?
}

public struct GuestMailboxCreateResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let grant: GuestMailboxGrant?
    public let inviteUrl: String?
    public let deepLinkUrl: String?
    public let imessageText: String?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
}

public struct GuestMailboxClaimResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let mailbox: String?
    public let grant: GuestMailboxGrant?
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
}

public struct GuestMailboxRevokeResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let revokedMailbox: String?
    public let sharedGuestMailboxes: [GuestMailboxGrant]?
    public let outgoingGuestGrants: [GuestMailboxGrant]?
}

public struct DirectMailLinkCreateResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let directMailLink: DirectMailShareLink?
    public let shareUrl: String?
    public let deepLinkUrl: String?
    public let imessageText: String?
}

public struct DirectMailLinkResolveResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let foundInMailbox: Bool?
    public let mailbox: String?
    public let link: DirectMailShareLink?
    public let message: VipleMailMessage?
}

public struct VipleMailSendResponse: Codable, Sendable {
    public let ok: Bool
    public let deliveryMode: String?
    public let message: String?
    public let error: String?
    public let rfcMessageId: String?
    public let sentMessageId: String?
    public let directMailLink: DirectMailShareLink?
}

public struct IMessageComposePayload: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let recipients: [String]
    public let body: String
    public let shareUrl: String?
    public let subjectLabel: String?

    public init(
        id: UUID = UUID(),
        recipients: [String] = [],
        body: String,
        shareUrl: String? = nil,
        subjectLabel: String? = nil
    ) {
        self.id = id
        self.recipients = recipients
        self.body = body
        self.shareUrl = shareUrl
        self.subjectLabel = subjectLabel
    }
}
