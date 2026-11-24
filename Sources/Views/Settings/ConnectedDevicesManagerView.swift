import SwiftUI

// MARK: - Gestionnaire d'Appareils Connectés & Sessions Actives « Écosystème Cenelis × Viple »
// Compatible Mode Clair & Mode Sombre OLED (VipleMailPalette) — Swift 6 Strict Concurrency.

public struct ConnectedDevicesManagerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private struct PendingRevocation: Identifiable, Equatable {
        let device: VipleConnectedDeviceDto
        let targetAppId: String
        let appDisplayName: String?

        var id: String {
            "\(device.deviceId)|\(targetAppId)"
        }

        var isFullDeviceRevocation: Bool {
            targetAppId == "*" || targetAppId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var willSignOutCurrentApp: Bool {
            guard device.isCurrentDevice else { return false }
            let lower = targetAppId.lowercased()
            return isFullDeviceRevocation
                || lower == "viple-mail"
                || lower == "viplemail"
                || lower == "com.viplenetwork.viplemail"
        }
    }

    @State private var pendingRevocation: PendingRevocation? = nil
    @State private var revokingKey: String? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                VipleMailPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        ecosystemSecurityHeroCard

                        if vm.isLoadingConnectedDevices && vm.connectedDevices.isEmpty {
                            loadingStateCard
                        } else if vm.connectedDevices.isEmpty {
                            fallbackCurrentDeviceCard
                        } else {
                            ForEach(vm.connectedDevices) { device in
                                connectedDeviceCard(device)
                            }
                        }

