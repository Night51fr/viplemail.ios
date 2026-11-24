import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - AppDelegate & Point d'Entrée Natif « Viple Mail » pour iOS 18+ / 2026

#if canImport(UIKit)
private final class RemoteFetchCompletionBox: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false
    private let completeBlock: (UIBackgroundFetchResult) -> Void

    init(_ complete: @escaping (UIBackgroundFetchResult) -> Void) {
        self.completeBlock = complete
    }

    func complete(_ result: UIBackgroundFetchResult) {
        lock.lock()
        guard !completed else {
            lock.unlock()
            return
        }
        completed = true
        lock.unlock()
        completeBlock(result)
    }
}

@MainActor
public final class VipleMailAppDelegate: NSObject, UIApplicationDelegate {
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UITextView.appearance().backgroundColor = .clear
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
        // Sur simulateur sans jeton APNs distant, BGAppRefreshTask + BGProcessingTask + fenêtre arrière-plan assurent le relais
        VipleMailNotificationManager.shared.scheduleBackgroundTasks()
    }

    public func application(
        _ application: UIApplication,
        performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let box = RemoteFetchCompletionBox(completionHandler)
        Task { @MainActor in
            VipleMailNotificationManager.shared.scheduleBackgroundTasks()
            let ok = await VipleMailNotificationManager.shared.performNotificationPollCycle(isBackground: true)
            box.complete(ok ? .newData : .noData)
        }
    }

    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let box = RemoteFetchCompletionBox(completionHandler)
        Task { @MainActor in
            VipleMailNotificationManager.shared.scheduleBackgroundTasks()
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
                .preferredColorScheme(mailVM.preferredColorSchemeOverride)
                .onOpenURL { incomingURL in
                    Task { @MainActor in
                        await mailVM.handleIncomingURL(incomingURL)
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let webURL = userActivity.webpageURL {
                        Task { @MainActor in
                            await mailVM.handleIncomingURL(webURL)
                        }
                    }
                }
                .onAppear {
                    mailVM.applyWindowInterfaceStyle()
                    notifManager.attachedViewModel = mailVM
                    if scenePhase != .background {
                        notifManager.enterForegroundMode()
                    } else {
                        notifManager.scheduleBackgroundTasks()
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        notifManager.attachedViewModel = mailVM
                        notifManager.enterForegroundMode()
                        Task {
                            if let pendingId = UserDefaults.standard.string(forKey: "viple.mail.ios.pendingOpenMsgId"),
                               !pendingId.isEmpty {
                                UserDefaults.standard.removeObject(forKey: "viple.mail.ios.pendingOpenMsgId")
                                await mailVM.openMessageByIdFromNotification(pendingId, presentReplyComposer: false)
                            }
                        }
                    case .background:
                        notifManager.enterBackgroundMode()
                    case .inactive:
                        notifManager.handleSceneBecameInactive()
                    @unknown default:
                        break
                    }
                }
        }
    }
}
