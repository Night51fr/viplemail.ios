import Foundation
import SwiftUI

// MARK: - Modèles de Données « Viple Mail » (100 % synchronisés avec SQL Server VipleLive & VipleID — Zéro donnée de démo)

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
    public let user: VipleMailUser?
}

public struct VipleMailUser: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let email: String
    public let vipleMailAddress: String?
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
        case id, email, vipleMailAddress, displayName, firstName, lastName, cid, puid, avatarUrl, colorScheme, personalMessage, bio, location
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

public struct VipleMailAttachment: Codable, Identifiable, Equatable, Sendable {
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

public struct VipleMailMessage: Codable, Identifiable, Equatable, Sendable {
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
    public let host: String
    public let ssoProvider: String
    public let serverTimeUtc: String
    public let version: String
}

// MARK: - État du Compositeur de Courrier

public enum MailComposeMode: Equatable, Sendable {
    case newMail(to: String = "", subject: String = "")
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
