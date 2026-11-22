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
}

public struct VipleMailAuthResponse: Codable, Sendable {
    public let ok: Bool
    public let token: String?
    public let accountType: String?
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
    public let user: VipleMailUser?
}

public struct VipleMailSwitchMailboxResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let mailbox: String?
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let availableMailboxes: [String]?
    public let token: String?
    public let user: VipleMailUser?
}

public struct VipleMailUser: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let accountType: String?
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
        case id, email, vipleMailAddress, cenelisMailAddress, accountType, displayName, firstName, lastName, cid, puid, avatarUrl, colorScheme, personalMessage, bio, location
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

    public var isChatDelivery: Bool {
        (deliveryMode ?? "mail").lowercased() == "chat"
    }

    private var normalizedSenderDomain: String {
        let clean = senderEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let at = clean.lastIndex(of: "@") else { return "" }
        return String(clean[clean.index(after: at)...])
    }

    /// Badge expéditeur vérifié : UNIQUEMENT pour @viplenetwork.com / @cenelis.com (« Cenelis SA ») ou un service officiel authentifié par DKIM/DMARC (ex : « Facebook Inc »). Jamais pour @viplemail.fr.
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
            if dom == "cenelis.com" || dom.hasSuffix(".cenelis.com") || dom == "viplenetwork.com" || dom.hasSuffix(".viplenetwork.com") {
                return "Cenelis SA"
            }
            return nil
        }
        if dom == "cenelis.com" || dom.hasSuffix(".cenelis.com") || dom == "viplenetwork.com" || dom.hasSuffix(".viplenetwork.com") {
            return "Cenelis SA"
        }
        return nil
    }

    public var shouldShowVerifiedSenderBadge: Bool {
        effectiveVerifiedOrganization != nil
    }

    /// Sécurité MailRTE : @viplemail.fr, @viplenetwork.com et @cenelis.com utilisent « Chiffrement Cenelis MailRTE » (logo vérifié affiché uniquement dans la section « Sécurité »).
    public var effectiveIsMailRteSecurity: Bool {
        if let srvRte = isMailRteEncrypted {
            return srvRte
        }
        let dom = normalizedSenderDomain
        return dom == "viplemail.fr" || dom.hasSuffix(".viplemail.fr")
            || dom == "cenelis.com" || dom.hasSuffix(".cenelis.com")
            || dom == "viplenetwork.com" || dom.hasSuffix(".viplenetwork.com")
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
        let withNewlines = bodyHtml
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
        chatSessionId: String? = nil
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
    case newMail(to: String = "", subject: String = "", forceMail: Bool = false)
    case reply(VipleMailMessage)
    case replyAll(VipleMailMessage)
    case forward(VipleMailMessage)
    case editDraft(VipleMailMessage)
}

public enum MailFilterChip: String, CaseIterable, Identifiable, Sendable {
    case all = "Tous"
    case unread = "Non lus"
    case starred = "Favoris"
    case vip = "Contacts VIP"
    case attachments = "Pièces jointes"
    case highPriority = "Priorité Haute"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .unread: return "envelope.badge.fill"
        case .starred: return "star.fill"
        case .vip: return "crown.fill"
        case .attachments: return "paperclip"
        case .highPriority: return "exclamationmark.circle.fill"
        }
    }
}
