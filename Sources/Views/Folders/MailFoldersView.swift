import SwiftUI

// MARK: - Dossiers & Stockage Cloud « Viple Mail » (Dossiers Système, Dossiers Personnalisés & Quota 5 Go SkyDrive)

public struct MailFoldersView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var newFolderName: String = ""

    public init() {}

    private var systemFolders: [VipleMailFolderSummary] {
        vm.folders.filter { $0.isSystem }
    }

    private var customFolders: [VipleMailFolderSummary] {
        vm.folders.filter { !$0.isSystem }
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                storageQuotaBannerCard
                systemFoldersSection
                customFoldersSection
            }
            .padding(16)
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.isShowingCreateFolderSheet) {
            createFolderSheet
        }
    }

    // MARK: - Jauge de Stockage Cloud Viple Mail / SkyDrive (5 Go)

    private var storageQuotaBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "externaldrive.fill.badge.icloud")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Stockage Cloud Viple Mail & SkyDrive")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    if let quota = vm.mailboxQuota {
                        Text("\(quota.formattedUsed) utilisés sur \(quota.formattedQuota)")
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

                TextField("Ex : Factures Viple, Projets 2026...", text: $newFolderName)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surface))
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
    }
}
