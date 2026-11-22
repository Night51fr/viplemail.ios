import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Client Réseau REST Natif « Viple Mail » (Serveurs officiels mail.viplemail.fr, identity-v2.viple.digital & sso.prod.cenelis.com)

public final class VipleMailTLSSessionDelegate: NSObject, URLSessionDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host.lowercased()
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           (host.hasSuffix("viplemail.fr")
            || host.hasSuffix("cenelis.com")
            || host.hasSuffix("cenelis.fr")
            || host.hasSuffix("viple.digital")
            || host.hasSuffix("livria.store")
            || host.hasSuffix("viplenetwork.com")),
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
            return
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

@MainActor
public final class VipleMailAPIClient {
    public static let shared = VipleMailAPIClient()

    public let primaryBaseURL = "https://mail.viplemail.fr/api/mobile/v1/mail"
    public let fallbackBaseURL = "https://viplemail.fr/api/mobile/v1/mail"
    public let webmailBaseURL = "https://mail.viplemail.fr"
    public let identityBaseURL = "https://identity-v2.viple.digital"
    public let cenelisSsoBaseURL = "https://sso.prod.cenelis.com"
    public let vipleApiBaseURL = "https://api.viple.digital"
    public let imapHost = "imap.viplemail.fr"
    public let imapPort = 993
    public let smtpHost = "smtp.viplemail.fr"
    public let smtpStartTlsPort = 587
    public let smtpImplicitTlsPort = 465
    public let autodiscoverHost = "autodiscover.viplemail.fr"
    public let livriaSsoBaseURL = "https://livria.store/api/mobile/v1"

    public var authToken: String? = nil

