import Foundation
import CryptoKit
import Darwin

// MARK: - Modèles Client du Conteneur MailRTE (.mrte) & Session Volatile

public struct MailRteDlpPolicyModel: Codable, Sendable, Equatable {
    public let preventScreenshot: Bool
    public let preventCopy: Bool
    public let maxTtlSeconds: Int

    enum CodingKeys: String, CodingKey {
        case preventScreenshot = "prevent_screenshot"
        case preventCopy = "prevent_copy"
        case maxTtlSeconds = "max_ttl_seconds"
    }
}

public struct MailRteEncryptedPartModel: Codable, Sendable {
    public let partId: String
    public let contentType: String
    public let fileName: String?
    public let iv: String
    public let aadHash: String
    public let ciphertext: String
    public let authTag: String

    enum CodingKeys: String, CodingKey {
        case partId = "part_id"
        case contentType = "content_type"
        case fileName = "file_name"
        case iv
        case aadHash = "aad_hash"
        case ciphertext
        case authTag = "auth_tag"
    }
}

public struct MailRteSignatureModel: Codable, Sendable {
    public let algorithm: String
    public let signerKeyId: String
    public let ed25519Sig: String
    public let mldsa65Sig: String

    enum CodingKeys: String, CodingKey {
        case algorithm
        case signerKeyId = "signer_key_id"
        case ed25519Sig = "ed25519_sig"
        case mldsa65Sig = "mldsa65_sig"
    }
}

public struct MailRteClientContainer: Codable, Sendable {
    public let version: String
    public let mailId: String
    public let tenantId: String
    public let sender: String
    public let recipient: String
    public let timestampUnix: Int64
    public let status: String
    public let dlpPolicy: MailRteDlpPolicyModel
    public let iv: String
    public let aadHash: String
    public let ciphertext: String
    public let authTag: String
    public let encryptedSubject: MailRteEncryptedPartModel
    public let attachments: [MailRteEncryptedPartModel]
    public let signature: MailRteSignatureModel

    enum CodingKeys: String, CodingKey {
        case version
        case mailId = "mail_id"
        case tenantId = "tenant_id"
        case sender
        case recipient
        case timestampUnix = "timestamp_unix"
        case status
        case dlpPolicy = "dlp_policy"
        case iv
        case aadHash = "aad_hash"
        case ciphertext
        case authTag = "auth_tag"
        case encryptedSubject = "encrypted_subject"
        case attachments
        case signature
    }
}

public enum MailRteClientError: LocalizedError, Sendable {
    case mailRevokedOrExpired
    case serverRejection(Int, String)
    case ephemeralDekExpired
    case invalidServerSignature
    case invalidBase64Material
    case aadIntegrityMismatch
    case utf8DecodingFailed

    public var errorDescription: String? {
        switch self {
        case .mailRevokedOrExpired:
            return "Ce message Cenelis MailRTE a été révoqué par l'expéditeur ou l'administrateur."
        case .serverRejection(let code, let detail):
            return "Déchiffrement temps réel refusé (HTTP \(code)) : \(detail)"
        case .ephemeralDekExpired:
            return "L'enveloppe de clé éphémère temps réel a expiré (> 30s)."
        case .invalidServerSignature:
            return "Signature Ed25519 d'authenticité serveur MailRTE invalide."
        case .invalidBase64Material:
            return "Matériel cryptographique MailRTE malformé."
        case .aadIntegrityMismatch:
            return "Alerte d'intégrité AEAD : les métadonnées AAD du message ont été altérées."
        case .utf8DecodingFailed:
            return "Impossible de décoder le contenu déchiffré UTF-8."
        }
    }
}

private struct RealtimeDecryptWireRequest: Codable, Sendable {
    let mailId: String
    let mailRteHeader: String
    let deviceKeyId: String
    let serverNonceBase64Url: String
    let clientTimestampUnix: Int64
    let assertionObjectBase64: String
    let clientEphemeralX25519PubBase64: String
    let clientEphemeralMlKem768PubBase64: String?
}

private struct RealtimeDecryptWireResponse: Codable, Sendable {
    let mailId: String
    let ephemeralServerX25519PubBase64: String
    let mlKem768CiphertextBase64: String?
    let hkdfSaltBase64: String
    let wrapIvBase64: String
    let wrappedDekBase64: String
    let wrapTagBase64: String
    let issuedAtUnix: Int64
    let expiresAtUnix: Int64
    let serverEd25519SignatureBase64: String
    let dlpPolicy: MailRteDlpPolicyModel
}

