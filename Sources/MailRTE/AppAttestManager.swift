import Foundation
import CryptoKit
import DeviceCheck
import LocalAuthentication
import Security

// MARK: - Erreurs d'Attestation Matérielle & Liaison DPoP

public enum MailRteAttestError: LocalizedError, Sendable {
    case appAttestUnsupported
    case keychainFailure(OSStatus)
    case invalidChallengeResponse
    case serverAttestationRejected(String)
    case biometricAuthenticationFailed
    case compromisedEnvironment(String)

    public var errorDescription: String? {
        switch self {
        case .appAttestUnsupported:
            return "Cet appareil ne prend pas en charge l'attestation matérielle Secure Enclave (DCAppAttestService)."
        case .keychainFailure(let status):
            return "Erreur d'accès au trousseau matériel iOS (OSStatus \(status))."
        case .invalidChallengeResponse:
            return "Réponse de challenge cryptographique Cenelis invalide."
        case .serverAttestationRejected(let detail):
            return "Attestation matérielle refusée par Cenelis MailRTE : \(detail)"
        case .biometricAuthenticationFailed:
            return "Authentification biométrique Face ID / Touch ID requise par la politique de sécurité."
        case .compromisedEnvironment(let reason):
            return "Environnement iOS non conforme détecté (\(reason)). Session révoquée."
        }
    }
}

// MARK: - DTOs d'Enrôlement & Challenge

public struct MailRteChallengeResponse: Codable, Sendable {
    public let challengeId: String
    public let nonceBase64Url: String
    public let expiresAtUtc: String
    public let serverEd25519PublicKeyBase64: String
}

private struct MailRteChallengeRequest: Codable, Sendable {
    let purpose: String
    let mailId: String?
}

private struct MailRteAttestPayload: Codable, Sendable {
    let keyId: String
    let nonceBase64Url: String
    let attestationObjectBase64: String
}

// MARK: - Gestionnaire Matériel DCAppAttestService + Clé DPoP Liée à l'Appareil

