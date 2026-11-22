import Foundation
import CryptoKit
import Security
import Darwin
import MachO

// MARK: - Résultat d'Audit Runtime & Durcissement Réseau (Couche 3)

public enum SecurityViolationReason: String, Sendable {
    case debuggerAttached = "DEBUGGER_P_TRACED"
    case suspiciousInjectedLibrary = "INJECTED_DYLIB_HOOK"
    case jailbreakArtifactDetected = "JAILBREAK_FILESYSTEM_OR_SANDBOX"
    case instrumentationPortOpen = "FRIDA_INSTRUMENTATION_PORT"
    case spkiPinningMismatch = "TLS_SPKI_PIN_MISMATCH"
}

public final class SecurityGuard: NSObject, URLSessionDelegate, Sendable {
    public static let shared = SecurityGuard()

    /// Condensats SHA-256 Base64 des SubjectPublicKeyInfo (SPKI) autorisés pour l'infrastructure
    /// Cenelis / Viple Mail (incluant ISRG Root X1, ISRG Root X2 et intermédiaires Let's Encrypt R10/R11/E5/E6/YR1).
    private let pinnedSpkiHashesByDomainSuffix: [String: Set<String>] = [
        "viplemail.fr": [
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=", // ISRG Root X1
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=", // ISRG Root X2
            "y7xVm0TVJNahMr2sZydE2jQH8SquXV9yLF9seROHHHU=", // Let's Encrypt E5/E6 ECDSA
            "Jg78dOE+fydIGk19swWwiypUSR6HWZybfnJG/8G7pyM="  // Let's Encrypt R10/R11 RSA
        ],
        "viple.fr": [
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI="
        ],
        "cenelis.com": [
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI=",
            "y7xVm0TVJNahMr2sZydE2jQH8SquXV9yLF9seROHHHU=",
            "Jg78dOE+fydIGk19swWwiypUSR6HWZybfnJG/8G7pyM="
        ],
        "viple.digital": [
            "C5+lpZ7tcVwmwQIMcRtPbsQtWLABXhQzejna0wHFr8M=",
            "diGVwiVYbubAI3RW4hB9xU8e/CH2GnkuvVFZE8zmgzI="
        ]
    ]

    // Préfixes ASN.1 DER SubjectPublicKeyInfo standard pour reconstruire le SPKI exact depuis SecKeyCopyExternalRepresentation
    private static let rsa2048SpkiHeader = Data([
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0F, 0x00
    ])
    private static let rsa4096SpkiHeader = Data([
        0x30, 0x82, 0x02, 0x22, 0x30, 0x0D, 0x06, 0x09, 0x2A, 0x86, 0x48, 0x86,
        0xF7, 0x0D, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x0F, 0x00
    ])
    private static let ecDsaSecp256r1SpkiHeader = Data([
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
        0x01, 0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ])
    private static let ecDsaSecp384r1SpkiHeader = Data([
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02,
        0x01, 0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00
    ])

    private override init() {
        super.init()
    }