// MARK: - Conteneur en Mémoire Volatile Auto-Purgeable (Zéro Persistance Disque)

public final class VolatileDecryptedEmailSession: @unchecked Sendable {
    public let mailId: String
    public let sender: String
    public let recipient: String
    public let dlpPolicy: MailRteDlpPolicyModel

    private var subjectBuffer: Data
    private var bodyBuffer: Data
    private var attachmentBuffers: [(id: String, fileName: String, contentType: String, bytes: Data)]
    private let lock = NSLock()
    private var isWiped = false

    public init(
        mailId: String,
        sender: String,
        recipient: String,
        dlpPolicy: MailRteDlpPolicyModel,
        subjectBytes: Data,
        bodyBytes: Data,
        attachments: [(id: String, fileName: String, contentType: String, bytes: Data)]
    ) {
        self.mailId = mailId
        self.sender = sender
        self.recipient = recipient
        self.dlpPolicy = dlpPolicy
        self.subjectBuffer = subjectBytes
        self.bodyBuffer = bodyBytes
        self.attachmentBuffers = attachments
    }

    deinit {
        wipeFromMemory()
    }

    public var subjectText: String {
        lock.lock()
        defer { lock.unlock() }
        guard !isWiped else { return "" }
        return String(data: subjectBuffer, encoding: .utf8) ?? ""
    }

    public var bodyText: String {
        lock.lock()
        defer { lock.unlock() }
        guard !isWiped else { return "" }
        return String(data: bodyBuffer, encoding: .utf8) ?? ""
    }

    public var attachmentsMetadata: [(id: String, fileName: String, contentType: String, size: Int)] {
        lock.lock()
        defer { lock.unlock() }
        guard !isWiped else { return [] }
        return attachmentBuffers.map { ($0.id, $0.fileName, $0.contentType, $0.bytes.count) }
    }

    /// Efface de manière déterministe tous les tampons en clair de la RAM vive.
    public func wipeFromMemory() {
        lock.lock()
        defer { lock.unlock() }
        guard !isWiped else { return }
        SecureMemory.zeroize(&subjectBuffer)
        SecureMemory.zeroize(&bodyBuffer)
        for index in attachmentBuffers.indices {
            SecureMemory.zeroize(&attachmentBuffers[index].bytes)
        }
        attachmentBuffers.removeAll(keepingCapacity: false)
        isWiped = true
    }
}

public enum SecureMemory {
    /// Écrase physiquement les octets en RAM avec des zéros (memset_s / écriture volatile) avant libération.
    public static func zeroize(_ data: inout Data) {
        let count = data.count
        guard count > 0 else { return }
        data.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            _ = memset_s(baseAddress, count, 0, count)
        }
        data.resetBytes(in: 0..<count)
        data.removeAll(keepingCapacity: false)
    }
}

// MARK: - Service Client de Déchiffrement Temps Réel Cenelis MailRTE (Couche 4)

