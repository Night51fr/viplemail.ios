import Foundation
#if canImport(Darwin)
import Darwin
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Identité Matérielle Unifiée de l'Écosystème Cenelis × Viple (Swift 6 Sendable)
// Partagée entre Viple Mail, Livria Store, Livria Social et Cenelis Academy via l'App Group `group.com.viplenetwork.shared`.

public struct CenelisDeviceIdentity: Sendable {
    public static let sharedSuiteName = "group.com.viplenetwork.shared"
    public static let secondaryLivriaSuiteName = "group.store.livria.shared"
    public static let sharedPhysicalDeviceIdKey = "cenelis.shared.physicalDeviceId.v1"

    public init() {}

    /// Lit ou initialise l'identifiant matériel partagé dans `UserDefaults(suiteName: "group.com.viplenetwork.shared")`
    /// afin d'unifier le même iPhone / iPad à travers Viple Mail, Livria Store, Livria Social et Cenelis Academy.
    public static func sharedPhysicalDeviceId(fallbackVendorId: String) -> String {
        let cleanFallback = fallbackVendorId.trimmingCharacters(in: .whitespacesAndNewlines)
        let validFallback = (!cleanFallback.isEmpty && cleanFallback != "00000000-0000-0000-0000-000000000000")
            ? cleanFallback
            : ""

        let sharedDefaults = UserDefaults(suiteName: sharedSuiteName)
        let livriaDefaults = UserDefaults(suiteName: secondaryLivriaSuiteName)

        if let existing = sharedDefaults?.string(forKey: sharedPhysicalDeviceIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existing.isEmpty,
           existing != "00000000-0000-0000-0000-000000000000" {
            if UserDefaults.standard.string(forKey: sharedPhysicalDeviceIdKey) != existing {
                UserDefaults.standard.set(existing, forKey: sharedPhysicalDeviceIdKey)
            }
            if livriaDefaults?.string(forKey: sharedPhysicalDeviceIdKey) != existing {
                livriaDefaults?.set(existing, forKey: sharedPhysicalDeviceIdKey)
            }
            return existing
        }

        if let existingLivria = livriaDefaults?.string(forKey: sharedPhysicalDeviceIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !existingLivria.isEmpty,
           existingLivria != "00000000-0000-0000-0000-000000000000" {
            sharedDefaults?.set(existingLivria, forKey: sharedPhysicalDeviceIdKey)
            UserDefaults.standard.set(existingLivria, forKey: sharedPhysicalDeviceIdKey)
            return existingLivria
        }

        if let localSaved = UserDefaults.standard.string(forKey: sharedPhysicalDeviceIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !localSaved.isEmpty,
           localSaved != "00000000-0000-0000-0000-000000000000" {
            sharedDefaults?.set(localSaved, forKey: sharedPhysicalDeviceIdKey)
            livriaDefaults?.set(localSaved, forKey: sharedPhysicalDeviceIdKey)
            return localSaved
        }

        let resolved = validFallback.isEmpty ? UUID().uuidString : validFallback
        sharedDefaults?.set(resolved, forKey: sharedPhysicalDeviceIdKey)
        livriaDefaults?.set(resolved, forKey: sharedPhysicalDeviceIdKey)
        UserDefaults.standard.set(resolved, forKey: sharedPhysicalDeviceIdKey)
        return resolved
    }

    /// Extrait le code machine Apple exact via `utsname` / `uname(&sys)` (ex: `"iPhone12,1"`, `"iPhone17,1"`).
    public static func hardwareModelCode() -> String {
        #if canImport(Darwin)
        var sys = utsname()
        uname(&sys)
        let machineMirror = Mirror(reflecting: sys.machine)
        let rawCode = machineMirror.children.reduce(into: "") { acc, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            acc.append(Character(UnicodeScalar(UInt8(bitPattern: value))))
        }.trimmingCharacters(in: .whitespacesAndNewlines)

        if rawCode == "arm64" || rawCode == "x86_64" || rawCode == "i386" {
            if let simCode = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !simCode.isEmpty {
                return simCode
            }
        }
        if !rawCode.isEmpty {
            return rawCode
        }
        #endif
        return "iPhone"
    }

    /// Indique si l'exécution courante tourne dans le simulateur iOS.
    public static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] != nil
        #endif
    }

    /// Retourne le nom commercial exact de l'appareil courant (ex: `"iPhone 11"`, `"iPhone 16 Pro"`).
    public static func friendlyModelName() -> String {
        let code = hardwareModelCode()
        let mapped = friendlyModelName(for: code)
        if isSimulator && !mapped.lowercased().contains("simulateur") {
            return "\(mapped) (Simulateur)"
        }
        return mapped
    }

    /// Table de correspondance complète des codes matériels Apple (`iPhone10,*` jusqu'à `iPhone19,*`, iPad, Mac, Simulateur).
    public static func friendlyModelName(for modelCode: String) -> String {
        let code = modelCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return "iPhone" }

        if let exact = appleModelTable[code] {
            return exact
        }
        if code.hasPrefix("iPhone") {
            return "iPhone (\(code))"
        }
        if code.hasPrefix("iPad") {
            return "iPad (\(code))"
        }
        if code.hasPrefix("Mac") || code.hasPrefix("MacBook") || code.hasPrefix("iMac") {
            return "Mac (\(code))"
        }
        if code == "arm64" || code == "x86_64" || code == "i386" {
            return "Simulateur iOS"
        }
        return code
    }

