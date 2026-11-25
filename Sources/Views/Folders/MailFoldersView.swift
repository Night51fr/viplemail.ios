import SwiftUI

// MARK: - Dossiers & Stockage Cloud « Viple Mail » (Dossiers Système, Dossiers Personnalisés & Quota 5 Go SkyDrive)

public struct MailFoldersView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var newFolderName: String = ""

    public init() {}

    private var systemFolders: [VipleMailFolderSummary] {
        vm.folders.filter { $0.isSystem }
    }

    private var customFolders: [VipleMailFolderSummary] {
        vm.folders.filter { !$0.isSystem }
    }

    private var enabledFolderBetaModules: [VipleBetaFeatureID] {
        [.f100, .f008, .f010, .f044, .f093, .f095, .f099].filter { beta.isEnabled($0) }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                storageQuotaBannerCard
                if !enabledFolderBetaModules.isEmpty {
                    betaCloudToolsSection
                }
                connectedMailboxesSection
                systemFoldersSection
                if !vm.isUnifiedInboxActive {
                    customFoldersSection
                }
            }
            .padding(16)
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.isShowingCreateFolderSheet) {
            createFolderSheet
        }
    }

    private var betaCloudToolsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MODULES BETA & STOCKAGE SOUVERAIN")
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)

            VStack(spacing: 8) {
                ForEach(enabledFolderBetaModules) { fid in
                    if let spec = VipleBetaFeatureCatalog.spec(for: fid) {
                        Button {
                            beta.presentedFeatureWorkspace = fid
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(spec.category.accentColor.opacity(0.14))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: spec.icon)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(spec.category.accentColor)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(spec.title)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundStyle(VipleMailPalette.ink)
                                        .lineLimit(1)
                                    Text("\(spec.code) • \(spec.locationHint)")
                                        .font(.system(size: 11.5))
                                        .foregroundStyle(VipleMailPalette.inkMuted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.inkMuted)
                            }
                            .padding(11)
                            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(VipleMailPalette.surface))
                            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(VipleMailPalette.border, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Sélecteur Rapide de Boîte aux Lettres (Viple, Cenelis & Boîtes Externes IMAP)

    private var connectedMailboxesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: VipleMailLayout.isCompactPhone ? 6 : 10) {
                Text("MES BOÎTES AUX LETTRES")
                    .font(.system(size: VipleMailLayout.isCompactPhone ? 10.5 : 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 4)
                Button {
                    vm.isShowingGuestAccessSheet = true
                } label: {
                    Label("Accès invité", systemImage: "key.radiowaves.forward.fill")
                        .font(.system(size: VipleMailLayout.isCompactPhone ? 11 : 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 8 : 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.11)))
                }
                Button {
                    vm.presentAddExternalAccountSheet()
                } label: {
                    Label("Externe", systemImage: "plus.circle.fill")
                        .font(.system(size: VipleMailLayout.isCompactPhone ? 11 : 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(VipleMailPalette.primary)
                }
            }

            if !vm.sharedGuestMailboxes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                        Text("BOÎTES PARTAGÉES AVEC MOI (ACCÈS INVITÉ)")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                        Spacer()
                    }
                    .padding(.top, 2)

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
                .padding(.bottom, 4)
            }

            VStack(spacing: 8) {
                if (vm.hostedMailboxes.count + vm.externalAccounts.count) > 1 {
                    mailboxSwitcherRow(
                        title: "Toutes les boîtes de réception",
                        subtitle: "\(vm.hostedMailboxes.count + vm.externalAccounts.count) comptes synchronisés",
                        icon: "tray.2.fill",
                        tint: VipleMailPalette.primary,
                        isActive: vm.isUnifiedInboxActive
                    ) {
                        Task {
                            vm.selectedTab = 0
                            await vm.switchActiveMailbox(to: "__all__")
                        }
                    }
                }

                ForEach(vm.hostedMailboxes, id: \.self) { mbx in
                    let active = !vm.isUnifiedInboxActive && mbx.lowercased() == vm.currentEmail.lowercased()
                    let isCenelis = mbx.lowercased().hasSuffix("@cenelis.com")
                    mailboxSwitcherRow(
                        title: mbx,
                        subtitle: isCenelis ? "Agent Groupe Cenelis • Sceau Cenelis SA & MailRTE" : "Viple Mail • Cenelis MailRTE",
                        icon: isCenelis ? "checkmark.seal.fill" : "checkmark.shield.fill",
                        tint: VipleMailPalette.primary,
                        isActive: active
                    ) {
                        Task {
                            vm.selectedTab = 0
                            await vm.switchActiveMailbox(to: mbx)
                        }
                    }
                }

                if vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil {
                    mailboxSwitcherRow(
                        title: "\(vm.suggestedCenelisLocalPart)@cenelis.com",
                        subtitle: "Proposée pour votre compte Agent Groupe Cenelis • Toucher pour activer",
                        icon: "checkmark.seal.fill",
                        tint: VipleMailPalette.primary,
                        isActive: false
                    ) {
                        Task {
                            vm.selectedTab = 0
                            _ = await vm.claimOrCustomizeCenelisMailbox(switchImmediately: true)
                        }
                    }
                }

                ForEach(vm.externalAccounts) { ext in
                    let active = !vm.isUnifiedInboxActive && ext.email.lowercased() == vm.currentEmail.lowercased()
                    mailboxSwitcherRow(
                        title: ext.email,
                        subtitle: "\(ext.providerName) • IMAP/TLS",
                        icon: ext.providerIcon,
                        tint: VipleMailPalette.colorFromHex(ext.colorHex),
                        isActive: active
                    ) {
                        Task {
                            vm.selectedTab = 0
                            await vm.switchActiveMailbox(to: ext.email)
                        }
                    }
                }
            }
        }
    }

    private func mailboxSwitcherRow(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .lineLimit(1)
                }

                Spacer()

                if isActive {
                    Text("ACTIVE")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VipleMailPalette.primary))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(VipleMailPalette.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isActive ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Jauge de Stockage Cloud Viple Mail / SkyDrive ou IMAP Externe

    private var storageQuotaBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: vm.isExternalMailboxActive ? "globe.europe.africa.fill" : (vm.isUnifiedInboxActive ? "tray.2.fill" : "externaldrive.fill.badge.icloud"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.isUnifiedInboxActive
                         ? "Vue Unifiée • Toutes vos boîtes"
                         : (vm.isExternalMailboxActive
                            ? "Boîte externe • \(vm.activeExternalProviderName ?? vm.currentEmail)"
                            : "Stockage Cloud Viple Mail & SkyDrive"))
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let quota = vm.mailboxQuota, quota.quotaBytes > 0 {
                        Text("\(quota.formattedUsed) utilisés sur \(quota.formattedQuota)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    } else if vm.isExternalMailboxActive {
                        Text("Synchronisé en direct via IMAP/TLS (\(vm.currentEmail))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    } else {
                        Text("5 Go inclus avec votre compte Viple Live ID")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.86))
                    }
                }
                Spacer()
            }

            GeometryReader { geo in
                let fraction = vm.mailboxQuota?.usageFraction ?? 0.01
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(12, geo.size.width * fraction), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VipleMailPalette.heroGradient)
                .shadow(color: VipleMailPalette.primary.opacity(0.32), radius: 14, x: 0, y: 6)
        )
    }

    // MARK: - Dossiers Système

    private var systemFoldersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BOÎTES & DOSSIERS SYSTÈME")
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)

            VStack(spacing: 8) {
                ForEach(systemFolders) { folder in
                    folderRow(folder)
                }
            }
        }
    }

    // MARK: - Dossiers Personnalisés

    private var customFoldersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("MES DOSSIERS PERSONNALISÉS")
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkMuted)
                Spacer()
                Button {
                    newFolderName = ""
                    vm.isShowingCreateFolderSheet = true
                } label: {
                    Label("Nouveau dossier", systemImage: "folder.badge.plus")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                }
            }

            if customFolders.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title3)
                        .foregroundStyle(VipleMailPalette.primary)
                    Text("Créez vos propres dossiers (ex: Factures, Projets, Voyages) pour classer vos courriers @viplemail.fr.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                }
                .vipleMailCard(cornerRadius: 18, padding: 14)
            } else {
                VStack(spacing: 8) {
                    ForEach(customFolders) { folder in
                        HStack {
                            folderRow(folder)
                            Button(role: .destructive) {
                                Task {
                                    await vm.deleteCustomFolder(name: folder.id)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(VipleMailPalette.danger)
                                    .padding(10)
                            }
                        }
                    }
                }
            }
        }
    }

    private func folderRow(_ folder: VipleMailFolderSummary) -> some View {
        let isActive = vm.activeFolderId.caseInsensitiveCompare(folder.id) == .orderedSame
        let tintColor = VipleMailPalette.colorFromHex(folder.colorHex)

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                vm.closeMessage()
                vm.activeFolderId = folder.id
                vm.selectedTab = 0
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tintColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: folder.icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(tintColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.name)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("\(folder.totalCount) message(s)")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                Spacer()

                if folder.unreadCount > 0 {
                    Text("\(folder.unreadCount) non lu(s)")
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tintColor))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkMuted)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VipleMailPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isActive ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: isActive ? 1.5 : 1)
            )
        }
    }

    private var createFolderSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Nom du nouveau dossier")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                TextField(
                    "Ex : Factures Viple, Projets 2026...",
                    text: $newFolderName,
                    prompt: VipleMailPalette.prompt("Ex : Factures Viple, Projets 2026...", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.resolvedSurface(for: colorScheme)))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VipleMailPalette.border, lineWidth: 1))

                Button {
                    let clean = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !clean.isEmpty else { return }
                    Task {
                        let ok = await vm.createCustomFolder(name: clean)
                        if ok {
                            vm.isShowingCreateFolderSheet = false
                        }
                    }
                } label: {
                    Text("Créer le dossier")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.heroGradient))
                }
                Spacer()
            }
            .padding(20)
            .background(VipleMailPalette.background)
            .navigationTitle("Nouveau dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        vm.isShowingCreateFolderSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(260)])
        .preferredColorScheme(vm.preferredColorSchemeOverride)
    }
}