    /// Crée une URLSession éphémère durcie (zéro cache disque, TLS 1.3, SPKI Pinning strict).
    public func makeHardenedURLSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.tlsMinimumSupportedProtocolVersion = .TLSv13
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }

    // MARK: - Vérification Intégrité Runtime Anti-Tampering

    /// Exécute l'ensemble des sondes d'intégrité runtime. En cas de compromission, révoque immédiatement
    /// les clés locales dans le Keychain et lève une erreur bloquante avant tout déchiffrement.
    public func enforceRuntimeIntegrity() async throws {
        #if !targetEnvironment(simulator)
        if Self.isDebuggerAttached() {
            await AppAttestManager.shared.revokeLocalHardwareSession()
            throw MailRteAttestError.compromisedEnvironment(SecurityViolationReason.debuggerAttached.rawValue)
        }

        if let injected = Self.detectSuspiciousLoadedDylib() {
            await AppAttestManager.shared.revokeLocalHardwareSession()
            throw MailRteAttestError.compromisedEnvironment("\(SecurityViolationReason.suspiciousInjectedLibrary.rawValue):\(injected)")
        }

        if Self.detectJailbreakOrSandboxEscape() {
            await AppAttestManager.shared.revokeLocalHardwareSession()
            throw MailRteAttestError.compromisedEnvironment(SecurityViolationReason.jailbreakArtifactDetected.rawValue)
        }

        if Self.isLocalInstrumentationPortOpen(port: 27042) {
            await AppAttestManager.shared.revokeLocalHardwareSession()
            throw MailRteAttestError.compromisedEnvironment(SecurityViolationReason.instrumentationPortOpen.rawValue)
        }
        #endif
    }

    /// Détecte l'attachement d'un débogueur (lldb / gdb / ptrace) via sysctl KERN_PROC_PID -> P_TRACED.
    public static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let rc = mib.withUnsafeMutableBufferPointer { mibPtr -> Int32 in
            sysctl(mibPtr.baseAddress, 4, &info, &size, nil, 0)
        }
        guard rc == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    /// Inspecte l'ensemble des images Mach-O chargées en mémoire via dyld à la recherche de frameworks d'instrumentation.
    public static func detectSuspiciousLoadedDylib() -> String? {
        let forbiddenTokens = [
            "frida", "cycript", "MobileSubstrate", "SubstrateLoader",
            "TweakInject", "libhooker", "Substitute", "SSLKillSwitch",
            "Shadow.dylib", "Choicy", "FlyJB"
        ]
        let count = _dyld_image_count()
        for idx in 0..<count {
            guard let cName = _dyld_get_image_name(idx) else { continue }
            let path = String(cString: cName)
            for token in forbiddenTokens where path.localizedCaseInsensitiveContains(token) {
                return token
            }
        }
        return nil
    }

    /// Vérifie l'absence d'artefacts de jailbreak rootless/rootful et l'étanchéité de la sandbox iOS.
    public static func detectJailbreakOrSandboxEscape() -> Bool {
        let suspiciousPaths = [
            "/var/jb",
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        let fm = FileManager.default
        for p in suspiciousPaths where fm.fileExists(atPath: p) {
            return true
        }

        // Test d'écriture hors sandbox (doit systématiquement échouer sur un iOS intègre)
        let probePath = "/private/cenelis_sandbox_probe_\(UUID().uuidString)"
        do {
            try "probe".write(toFile: probePath, atomically: true, encoding: .utf8)
            try? fm.removeItem(atPath: probePath)
            return true
        } catch {
            return false
        }
    }

    /// Vérifie si le démon par défaut de Frida écoute sur 127.0.0.1:27042.
    public static func isLocalInstrumentationPortOpen(port: UInt16) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var tv = timeval(tv_sec: 0, tv_usec: 150_000)
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let connected = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return connected == 0
    }

    // MARK: - URLSessionDelegate : TLS Certificate SPKI Pinning

    public func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let host = challenge.protectionSpace.host.lowercased()

        // 1. Validation X.509 système standard obligatoire (dates, révocation OCSP/SCT, hostname)
        var cfError: CFError?
        guard SecTrustEvaluateWithError(serverTrust, &cfError) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // 2. Recherche du jeu d'empreintes SPKI correspondant au domaine
        guard let matchedEntry = pinnedSpkiHashesByDomainSuffix.first(where: { suffix, _ in
            host == suffix || host.hasSuffix("." + suffix)
        }) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let expectedPins = matchedEntry.value
        let chain = (SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate]) ?? []

        for certificate in chain {
            if let spkiHash = Self.extractSpkiSha256Base64(from: certificate),
               expectedPins.contains(spkiHash) {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
                return
            }
        }

        Task {
            await AppAttestManager.shared.revokeLocalHardwareSession()
        }
        completionHandler(.cancelAuthenticationChallenge, nil)
    }

    private static func extractSpkiSha256Base64(from certificate: SecCertificate) -> String? {
        guard let publicKey = SecCertificateCopyKey(certificate),
              let rawKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data?,
              let attrs = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attrs[kSecAttrKeyType] as? String,
              let keySize = attrs[kSecAttrKeySizeInBits] as? Int else {
            return nil
        }

        let header: Data
        if keyType == (kSecAttrKeyTypeRSA as String) {
            if keySize == 2048 {
                header = rsa2048SpkiHeader
            } else if keySize == 4096 {
                header = rsa4096SpkiHeader
            } else {
                return nil
            }
        } else if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String) {
            if keySize == 256 {
                header = ecDsaSecp256r1SpkiHeader
            } else if keySize == 384 {
                header = ecDsaSecp384r1SpkiHeader
            } else {
                return nil
            }
        } else {
            return nil
        }

        var spki = Data(capacity: header.count + rawKeyData.count)
        spki.append(header)
        spki.append(rawKeyData)
        return Data(SHA256.hash(data: spki)).base64EncodedString()
    }
}