    /// Retourne la version complète du système d'exploitation (ex: `"iOS 27.3"`), compatible contexte `nonisolated` Swift 6.
    public static func osVersionString() -> String {
        let ver = ProcessInfo.processInfo.operatingSystemVersion
        let versionNumber: String
        if ver.patchVersion > 0 {
            versionNumber = "\(ver.majorVersion).\(ver.minorVersion).\(ver.patchVersion)"
        } else {
            versionNumber = "\(ver.majorVersion).\(ver.minorVersion)"
        }
        let code = hardwareModelCode()
        if code.hasPrefix("iPad") {
            return "iPadOS \(versionNumber)"
        }
        return "iOS \(versionNumber)"
    }

    /// Icône SF Symbol adaptée au facteur de forme de l'appareil courant.
    public static func currentDeviceSymbolName() -> String {
        let code = hardwareModelCode().lowercased()
        if code.hasPrefix("ipad") {
            return "ipad"
        }
        if code.hasPrefix("mac") {
            return "desktopcomputer"
        }
        return "iphone.gen3"
    }

    /// Convertit une chaîne en valeur ASCII sûre pour les en-têtes HTTP/2 Kestrel.
    public static func httpHeaderSafe(_ value: String) -> String {
        let folded = value.folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
        let scalars = folded.unicodeScalars.filter { $0.value >= 0x20 && $0.value <= 0x7E }
        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let appleModelTable: [String: String] = [
        // Simulateurs
        "i386": "Simulateur iOS",
        "x86_64": "Simulateur iOS",
        "arm64": "Simulateur iOS",

        // iPhone 8 / X (iPhone10,*)
        "iPhone10,1": "iPhone 8",
        "iPhone10,4": "iPhone 8",
        "iPhone10,2": "iPhone 8 Plus",
        "iPhone10,5": "iPhone 8 Plus",
        "iPhone10,3": "iPhone X",
        "iPhone10,6": "iPhone X",

        // iPhone XS / XS Max / XR (iPhone11,*)
        "iPhone11,2": "iPhone XS",
        "iPhone11,4": "iPhone XS Max",
        "iPhone11,6": "iPhone XS Max",
        "iPhone11,8": "iPhone XR",

        // iPhone 11 / Pro / Pro Max / SE 2 (iPhone12,*)
        "iPhone12,1": "iPhone 11",
        "iPhone12,3": "iPhone 11 Pro",
        "iPhone12,5": "iPhone 11 Pro Max",
        "iPhone12,8": "iPhone SE (2e gen.)",

        // iPhone 12 mini / 12 / Pro / Pro Max (iPhone13,*)
        "iPhone13,1": "iPhone 12 mini",
        "iPhone13,2": "iPhone 12",
        "iPhone13,3": "iPhone 12 Pro",
        "iPhone13,4": "iPhone 12 Pro Max",

        // iPhone 13 / SE 3 / 14 / 14 Plus (iPhone14,*)
        "iPhone14,2": "iPhone 13 Pro",
        "iPhone14,3": "iPhone 13 Pro Max",
        "iPhone14,4": "iPhone 13 mini",
        "iPhone14,5": "iPhone 13",
        "iPhone14,6": "iPhone SE (3e gen.)",
        "iPhone14,7": "iPhone 14",
        "iPhone14,8": "iPhone 14 Plus",

        // iPhone 14 Pro / 14 Pro Max / 15 / 15 Plus (iPhone15,*)
        "iPhone15,2": "iPhone 14 Pro",
        "iPhone15,3": "iPhone 14 Pro Max",
        "iPhone15,4": "iPhone 15",
        "iPhone15,5": "iPhone 15 Plus",

        // iPhone 15 Pro / 15 Pro Max (iPhone16,*)
        "iPhone16,1": "iPhone 15 Pro",
        "iPhone16,2": "iPhone 15 Pro Max",

        // iPhone 16 Pro / Pro Max / 16 / 16 Plus / 16e (iPhone17,*)
        "iPhone17,1": "iPhone 16 Pro",
        "iPhone17,2": "iPhone 16 Pro Max",
        "iPhone17,3": "iPhone 16",
        "iPhone17,4": "iPhone 16 Plus",
        "iPhone17,5": "iPhone 16e",

        // iPhone 17 Pro / Pro Max / 17 / 17 Air / 17e (iPhone18,*)
        "iPhone18,1": "iPhone 17 Pro",
        "iPhone18,2": "iPhone 17 Pro Max",
        "iPhone18,3": "iPhone 17",
        "iPhone18,4": "iPhone 17 Air",
        "iPhone18,5": "iPhone 17e",

        // iPhone 18 series (iPhone19,*)
        "iPhone19,1": "iPhone 18 Pro",
        "iPhone19,2": "iPhone 18 Pro Max",
        "iPhone19,3": "iPhone 18",
        "iPhone19,4": "iPhone 18 Air",

        // Générations antérieures utiles
        "iPhone8,1": "iPhone 6s",
        "iPhone8,2": "iPhone 6s Plus",
        "iPhone8,4": "iPhone SE (1re gen.)",
        "iPhone9,1": "iPhone 7",
        "iPhone9,3": "iPhone 7",
        "iPhone9,2": "iPhone 7 Plus",
        "iPhone9,4": "iPhone 7 Plus",

        // iPad mini / iPad / iPad Air / iPad Pro
        "iPad7,11": "iPad (7e gen.)",
        "iPad7,12": "iPad (7e gen.)",
        "iPad8,1": "iPad Pro 11 pouces",
        "iPad8,2": "iPad Pro 11 pouces",
        "iPad8,3": "iPad Pro 11 pouces",
        "iPad8,4": "iPad Pro 11 pouces",
        "iPad8,5": "iPad Pro 12,9 pouces (3e gen.)",
        "iPad8,6": "iPad Pro 12,9 pouces (3e gen.)",
        "iPad8,7": "iPad Pro 12,9 pouces (3e gen.)",
        "iPad8,8": "iPad Pro 12,9 pouces (3e gen.)",
        "iPad8,9": "iPad Pro 11 pouces (2e gen.)",
        "iPad8,10": "iPad Pro 11 pouces (2e gen.)",
        "iPad8,11": "iPad Pro 12,9 pouces (4e gen.)",
        "iPad8,12": "iPad Pro 12,9 pouces (4e gen.)",
        "iPad11,1": "iPad mini (5e gen.)",
        "iPad11,2": "iPad mini (5e gen.)",
        "iPad11,3": "iPad Air (3e gen.)",
        "iPad11,4": "iPad Air (3e gen.)",
        "iPad11,6": "iPad (8e gen.)",
        "iPad11,7": "iPad (8e gen.)",
        "iPad12,1": "iPad (9e gen.)",
        "iPad12,2": "iPad (9e gen.)",
        "iPad13,1": "iPad Air (4e gen.)",
        "iPad13,2": "iPad Air (4e gen.)",
        "iPad13,4": "iPad Pro 11 pouces (M1)",
        "iPad13,5": "iPad Pro 11 pouces (M1)",
        "iPad13,6": "iPad Pro 11 pouces (M1)",
        "iPad13,7": "iPad Pro 11 pouces (M1)",
        "iPad13,8": "iPad Pro 12,9 pouces (M1)",
        "iPad13,9": "iPad Pro 12,9 pouces (M1)",
        "iPad13,10": "iPad Pro 12,9 pouces (M1)",
        "iPad13,11": "iPad Pro 12,9 pouces (M1)",
        "iPad13,16": "iPad Air (M1)",
        "iPad13,17": "iPad Air (M1)",
        "iPad13,18": "iPad (10e gen.)",
        "iPad13,19": "iPad (10e gen.)",
        "iPad14,1": "iPad mini (6e gen.)",
        "iPad14,2": "iPad mini (6e gen.)",
        "iPad14,3": "iPad Pro 11 pouces (M2)",
        "iPad14,4": "iPad Pro 11 pouces (M2)",
        "iPad14,5": "iPad Pro 12,9 pouces (M2)",
        "iPad14,6": "iPad Pro 12,9 pouces (M2)",
        "iPad14,8": "iPad Air 11 pouces (M2)",
        "iPad14,9": "iPad Air 11 pouces (M2)",
        "iPad14,10": "iPad Air 13 pouces (M2)",
        "iPad14,11": "iPad Air 13 pouces (M2)",
        "iPad15,3": "iPad Air 11 pouces (M3)",
        "iPad15,4": "iPad Air 11 pouces (M3)",
        "iPad15,5": "iPad Air 13 pouces (M3)",
        "iPad15,6": "iPad Air 13 pouces (M3)",
        "iPad15,7": "iPad (A16)",
        "iPad15,8": "iPad (A16)",
        "iPad16,1": "iPad mini (A17 Pro)",
        "iPad16,2": "iPad mini (A17 Pro)",
        "iPad16,3": "iPad Pro 11 pouces (M4)",
        "iPad16,4": "iPad Pro 11 pouces (M4)",
        "iPad16,5": "iPad Pro 13 pouces (M4)",
        "iPad16,6": "iPad Pro 13 pouces (M4)"
    ]
}
