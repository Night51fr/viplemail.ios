import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AppDelegate & Point d'Entrée Natif « Viple Mail » pour iOS 18+ / 2026

#if canImport(UIKit)
private final class RemoteFetchCompletionBox: @unchecked Sendable {
    let complete: (UIBackgroundFetchResult) -> Void
    init(_ complete: @escaping (UIBackgroundFetchResult) -> Void) {
        self.complete = complete
    }
}

@MainActor
public final class VipleMailAppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        VipleMailNotificationManager.shared.configureOnLaunch()
        return true
    }

    public func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        VipleMailNotificationManager.shared.handleRegisteredDeviceToken(deviceToken)
    }

    public func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // Sur simulateur ou profil sans jeton APNs distant, le moteur BGAppRefreshTask + sondage IMAP rapide prend le relais automatiquement
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let box = RemoteFetchCompletionBox(completionHandler)
        Task { @MainActor in
            let ok = await VipleMailNotificationManager.shared.performNotificationPollCycle(isBackground: true)
            box.complete(ok ? .newData : .noData)
        }
    }
}
#endif

@main
public struct VipleMailApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(VipleMailAppDelegate.self) private var appDelegate
    #endif

    @StateObject private var mailVM = VipleMailViewModel()
    @StateObject private var notifManager = VipleMailNotificationManager.shared
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some Scene {
        WindowGroup {
            VipleMailMainView()
                .environmentObject(mailVM)
                .environmentObject(notifManager)
                .tint(VipleMailPalette.primary)
                .onAppear {
                    notifManager.attachedViewModel = mailVM
                    notifManager.startForegroundSyncLoop()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        notifManager.attachedViewModel = mailVM
                        notifManager.startForegroundSyncLoop()
                        Task {
                            await notifManager.refreshAuthorizationStatus()
                            if let pendingId = UserDefaults.standard.string(forKey: "viple.mail.ios.pendingOpenMsgId"),
                               !pendingId.isEmpty {
                                UserDefaults.standard.removeObject(forKey: "viple.mail.ios.pendingOpenMsgId")
                                await mailVM.openMessageByIdFromNotification(pendingId, presentReplyComposer: false)
                            }
                        }
                    case .background:
                        notifManager.stopForegroundSyncLoop()
                        notifManager.scheduleBackgroundTasks()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
