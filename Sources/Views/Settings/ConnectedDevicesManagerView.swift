import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Gestionnaire d'Appareils Connectés au Compte Viple Live ID & Badges d'Applications Actives
// Affiche chaque appareil associé au Viple Live ID, les badges d'applications actuellement connectées,
// efface l'icône d'une application dès sa déconnexion, conserve « Connecté » tant qu'au moins une app
// reste active, et affiche « Déconnecté » lorsque toutes les applications sont déconnectées sur l'appareil.

public struct ConnectedDevicesManagerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private enum DeviceStatusFilter: String, CaseIterable, Identifiable {
        case all = "Tous"
        case connected = "Connectés"
        case disconnected = "Déconnectés"

        var id: String { rawValue }
    }

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

    @State private var selectedFilter: DeviceStatusFilter = .all
    @State private var pendingRevocation: PendingRevocation? = nil
    @State private var revokingKey: String? = nil

    public init() {}

    private var resolvedDevices: [VipleConnectedDeviceDto] {
        if vm.connectedDevices.isEmpty {
            return [fallbackCurrentDevice]
        }
        return vm.connectedDevices
    }

    private var connectedDevicesCount: Int {
        resolvedDevices.filter { $0.effectiveIsConnected }.count
    }

    private var disconnectedDevicesCount: Int {
        resolvedDevices.filter { !$0.effectiveIsConnected }.count
    }

    private var totalActiveAppSessions: Int {
        resolvedDevices.reduce(0) { $0 + $1.connectedApps.count }
    }

    private var filteredDevices: [VipleConnectedDeviceDto] {
        switch selectedFilter {
        case .all:
            return resolvedDevices
        case .connected:
            return resolvedDevices.filter { $0.effectiveIsConnected }
        case .disconnected:
            return resolvedDevices.filter { !$0.effectiveIsConnected }
        }
    }

    private var fallbackCurrentDevice: VipleConnectedDeviceDto {
        VipleConnectedDeviceDto(
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
                    lastSeenAtUtc: nil,
                    assetIconName: "EcoIconVipleMail"
                )
            ],
            isConnected: true,
            status: "connected",
            statusLabel: "Connecté"
        )
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VipleMailPalette.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        vipleLiveIdDevicesHeroCard
                        statusFilterBar

                        if vm.isLoadingConnectedDevices && vm.connectedDevices.isEmpty {
                            loadingStateCard
                        } else if filteredDevices.isEmpty {
                            emptyFilterStateCard
                        } else {
                            ForEach(filteredDevices) { device in
                                connectedDeviceCard(device)
                                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                            }
                        }

                        securityFootnoteCard
                    }
                    .padding(16)
                    .animation(.spring(response: 0.36, dampingFraction: 0.84), value: vm.connectedDevices)
                    .animation(.spring(response: 0.32, dampingFraction: 0.84), value: selectedFilter)
                }
                .refreshable {
                    await vm.syncDevicePushRegistration(promptIfNotDetermined: false)
                    await vm.refreshConnectedDevices(silent: true)
                }
            }
            .navigationTitle("Appareils Viple Live ID")
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
                    .accessibilityLabel("Actualiser les appareils Viple Live ID")
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
                        ? "Déconnecter toutes les apps"
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

    // MARK: - En-tête Synthèse du Compte Viple Live ID

    private var vipleLiveIdDevicesHeroCard: some View {
        let primaryAddr = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                        .frame(width: 50, height: 50)
                        .shadow(color: VipleMailPalette.primarySolid.opacity(0.30), radius: 8, x: 0, y: 4)

                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Appareils associés à votre Viple Live ID")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)

                    Text(primaryAddr)
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.primary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                metricCounterPill(
                    count: connectedDevicesCount,
                    label: connectedDevicesCount > 1 ? "Connectés" : "Connecté",
                    tint: VipleMailPalette.success,
                    dotFilled: true
                )
                metricCounterPill(
                    count: disconnectedDevicesCount,
                    label: disconnectedDevicesCount > 1 ? "Déconnectés" : "Déconnecté",
                    tint: VipleMailPalette.inkMuted,
                    dotFilled: false
                )
                metricCounterPill(
                    count: totalActiveAppSessions,
                    label: totalActiveAppSessions > 1 ? "Apps actives" : "App active",
                    tint: VipleMailPalette.primary,
                    dotFilled: true
                )
            }

            Text("Les badges d'applications indiquent précisément où chaque appareil est connecté en ce moment. Déconnecter une application efface son badge ; si toutes les applications sont fermées sur un appareil, celui-ci passe à l'état « Déconnecté ».")
                .font(.system(size: 12))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func metricCounterPill(count: Int, label: String, tint: Color, dotFilled: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotFilled ? tint : Color.clear)
                .overlay(Circle().stroke(tint, lineWidth: 1.5))
                .frame(width: 7, height: 7)
            Text("\(count)")
                .font(.system(size: 12.5, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(VipleMailPalette.surfaceSubtle)
        )
    }

    private var statusFilterBar: some View {
        HStack(spacing: 8) {
            ForEach(DeviceStatusFilter.allCases) { filter in
                let isSelected = selectedFilter == filter
                let count: Int = {
                    switch filter {
                    case .all: return resolvedDevices.count
                    case .connected: return connectedDevicesCount
                    case .disconnected: return disconnectedDevicesCount
                    }
                }()

                Button {
                    selectedFilter = filter
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        Text("\(count)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule().fill(isSelected ? Color.white.opacity(0.22) : VipleMailPalette.surfaceSubtle)
                            )
                    }
                    .foregroundStyle(isSelected ? Color.white : VipleMailPalette.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? VipleMailPalette.primary : VipleMailPalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected ? Color.clear : VipleMailPalette.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingStateCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(VipleMailPalette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Synchronisation de vos appareils Viple Live ID…")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Text("Vérification des applications actives sur l'écosystème")
                    .font(.system(size: 12))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            Spacer()
        }
        .vipleMailCard(cornerRadius: 18, padding: 16)
    }

    private var emptyFilterStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedFilter == .disconnected ? "checkmark.shield.fill" : "iphone.slash")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(VipleMailPalette.primary)
            Text(selectedFilter == .disconnected ? "Aucun appareil déconnecté" : "Aucun appareil dans ce filtre")
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text("Tous les appareils associés à votre Viple Live ID s'affichent automatiquement ici.")
                .font(.system(size: 12))
                .foregroundStyle(VipleMailPalette.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .vipleMailCard(cornerRadius: 18, padding: 20)
    }

    // MARK: - Carte d'un Appareil Physique (Connecté ou Déconnecté)

    private func connectedDeviceCard(_ device: VipleConnectedDeviceDto) -> some View {
        let isConnected = device.effectiveIsConnected
        let isRevokingWholeDevice = revokingKey == "\(device.deviceId)|*"
        let accentColor: Color = !isConnected
            ? VipleMailPalette.inkMuted
            : (device.isCurrentDevice ? VipleMailPalette.success : VipleMailPalette.primary)

        return VStack(alignment: .leading, spacing: 14) {
            // 1. En-tête matériel + Pastille explicite « Connecté » / « Déconnecté »
            HStack(alignment: .top, spacing: 13) {
                ZStack(alignment: .bottomTrailing) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accentColor.opacity(colorScheme == .dark ? 0.18 : 0.11))
                        .frame(width: 50, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accentColor.opacity(0.30), lineWidth: 1)
                        )

                    Image(systemName: device.deviceSymbolName)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(accentColor)
                        .frame(width: 50, height: 50)

                    Circle()
                        .fill(isConnected ? VipleMailPalette.success : VipleMailPalette.inkMuted.opacity(0.65))
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(VipleMailPalette.surface, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(device.resolvedModelDisplayName)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(isConnected ? VipleMailPalette.ink : VipleMailPalette.inkSecondary)
                            .lineLimit(1)

                        if device.isCurrentDevice {
                            currentDeviceBadge
                        }

                        Spacer(minLength: 4)

                        deviceConnectionStateBadge(isConnected: isConnected)
                    }

                    HStack(spacing: 6) {
                        Label(device.resolvedOsDisplayLabel, systemImage: "cpu")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
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
                            Text(isConnected ? device.formattedRelativeLastSeen : "Dernière activité : \(device.formattedRelativeLastSeen)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(isConnected && device.isCurrentDevice ? VipleMailPalette.success : VipleMailPalette.inkMuted)

                        if isConnected {
                            Text("•")
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)

                            HStack(spacing: 4) {
                                Image(systemName: device.pushActive ? "bell.badge.fill" : "bell.slash.fill")
                                    .font(.system(size: 10.5, weight: .semibold))
                                Text(device.pushActive ? "Push actif" : "Push coupé")
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                            .foregroundStyle(device.pushActive ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                        }
                    }
                }
            }

            Divider()

            // 2. Ruban visuel des Badges d'Applications + Actions par Application (ou État « Déconnecté »)
            if isConnected {
                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        Label(
                            device.connectedApps.count > 1
                                ? "Connecté sur \(device.connectedApps.count) applications"
                                : "Connecté sur 1 application",
                            systemImage: "square.grid.2x2.fill"
                        )
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                        Spacer()

                        // Ruban compact des vraies icônes d'applications connectées
                        HStack(spacing: -5) {
                            ForEach(device.connectedApps) { app in
                                realAppIconSquircle(for: app, size: 24, cornerRadius: 6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(VipleMailPalette.surface, lineWidth: 1.5)
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // Badges détaillés avec icône officielle + bouton de déconnexion individuelle
                    VStack(spacing: 8) {
                        ForEach(device.connectedApps) { app in
                            connectedAppBadgeRow(app, on: device)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                                    removal: .scale(scale: 0.86).combined(with: .opacity)
                                ))
                        }
                    }
                }

                // 3. Bouton global « Déconnecter de toutes les applications »
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
                        Text(device.isCurrentDevice
                             ? "Déconnecter cet appareil de toutes les apps"
                             : "Déconnecter cet appareil à distance")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(VipleMailPalette.danger)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(VipleMailPalette.danger.opacity(colorScheme == .dark ? 0.16 : 0.09))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(VipleMailPalette.danger.opacity(0.28), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(revokingKey != nil)
            } else {
                // État lorsque le compte est déconnecté sur TOUTES les applications de cet appareil
                HStack(spacing: 10) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkMuted)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Déconnecté sur toutes les applications")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Text("Aucune application Viple ou Cenelis n'est actuellement connectée à votre compte sur cet appareil.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )
            }
        }
        .padding(16)
        .opacity(isConnected ? 1.0 : 0.88)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(VipleMailPalette.surface)
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.32)
                        : VipleMailPalette.cobaltDeep.opacity(isConnected ? 0.06 : 0.03),
                    radius: colorScheme == .dark ? 11 : 13,
                    x: 0,
                    y: 5
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    !isConnected
                        ? VipleMailPalette.border
                        : (device.isCurrentDevice ? VipleMailPalette.success.opacity(0.45) : VipleMailPalette.primary.opacity(0.25)),
                    lineWidth: isConnected && device.isCurrentDevice ? 1.4 : 1
                )
        )
    }

    private func deviceConnectionStateBadge(isConnected: Bool) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isConnected ? VipleMailPalette.success : Color.clear)
                .overlay(
                    Circle().stroke(isConnected ? VipleMailPalette.success : VipleMailPalette.inkMuted, lineWidth: 1.5)
                )
                .frame(width: 6.5, height: 6.5)

            Text(isConnected ? "Connecté" : "Déconnecté")
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundStyle(isConnected ? VipleMailPalette.success : VipleMailPalette.inkMuted)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(isConnected
                      ? VipleMailPalette.success.opacity(colorScheme == .dark ? 0.20 : 0.13)
                      : VipleMailPalette.surfaceSubtle)
        )
        .overlay(
            Capsule()
                .stroke(isConnected ? VipleMailPalette.success.opacity(0.35) : VipleMailPalette.border, lineWidth: 0.9)
        )
    }

    private var currentDeviceBadge: some View {
        Text("Cet appareil")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .foregroundStyle(VipleMailPalette.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(VipleMailPalette.primary.opacity(colorScheme == .dark ? 0.20 : 0.12))
            )
    }

    // MARK: - Icône Officielle d'Application & Badge Interactif

    @ViewBuilder
    private func realAppIconSquircle(for app: VipleConnectedAppBadgeDto, size: CGFloat, cornerRadius: CGFloat) -> some View {
        let appTint = VipleMailPalette.colorFromHex(app.resolvedColorHex)
        #if canImport(UIKit)
        if let assetName = app.resolvedAssetIconName, let uiImg = UIImage(named: assetName) {
            Image(uiImage: uiImg)
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            fallbackAppIconSquircle(symbol: app.resolvedSymbolName, tint: appTint, size: size, cornerRadius: cornerRadius)
        }
        #else
        fallbackAppIconSquircle(symbol: app.resolvedSymbolName, tint: appTint, size: size, cornerRadius: cornerRadius)
        #endif
    }

    private func fallbackAppIconSquircle(symbol: String, tint: Color, size: CGFloat, cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint, tint.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    private func connectedAppBadgeRow(_ app: VipleConnectedAppBadgeDto, on device: VipleConnectedDeviceDto) -> some View {
        let appTint = VipleMailPalette.colorFromHex(app.resolvedColorHex)
        let isRevokingThisApp = revokingKey == "\(device.deviceId)|\(app.appId)"

        return HStack(spacing: 11) {
            ZStack(alignment: .bottomTrailing) {
                realAppIconSquircle(for: app, size: 38, cornerRadius: 9.5)
                    .shadow(color: appTint.opacity(0.25), radius: 5, y: 2)

                Circle()
                    .fill(VipleMailPalette.success)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().stroke(VipleMailPalette.surface, lineWidth: 1.8))
                    .offset(x: 2, y: 2)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(app.appName)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)

                    Text("Connecté")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(VipleMailPalette.success.opacity(0.12)))

                    if app.notificationsEnabled {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(appTint)
                    }
                }

                HStack(spacing: 6) {
                    if !app.accountEmail.isEmpty {
                        Text(app.accountEmail)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineLimit(1)
                    }
                    if !app.appVersion.isEmpty {
                        Text("• v\(app.appVersion)")
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(1)
                    }
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
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 10.5, weight: .bold))
                            Text("Déco.")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(VipleMailPalette.danger)
                    }
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 6.5)
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
        .padding(.vertical, 9.5)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(appTint.opacity(colorScheme == .dark ? 0.10 : 0.055))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(appTint.opacity(colorScheme == .dark ? 0.30 : 0.20), lineWidth: 1)
        )
    }

    private var securityFootnoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VipleMailPalette.primary)
                .padding(.top, 1)

            Text("Synchronisation temps réel Viple Live ID : lorsqu'une application est déconnectée (depuis celle-ci ou à distance ici), son badge disparaît immédiatement. L'appareil reste affiché « Connecté » tant qu'au moins une application reste ouverte sur votre compte, puis bascule sur « Déconnecté » dès que toutes les sessions sont fermées.")
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

    // MARK: - Confirmation & Révocation

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
                return "Toutes vos sessions Viple & Cenelis seront fermées sur \(target.device.resolvedModelDisplayName) et cet appareil passera à l'état « Déconnecté »."
            }
            return "Toutes les applications actives sur \(target.device.resolvedModelDisplayName) seront immédiatement déconnectées à distance et cet appareil s'affichera comme « Déconnecté »."
        }
        if target.willSignOutCurrentApp {
            return "Votre session Viple Mail sur \(target.device.resolvedModelDisplayName) sera fermée immédiatement."
        }
        let remaining = max(0, target.device.connectedApps.count - 1)
        if remaining > 0 {
            return "Le badge \(target.appDisplayName ?? target.targetAppId) sera retiré de \(target.device.resolvedModelDisplayName). L'appareil restera « Connecté » sur \(remaining == 1 ? "l'autre application active" : "les \(remaining) autres applications actives")."
        }
        return "Le badge \(target.appDisplayName ?? target.targetAppId) sera retiré et \(target.device.resolvedModelDisplayName) passera à l'état « Déconnecté »."
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
