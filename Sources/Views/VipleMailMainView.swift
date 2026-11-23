import SwiftUI

// MARK: - Coquille Principale « Viple Mail » (Splash animé, En-tête Logo Horizontal Viple Mail, SSO Viple Live ID & Barre d'Onglets Flottante)

public struct VipleMailMainView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    public var body: some View {
        ZStack {
            VipleMailPalette.background
                .ignoresSafeArea()

            if vm.isInitialBootstrapping {
                splashScreen
                    .transition(.opacity)
            } else if !vm.isAuthenticated {
                VipleMailAuthView()
                    .environmentObject(vm)
                    .transition(.opacity)
            } else {
                authenticatedShell
                    .transition(.opacity)
            }

            if let toast = vm.activeToastMessage {
                VStack {
                    toastBanner(text: toast)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }
        }
        .fullScreenCover(isPresented: $vm.isShowingComposeSheet) {
            ComposeMailView(mode: vm.activeComposeMode ?? .newMail())
                .environmentObject(vm)
        }
        .sheet(isPresented: $vm.isShowingAddExternalAccountSheet) {
            AddExternalAccountSheet()
                .environmentObject(vm)
        }
    }

    // MARK: - Splash Screen Animé Viple Mail

    private var splashScreen: some View {
        ZStack {
            VipleMailPalette.heroGradient
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 118, height: 118)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 92, height: 92)
                        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)

                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Text("Viple")
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Mail")
                            .font(.system(size: 36, weight: .medium, design: .rounded))
                            .foregroundStyle(VipleMailPalette.azureGlow)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(VipleMailPalette.azureGlow)
                        Text("Connecté en direct au SSO Viple Live ID")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
                    .padding(.top, 10)
            }
        }
    }

    // MARK: - Interface Principale Authentifiée

    private var isDetailOverlayActive: Bool {
        vm.isReadingMessage || vm.openedMessage != nil || vm.isChatConversationOpen || vm.openedChatSession != nil
    }

    private var authenticatedShell: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                // Couche 1 : Barre supérieure « Viple Mail » + Contenu de l'onglet actif (0 décalage garanti)
                VStack(spacing: 0) {
                    topBrandHeaderBar
                        .offset(y: isDetailOverlayActive ? -72 : 0)
                        .opacity(isDetailOverlayActive ? 0 : 1)

                    Group {
                        switch vm.selectedTab {
                        case 0:
                            InboxListView()
                        case 1:
                            MailChatView()
                        case 2:
                            MailFoldersView()
                        case 3:
                            MailContactsView()
                        default:
                            MailSettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Couche 2 : Lecture d'un courrier classique plein espace
                if vm.selectedTab == 0, let openedMsg = vm.openedMessage {
                    NavigationStack {
                        MessageDetailView(message: openedMsg)
                    }
                    .id(openedMsg.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VipleMailPalette.surface)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(10)
                }

                // Couche 3 : Session de discussion Chat @viplemail.fr plein espace
                if vm.selectedTab == 1, let openedChat = vm.openedChatSession {
                    NavigationStack {
                        MailChatConversationView(session: openedChat)
                    }
                    .id(openedChat.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VipleMailPalette.background)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing),
                        removal: .move(edge: .trailing)
                    ))
                    .zIndex(11)
                }

                // Bouton Flottant « Nouveau » (masqué dans l'onglet Chat, en sélection multiple et pendant la lecture)
                if vm.selectedTab != 1 && !vm.isSelectionMode && !isDetailOverlayActive {
                    Button {
                        vm.presentComposer(.newMail())
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 17, weight: .bold))
                            Text("Nouveau")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(VipleMailPalette.heroGradient)
                                .shadow(color: VipleMailPalette.primary.opacity(0.42), radius: 14, x: 0, y: 7)
                        )
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 18)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            bottomNavigationBar
        }
    }

    // MARK: - En-tête Signature Viple Mail (Logo Horizontal en Haut à Gauche + Boîte Active + Actions)

    private var topBrandHeaderBar: some View {
        HStack(spacing: 12) {
            VipleMailHorizontalLogoView(height: 36)

            Spacer()

            if let user = vm.currentUser {
                Menu {
                    if (vm.hostedMailboxes.count + vm.externalAccounts.count) > 1 {
                        Button {
                            Task {
                                await vm.switchActiveMailbox(to: "__all__")
                            }
                        } label: {
                            Label(
                                "Toutes les boîtes de réception",
                                systemImage: vm.isUnifiedInboxActive ? "checkmark.circle.fill" : "tray.2.fill"
                            )
                        }
                        Divider()
                    }

                    Section("Boîtes Viple & Cenelis") {
                        ForEach(vm.hostedMailboxes, id: \.self) { mbx in
                            let isCenelis = mbx.lowercased().hasSuffix("@cenelis.com")
                            let isActive = !vm.isUnifiedInboxActive && mbx.lowercased() == vm.currentEmail.lowercased()
                            Button {
                                Task {
                                    await vm.switchActiveMailbox(to: mbx)
                                }
                            } label: {
                                Label(
                                    isCenelis ? "\(mbx) (Agent Cenelis)" : mbx,
                                    systemImage: isActive
                                        ? "checkmark.circle.fill"
                                        : (isCenelis ? "checkmark.seal.fill" : "envelope.fill")
                                )
                            }
                        }

                        if vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil {
                            Button {
                                Task {
                                    _ = await vm.claimOrCustomizeCenelisMailbox(switchImmediately: true)
                                }
                            } label: {
                                Label(
                                    "Activer \(vm.suggestedCenelisLocalPart)@cenelis.com",
                                    systemImage: "checkmark.seal.fill"
                                )
                            }
                        }
                    }

                    if !vm.externalAccounts.isEmpty {
                        Section("Boîtes e-mail externes (IMAP)") {
                            ForEach(vm.externalAccounts) { ext in
                                Button {
                                    Task {
                                        await vm.switchActiveMailbox(to: ext.email)
                                    }
                                } label: {
                                    Label(
                                        "\(ext.email) (\(ext.providerName))",
                                        systemImage: (!vm.isUnifiedInboxActive && ext.email.lowercased() == vm.currentEmail.lowercased())
                                            ? "checkmark.circle.fill"
                                            : ext.providerIcon
                                    )
                                }
                            }
                        }
                    }

                    Divider()

                    Button {
                        vm.presentAddExternalAccountSheet()
                    } label: {
                        Label("Ajouter une boîte e-mail externe…", systemImage: "plus.circle.fill")
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            vm.selectedTab = 4
                        }
                    } label: {
                        Label("Réglages & Comptes", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    headerAccountPill(user: user, showDropdownChevron: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            VipleMailPalette.surface
                .shadow(color: VipleMailPalette.cobaltDeep.opacity(0.05), radius: 8, x: 0, y: 3)
        )
    }

    private func headerAccountPill(user: VipleMailUser, showDropdownChevron: Bool) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(vm.isExternalMailboxActive ? (vm.activeExternalProviderName ?? user.displayName) : user.displayName)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    if !vm.isUnifiedInboxActive && vm.currentEmail.lowercased().hasSuffix("@cenelis.com") {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text(vm.activeMailboxDisplayLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .lineLimit(1)
                    if showDropdownChevron {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
            }
            VipleMailAvatarView(
                name: user.displayName,
                email: vm.isUnifiedInboxActive ? vm.primaryHostedEmail : vm.currentEmail,
                avatarUrl: vm.isExternalMailboxActive ? nil : user.avatarUrl,
                size: 34,
                isVip: true
            )
        }
        .padding(.leading, 10)
        .padding(.trailing, 5)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(VipleMailPalette.surfaceSubtle)
        )
        .overlay(
            Capsule()
                .stroke(VipleMailPalette.border, lineWidth: 1)
        )
    }

    // MARK: - Barre de Navigation Inférieure Optimisée iOS

    private var bottomNavigationBar: some View {
        HStack(spacing: 4) {
            tabBarItem(
                index: 0,
                title: "Boîte",
                icon: "tray.full.fill",
                badge: vm.unreadInboxCount
            )
            tabBarItem(
                index: 1,
                title: "Chat",
                icon: "bubble.left.and.bubble.right.fill",
                badge: vm.chatUnreadCount
            )
            tabBarItem(
                index: 2,
                title: "Dossiers",
                icon: "folder.fill",
                badge: 0
            )
            tabBarItem(
                index: 3,
                title: "Contacts",
                icon: "person.2.crop.square.stack.fill",
                badge: vm.contacts.filter { $0.isFavorite }.count
            )
            tabBarItem(
                index: 4,
                title: "Réglages",
                icon: "slider.horizontal.3",
                badge: 0
            )
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            VipleMailPalette.surface
                .shadow(color: VipleMailPalette.cobaltDeep.opacity(0.08), radius: 14, x: 0, y: -4)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarItem(index: Int, title: String, icon: String, badge: Int) -> some View {
        let isSelected = vm.selectedTab == index
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                vm.closeMessage()
                vm.closeChatSession()
                vm.selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                        .frame(width: 42, height: 26)
                        .background(
                            Capsule()
                                .fill(isSelected ? VipleMailPalette.primary.opacity(0.14) : Color.clear)
                        )

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(index == 3 ? VipleMailPalette.vipGold : VipleMailPalette.primary)
                            )
                            .offset(x: 8, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func toastBanner(text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VipleMailPalette.azureGlow)
            Text(text)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VipleMailPalette.cobaltDeep.opacity(0.96))
                .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 6)
        )
    }
}
