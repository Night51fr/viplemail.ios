import SwiftUI

// MARK: - Point d'Entrée Natif « Viple Mail » pour iOS 18+ / 2026

@main
public struct VipleMailApp: App {
    @StateObject private var mailVM = VipleMailViewModel()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            VipleMailMainView()
                .environmentObject(mailVM)
                .tint(VipleMailPalette.primary)
        }
    }
}
