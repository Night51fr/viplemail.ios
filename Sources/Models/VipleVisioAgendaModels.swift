import Foundation
import SwiftUI

// MARK: - Modèles « Amis Viple Live ID », « Viple Visio » & « Agenda #viplecalandar »

public struct VipleFriend: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let friendshipId: String
    public let cid: String
    public let email: String
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let displayName: String
    public let avatarUrl: String?
    public let status: String      // "accepted" | "pending"
    public let direction: String   // "mutual" | "incoming" | "outgoing"
    public let createdAtUtc: String

    public var id: String { friendshipId }

    public var isAccepted: Bool {
        status.lowercased() == "accepted"
    }

    public var isIncomingRequest: Bool {
        status.lowercased() == "pending" && direction.lowercased() == "incoming"
    }

    public var isOutgoingRequest: Bool {
        status.lowercased() == "pending" && direction.lowercased() == "outgoing"
    }

    public var allKnownEmails: [String] {
        [email, vipleMailAddress, cenelisMailAddress]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
    }
}

public struct VipleFriendsListResponse: Codable, Sendable {
    public let ok: Bool
    public let friends: [VipleFriend]?
    public let error: String?
}

public struct VipleFriendMutationResponse: Codable, Sendable {
    public let ok: Bool
    public let message: String?
    public let error: String?
    public let friend: VipleFriend?
    public let friends: [VipleFriend]?
}

public struct VipleLiveIdPeerStatus: Codable, Equatable, Sendable {
    public let ok: Bool
    public let isVipleLiveIdUser: Bool
    public let cid: String?
    public let primaryEmail: String?
    public let vipleMailAddress: String?
    public let cenelisMailAddress: String?
    public let displayName: String?
    public let avatarUrl: String?
    public let friendshipStatus: String // "self" | "none" | "pending_outgoing" | "pending_incoming" | "friends"
    public let friendshipId: String?
    public let canCallDirect: Bool
}

// MARK: - Modèles d'Appel Direct « Viple Visio » (Appel Classique Audio & Appel Visio)

public struct VipleVisioCall: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let callId: String
    public let roomCode: String
    public let callerCid: String
    public let callerEmail: String
    public let callerName: String
    public let callerAvatarUrl: String?
    public let calleeCid: String
    public let calleeEmail: String
    public let calleeName: String
    public let calleeAvatarUrl: String?
    public let mode: String    // "audio" | "video"
    public var status: String  // "ringing" | "accepted" | "declined" | "ended" | "missed"
    public let joinUrl: String
    public let guestJoinUrl: String
    public let createdAtUtc: String
    public let expiresAtUtc: String

    public var id: String { callId }

    public var isAudioOnly: Bool {
        mode.lowercased() == "audio"
    }

    public var modeLabel: String {
        isAudioOnly ? "Appel classique (audio)" : "Appel Viple Visio"
    }
}

public struct VipleVisioCallStartResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let call: VipleVisioCall?
}

public struct VipleVisioActiveCallsResponse: Codable, Sendable {
    public let ok: Bool
    public let incomingCall: VipleVisioCall?
    public let outgoingCall: VipleVisioCall?
    public let trackedCall: VipleVisioCall?
}

public struct VipleVisioCallRespondResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let call: VipleVisioCall?
}

public struct VipleVisioRoomPresentation: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let peerName: String
    public let joinUrl: String
    public let isAudioOnly: Bool
    public let activeCallId: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        peerName: String,
        joinUrl: String,
        isAudioOnly: Bool,
        activeCallId: String? = nil
    ) {
        self.id = id
        self.title = title
        self.peerName = peerName
        self.joinUrl = joinUrl
        self.isAudioOnly = isAudioOnly
        self.activeCallId = activeCallId
    }
}

// MARK: - Modèles « Agenda » & Formule « #viplecalandar »

public struct VipleAgendaEvent: Codable, Identifiable, Equatable, Hashable, Sendable {
    public let eventId: String
    public let ownerEmail: String
    public let organizerEmail: String
    public let organizerName: String
    public let title: String
    public let description: String
    public let location: String
    public let startUtc: String
    public let endUtc: String
    public let colorHex: String
    public let isVisioSession: Bool
    public let visioRoomCode: String?
    public let visioJoinUrl: String?
    public let visioGuestJoinUrl: String?
    public let invitedFriends: [String]
    public let invitedGuests: [String]
    public let sourceMessageId: String?
    public let createdAtUtc: String

    public var id: String { eventId }

    public var startDate: Date {
        VipleCalendarParser.parseISODate(startUtc) ?? Date()
    }

    public var endDate: Date {
        VipleCalendarParser.parseISODate(endUtc) ?? startDate.addingTimeInterval(3600)
    }
}

public struct VipleAgendaListResponse: Codable, Sendable {
    public let ok: Bool
    public let events: [VipleAgendaEvent]?
}

public struct VipleAgendaCreateResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let eventItem: VipleAgendaEvent?
    public let events: [VipleAgendaEvent]?
    public let emailsSent: Int?
    public let formula: String?
}

public struct VipleAgendaSendLinkResponse: Codable, Sendable {
    public let ok: Bool
    public let error: String?
    public let guestJoinUrl: String?
    public let sentCount: Int?
    public let message: String?
}