    private let session: URLSession
    private let tlsDelegate: VipleMailTLSSessionDelegate
    private let decoder: JSONDecoder

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 20
        cfg.timeoutIntervalForResource = 35
        let delegate = VipleMailTLSSessionDelegate()
        self.tlsDelegate = delegate
        self.session = URLSession(configuration: cfg, delegate: delegate, delegateQueue: nil)
        self.decoder = JSONDecoder()
    }

    public var resolvedDeviceIdentifier: String {
        #if canImport(UIKit)
        if let idfv = UIDevice.current.identifierForVendor?.uuidString,
           !idfv.isEmpty,
           idfv != "00000000-0000-0000-0000-000000000000" {
            UserDefaults(suiteName: "group.store.livria.shared")?.set(idfv, forKey: "viple.shared.deviceId")
            UserDefaults.standard.set(idfv, forKey: "viple.local.deviceId")
            return idfv
        }
        #endif
        if let shared = UserDefaults(suiteName: "group.store.livria.shared")?.string(forKey: "viple.shared.deviceId"),
           !shared.isEmpty {
            return shared
        }
        if let saved = UserDefaults.standard.string(forKey: "viple.local.deviceId"), !saved.isEmpty {
            return saved
        }
        let generated = UUID().uuidString
        UserDefaults.standard.set(generated, forKey: "viple.local.deviceId")
        return generated
    }

    private func applyDeviceHeaders(to req: inout URLRequest) async {
        req.setValue("Viple Mail", forHTTPHeaderField: "X-Viple-App-Name")
        req.setValue("2026.11.6", forHTTPHeaderField: "X-Viple-Client-Version")
        req.setValue("1.0", forHTTPHeaderField: "X-Cenelis-MailRTE-Version")
        req.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Viple-Request-Id")
        req.setValue("VipleMail-iOS/2026.11.6 (iPhone; iOS 18.0+; mail.viplemail.fr; MailRTE/1.0)", forHTTPHeaderField: "User-Agent")
        let currentToken = authToken ?? ""
        if !currentToken.isEmpty {
            req.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
        }
        if let targetURL = req.url,
           let dpopJwt = try? await AppAttestManager.shared.buildDpopProofJwt(
               httpMethod: req.httpMethod ?? "GET",
               targetURL: targetURL,
               accessToken: currentToken
           ) {
            req.setValue(dpopJwt, forHTTPHeaderField: "DPoP")
        }
        let devId = resolvedDeviceIdentifier
        if !devId.isEmpty {
            req.setValue(devId, forHTTPHeaderField: "X-Viple-Vendor-Id")
            req.setValue(devId, forHTTPHeaderField: "X-Viple-Device-Id")
        }
        #if canImport(UIKit)
        let dev = UIDevice.current
        let bounds = UIScreen.main.bounds
        let sig = "\(dev.model)|\(dev.systemName)-\(dev.systemVersion)|\(Int(bounds.width))x\(Int(bounds.height))"
        req.setValue(sig, forHTTPHeaderField: "X-Viple-Device-Info")
        #endif
    }

    public func getJSON<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        do {
            return try await performGet(base: primaryBaseURL, path: path, queryItems: queryItems)
        } catch {
            if !path.hasPrefix("http") {
                return try await performGet(base: fallbackBaseURL, path: path, queryItems: queryItems)
            }
            throw error
        }
    }

    private func performGet<T: Decodable>(base: String, path: String, queryItems: [URLQueryItem]) async throws -> T {
        var comps = URLComponents(string: path.hasPrefix("http") ? path : "\(base)\(path)")!
        if !queryItems.isEmpty {
            comps.queryItems = queryItems
        }
        guard let url = comps.url else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        await applyDeviceHeaders(to: &req)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? "Erreur serveur Viple Mail (\(http.statusCode))"
                throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur Viple Mail (\(http.statusCode))"])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postJSON<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        do {
            return try await performPost(base: primaryBaseURL, path: path, body: body)
        } catch let err as NSError where err.domain == "VipleMailAPI" {
            throw err
        } catch {
            if !path.hasPrefix("http") {
                return try await performPost(base: fallbackBaseURL, path: path, body: body)
            }
            throw error
        }
    }

    private func performPost<T: Decodable>(base: String, path: String, body: [String: Any]) async throws -> T {
        guard let url = URL(string: path.hasPrefix("http") ? path : "\(base)\(path)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        await applyDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? "Erreur serveur Viple Mail (\(http.statusCode))"
                throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur Viple Mail (\(http.statusCode))"])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postRaw(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        do {
            return try await performPostRaw(base: primaryBaseURL, path: path, body: body)
        } catch let err as NSError where err.domain == "VipleMailAPI" {
            throw err
        } catch {
            if !path.hasPrefix("http") {
                return try await performPostRaw(base: fallbackBaseURL, path: path, body: body)
            }
            throw error
        }
    }

    private func performPostRaw(base: String, path: String, body: [String: Any]) async throws -> [String: Any] {
        let urlString = path.hasPrefix("http") ? path : "\(base)\(path)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        await applyDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = (dict["message"] as? String) ?? (dict["error"] as? String) ?? "Impossible d'exécuter l'opération sur Viple Mail."
            throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return dict
    }

    // MARK: - 1. Découverte & Synchronisation SSO Viple Live ID Inter-Applications

    public func discoverCrossAppAccount() async -> VipleCrossAppAccount? {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return nil }
        let items = [
            URLQueryItem(name: "currentApp", value: "Viple Mail"),
            URLQueryItem(name: "vendorId", value: devId),
            URLQueryItem(name: "deviceId", value: devId)
        ]
        if let res: VipleCrossAppDiscoverResponse = try? await getJSON("/sso/discover", queryItems: items),
           res.hasDetectedAccount, let acc = res.account {
            return acc
        }
        if let resLivria: VipleCrossAppDiscoverResponse = try? await getJSON("\(livriaSsoBaseURL)/sso/discover", queryItems: items),
           resLivria.hasDetectedAccount, let acc = resLivria.account {
            return acc
        }
        return nil
    }

    public func announceCrossAppSession(email: String, cid: String?) async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return }
        let payload: [String: Any] = [
            "sourceApp": "Viple Mail",
            "appName": "Viple Mail",
            "email": email,
            "cid": cid ?? "",
            "vendorId": devId,
            "deviceId": devId
        ]
        _ = try? await postRaw("/sso/announce", body: payload)
        _ = try? await postRaw("\(livriaSsoBaseURL)/sso/announce", body: payload)
    }

    public func clearCrossAppSession() async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return }
        let payload: [String: Any] = [
            "sourceApp": "Viple Mail",
            "appName": "Viple Mail",
            "vendorId": devId,
            "deviceId": devId
        ]
        _ = try? await postRaw("/sso/clear", body: payload)
        _ = try? await postRaw("\(livriaSsoBaseURL)/sso/clear", body: payload)
    }

    public func acceptCrossAppAccount(email: String, cid: String?) async throws -> VipleMailAuthResponse {
        let devId = resolvedDeviceIdentifier
        return try await postJSON("/sso/accept", body: [
            "email": email,
            "cid": cid ?? "",
            "vendorId": devId,
            "deviceId": devId
        ])
    }

    // MARK: - 2. Authentification Viple Live ID & Sign in with Apple

    public func loginVipleLiveID(email: String, password: String) async throws -> VipleMailAuthResponse {
        return try await postJSON("/auth/login", body: [
            "email": email,
            "password": password
        ])
    }

    public func registerVipleLiveID(
        emailMode: String,
        emailUser: String,
        customEmail: String,
        password: String,
        firstName: String,
        lastName: String,
        displayName: String
    ) async throws -> VipleMailAuthResponse {
        return try await postJSON("/auth/register", body: [
            "emailMode": emailMode,
            "emailUser": emailUser,
            "customEmail": customEmail,
            "email": emailMode == "viplemail" ? "\(emailUser)@viplemail.fr" : customEmail,
            "password": password,
            "firstName": firstName,
            "lastName": lastName,
            "displayName": displayName
        ])
    }

    public func signInWithApple(
        appleUserId: String,
        identityToken: String?,
        email: String?,
        firstName: String?,
        lastName: String?
    ) async throws -> VipleMailAuthResponse {
        var payload: [String: Any] = ["appleUserId": appleUserId]
        if let identityToken { payload["identityToken"] = identityToken }
        if let email { payload["email"] = email }
        if let firstName { payload["firstName"] = firstName }
        if let lastName { payload["lastName"] = lastName }
        return try await postJSON("/auth/apple", body: payload)
    }

    public func completeAppleSignup(
        appleUserId: String,
        appleEmail: String?,
        firstName: String,
        lastName: String,
        displayName: String,
        vipleMailUser: String
    ) async throws -> VipleMailAuthResponse {
        return try await postJSON("/auth/apple-complete", body: [
            "appleUserId": appleUserId,
            "appleEmail": appleEmail ?? "",
            "firstName": firstName,
            "lastName": lastName,
            "displayName": displayName,
            "vipleMailUser": vipleMailUser
        ])
    }

    public func linkAppleToExistingAccount(
        appleUserId: String,
        appleEmail: String?,
        email: String,
        password: String
    ) async throws -> VipleMailAuthResponse {
        return try await postJSON("/auth/apple-link-existing", body: [
            "appleUserId": appleUserId,
            "appleEmail": appleEmail ?? "",
            "email": email,
            "password": password
        ])
    }

    // MARK: - 3. Opérations Boîte aux Lettres, Messages, Contacts & Réglages

    public func fetchBootstrap(email: String?, cid: String?, folder: String = "Inbox") async throws -> VipleMailBootstrapResponse {
        var items: [URLQueryItem] = [URLQueryItem(name: "folder", value: folder)]
        if let email, !email.isEmpty {
            items.append(URLQueryItem(name: "email", value: email))
        }
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/bootstrap", queryItems: items)
    }

    public func fetchMessageDetail(messageId: String, email: String, cid: String?) async throws -> VipleMailMessageDetailResponse {
        var items: [URLQueryItem] = [URLQueryItem(name: "email", value: email)]
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        let escapedId = messageId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? messageId
        return try await getJSON("/messages/\(escapedId)", queryItems: items)
    }

    public func checkDiagnosticsPing() async throws -> VipleMailDiagnosticsPing {
        return try await getJSON("/diagnostics/ping")
    }

    public func switchMailbox(
        to targetMailbox: String,
        currentEmail: String,
        cid: String?
    ) async throws -> VipleMailSwitchMailboxResponse {
        let body: [String: Any] = [
            "mailbox": targetMailbox,
            "currentEmail": currentEmail,
            "cid": cid ?? ""
        ]
        do {
            return try await postJSON("/switch-mailbox", body: body)
        } catch {
            return try await postJSON("\(webmailBaseURL)/api/web/switch-mailbox", body: body)
        }
    }

    public func updateImapPassword(password: String, email: String? = nil, cid: String? = nil) async throws -> String {
        var payload: [String: Any] = ["password": password]
        if let email, !email.isEmpty { payload["email"] = email }
        if let cid, !cid.isEmpty { payload["cid"] = cid }
        let res: [String: Any]
        do {
            res = try await postRaw("/imap-password", body: payload)
        } catch {
            res = try await postRaw("\(webmailBaseURL)/api/v1/imap-password", body: payload)
        }
        return (res["message"] as? String) ?? "Mot de passe IMAP/SMTP mis à jour sur \(imapHost) & \(smtpHost)."
    }

    public func appleProfileDownloadURL(for email: String) -> URL? {
        guard let encoded = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              !encoded.isEmpty else { return nil }
        return URL(string: "\(webmailBaseURL)/api/v1/apple-profile.mobileconfig?email=\(encoded)")
    }

    // MARK: - 3a. Comptes E-Mail Externes (IMAP / SMTP : Gmail, Outlook, iCloud, Yahoo, Orange, OVH, Pro...)

    public func fetchExternalAccounts(ownerEmail: String?, cid: String?) async throws -> ExternalMailAccountListResponse {
        var items: [URLQueryItem] = []
        if let ownerEmail, !ownerEmail.isEmpty {
            items.append(URLQueryItem(name: "email", value: ownerEmail))
        }
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/external-accounts", queryItems: items)
    }

    public func autodiscoverExternalAccount(email: String) async throws -> ExternalMailAutodiscoverResponse {
        return try await getJSON("/external-accounts/autodiscover", queryItems: [
            URLQueryItem(name: "email", value: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        ])
    }

    public func testExternalAccount(
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
    ) async throws -> ExternalMailTestResponse {
        return try await postJSON("/external-accounts/test", body: [
            "externalEmail": externalEmail,
            "imapHost": imapHost,
            "imapPort": imapPort,
            "imapSecurity": imapSecurity,
            "imapUsername": imapUsername,
            "imapPassword": imapPassword,
            "canSendSmtp": canSendSmtp,
            "smtpHost": smtpHost,
            "smtpPort": smtpPort,
            "smtpSecurity": smtpSecurity,
            "smtpUsername": smtpUsername,
            "smtpPassword": smtpPassword
        ])
    }

    public func addExternalAccount(
        ownerEmail: String,
        cid: String?,
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
        smtpPassword: String
    ) async throws -> ExternalMailAccountActionResponse {
        var body: [String: Any] = [
            "ownerEmail": ownerEmail,
            "cid": cid ?? "",
            "externalEmail": externalEmail,
            "displayName": displayName,
            "imapHost": imapHost,
            "imapPort": imapPort,
            "imapSecurity": imapSecurity,
            "imapUsername": imapUsername,
            "imapPassword": imapPassword,
            "canSendSmtp": canSendSmtp,
            "smtpHost": smtpHost,
            "smtpPort": smtpPort,
            "smtpSecurity": smtpSecurity,
            "smtpUsername": smtpUsername,
            "smtpPassword": smtpPassword
        ]
        if let providerName, !providerName.isEmpty { body["providerName"] = providerName }
        if let colorHex, !colorHex.isEmpty { body["colorHex"] = colorHex }
        return try await postJSON("/external-accounts/add", body: body)
    }

    public func deleteExternalAccount(
        ownerEmail: String,
        cid: String?,
        accountId: String?,
        externalEmail: String?
    ) async throws -> ExternalMailAccountActionResponse {
        return try await postJSON("/external-accounts/delete", body: [
            "ownerEmail": ownerEmail,
            "cid": cid ?? "",
            "accountId": accountId ?? "",
            "externalEmail": externalEmail ?? ""
        ])
    }

    // MARK: - 3b. Discussions Instantanées « Chat @viplemail.fr »

    public func fetchChatSessions(email: String, cid: String?) async throws -> VipleChatSessionsResponse {
        var items: [URLQueryItem] = [URLQueryItem(name: "email", value: email)]
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/chat/sessions", queryItems: items)
    }

    public func fetchChatMessages(
        sessionId: String?,
        peerEmail: String?,
        email: String,
        cid: String?
    ) async throws -> VipleChatMessagesResponse {
        var items: [URLQueryItem] = [URLQueryItem(name: "email", value: email)]
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        if let sessionId, !sessionId.isEmpty {
            items.append(URLQueryItem(name: "sessionId", value: sessionId))
        }
        if let peerEmail, !peerEmail.isEmpty {
            items.append(URLQueryItem(name: "peerEmail", value: peerEmail))
        }
        return try await getJSON("/chat/messages", queryItems: items)
    }

    public func sendChatMessage(
        senderEmail: String,
        senderCid: String?,
        recipientEmail: String,
        bodyText: String,
        attachments: [VipleMailAttachment]
    ) async throws -> VipleChatSendResponse {
        let encodedAtts: [[String: Any]] = attachments.map { att in
            [
                "id": att.id,
                "fileName": att.fileName,
                "mimeType": att.mimeType,
                "sizeBytes": att.sizeBytes,
                "url": att.url
            ]
        }
        return try await postJSON("/chat/send", body: [
            "senderEmail": senderEmail,
            "senderCid": senderCid ?? "",
            "recipientEmail": recipientEmail,
            "bodyText": bodyText,
            "attachments": encodedAtts
        ])
    }

    public func markChatSessionRead(sessionId: String, email: String, cid: String?) async {
        _ = try? await postRaw("/chat/read", body: [
            "sessionId": sessionId,
            "email": email,
            "cid": cid ?? ""
        ])
    }

    public func deleteChatSession(sessionId: String, email: String, cid: String?) async throws {
        _ = try await postRaw("/chat/delete", body: [
            "sessionId": sessionId,
            "email": email,
            "cid": cid ?? ""
        ])
    }

    // MARK: - 4. Notifications Push, Sondage Rapide IMAP & Enregistrement d'Appareil iOS

    public func pollNotifications(email: String, cid: String?, limit: Int = 15) async throws -> VipleMailNotificationPollResponse {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "email", value: email),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let cid, !cid.isEmpty {
            items.append(URLQueryItem(name: "cid", value: cid))
        }
        return try await getJSON("/notifications/poll", queryItems: items)
    }

    public func registerDeviceForPush(
        email: String,
        cid: String?,
        apnsToken: String?,
        notificationsEnabled: Bool,
        vipOnly: Bool
    ) async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty, !email.isEmpty else { return }
        let payload: [String: Any] = [
            "email": email,
            "cid": cid ?? "",
            "deviceId": devId,
            "vendorId": devId,
            "apnsToken": apnsToken ?? "",
            "platform": "iOS",
            "appVersion": "2026.11.2",
            "notificationsEnabled": notificationsEnabled,
            "vipOnly": vipOnly
        ]
        _ = try? await postRaw("/devices/register", body: payload)
    }

    public func unregisterDeviceForPush(email: String?) async {
        let devId = resolvedDeviceIdentifier
        guard !devId.isEmpty else { return }
        _ = try? await postRaw("/devices/unregister", body: [
            "email": email ?? "",
            "deviceId": devId,
            "vendorId": devId
        ])
    }
}