public actor AppAttestManager {
    public static let shared = AppAttestManager()

    private let keychainService = "com.viplenetwork.viplemail.mailrte"
    private let attestKeyIdAccount = "dcappattest.key_id.v1"
    private let attestEnrolledFlagAccount = "dcappattest.enrolled.v1"
    private let dpopPrivateKeyAccount = "dpop.p256.privkey.v1"
    private let serverSignPubKeyAccount = "server.ed25519.pubkey.v1"

    private init() {}

    // MARK: - Cycle de vie DCAppAttestService (Couche 1)

    /// Garantit que l'appareil possède une clé Secure Enclave attestée auprès du serveur Cenelis MailRTE.
    public func ensureDeviceAttested(
        baseURL: URL,
        accessToken: String,
        urlSession: URLSession,
        requireBiometrics: Bool = false
    ) async throws -> String {
        if requireBiometrics {
            try await authenticateWithBiometricsIfRequired()
        }

        if let existingKeyId = try readKeychainString(account: attestKeyIdAccount),
           let enrolledFlag = try readKeychainString(account: attestEnrolledFlagAccount),
           enrolledFlag == "1" {
            return existingKeyId
        }

        let service = DCAppAttestService.shared
        guard service.isSupported else {
            throw MailRteAttestError.appAttestUnsupported
        }

        // 1. Génération d'une paire de clés matérielle dans la Secure Enclave via DCAppAttestService
        let keyId = try await service.generateKey()
        try saveKeychainData(Data(keyId.utf8), account: attestKeyIdAccount)
        try saveKeychainData(Data("0".utf8), account: attestEnrolledFlagAccount)

        // 2. Récupération d'un challenge serveur unique signé sous preuve DPoP
        let challenge = try await fetchServerChallenge(
            purpose: "ATTEST",
            mailId: nil,
            baseURL: baseURL,
            accessToken: accessToken,
            urlSession: urlSession
        )

        if !challenge.serverEd25519PublicKeyBase64.isEmpty,
           let srvPubData = Data(base64Encoded: challenge.serverEd25519PublicKeyBase64) {
            try saveKeychainData(srvPubData, account: serverSignPubKeyAccount)
        }

        // 3. Calcul du clientDataHash liant le challenge serveur au thumbprint JKT DPoP de l'appareil
        let dpopJkt = try currentDpopJwkThumbprint()
        let bindingTranscript = "\(challenge.nonceBase64Url)|\(dpopJkt)"
        let clientDataHash = Data(SHA256.hash(data: Data(bindingTranscript.utf8)))

        // 4. Appel matériel Apple pour produire l'objet CBOR d'attestation X.509
        let attestationObject = try await service.attestKey(keyId, clientDataHash: clientDataHash)

        // 5. Envoi de l'attestation CBOR au serveur Cenelis MailRTE
        let attestURL = baseURL.appendingPathComponent("api/v1/mailrte/attest")
        var req = URLRequest(url: attestURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(
            try buildDpopProofJwt(httpMethod: "POST", targetURL: attestURL, accessToken: accessToken),
            forHTTPHeaderField: "DPoP"
        )

        let body = MailRteAttestPayload(
            keyId: keyId,
            nonceBase64Url: challenge.nonceBase64Url,
            attestationObjectBase64: attestationObject.base64EncodedString()
        )
        req.httpBody = try JSONEncoder().encode(body)

        let (respData, resp) = try await urlSession.data(for: req)
        guard let httpResp = resp as? HTTPURLResponse, (200..<300).contains(httpResp.statusCode) else {
            let errText = String(data: respData, encoding: .utf8) ?? "HTTP Error"
            throw MailRteAttestError.serverAttestationRejected(errText)
        }

        try saveKeychainData(Data("1".utf8), account: attestEnrolledFlagAccount)
        return keyId
    }

    /// Demande un challenge serveur à usage unique (ATTEST ou DECRYPT_ASSERTION).
    public func fetchServerChallenge(
        purpose: String,
        mailId: String?,
        baseURL: URL,
        accessToken: String,
        urlSession: URLSession
    ) async throws -> MailRteChallengeResponse {
        let url = baseURL.appendingPathComponent("api/v1/mailrte/challenge")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("DPoP \(accessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(
            try buildDpopProofJwt(httpMethod: "POST", targetURL: url, accessToken: accessToken),
            forHTTPHeaderField: "DPoP"
        )
        req.httpBody = try JSONEncoder().encode(MailRteChallengeRequest(purpose: purpose, mailId: mailId))

        let (data, resp) = try await urlSession.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw MailRteAttestError.invalidChallengeResponse
        }

        let decoded = try JSONDecoder().decode(MailRteChallengeResponse.self, from: data)
        if let srvPub = Data(base64Encoded: decoded.serverEd25519PublicKeyBase64), !srvPub.isEmpty {
            try? saveKeychainData(srvPub, account: serverSignPubKeyAccount)
        }
        return decoded
    }

    /// Génère une assertion matérielle signée par la Secure Enclave couvrant exactement la transaction de déchiffrement.
    public func generateRealtimeDecryptAssertion(
        keyId: String,
        mailId: String,
        serverNonceBase64Url: String,
        clientTimestampUnix: Int64,
        accessToken: String,
        clientEphemeralX25519PubBase64: String
    ) async throws -> Data {
        let ath = Self.base64UrlEncode(Data(SHA256.hash(data: Data(accessToken.utf8))))
        let canonicalTranscript = "Cenelis.MailRTE.Assert.v1|\(mailId)|\(serverNonceBase64Url)|\(clientTimestampUnix)|\(ath)|\(clientEphemeralX25519PubBase64)"
        let clientDataHash = Data(SHA256.hash(data: Data(canonicalTranscript.utf8)))
        return try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: clientDataHash)
    }

    public func cachedServerEd25519PublicKey() throws -> Data? {
        try readKeychainData(account: serverSignPubKeyAccount)
    }

    // MARK: - Liaison Forte Identité & Appareil DPoP RFC 9449 (Couche 2)

    /// Construit un jeton JWS DPoP (typ="dpop+jwt", alg="ES256") signé par la clé liée au Keychain de cet appareil uniquement.
    public func buildDpopProofJwt(
        httpMethod: String,
        targetURL: URL,
        accessToken: String
    ) throws -> String {
        let signingKey = try loadOrCreateDeviceBoundDpopKey()
        let pubRaw = signingKey.publicKey.x963Representation // 0x04 || X (32) || Y (32)
        let xB64Url = Self.base64UrlEncode(pubRaw.subdata(in: 1..<33))
        let yB64Url = Self.base64UrlEncode(pubRaw.subdata(in: 33..<65))

        let headerObj: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": [
                "kty": "EC",
                "crv": "P-256",
                "x": xB64Url,
                "y": yB64Url
            ]
        ]

        var components = URLComponents(url: targetURL, resolvingAgainstBaseURL: false)
        components?.query = nil
        components?.fragment = nil
        let htu = components?.string ?? targetURL.absoluteString

        let ath = Self.base64UrlEncode(Data(SHA256.hash(data: Data(accessToken.utf8))))
        let payloadObj: [String: Any] = [
            "htm": httpMethod.uppercased(),
            "htu": htu,
            "iat": Int64(Date().timeIntervalSince1970),
            "jti": UUID().uuidString.lowercased(),
            "ath": ath
        ]

        let headerB64 = Self.base64UrlEncode(try JSONSerialization.data(withJSONObject: headerObj))
        let payloadB64 = Self.base64UrlEncode(try JSONSerialization.data(withJSONObject: payloadObj))
        let signingInput = "\(headerB64).\(payloadB64)"

        // Signature ECDSA P-256 au format JWS IEEE P1363 (r || s de 64 octets)
        let signature = try signingKey.signature(for: Data(signingInput.utf8))
        let sigB64 = Self.base64UrlEncode(signature.rawRepresentation)
        return "\(signingInput).\(sigB64)"
    }

    /// Calcule le thumbprint RFC 7638 SHA-256 de la clé publique DPoP de l'appareil.
    public func currentDpopJwkThumbprint() throws -> String {
        let signingKey = try loadOrCreateDeviceBoundDpopKey()
        let pubRaw = signingKey.publicKey.x963Representation
        let x = Self.base64UrlEncode(pubRaw.subdata(in: 1..<33))
        let y = Self.base64UrlEncode(pubRaw.subdata(in: 33..<65))
        let canonicalJwk = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
        let digest = SHA256.hash(data: Data(canonicalJwk.utf8))
        return Self.base64UrlEncode(Data(digest))
    }

    /// Révoque et détruit immédiatement toutes les clés locales (appelé par SecurityGuard en cas d'anomalie runtime).
    public func revokeLocalHardwareSession() {
        deleteKeychainItem(account: attestKeyIdAccount)
        deleteKeychainItem(account: attestEnrolledFlagAccount)
        deleteKeychainItem(account: dpopPrivateKeyAccount)
    }

    // MARK: - Gestion Keychain Matériel (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)

    private func loadOrCreateDeviceBoundDpopKey() throws -> P256.Signing.PrivateKey {
        if let raw = try readKeychainData(account: dpopPrivateKeyAccount) {
            return try P256.Signing.PrivateKey(rawRepresentation: raw)
        }
        let created = P256.Signing.PrivateKey()
        try saveKeychainData(created.rawRepresentation, account: dpopPrivateKeyAccount)
        return created
    }

    private func authenticateWithBiometricsIfRequired() async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw MailRteAttestError.biometricAuthenticationFailed
        }
        let ok = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Déverrouiller le chiffrement Cenelis MailRTE"
        )
        if !ok {
            throw MailRteAttestError.biometricAuthenticationFailed
        }
    }

    private func saveKeychainData(_ data: Data, account: String) throws {
        deleteKeychainItem(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MailRteAttestError.keychainFailure(status)
        }
    }

    private func readKeychainData(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw MailRteAttestError.keychainFailure(status)
        }
        return item as? Data
    }

    private func readKeychainString(account: String) throws -> String? {
        guard let data = try readKeychainData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychainItem(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    public static func base64UrlEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