public struct VipleAgendaImportResponse: Codable, Sendable {
    public let ok: Bool
    public let alreadyImported: Bool?
    public let eventItem: VipleAgendaEvent?
    public let events: [VipleAgendaEvent]?
    public let message: String?
    public let error: String?
}

public struct ParsedVipleCalendarInvite: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let location: String
    public let visioJoinUrl: String?
    public let notes: String
    public let organizerEmail: String
    public let organizerName: String
    public let sourceMessageId: String?
}

public enum VipleCalendarParser {
    public static func parseISODate(_ raw: String?) -> Date? {
        guard let clean = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else {
            return nil
        }
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: clean) { return d }

        let isoStd = ISO8601DateFormatter()
        isoStd.formatOptions = [.withInternetDateTime]
        if let d = isoStd.date(from: clean) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        for fmt in ["yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd HH:mm", "dd/MM/yyyy HH:mm"] {
            df.dateFormat = fmt
            if let d = df.date(from: clean) { return d }
        }
        return nil
    }

    public static func formatISOUtc(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.string(from: date)
    }

    public static func buildFormulaTag(
        title: String,
        start: Date,
        end: Date,
        location: String,
        visioUrl: String?,
        notes: String
    ) -> String {
        func sanitize(_ s: String?) -> String {
            (s ?? "")
                .replacingOccurrences(of: "|", with: " - ")
                .replacingOccurrences(of: "]", with: ")")
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "#viplecalandar[\(sanitize(title)) | \(formatISOUtc(start)) | \(formatISOUtc(end)) | \(sanitize(location)) | \(sanitize(visioUrl)) | \(sanitize(notes))]"
    }

    /// Extrait toute invitation #viplecalandar (structurée ou saisie libre) depuis le corps d'un courrier.
    public static func extractInvites(
        fromPlain plain: String,
        html: String,
        defaultTitle: String,
        organizerEmail: String,
        organizerName: String,
        messageId: String?
    ) -> [ParsedVipleCalendarInvite] {
        let combined = "\(plain)\n\(html)"
        let lower = combined.lowercased()
        guard lower.contains("#viplecalandar") || lower.contains("#viplecalendar") || lower.contains("data-viplecalandar") else {
            return []
        }

        var results: [ParsedVipleCalendarInvite] = []
        var seenKeys: Set<String> = []

        if let regex = try? NSRegularExpression(pattern: "#viplecal(?:a|e)ndar\\[([^\\]]+)\\]", options: [.caseInsensitive]) {
            let nsRange = NSRange(combined.startIndex..<combined.endIndex, in: combined)
            for match in regex.matches(in: combined, options: [], range: nsRange) {
                guard match.numberOfRanges > 1, let r = Range(match.range(at: 1), in: combined) else { continue }
                let inside = String(combined[r])
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                let parts = inside.split(separator: "|", omittingEmptySubsequences: false).map {
                    String($0).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                let rawTitle = parts.count > 0 && !parts[0].isEmpty ? parts[0] : defaultTitle
                let startDt = (parts.count > 1 ? parseISODate(parts[1]) : nil) ?? Date().addingTimeInterval(3600)
                let endDt = (parts.count > 2 ? parseISODate(parts[2]) : nil) ?? startDt.addingTimeInterval(3600)
                let loc = parts.count > 3 ? parts[3] : ""
                let visioRaw = parts.count > 4 && parts[4].lowercased().hasPrefix("https://") ? parts[4] : nil
                let notes = parts.count > 5 ? parts[5] : ""

                let dedupe = "\(rawTitle.lowercased())|\(Int(startDt.timeIntervalSince1970))"
                guard !seenKeys.contains(dedupe) else { continue }
                seenKeys.insert(dedupe)

                results.append(ParsedVipleCalendarInvite(
                    id: "\(messageId ?? "msg")-\(results.count)",
                    title: rawTitle,
                    startDate: startDt,
                    endDate: endDt > startDt ? endDt : startDt.addingTimeInterval(3600),
                    location: loc,
                    visioJoinUrl: visioRaw,
                    notes: notes,
                    organizerEmail: organizerEmail,
                    organizerName: organizerName,
                    sourceMessageId: messageId
                ))
            }
        }

        // Si l'expéditeur a tapé simplement "#viplecalandar" à la main sans crochets structurés
        if results.isEmpty {
            let fallbackStart = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
            let fallbackEnd = fallbackStart.addingTimeInterval(3600)
            var detectedVisio: String? = nil
            if let urlRx = try? NSRegularExpression(pattern: "https://visio\\.prod\\.viple\\.digital/r/[A-Za-z0-9_\\-?=&%]+", options: [.caseInsensitive]) {
                let nsRange = NSRange(combined.startIndex..<combined.endIndex, in: combined)
                if let m = urlRx.firstMatch(in: combined, options: [], range: nsRange), let r = Range(m.range, in: combined) {
                    detectedVisio = String(combined[r])
                }
            }
            let cleanSubj = defaultTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            results.append(ParsedVipleCalendarInvite(
                id: "\(messageId ?? "msg")-freehand",
                title: cleanSubj.isEmpty ? "Rendez-vous proposé par \(organizerName)" : cleanSubj,
                startDate: fallbackStart,
                endDate: fallbackEnd,
                location: detectedVisio != nil ? "Salon Viple Visio" : "",
                visioJoinUrl: detectedVisio,
                notes: "",
                organizerEmail: organizerEmail,
                organizerName: organizerName,
                sourceMessageId: messageId
            ))
        }

        return results
    }
}
