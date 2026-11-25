import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Réglages & Compte Viple Live ID « Viple Mail » (Signature, Gestes de Balayage, Répondeur Automatique, Diagnostics & Déconnexion)

public struct MailSettingsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var notifManager = VipleMailNotificationManager.shared
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var isShowingBetaFeaturesSheet: Bool = false

    @State private var displayNameField: String = ""
    @State private var personalMessageField: String = ""
    @State private var newImapPasswordField: String = ""
    @State private var cenelisCustomHandleField: String = ""
    @State private var isEditingCenelisHandle: Bool = false
    @State private var accountPendingDeletion: ExternalMailAccount? = nil
    @State private var isShowingConnectedDevicesSheet: Bool = false
    @State private var isShowingDeleteAccountSheet: Bool = false
    @State private var deleteAccountConfirmationInput: String = ""
    @State private var deleteAccountError: String? = nil

    // Configuration Serveur Push Apple APNs (.p8) pour administrateurs / agents Cenelis
    @State private var isApnsConfigExpanded: Bool = false
    @State private var apnsTeamIdField: String = ""
    @State private var apnsKeyIdField: String = ""
    @State private var apnsBundleIdField: String = "com.viplenetwork.viplemail"
    @State private var apnsPrivateKeyP8Field: String = ""
    @State private var apnsPreferSandboxField: Bool = false
    @State private var isSavingApnsConfig: Bool = false
    @State private var isTestingRemoteApns: Bool = false
    @State private var isImportingP8File: Bool = false

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                accountProfileCard
                betaFeaturesEntryCard
                if [.f047, .f049, .f093, .f097, .f099].contains(where: { beta.isEnabled($0) }) {
                    activeBetaSettingsShortcutsCard
                }
                academyEmbeddedHelpCard
                guestAccessAndIMessageCard
                connectedDevicesEntryCard
                if vm.isApprovedCenelisAgent {
                    cenelisAgentMailboxCard
                }
                appearanceCustomizationCard
                externalAccountsCard
                notificationsControlCard
                officialMailServersCard
                inboxAndSwipeCustomizationCard
                signatureCard
                vacationResponderCard
                privacyLegalAndAccountDeletionCard
                diagnosticsAndSignOutCard
            }
            .padding(16)
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .alert(
            "Retirer cette boîte externe ?",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            presenting: accountPendingDeletion
        ) { acc in
            Button("Retirer de Viple Mail", role: .destructive) {
                accountPendingDeletion = nil
                Task {
                    await vm.removeExternalAccount(acc)
                }
            }
            Button("Annuler", role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: { acc in
            Text("L'adresse \(acc.email) ne sera plus affichée dans Viple Mail. Aucun e-mail ne sera supprimé sur le serveur \(acc.providerName).")
        }
        .fileImporter(
            isPresented: $isImportingP8File,
            allowedContentTypes: [.data, .plainText, .item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    apnsPrivateKeyP8Field = content.trimmingCharacters(in: .whitespacesAndNewlines)
                    let fname = url.deletingPathExtension().lastPathComponent
                    if fname.uppercased().hasPrefix("AUTHKEY_"), apnsKeyIdField.isEmpty {
                        let extracted = String(fname.dropFirst("AuthKey_".count)).uppercased()
                        if extracted.count >= 6 {
                            apnsKeyIdField = extracted
                        }
                    }
                    vm.showToast("Clé \(url.lastPathComponent) chargée.")
                } else {
                    vm.showToast("Impossible de lire le fichier .p8 sélectionné.")
                }
            case .failure(let err):
                vm.showToast(err.localizedDescription)
            }
        }
        .sheet(isPresented: $isShowingConnectedDevicesSheet) {
            ConnectedDevicesManagerView()
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $isShowingDeleteAccountSheet) {
            deleteAccountConfirmationSheet
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $isShowingBetaFeaturesSheet) {
            VipleBetaSettingsView()
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .onAppear {
            displayNameField = vm.currentUser?.displayName ?? ""
            personalMessageField = vm.currentUser?.personalMessage ?? ""
            cenelisCustomHandleField = vm.suggestedCenelisLocalPart
            Task {
                await notifManager.refreshAuthorizationStatus()
                if vm.isApprovedCenelisAgent {
                    await notifManager.refreshServerApnsStatus()
                }
                await vm.refreshConnectedDevices(silent: true)
                await vm.refreshBlockedSenders()
                if let details = notifManager.apnsStatusDetails?.apns {
                    if !details.teamId.isEmpty { apnsTeamIdField = details.teamId }
                    if !details.keyId.isEmpty { apnsKeyIdField = details.keyId }
                    if !details.bundleId.isEmpty { apnsBundleIdField = details.bundleId }
                    apnsPreferSandboxField = details.preferSandbox
                }
            }
        }
    }

    // MARK: - Carte « Accès Invité Temporaire (1h, 8h, 24h, 48h) & iMessage »

    // MARK: - Carte Proéminente « Fonctions Beta (100 Fonctionnalités — Cases à Cocher & Tout Activer) »

    private var betaFeaturesEntryCard: some View {
        Button {
            isShowingBetaFeaturesSheet = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                        .frame(width: 48, height: 48)
                    Image(systemName: "flask.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Fonctions Beta")
                            .font(.system(size: 15.5, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Text("\(beta.enabledCount) / 100")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(beta.enabledCount > 0 ? VipleMailPalette.success : VipleMailPalette.primary))
                    }
                    Text("100 fonctions complètes (Productivité, Lecture, Rédaction, Motion, Sécurité, Chat, Visio, Agenda, CRM, Power-Tools) — désactivées par défaut.")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            .vipleMailCard(cornerRadius: 18, padding: 14)
        }
    }

    private var activeBetaSettingsShortcutsCard: some View {
        let activeSettingsTools: [VipleBetaFeatureID] = [.f097, .f047, .f049, .f093, .f099].filter { beta.isEnabled($0) }
        return VStack(alignment: .leading, spacing: 10) {
            Label("Outils Beta Actifs (Diagnostic, Sécurité & Règles)", systemImage: "cpu.fill")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            ForEach(activeSettingsTools) { fid in
                let spec = fid.spec
                Button {
                    beta.presentedFeatureWorkspace = fid
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: spec.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(spec.category.accentColor)
                            .frame(width: 28, height: 28)
                            .background(RoundedRectangle(cornerRadius: 8).fill(spec.category.accentColor.opacity(0.14)))
                        Text(spec.title)
                            .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }

    private var academyEmbeddedHelpCard: some View {
        Button {
            vm.isShowingAcademyHelp = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.078, green: 0.325, blue: 0.275))
                        .frame(width: 48, height: 48)
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(Color(red: 0.945, green: 0.733, blue: 0.212))
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Aide & Cours Cenelis Academy")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Text("NOUVEAU")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(red: 0.722, green: 0.365, blue: 0.098)))
                    }
                    Text("« Bienvenue sur Viple Mail, Visio, MailRTE » — parcours interactif intégré")
                        .font(.system(size: 12.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            .vipleMailCard(cornerRadius: 18, padding: 14)
        }
    }

    private var guestAccessAndIMessageCard: some View {
        let activeOutCount = vm.outgoingGuestGrants.count
        let activeInCount = vm.sharedGuestMailboxes.count

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Accès Invité & iMessage", systemImage: "key.radiowaves.forward.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                if activeOutCount > 0 || activeInCount > 0 {
                    Text("\(activeOutCount + activeInCount) ACTIF\((activeOutCount + activeInCount) > 1 ? "S" : "")")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.14)))
                } else {
                    Text("1H • 8H • 24H • 48H")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                }
            }

            Text("Partagez temporairement votre boîte mail pendant 1h, 8h, 24h ou 48h par lien iMessage ou adresse Viple Mail. La boîte partagée s'affiche chez votre invité avec un compte à rebours en direct.")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            if !vm.sharedGuestMailboxes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(vm.sharedGuestMailboxes) { grant in
                        SharedGuestMailboxRowView(
                            grant: grant,
                            isActive: vm.isGuestMailboxActive && vm.currentEmail.lowercased() == grant.ownerMailbox.lowercased()
                        ) {
                            Task {
                                vm.selectedTab = 0
                                await vm.switchActiveMailbox(to: grant.ownerMailbox)
                            }
                        }
                    }
                }
            }

            Button {
                vm.isShowingGuestAccessSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.badge.filled.fill")
                    Text("Partager ma boîte (1h, 8h, 24h, 48h) par iMessage")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Carte Proéminente « Appareils connectés & Badges d'applications Viple Live ID »

    private var connectedDevicesEntryCard: some View {
        let localModel = CenelisDeviceIdentity.friendlyModelName()
        let localOs = CenelisDeviceIdentity.osVersionString()
        let localSymbol = CenelisDeviceIdentity.currentDeviceSymbolName()
        let connectedCount = max(1, vm.connectedDevices.filter { $0.effectiveIsConnected }.count)
        let disconnectedCount = vm.connectedDevices.filter { !$0.effectiveIsConnected }.count
        let currentDevApps = vm.connectedDevices.first(where: { $0.isCurrentDevice })?.connectedApps ?? []

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Appareils Viple Live ID", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineLimit(1)

                Spacer(minLength: 4)

                HStack(spacing: 5) {
                    Text("\(connectedCount) CONNECTÉ\(connectedCount > 1 ? "S" : "")")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.success)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(Capsule().fill(VipleMailPalette.success.opacity(0.14)))

                    if disconnectedCount > 0 {
                        Text("\(disconnectedCount) DÉCO.")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3.5)
                            .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                    }
                }
            }

            Text("Vérifiez dans quelles applications chaque appareil est actuellement connecté grâce aux badges d'icônes, et déconnectez une application ou tout un appareil à distance.")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            Button {
                isShowingConnectedDevicesSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VipleMailPalette.success.opacity(colorScheme == .dark ? 0.18 : 0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: localSymbol)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundStyle(VipleMailPalette.success)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(localModel)
                                .font(.system(size: 14.5, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(VipleMailPalette.success)
                                    .frame(width: 5.5, height: 5.5)
                                Text("Connecté")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.success)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(VipleMailPalette.success.opacity(0.14)))
                        }

                        Text("\(localOs) • \(max(1, currentDevApps.count)) application\(currentDevApps.count > 1 ? "s" : "") active\(currentDevApps.count > 1 ? "s" : "")")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    HStack(spacing: -4) {
                        if currentDevApps.isEmpty {
                            #if canImport(UIKit)
                            if let uiImg = UIImage(named: "EcoIconVipleMail") {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 24, height: 24)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            #endif
                        } else {
                            ForEach(currentDevApps.prefix(4)) { app in
                                #if canImport(UIKit)
                                if let asset = app.resolvedAssetIconName, let uiImg = UIImage(named: asset) {
                                    Image(uiImage: uiImg)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(VipleMailPalette.surface, lineWidth: 1.4))
                                }
                                #endif
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(VipleMailPalette.success.opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Button {
                isShowingConnectedDevicesSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                    Text("Gérer mes appareils & badges d'apps (\(max(1, vm.connectedDevices.count)))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Carte Profil Viple Live ID

    private var accountProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VipleMailAvatarView(
                    name: vm.currentUser?.displayName ?? "Viple",
                    email: vm.primaryHostedEmail,
                    avatarUrl: vm.currentUser?.avatarUrl,
                    size: 58,
                    isVip: true
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.currentUser?.displayName ?? vm.primaryHostedEmail)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        if vm.isApprovedCenelisAgent
                            || vm.primaryHostedEmail.lowercased().hasSuffix("@cenelis.com")
                            || vm.primaryHostedEmail.lowercased().hasSuffix("@viplenetwork.com") {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                    Text(vm.activeMailboxDisplayLabel)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                    if let cid = vm.currentUser?.cid, !cid.isEmpty {
                        Text("Viple Live ID • CID \(cid)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }
                Spacer()
            }

            if (vm.hostedMailboxes.count + vm.externalAccounts.count) > 1 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Boîtes Viple & Vue unifiée", systemImage: "tray.2.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Spacer()
                        if vm.isSwitchingMailbox {
                            ProgressView()
                                .scaleEffect(0.75)
                        }
                    }

                    Button {
                        Task {
                            await vm.switchActiveMailbox(to: "__all__")
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: vm.isUnifiedInboxActive ? "checkmark.circle.fill" : "tray.2.fill")
                                .foregroundStyle(vm.isUnifiedInboxActive ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                            Text("Toutes les boîtes de réception")
                                .font(.system(size: 13.5, weight: vm.isUnifiedInboxActive ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(vm.isUnifiedInboxActive ? VipleMailPalette.primary : VipleMailPalette.ink)
                            Spacer()
                            if vm.isUnifiedInboxActive {
                                Text("ACTIVE")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VipleMailPalette.primary))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(vm.isUnifiedInboxActive ? VipleMailPalette.primary.opacity(0.10) : VipleMailPalette.surfaceSubtle)
                        )
                    }
                    .disabled(vm.isSwitchingMailbox)

                    ForEach(vm.hostedMailboxes, id: \.self) { mbx in
                        let isActive = !vm.isUnifiedInboxActive && mbx.lowercased() == vm.currentEmail.lowercased()
                        let isCenelis = mbx.lowercased().hasSuffix("@cenelis.com")
                        Button {
                            Task {
                                await vm.switchActiveMailbox(to: mbx)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isActive ? "checkmark.circle.fill" : (isCenelis ? "checkmark.seal.fill" : "circle"))
                                    .foregroundStyle((isActive || isCenelis) ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                                Text(mbx)
                                    .font(.system(size: 13.5, weight: isActive ? .bold : .semibold, design: .monospaced))
                                    .foregroundStyle(isActive ? VipleMailPalette.primary : VipleMailPalette.ink)
                                if isCenelis {
                                    Text("CENELIS")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(VipleMailPalette.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                                }
                                Spacer()
                                if isActive {
                                    Text("ACTIVE")
                                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(VipleMailPalette.primary))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isActive ? VipleMailPalette.primary.opacity(0.10) : VipleMailPalette.surfaceSubtle)
                            )
                        }
                        .disabled(vm.isSwitchingMailbox)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Nom d'expéditeur affiché")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField(
                    "Votre nom complet",
                    text: $displayNameField,
                    prompt: VipleMailPalette.prompt("Votre nom complet", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                Text("Statut Viple Live")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField(
                    "Votre message personnel Viple Live",
                    text: $personalMessageField,
                    prompt: VipleMailPalette.prompt("Votre message personnel Viple Live", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Espace Agent Groupe Cenelis (Boîte Professionnelle Officielle @cenelis.com)

    private var cenelisAgentMailboxCard: some View {
        let cenAddr = vm.cenelisMailboxAddress
        let displayAddr = cenAddr ?? "\(vm.suggestedCenelisLocalPart)@cenelis.com"
        let isCurrentlyOpen = !vm.isUnifiedInboxActive && (cenAddr != nil) && vm.currentEmail.lowercased() == cenAddr?.lowercased()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Adresse officielle @cenelis.com", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                Text("AGENT CENELIS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
            }

            Text("En tant qu'agent habilité du Groupe Cenelis, vous disposez de votre boîte professionnelle @cenelis.com certifiée (« Vérifiée : Cenelis SA ») et protégée par Cenelis MailRTE.")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayAddr)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                    Text(cenAddr != nil
                         ? "Active sur Stalwart • Chiffrement Cenelis MailRTE"
                         : "Prête à être activée sur votre compte")
                        .font(.system(size: 11))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                Spacer()

                if isCurrentlyOpen {
                    Text("OUVERTE")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VipleMailPalette.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VipleMailPalette.primary.opacity(0.30), lineWidth: 1)
            )

            if let activeCenelis = cenAddr {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            vm.selectedTab = 0
                            await vm.switchActiveMailbox(to: activeCenelis)
                        }
                    } label: {
                        Label(isCurrentlyOpen ? "Aller à la boîte" : "Ouvrir @cenelis.com", systemImage: "tray.full.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(VipleMailPalette.heroGradient)
                            )
                    }
                    .disabled(vm.isSwitchingMailbox)

                    Button {
                        vm.presentComposer(.newMail(preferredFromMailbox: activeCenelis))
                    } label: {
                        Label("Écrire avec", systemImage: "square.and.pencil")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(VipleMailPalette.primary.opacity(0.11))
                            )
                    }
                }
            } else {
                Button {
                    Task {
                        _ = await vm.claimOrCustomizeCenelisMailbox(
                            desiredLocalPart: cenelisCustomHandleField,
                            switchImmediately: true
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isClaimingCenelisMailbox {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                        }
                        Text("Activer mon adresse \(displayAddr)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(VipleMailPalette.heroGradient)
                    )
                }
                .disabled(vm.isClaimingCenelisMailbox)
            }

            DisclosureGroup(
                isExpanded: $isEditingCenelisHandle,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            TextField(
                                "prenom.nom",
                                text: $cenelisCustomHandleField,
                                prompt: VipleMailPalette.prompt("prenom.nom", scheme: colorScheme)
                            )
                                .vipleMailTextInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, design: .monospaced))
                                .padding(11)
                            Text("@cenelis.com")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(VipleMailPalette.primary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                        Button {
                            Task {
                                let ok = await vm.claimOrCustomizeCenelisMailbox(
                                    desiredLocalPart: cenelisCustomHandleField,
                                    switchImmediately: true
                                )
                                if ok {
                                    isEditingCenelisHandle = false
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isClaimingCenelisMailbox {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text("Attribuer cet identifiant @cenelis.com")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.primary))
                        }
                        .disabled(vm.isClaimingCenelisMailbox)
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text("Personnaliser mon identifiant @cenelis.com")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                }
            )
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Apparence, Thème Clair / Sombre OLED & Rendu des Courriers HTML

    private var appearanceCustomizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Apparence & Mode sombre", systemImage: "moon.stars.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                Text(vm.appearanceMode.title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
            }

            HStack(spacing: 10) {
                ForEach(VipleMailAppearanceMode.allCases) { mode in
                    appearanceModeTile(mode)
                }
            }

            Text(vm.appearanceMode.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            Divider()

            Toggle(isOn: $vm.adaptHtmlEmailsInDarkMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adapter les courriers HTML au mode sombre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Convertit automatiquement les fonds clairs des e-mails reçus pour un confort nocturne optimal (un bouton ☀️/🌙 reste accessible dans chaque courrier)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func appearanceModeTile(_ mode: VipleMailAppearanceMode) -> some View {
        let isSelected = vm.appearanceMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                vm.appearanceMode = mode
            }
        } label: {
            VStack(spacing: 9) {
                // Aperçu visuel miniature Clair / Sombre / Auto
                ZStack {
                    switch mode {
                    case .light:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.95, green: 0.97, blue: 1.00))
                            .overlay(
                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.00, green: 0.47, blue: 0.83))
                                        .frame(width: 24, height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white)
                                        .frame(height: 11)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white)
                                        .frame(height: 11)
                                }
                                .padding(7)
                            )
                    case .dark:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.03, green: 0.04, blue: 0.08))
                            .overlay(
                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.26, green: 0.82, blue: 1.00))
                                        .frame(width: 24, height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.09, green: 0.13, blue: 0.21))
                                        .frame(height: 11)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.09, green: 0.13, blue: 0.21))
                                        .frame(height: 11)
                                }
                                .padding(7)
                            )
                    case .system:
                        HStack(spacing: 0) {
                            Color(red: 0.95, green: 0.97, blue: 1.00)
                            Color(red: 0.03, green: 0.04, blue: 0.08)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.16, green: 0.56, blue: 1.00))
                        )
                    }
                }
                .frame(height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: 1)
                )

                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : mode.iconName)
                        .font(.system(size: 11.5, weight: .bold))
                    Text(mode.title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkSecondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? VipleMailPalette.primary.opacity(0.11) : VipleMailPalette.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comptes E-Mail Externes (Gmail, Outlook, iCloud, Orange, OVH, Pro...)

    private var externalAccountsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Boîtes e-mail externes", systemImage: "globe.europe.africa.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                if !vm.externalAccounts.isEmpty {
                    Text("\(vm.externalAccounts.count)")
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }

            if vm.externalAccounts.isEmpty {
                Text("Ajoutez vos autres adresses e-mail (Gmail, Outlook, iCloud, Yahoo, Orange, Free, SFR, OVH ou professionnelles) pour lire et gérer tous vos courriers dans Viple Mail.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.externalAccounts) { ext in
                        let isActive = !vm.isUnifiedInboxActive && ext.email.lowercased() == vm.currentEmail.lowercased()
                        let tint = VipleMailPalette.colorFromHex(ext.colorHex)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(tint.opacity(0.14))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: ext.providerIcon)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(tint)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(ext.email)
                                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(VipleMailPalette.ink)
                                            .lineLimit(1)
                                        if isActive {
                                            Text("ACTIVE")
                                                .font(.system(size: 9, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(VipleMailPalette.primary))
                                        }
                                    }
                                    Text("\(ext.providerName) • \(ext.imapHost):\(ext.imapPort) • \(ext.canSendSmtp ? "Lecture & Envoi" : "Lecture seule")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(VipleMailPalette.inkMuted)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                Button {
                                    Task {
                                        vm.selectedTab = 0
                                        await vm.switchActiveMailbox(to: ext.email)
                                    }
                                } label: {
                                    Label(isActive ? "Ouvrir la boîte" : "Lire les e-mails", systemImage: "envelope.open.fill")
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(isActive ? .white : VipleMailPalette.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isActive ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.11))
                                        )
                                }

                                Button {
                                    vm.presentAddExternalAccountSheet(editing: ext)
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VipleMailPalette.inkSecondary)
                                        .frame(width: 36, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.surface))
                                }
                                .accessibilityLabel("Modifier les serveurs")

                                Button(role: .destructive) {
                                    accountPendingDeletion = ext
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VipleMailPalette.danger)
                                        .frame(width: 36, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.danger.opacity(0.10)))
                                }
                                .accessibilityLabel("Retirer cette boîte externe")
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isActive ? VipleMailPalette.primary.opacity(0.07) : VipleMailPalette.surfaceSubtle)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isActive ? VipleMailPalette.primary.opacity(0.35) : VipleMailPalette.border, lineWidth: 1)
                        )
                    }
                }
            }

            Button {
                vm.presentAddExternalAccountSheet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(vm.externalAccounts.isEmpty ? "Ajouter une adresse e-mail externe" : "Ajouter une autre boîte externe")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Notifications Push, Badges & Synchronisation d'Arrière-Plan

    private var notificationsControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Notifications & Arrière-plan", systemImage: "bell.badge.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(notifManager.isOsAuthorized && vm.settings.pushNotificationsEnabled
                              ? VipleMailPalette.success
                              : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(notifManager.osStatusLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(notifManager.isOsAuthorized ? VipleMailPalette.success : Color.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((notifManager.isOsAuthorized ? VipleMailPalette.success : Color.orange).opacity(0.12))
                )
            }

            Toggle(isOn: Binding(
                get: { vm.settings.pushNotificationsEnabled },
                set: { newVal in
                    vm.settings.pushNotificationsEnabled = newVal
                    Task {
                        if newVal {
                            let granted = await notifManager.requestPermissionIfNeeded(promptIfNotDetermined: true)
                            if !granted && notifManager.authorizationStatus == .denied {
                                vm.showToast("Activez les notifications Viple Mail dans les Réglages iOS.")
                            }
                        }
                        await vm.saveMailSettings(
                            displayName: displayNameField,
                            personalMessage: personalMessageField
                        )
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activer les notifications instantanées")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Bannières riches avec avatar, actions rapides (Répondre, Lu, Archiver) et actualisation en arrière-plan")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            if notifManager.authorizationStatus == .denied {
                Button {
                    notifManager.openSystemNotificationSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear.badge")
                        Text("Ouvrir les Réglages de notifications iOS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                }
            }

            if vm.settings.pushNotificationsEnabled {
                Divider()

                Toggle(isOn: Binding(
                    get: { vm.settings.vipNotificationsOnly },
                    set: { newVal in
                        vm.settings.vipNotificationsOnly = newVal
                        Task {
                            await vm.saveMailSettings(
                                displayName: displayNameField,
                                personalMessage: personalMessageField
                            )
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uniquement mes Contacts VIP 👑")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Filtre les bannières sonores pour ne signaler que vos expéditeurs favoris")
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }

                Toggle("Son de notification", isOn: $notifManager.soundEnabled)
                    .font(.system(size: 14, weight: .semibold))

                Toggle("Pastille du nombre de non-lus sur l'icône", isOn: $notifManager.badgeEnabled)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    Button {
                        Task {
                            let ok = await notifManager.sendTestNotification(mailboxEmail: vm.currentEmail)
                            if ok {
                                vm.showToast("Notification locale envoyée !")
                            } else {
                                vm.showToast("Veuillez autoriser les notifications dans iOS.")
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "bell.and.waves.left.and.right.fill")
                            Text("Test immédiat")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary.opacity(0.11)))
                    }

                    if vm.isApprovedCenelisAgent {
                        Button {
                            let ownerEmail = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
                            guard !ownerEmail.isEmpty else { return }
                            isTestingRemoteApns = true
                            Task {
                                defer { isTestingRemoteApns = false }
                                do {
                                    let res = try await VipleMailAPIClient.shared.triggerServerApnsTest(
                                        email: ownerEmail,
                                        cid: vm.currentCid,
                                        delaySeconds: 5
                                    )
                                    if res.ok {
                                        vm.showToast(res.message ?? "Verrouillez votre iPhone : push Apple APNs dans 5 s !")
                                    } else {
                                        if res.apnsConfigured == false {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                isApnsConfigExpanded = true
                                            }
                                        }
                                        vm.showToast(res.message ?? "Push APNs indisponible.")
                                    }
                                } catch {
                                    vm.showToast(error.localizedDescription)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isTestingRemoteApns {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "lock.iphone")
                                }
                                Text("Test écran verrouillé (5 s)")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary))
                        }
                        .disabled(isTestingRemoteApns)
                    }
                }

                if vm.isApprovedCenelisAgent {
                    apnsServerAdminSection
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private var apnsServerAdminSection: some View {
        let configured = notifManager.isServerApnsConfigured
        let hasDeviceToken = !(notifManager.apnsDeviceTokenHex ?? "").isEmpty

        return VStack(alignment: .leading, spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Image(systemName: configured ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(configured ? VipleMailPalette.success : Color.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(configured ? "Serveur Push Apple APNs (.p8) actif" : "Clé Apple Push APNs (.p8) non configurée")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)

                    Text(configured
                         ? "Réveil distant HTTP/2 actif sur mail.viplemail.fr • Jeton iPhone : \(hasDeviceToken ? "enregistré" : "en attente")"
                         : "Sans clé Apple .p8 sur mail.viplemail.fr, iOS suspend l'application après ~30 s d'inactivité. Ajoutez votre clé .p8 pour recevoir les notifications même app totalement fermée.")
                        .font(.system(size: 11))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isApnsConfigExpanded.toggle()
                    }
                } label: {
                    Text(isApnsConfigExpanded ? "Fermer" : (configured ? "Modifier" : "Configurer"))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(configured ? VipleMailPalette.primary : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(configured ? VipleMailPalette.primary.opacity(0.12) : Color.orange)
                        )
                }
            }

            if isApnsConfigExpanded {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        TextField(
                            "Team ID Apple (ex: ABCD123456)",
                            text: $apnsTeamIdField,
                            prompt: VipleMailPalette.prompt("Team ID Apple", scheme: colorScheme)
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))

                        TextField(
                            "Key ID .p8 (ex: 9XYZ876543)",
                            text: $apnsKeyIdField,
                            prompt: VipleMailPalette.prompt("Key ID (.p8)", scheme: colorScheme)
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))
                    }

                    TextField(
                        "Bundle ID (com.viplenetwork.viplemail)",
                        text: $apnsBundleIdField,
                        prompt: VipleMailPalette.prompt("com.viplenetwork.viplemail", scheme: colorScheme)
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .vipleMailTextInput()
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))

                    HStack(spacing: 8) {
                        Button {
                            isImportingP8File = true
                        } label: {
                            Label("Importer AuthKey.p8", systemImage: "doc.badge.plus")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(VipleMailPalette.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(VipleMailPalette.primary.opacity(0.12)))
                        }

                        #if canImport(UIKit)
                        Button {
                            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !clip.isEmpty {
                                apnsPrivateKeyP8Field = clip
                                vm.showToast("Clé .p8 collée depuis le presse-papiers.")
                            } else {
                                vm.showToast("Presse-papiers vide.")
                            }
                        } label: {
                            Label("Coller .p8", systemImage: "doc.on.clipboard")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 9).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))
                        }
                        #endif
                    }

                    VipleMailMultiLineEditor(
                        text: $apnsPrivateKeyP8Field,
                        placeholder: configured
                            ? "Laissez vide pour conserver la clé .p8 actuelle, ou collez -----BEGIN PRIVATE KEY----- …"
                            : "-----BEGIN PRIVATE KEY-----\nCollez ici le contenu de votre fichier Apple AuthKey_XXXXXX.p8\n-----END PRIVATE KEY-----",
                        fontSize: 11.5,
                        minHeight: 84,
                        horizontalInset: 10,
                        verticalInset: 8
                    )
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))

                    Toggle("Préférer passerelle Sandbox Xcode (développement)", isOn: $apnsPreferSandboxField)
                        .font(.system(size: 12.5, weight: .medium))

                    Button {
                        let ownerEmail = vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail
                        guard !ownerEmail.isEmpty else { return }
                        isSavingApnsConfig = true
                        Task {
                            defer { isSavingApnsConfig = false }
                            do {
                                let res = try await VipleMailAPIClient.shared.saveAdminApnsCredentials(
                                    email: ownerEmail,
                                    cid: vm.currentCid,
                                    teamId: apnsTeamIdField,
                                    keyId: apnsKeyIdField,
                                    bundleId: apnsBundleIdField,
                                    privateKeyP8: apnsPrivateKeyP8Field,
                                    preferSandbox: apnsPreferSandboxField
                                )
                                if res.ok {
                                    apnsPrivateKeyP8Field = ""
                                    await notifManager.refreshServerApnsStatus()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        isApnsConfigExpanded = false
                                    }
                                    vm.showToast(res.message ?? "Clé APNs .p8 activée sur mail.viplemail.fr !")
                                } else {
                                    vm.showToast(res.error ?? "Impossible d'enregistrer la clé APNs.")
                                }
                            } catch {
                                vm.showToast(error.localizedDescription)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isSavingApnsConfig {
                                ProgressView()
                                    .tint(.white)
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "bolt.shield.fill")
                            }
                            Text("Enregistrer & Activer Push APNs sur le serveur")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.heroGradient))
                    }
                    .disabled(isSavingApnsConfig || apnsTeamIdField.trimmingCharacters(in: .whitespacesAndNewlines).count < 6 || apnsKeyIdField.trimmingCharacters(in: .whitespacesAndNewlines).count < 6)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VipleMailPalette.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Serveurs Officiels viplemail.fr (IMAP / SMTP / Autodiscover)

    private var officialMailServersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Serveurs officiels viplemail.fr & cenelis.com", systemImage: "server.rack")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            VStack(spacing: 8) {
                serverRow(title: "API Mobile & Webmail", value: "mail.viplemail.fr")
                serverRow(title: "Serveur IMAP (SSL/TLS)", value: "\(VipleMailAPIClient.shared.imapHost) : \(VipleMailAPIClient.shared.imapPort)")
                serverRow(title: "Serveur SMTP (STARTTLS / SSL)", value: "\(VipleMailAPIClient.shared.smtpHost) : \(VipleMailAPIClient.shared.smtpStartTlsPort) / \(VipleMailAPIClient.shared.smtpImplicitTlsPort)")
                serverRow(title: "SSO Viple / Cenelis", value: "identity-v2.viple.digital / sso.prod.cenelis.com")
                serverRow(title: "Autodiscover", value: VipleMailAPIClient.shared.autodiscoverHost)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

            if let profileUrl = VipleMailAPIClient.shared.appleProfileDownloadURL(for: vm.currentEmail) {
                Link(destination: profileUrl) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                        Text("Installer le profil Apple Mail (.mobileconfig)")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary.opacity(0.10)))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Mot de passe IMAP / SMTP (pour clients externes)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 8) {
                    SecureField(
                        "Nouveau mot de passe (min. 8 car.)",
                        text: $newImapPasswordField,
                        prompt: VipleMailPalette.prompt("Nouveau mot de passe (min. 8 car.)", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                    Button {
                        let pw = newImapPasswordField
                        Task {
                            if await vm.updatePersonalImapPassword(pw) {
                                newImapPasswordField = ""
                            }
                        }
                    } label: {
                        Text("Activer")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.primary))
                    }
                    .disabled(newImapPasswordField.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func serverRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VipleMailPalette.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(VipleMailPalette.ink)
                .textSelection(.enabled)
        }
    }

    // MARK: - Boîte Prioritaire & Gestes de Balayage

    private var inboxAndSwipeCustomizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Boîte de réception & Gestes de balayage", systemImage: "hand.draw.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            Toggle(isOn: $vm.settings.focusedInboxEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Boîte de réception Prioritaire")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sépare automatiquement vos courriers importants et VIP des autres notifications")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            Divider()

            HStack {
                Text("Balayage vers la droite")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Balayage droite", selection: $vm.settings.swipeRightAction) {
                    Text("Lu / Non lu").tag("ToggleRead")
                    Text("Favori ⭐").tag("Star")
                    Text("Épingler 📌").tag("Pin")
                    Text("Archiver").tag("Archive")
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Balayage vers la gauche")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Balayage gauche", selection: $vm.settings.swipeLeftAction) {
                    Text("Corbeille 🗑️").tag("Trash")
                    Text("Archiver").tag("Archive")
                    Text("Indésirable").tag("Spam")
                    Text("Favori ⭐").tag("Star")
                }
                .pickerStyle(.menu)
            }

            Toggle("Notifications réservées aux Contacts VIP 👑", isOn: $vm.settings.vipNotificationsOnly)
                .font(.system(size: 14, weight: .semibold))
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Signature Personnalisée

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Signature électronique", systemImage: "signature")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Toggle("", isOn: $vm.settings.signatureEnabled)
                    .labelsHidden()
            }

            VipleMailMultiLineEditor(
                text: $vm.settings.signatureHtml,
                placeholder: "Votre signature électronique Viple Mail…",
                fontSize: 13.5,
                minHeight: 75,
                horizontalInset: 12,
                verticalInset: 10
            )
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Répondeur Automatique d'Absence

    private var vacationResponderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Réponse automatique d'absence", systemImage: "airplane.departure")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Toggle("", isOn: $vm.settings.vacationEnabled)
                    .labelsHidden()
            }

            if vm.settings.vacationEnabled {
                TextField(
                    "Objet de la réponse automatique",
                    text: $vm.settings.vacationSubject,
                    prompt: VipleMailPalette.prompt("Objet de la réponse automatique", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                VipleMailMultiLineEditor(
                    text: $vm.settings.vacationBody,
                    placeholder: "Message envoyé automatiquement à vos correspondants pendant votre absence…",
                    fontSize: 13.5,
                    minHeight: 80,
                    horizontalInset: 12,
                    verticalInset: 10
                )
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            Button {
                Task {
                    await vm.saveMailSettings(
                        displayName: displayNameField,
                        personalMessage: personalMessageField
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Enregistrer toutes mes préférences")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.heroGradient))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Confidentialité, Expéditeurs Bloqués, Mentions Légales & Suppression du Compte (Conformité App Store)

    private var privacyLegalAndAccountDeletionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Confidentialité, Sécurité & Compte", systemImage: "hand.raised.shield.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            if !vm.blockedSenders.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expéditeurs bloqués (\(vm.blockedSenders.count))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                    ForEach(vm.blockedSenders, id: \.self) { blocked in
                        HStack {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(VipleMailPalette.danger)
                            Text(blocked)
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.ink)
                                .lineLimit(1)
                            Spacer()
                            Button("Débloquer") {
                                Task {
                                    await vm.unblockSenderAddress(blocked)
                                }
                            }
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.surfaceSubtle))
                    }
                }
                Divider()
            }

            VStack(spacing: 8) {
                if let privUrl = URL(string: "https://mail.viplemail.fr/privacy") {
                    legalNavigationRow(title: "Politique de confidentialité (RGPD)", icon: "lock.doc.fill", url: privUrl)
                }
                if let termsUrl = URL(string: "https://mail.viplemail.fr/terms") {
                    legalNavigationRow(title: "Conditions d'utilisation (CLUF / EULA)", icon: "doc.text.fill", url: termsUrl)
                }
                if let supUrl = URL(string: "https://mail.viplemail.fr/support") {
                    legalNavigationRow(title: "Assistance officielle & Signalement", icon: "lifepreserver.fill", url: supUrl)
                }
            }

            Divider()

            Button(role: .destructive) {
                deleteAccountConfirmationInput = ""
                deleteAccountError = nil
                isShowingDeleteAccountSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.xmark")
                    Text("Supprimer mon compte Viple Live ID…")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(VipleMailPalette.danger)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.danger.opacity(0.09))
                )
            }
            .buttonStyle(.plain)
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func legalNavigationRow(title: String, icon: String, url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.surfaceSubtle))
        }
    }

    private var deleteAccountConfirmationSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(VipleMailPalette.danger.opacity(0.14))
                                .frame(width: 48, height: 48)
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(VipleMailPalette.danger)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Suppression définitive du compte")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)
                            Text(vm.primaryHostedEmail.isEmpty ? vm.currentEmail : vm.primaryHostedEmail)
                                .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.danger)
                        }
                    }

                    Text("Cette opération est irréversible. En confirmant, votre compte Viple Live ID, votre boîte @viplemail.fr, vos courriers, pièces jointes, discussions et l'ensemble de vos sessions d'appareils connectés seront définitivement effacés de nos serveurs.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                    if let deleteAccountError {
                        Text(deleteAccountError)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.danger)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.danger.opacity(0.10)))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Saisissez SUPPRIMER en majuscules pour confirmer :")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.ink)

                        TextField(
                            "SUPPRIMER",
                            text: $deleteAccountConfirmationInput,
                            prompt: VipleMailPalette.prompt("SUPPRIMER", scheme: colorScheme)
                        )
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                        .padding(13)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                    }

                    Button(role: .destructive) {
                        Task {
                            let res = await vm.deleteMyVipleAccount(confirmation: deleteAccountConfirmationInput)
                            if res.ok {
                                isShowingDeleteAccountSheet = false
                            } else {
                                deleteAccountError = res.error
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isDeletingAccount {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text("Supprimer définitivement mon Viple Live ID")
                                .font(.system(size: 15, weight: .heavy, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(deleteAccountConfirmationInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "SUPPRIMER"
                                      ? VipleMailPalette.danger
                                      : VipleMailPalette.inkMuted.opacity(0.45))
                        )
                    }
                    .disabled(vm.isDeletingAccount || deleteAccountConfirmationInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() != "SUPPRIMER")
                }
                .padding(20)
            }
            .background(VipleMailPalette.background)
            .navigationTitle("Supprimer mon compte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Annuler") {
                        isShowingDeleteAccountSheet = false
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                }
            }
        }
    }

    // MARK: - Diagnostics Serveur & Déconnexion

    private var diagnosticsAndSignOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Serveur Viple Mail & SSO Viple Live ID")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text(vm.lastDiagnosticsPing != nil
                         ? "Connecté : \(vm.lastDiagnosticsPing!.host) • \(vm.lastDiagnosticsPing!.version)"
                         : "Hôte : mail.viplemail.fr • IMAP 993 / SMTP 587 TLS")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.success)
                }
                Spacer()
                Button {
                    Task {
                        await vm.runDiagnosticsPing()
                    }
                } label: {
                    Label("Tester", systemImage: "waveform.path.ecg")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }

            Divider()

            Button(role: .destructive) {
                vm.signOut()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Se déconnecter de Viple Mail")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(VipleMailPalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.danger.opacity(0.10)))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }
}