public actor MailRteClientService {
    public static let shared = MailRteClientService()

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://mail.viplemail.fr")!) {
        self.baseURL = baseURL
        self.session = SecurityGuard.shared.makeHardenedURLSession()
    }

    /// Exécute le pipeline complet à 4 couches et retourne une session déchiffrée uniquement en RAM volatile.
    public func decryptEmailRealtime(
        container: MailRteClientContainer,
        mailRteMimeHeader: String,
        vipleLiveIdAccessToken: String,
        requireBiometrics: Bool = false
    ) async throws -> VolatileDecryptedEmailSession {
        // 1. Couche 3 : Sondes anti-debugging, anti-Frida, anti-jailbreak
        try await SecurityGuard.shared.enforceRuntimeIntegrity()

        guard container.status.uppercased() == "ACTIVE" else {
            throw MailRteClientError.mailRevokedOrExpired
        }

        // 2. Couche 1 & 2 : Enrôlement/Vérification DCAppAttestService + Clé DPoP
        let deviceKeyId = try await AppAttestManager.shared.ensureDeviceAttested(
            baseURL: baseURL,
            accessToken: vipleLiveIdAccessToken,
            urlSession: session,
            requireBiometrics: requireBiometrics
        )

        // 3. Challenge serveur anti-rejeu dédié à ce MailID précis
        let challenge = try await AppAttestManager.shared.fetchServerChallenge(
            purpose: "DECRYPT_ASSERTION",
            mailId: container.mailId,
            baseURL: baseURL,
            accessToken: vipleLiveIdAccessToken,
            urlSession: session
        )

        // 4. Clé éphémère X25519 à usage unique (jamais écrite sur disque, détruite dès sortie de portée)
        let ephemeralClientX25519Priv = Curve25519.KeyAgreement.PrivateKey()
        let ephemeralClientX25519PubB64 = ephemeralClientX25519Priv.publicKey.rawRepresentation.base64EncodedString()
        let clientTimestamp = Int64(Date().timeIntervalSince1970)

        // 5. Assertion matérielle Secure Enclave couvrant MailID + Nonce + Timestamp + ATH + Clé X25519 éphémère
        let assertionCbor = try await AppAttestManager.shared.generateRealtimeDecryptAssertion(
            keyId: deviceKeyId,
            mailId: container.mailId,
            serverNonceBase64Url: challenge.nonceBase64Url,
            clientTimestampUnix: clientTimestamp,
            accessToken: vipleLiveIdAccessToken,
            clientEphemeralX25519PubBase64: ephemeralClientX25519PubB64
        )

        let endpoint = baseURL.appendingPathComponent("api/v1/mailrte/decrypt-realtime")
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("DPoP \(vipleLiveIdAccessToken)", forHTTPHeaderField: "Authorization")
        req.setValue(
            try await AppAttestManager.shared.buildDpopProofJwt(
                httpMethod: "POST",
                targetURL: endpoint,
                accessToken: vipleLiveIdAccessToken
            ),
            forHTTPHeaderField: "DPoP"
        )

        let wireBody = RealtimeDecryptWireRequest(
            mailId: container.mailId,
            mailRteHeader: mailRteMimeHeader,
            deviceKeyId: deviceKeyId,
            serverNonceBase64Url: challenge.nonceBase64Url,
            clientTimestampUnix: clientTimestamp,
            assertionObjectBase64: assertionCbor.base64EncodedString(),
            clientEphemeralX25519PubBase64: ephemeralClientX25519PubB64,
            clientEphemeralMlKem768PubBase64: nil
        )
        req.httpBody = try JSONEncoder().encode(wireBody)

        let (respData, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw MailRteClientError.serverRejection(0, "Réponse réseau invalide.")
        }
        if http.statusCode == 410 {
            throw MailRteClientError.mailRevokedOrExpired
        }
        guard (200..<300).contains(http.statusCode) else {
            let errDetail = String(data: respData, encoding: .utf8) ?? "Accès refusé"
            throw MailRteClientError.serverRejection(http.statusCode, errDetail)
        }

        let rtEnvelope = try JSONDecoder().decode(RealtimeDecryptWireResponse.self, from: respData)

        // 6. Vérification stricte du TTL court (30s) et de la signature Ed25519 d'autorité serveur
        let nowUnix = Int64(Date().timeIntervalSince1970)
        guard nowUnix <= rtEnvelope.expiresAtUnix + 5 else {
            throw MailRteClientError.ephemeralDekExpired
        }

        try await verifyServerEd25519RealtimeSignature(
            envelope: rtEnvelope,
            fallbackServerPubKeyB64: challenge.serverEd25519PublicKeyBase64
        )

        // 7. Dérivation HKDF-SHA384 & désencapsulation de la DEK 256 bits en RAM
        guard let serverX25519PubBytes = Data(base64Encoded: rtEnvelope.ephemeralServerX25519PubBase64),
              let hkdfSalt = Data(base64Encoded: rtEnvelope.hkdfSaltBase64),
              let wrapIv = Data(base64Encoded: rtEnvelope.wrapIvBase64),
              let wrappedDek = Data(base64Encoded: rtEnvelope.wrappedDekBase64),
              let wrapTag = Data(base64Encoded: rtEnvelope.wrapTagBase64) else {
            throw MailRteClientError.invalidBase64Material
        }

        let serverEphPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: serverX25519PubBytes)
        let sharedSecret = try ephemeralClientX25519Priv.sharedSecretFromKeyAgreement(with: serverEphPub)

        let dpopJkt = try await AppAttestManager.shared.currentDpopJwkThumbprint()
        let sessionInfo = Data(
            "Cenelis-MailRTE-RealtimeSession-v1|\(container.mailId)|\(deviceKeyId)|\(dpopJkt)|\(rtEnvelope.issuedAtUnix)|\(rtEnvelope.expiresAtUnix)".utf8
        )

        let wrappingSymmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA384.self,
            salt: hkdfSalt,
            sharedInfo: sessionInfo,
            outputByteCount: 32
        )

        let dekSealedBox = try AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: wrapIv),
            ciphertext: wrappedDek,
            tag: wrapTag
        )
        var rawDekBytes = try AES.GCM.open(dekSealedBox, using: wrappingSymmetricKey, authenticating: sessionInfo)
        defer {
            // Effacement inconditionnel de la DEK de la RAM dès la fin du déchiffrement local !
            SecureMemory.zeroize(&rawDekBytes)
        }

        let dekSymmetricKey = SymmetricKey(data: rawDekBytes)

        // 8. Déchiffrement local AES-256-GCM de l'objet, du corps et de chaque pièce jointe avec vérification AAD
        let subjectPlain = try Self.decryptPart(
            part: container.encryptedSubject,
            dek: dekSymmetricKey,
            container: container
        )

        let bodyPart = MailRteEncryptedPartModel(
            partId: "body",
            contentType: "text/html; charset=utf-8",
            fileName: nil,
            iv: container.iv,
            aadHash: container.aadHash,
            ciphertext: container.ciphertext,
            authTag: container.authTag
        )
        let bodyPlain = try Self.decryptPart(
            part: bodyPart,
            dek: dekSymmetricKey,
            container: container
        )

        var decryptedAttachments: [(id: String, fileName: String, contentType: String, bytes: Data)] = []
        decryptedAttachments.reserveCapacity(container.attachments.count)

        for att in container.attachments {
            let plainBytes = try Self.decryptPart(part: att, dek: dekSymmetricKey, container: container)
            decryptedAttachments.append((
                id: att.partId,
                fileName: att.fileName ?? "piece-jointe.bin",
                contentType: att.contentType,
                bytes: plainBytes
            ))
        }

        return VolatileDecryptedEmailSession(
            mailId: container.mailId,
            sender: container.sender,
            recipient: container.recipient,
            dlpPolicy: rtEnvelope.dlpPolicy,
            subjectBytes: subjectPlain,
            bodyBytes: bodyPlain,
            attachments: decryptedAttachments
        )
    }

    private func verifyServerEd25519RealtimeSignature(
        envelope: RealtimeDecryptWireResponse,
        fallbackServerPubKeyB64: String
    ) async throws {
        let pubKeyData: Data
        if let cached = try await AppAttestManager.shared.cachedServerEd25519PublicKey() {
            pubKeyData = cached
        } else if let fallback = Data(base64Encoded: fallbackServerPubKeyB64) {
            pubKeyData = fallback
        } else {
            throw MailRteClientError.invalidServerSignature
        }

        guard let sigBytes = Data(base64Encoded: envelope.serverEd25519SignatureBase64) else {
            throw MailRteClientError.invalidServerSignature
        }

        let serverSignKey = try Curve25519.Signing.PublicKey(rawRepresentation: pubKeyData)
        let transcript = Data(
            "Cenelis-MailRTE-RT-Resp-v1|\(envelope.mailId)|\(envelope.ephemeralServerX25519PubBase64)|\(envelope.wrappedDekBase64)|\(envelope.issuedAtUnix)|\(envelope.expiresAtUnix)".utf8
        )

        guard serverSignKey.isValidSignature(sigBytes, for: transcript) else {
            throw MailRteClientError.invalidServerSignature
        }
    }

    private static func decryptPart(
        part: MailRteEncryptedPartModel,
        dek: SymmetricKey,
        container: MailRteClientContainer
    ) throws -> Data {
        let canonicalAadString = "Cenelis.MailRTE.v1|mail_id=\(container.mailId.trimmingCharacters(in: .whitespaces))|sender=\(container.sender.lowercased())|recipient=\(container.recipient.lowercased())|ts=\(container.timestampUnix)|tenant=\(container.tenantId.lowercased())|part=\(part.partId)"
        let aadData = Data(canonicalAadString.utf8)
        let computedAadHash = Data(SHA256.hash(data: aadData))

        guard let expectedAadHash = Data(base64Encoded: part.aadHash),
              computedAadHash == expectedAadHash else {
            throw MailRteClientError.aadIntegrityMismatch
        }

        guard let ivData = Data(base64Encoded: part.iv),
              let cipherData = Data(base64Encoded: part.ciphertext),
              let tagData = Data(base64Encoded: part.authTag) else {
            throw MailRteClientError.invalidBase64Material
        }

        let box = try AES.GCM.SealedBox(
            nonce: try AES.GCM.Nonce(data: ivData),
            ciphertext: cipherData,
            tag: tagData
        )
        return try AES.GCM.open(box, using: dek, authenticating: aadData)
    }
}
