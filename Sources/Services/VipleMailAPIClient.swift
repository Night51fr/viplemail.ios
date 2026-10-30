import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Client Réseau REST Natif « Viple Mail » (Connecté à mail.live.viplenetwork.com & identity-v2.viple.digital)

public final class VipleMailTLSSessionDelegate: NSObject, URLSessionDelegate, Sendable {
    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let host = challenge.protectionSpace.host.lowercased()
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           (host.hasSuffix("viplenetwork.com") || host.hasSuffix("viple.digital") || host.hasSuffix("livria.store")),
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

    public let primaryBaseURL = "https://mail.live.viplenetwork.com/api/mobile/v1/mail"
    public let fallbackBaseURL = "https://live.viplenetwork.com/api/mobile/v1/mail"
    public let livriaSsoBaseURL = "https://livria.store/api/mobile/v1"

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

    private func applyDeviceHeaders(to req: inout URLRequest) {
        req.setValue("Viple Mail", forHTTPHeaderField: "X-Viple-App-Name")
        req.setValue("2026.11", forHTTPHeaderField: "X-Viple-Client-Version")
        req.setValue(UUID().uuidString.lowercased(), forHTTPHeaderField: "X-Viple-Request-Id")
        req.setValue("VipleMail-iOS/2026.11 (iPhone; iOS 18.0+; VipleLiveID)", forHTTPHeaderField: "User-Agent")
        #if canImport(UIKit)
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString, !vendorId.isEmpty {
            req.setValue(vendorId, forHTTPHeaderField: "X-Viple-Vendor-Id")
        }
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
        applyDeviceHeaders(to: &req)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["error"] as? String {
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
        applyDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = dict["error"] as? String {
                throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
            }
            throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Erreur serveur Viple Mail (\(http.statusCode))"])
        }
        return try decoder.decode(T.self, from: data)
    }

    public func postRaw(_ path: String, body: [String: Any]) async throws -> [String: Any] {
        let urlString = path.hasPrefix("http") ? path : "\(primaryBaseURL)\(path)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        applyDeviceHeaders(to: &req)
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: req)
        let dict = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let msg = (dict["error"] as? String) ?? "Impossible d'exécuter l'opération sur Viple Mail."
            throw NSError(domain: "VipleMailAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
        return dict
    }

    // MARK: - 1. Découverte & Synchronisation SSO Viple Live ID Inter-Applications

    public func discoverCrossAppAccount() async -> VipleCrossAppAccount? {
        let items = [URLQueryItem(name: "currentApp", value: "Viple Mail")]
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
        let payload: [String: Any] = [
            "sourceApp": "Viple Mail",
            "appName": "Viple Mail",
            "email": email,
            "cid": cid ?? ""
        ]
        _ = try? await postRaw("/sso/announce", body: payload)
        _ = try? await postRaw("\(livriaSsoBaseURL)/sso/announce", body: payload)
    }

    public func clearCrossAppSession() async {
        let payload: [String: Any] = [
            "sourceApp": "Viple Mail",
            "appName": "Viple Mail"
        ]
        _ = try? await postRaw("/sso/clear", body: payload)
        _ = try? await postRaw("\(livriaSsoBaseURL)/sso/clear", body: payload)
    }

    public func acceptCrossAppAccount(email: String, cid: String?) async throws -> VipleMailAuthResponse {
        return try await postJSON("/sso/accept", body: [
            "email": email,
            "cid": cid ?? ""
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
}