                        securityFootnoteCard
                    }
                    .padding(16)
                }
                .refreshable {
                    await vm.syncDevicePushRegistration(promptIfNotDetermined: false)
                    await vm.refreshConnectedDevices(silent: true)
                }
            }
            .navigationTitle("Appareils connectés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        Task {
                            await vm.refreshConnectedDevices(silent: false)
                        }
                    } label: {
                        if vm.isLoadingConnectedDevices {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                    .disabled(vm.isLoadingConnectedDevices)
                    .accessibilityLabel("Actualiser la liste des appareils")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                }
            }
            .alert(
                revocationAlertTitle,
                isPresented: Binding(
                    get: { pendingRevocation != nil },
                    set: { if !$0 { pendingRevocation = nil } }
                ),
                presenting: pendingRevocation
            ) { target in
                Button(
                    target.isFullDeviceRevocation
                        ? "Déconnecter cet appareil"
                        : "Déconnecter \(target.appDisplayName ?? "l'application")",
                    role: .destructive
                ) {
                    pendingRevocation = nil
                    executeRevocation(target)
                }
                Button("Annuler", role: .cancel) {
                    pendingRevocation = nil
                }
            } message: { target in
                Text(revocationAlertMessage(for: target))
            }
            .task {
                await vm.syncDevicePushRegistration(promptIfNotDetermined: false)
                await vm.refreshConnectedDevices(silent: false)
            }
        }
    }

    // MARK: - En-tête Sécurité Écosystème Cenelis × Viple

    private var ecosystemSecurityHeroCard: some View {
        let totalDevices = max(1, vm.connectedDevices.count)
        let totalAppSessions = max(1, vm.connectedDevices.reduce(0) { $0 + max(1, $1.connectedApps.count) })

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                        .frame(width: 48, height: 48)
                        .shadow(color: VipleMailPalette.primarySolid.opacity(0.32), radius: 8, x: 0, y: 4)

                    Image(systemName: "lock.iphone")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Sessions Viple Live ID")
                            .font(.system(size: 16.5, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)

                        Text("\(totalDevices) APPAREIL\(totalDevices > 1 ? "S" : "")")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                    }

                    Text("\(vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail) • \(totalAppSessions) session\(totalAppSessions > 1 ? "s" : "") active\(totalAppSessions > 1 ? "s" : "")")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Text("Visualisez tous les appareils connectés à votre compte — y compris lorsque l'application est fermée — à travers Viple Mail, Livria Store, Livria Social et Cenelis Academy. La révocation coupe immédiatement l'accès et toutes les notifications push.")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - États Chargement & Appareil Local par Défaut

    private var loadingStateCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(VipleMailPalette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Vérification des sessions actives…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Text("Interrogation chiffrée de mail.viplemail.fr")
                    .font(.system(size: 12))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            Spacer()
        }
        .vipleMailCard(cornerRadius: 18, padding: 16)
    }

    private var fallbackCurrentDeviceCard: some View {
        let localDevice = VipleConnectedDeviceDto(
            deviceId: VipleMailAPIClient.shared.resolvedDeviceIdentifier,
            rawDeviceIds: [VipleMailAPIClient.shared.resolvedDeviceIdentifier],
            modelName: CenelisDeviceIdentity.friendlyModelName(),
            modelCode: CenelisDeviceIdentity.hardwareModelCode(),
            platform: "iOS",
            osVersion: CenelisDeviceIdentity.osVersionString(),
            isCurrentDevice: true,
            pushActive: vm.settings.pushNotificationsEnabled,
            connectedAtUtc: nil,
            lastSeenAtUtc: nil,
            connectedApps: [
                VipleConnectedAppBadgeDto(
                    appId: "viple-mail",
                    appName: "Viple Mail",
                    bundleId: "com.viplenetwork.viplemail",
                    icon: "envelope.fill",
                    colorHex: "#2563EB",
                    accountEmail: vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail,
                    appVersion: VipleMailAPIClient.clientVersion,
                    notificationsEnabled: vm.settings.pushNotificationsEnabled,
                    lastSeenAtUtc: nil
                )
            ]
        )
        return connectedDeviceCard(localDevice)
    }

    // MARK: - Carte d'un Appareil Connecté

    private func connectedDeviceCard(_ device: VipleConnectedDeviceDto) -> some View {
        let isRevokingWholeDevice = revokingKey == "\(device.deviceId)|*"
        let accentColor = device.isCurrentDevice ? VipleMailPalette.success : VipleMailPalette.primary

        return VStack(alignment: .leading, spacing: 14) {
            // 1. En-tête matériel : Icône + Modèle exact + OS + Badge « Cet appareil » + Activité relative
            HStack(alignment: .top, spacing: 13) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accentColor.opacity(0.30), lineWidth: 1)
                        )

                    Image(systemName: device.deviceSymbolName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 48, height: 48)

                    if device.pushActive {
                        Circle()
                            .fill(VipleMailPalette.success)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().stroke(VipleMailPalette.surface, lineWidth: 2))
                            .offset(x: 2, y: 2)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(device.resolvedModelDisplayName)
                            .font(.system(size: 16.5, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)

                        if device.isCurrentDevice {
                            currentDeviceBadge
                        }
                    }

                    HStack(spacing: 6) {
                        Label(device.resolvedOsDisplayLabel, systemImage: "cpu")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkSecondary)

                        if !device.modelCode.isEmpty && device.modelCode.lowercased() != device.resolvedModelDisplayName.lowercased() {
                            Text("• \(device.modelCode)")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(device.formattedRelativeLastSeen)
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(device.isCurrentDevice ? VipleMailPalette.success : VipleMailPalette.inkMuted)

                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(VipleMailPalette.inkMuted)

                        HStack(spacing: 4) {
                            Image(systemName: device.pushActive ? "bell.badge.fill" : "bell.slash.fill")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text(device.pushActive ? "Push APNs actif" : "Push désactivé")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(device.pushActive ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                    }
                }

                Spacer(minLength: 0)
            }

            Divider()

            // 2. Section « Applications actuellement connectées » sous forme de badges/pilules colorées
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Applications actuellement connectées", systemImage: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                    Spacer()

                    Text("\(device.connectedApps.count)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }

                if device.connectedApps.isEmpty {
                    Text("Session principale enregistrée sur l'écosystème Viple.")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(device.connectedApps) { app in
                            connectedAppPill(app, on: device)
                        }
                    }
                }
            }

            // 3. Bouton rouge clair « Déconnecter cet appareil » (avec confirmation)
            Button(role: .destructive) {
                pendingRevocation = PendingRevocation(
                    device: device,
                    targetAppId: "*",
                    appDisplayName: nil
                )
            } label: {
                HStack(spacing: 8) {
                    if isRevokingWholeDevice {
                        ProgressView()
                            .tint(VipleMailPalette.danger)
                            .controlSize(.small)
                    } else {
                        Image(systemName: "iphone.slash")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(device.isCurrentDevice ? "Déconnecter cet appareil" : "Déconnecter cet appareil à distance")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(VipleMailPalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11.5)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.danger.opacity(colorScheme == .dark ? 0.16 : 0.10))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(VipleMailPalette.danger.opacity(0.30), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(revokingKey != nil)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VipleMailPalette.surface)
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.36)
                        : VipleMailPalette.cobaltDeep.opacity(0.06),
                    radius: colorScheme == .dark ? 12 : 14,
                    x: 0,
                    y: colorScheme == .dark ? 6 : 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    device.isCurrentDevice
                        ? VipleMailPalette.success.opacity(0.45)
                        : VipleMailPalette.border,
                    lineWidth: device.isCurrentDevice ? 1.4 : 1
                )
        )
    }

    private var currentDeviceBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(VipleMailPalette.success)
                .frame(width: 6, height: 6)
            Text("Cet appareil")
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.success)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(
            Capsule()
                .fill(VipleMailPalette.success.opacity(colorScheme == .dark ? 0.20 : 0.13))
        )
        .overlay(
            Capsule()
                .stroke(VipleMailPalette.success.opacity(0.35), lineWidth: 0.8)
        )
    }

    // MARK: - Pilule Colorée d'une Application de l'Écosystème + Révocation Individuelle

    private func connectedAppPill(_ app: VipleConnectedAppBadgeDto, on device: VipleConnectedDeviceDto) -> some View {
        let appTint = VipleMailPalette.colorFromHex(app.resolvedColorHex)
        let isRevokingThisApp = revokingKey == "\(device.deviceId)|\(app.appId)"

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(appTint.opacity(colorScheme == .dark ? 0.24 : 0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: app.resolvedSymbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(appTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.appName)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)

                    if !app.appVersion.isEmpty {
                        Text("v\(app.appVersion)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(appTint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(appTint.opacity(0.13)))
                    }

                    if app.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VipleMailPalette.success)
                    }
                }

                if !app.accountEmail.isEmpty {
                    Text(app.accountEmail)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            Button {
                pendingRevocation = PendingRevocation(
                    device: device,
                    targetAppId: app.appId,
                    appDisplayName: app.appName
                )
            } label: {
                Group {
                    if isRevokingThisApp {
                        ProgressView()
                            .tint(VipleMailPalette.danger)
                            .controlSize(.mini)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "power")
                                .font(.system(size: 10.5, weight: .bold))
                            Text("Couper")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(VipleMailPalette.danger)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(VipleMailPalette.danger.opacity(colorScheme == .dark ? 0.18 : 0.10))
                )
            }
            .buttonStyle(.plain)
            .disabled(revokingKey != nil)
            .accessibilityLabel("Déconnecter \(app.appName) sur \(device.resolvedModelDisplayName)")
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(appTint.opacity(colorScheme == .dark ? 0.10 : 0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(appTint.opacity(colorScheme == .dark ? 0.32 : 0.22), lineWidth: 1)
        )
        .contextMenu {
            Button(role: .destructive) {
                pendingRevocation = PendingRevocation(
                    device: device,
                    targetAppId: app.appId,
                    appDisplayName: app.appName
                )
            } label: {
                Label("Déconnecter \(app.appName)", systemImage: "power")
            }

            Button(role: .destructive) {
                pendingRevocation = PendingRevocation(
                    device: device,
                    targetAppId: "*",
                    appDisplayName: nil
                )
            } label: {
                Label("Déconnecter tout l'appareil", systemImage: "iphone.slash")
            }
        }
    }

    private var securityFootnoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VipleMailPalette.primary)
                .padding(.top, 1)

            Text("Exclusivité matérielle garantie : un seul compte Viple Live ID reçoit les notifications push sur un même iPhone ou iPad. Dès qu'une session est révoquée ici, ses jetons APNs et son sondage d'arrière-plan sont immédiatement invalidés.")
                .font(.system(size: 11.5))
                .foregroundStyle(VipleMailPalette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VipleMailPalette.surfaceSubtle)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VipleMailPalette.border, lineWidth: 1)
        )
    }

    // MARK: - Confirmation & Exécution de Révocation

    private var revocationAlertTitle: String {
        guard let target = pendingRevocation else { return "Déconnecter ?" }
        if target.isFullDeviceRevocation {
            return target.device.isCurrentDevice
                ? "Déconnecter cet appareil ?"
                : "Déconnecter \(target.device.resolvedModelDisplayName) ?"
        }
        return "Déconnecter \(target.appDisplayName ?? "cette application") ?"
    }

    private func revocationAlertMessage(for target: PendingRevocation) -> String {
        if target.isFullDeviceRevocation {
            if target.device.isCurrentDevice {
                return "Votre session locale sur \(target.device.resolvedModelDisplayName) sera fermée immédiatement et toutes les notifications push seront coupées sur cet appareil."
            }
            return "L'appareil \(target.device.resolvedModelDisplayName) (\(target.device.resolvedOsDisplayLabel)) sera immédiatement déconnecté de toutes les applications Viple & Cenelis (même si elles sont fermées) et ne recevra plus aucune notification."
        }
        if target.willSignOutCurrentApp {
            return "Votre session Viple Mail sur cet appareil (\(target.device.resolvedModelDisplayName)) sera immédiatement fermée."
        }
        return "La session \(target.appDisplayName ?? target.targetAppId) sur \(target.device.resolvedModelDisplayName) sera fermée à distance et ses notifications push seront coupées immédiatement."
    }

    private func executeRevocation(_ target: PendingRevocation) {
        let key = target.id
        revokingKey = key
        Task {
            defer { revokingKey = nil }
            let signedOutLocally = await vm.revokeDeviceSession(
                device: target.device,
                targetAppId: target.targetAppId,
                appDisplayName: target.appDisplayName
            )
            if signedOutLocally {
                dismiss()
            }
        }
    }
}
