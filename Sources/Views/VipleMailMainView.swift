import SwiftUI

// MARK: - Coquille Principale « Viple Mail » (Splash animé, En-tête Logo Horizontal Viple Mail, SSO Viple Live ID & Barre d'Onglets Flottante)

public struct VipleMailMainView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var outbox = BetaOutboxCoordinator.shared
    @Environment(\.colorScheme) private var colorScheme

    private enum LaunchExperienceStage {
        case cenelisAppsIntro
        case vipleMailSplash
        case ready
    }

    @State private var launchStage: LaunchExperienceStage = .cenelisAppsIntro
    @State private var vipleMailMinimumSplashDone: Bool = false
    @State private var splashEmblemAppeared: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            if beta.isEnabled(.f039) && beta.oledPureBlackEnabled && colorScheme == .dark {
                Color.black.ignoresSafeArea()
            } else {
                VipleMailPalette.background
                    .ignoresSafeArea()
            }

            switch launchStage {
            case .cenelisAppsIntro:
                CenelisAppsIntroView(currentApp: .vipleMail) {
                    transitionFromEcosystemPortalToAppSplash()
                }
                .transition(.opacity)
                .zIndex(30)

            case .vipleMailSplash:
                splashScreen
                    .transition(.opacity)
                    .zIndex(25)

            case .ready:
                if !vm.isAuthenticated {
                    VipleMailAuthView()
                        .environmentObject(vm)
                        .transition(.opacity)
                } else {
                    authenticatedShell
                        .transition(.opacity)
                }
            }

            if launchStage == .ready, let toast = vm.activeToastMessage {
                VStack {
                    toastBanner(text: toast)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }

            if launchStage == .ready && vm.isAuthenticated {
                VipleVisioGlobalCallOverlay()
                    .environmentObject(vm)
                    .zIndex(200)

                BetaCelebrationParticlesOverlay()
                    .zIndex(220)

                BetaAmberNightShieldOverlay()
                    .zIndex(225)

                BetaBiometricPrivacyShieldOverlay()
                    .zIndex(235)
            }
        }
        .tint(beta.isEnabled(.f032) ? beta.selectedChromaticTheme.primaryColor : VipleMailPalette.primary)
        .task {
            outbox.startScheduledOutboxWatcher(vm: vm)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vipleDeviceDidShake)) { _ in
            guard beta.isEnabled(.f098), let snap = beta.lastUndoSnapshot else { return }
            beta.lastUndoSnapshot = nil
            BetaChoreographedHaptics.play(.tapCrisp)
            Task {
                for (mid, prevFolder) in snap.previousFolderByMessageId {
                    await vm.performMessageAction(messageIds: [mid], action: "move", targetFolder: prevFolder, toast: "📳 Secousse détectée : action annulée")
                }
            }
        }
        .sheet(item: $beta.presentedFeatureWorkspace) { fid in
            VipleBetaWorkspaceRouterSheet(featureId: fid)
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .onChange(of: vm.isInitialBootstrapping) { _, isBootstrapping in
            if !isBootstrapping && vipleMailMinimumSplashDone && launchStage == .vipleMailSplash {
                withAnimation(.easeInOut(duration: 0.42)) {
                    launchStage = .ready
                }
            }
        }
        .fullScreenCover(isPresented: $vm.isShowingAcademyHelp) {
            CenelisAcademyHelpView()
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .fullScreenCover(isPresented: $vm.isShowingComposeSheet) {
            ComposeMailView(mode: vm.activeComposeMode ?? .newMail())
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $vm.isShowingAddExternalAccountSheet) {
            AddExternalAccountSheet()
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $vm.isShowingConnectedDevicesSheet) {
            ConnectedDevicesManagerView()
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(isPresented: $vm.isShowingGuestAccessSheet) {
            GuestMailboxAccessManagerSheet()
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
        .sheet(item: $vm.activeIMessagePayload) { imsgPayload in
            VipleIMessagePresenterSheet(payload: imsgPayload)
                .environmentObject(vm)
                .preferredColorScheme(vm.preferredColorSchemeOverride)
        }
    }

    private func transitionFromEcosystemPortalToAppSplash() {
        splashEmblemAppeared = false
        withAnimation(.easeOut(duration: 0.24)) {
            launchStage = .vipleMailSplash
        }
        withAnimation(.spring(response: 0.54, dampingFraction: 0.78)) {
            splashEmblemAppeared = true
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            vipleMailMinimumSplashDone = true
            if !vm.isInitialBootstrapping && launchStage == .vipleMailSplash {
                withAnimation(.easeInOut(duration: 0.42)) {
                    launchStage = .ready
                }
            }
        }
    }

    // MARK: - Acte 2 : LaunchScreen Officiel « Viple Mail » (Émerge du Portail Cenelis Apps)

    private var splashScreen: some View {
        ZStack {
            Group {
                if colorScheme == .dark {
                    LinearGradient(
                        colors: [
                            Color(red: 0.02, green: 0.05, blue: 0.12),
                            Color(red: 0.03, green: 0.12, blue: 0.28),
                            Color(red: 0.04, green: 0.22, blue: 0.48)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    VipleMailPalette.heroGradient
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(colorScheme == .dark ? 0.10 : 0.16))
                        .frame(width: 132, height: 132)
                        .scaleEffect(splashEmblemAppeared ? 1.0 : 1.35)

                    #if canImport(UIKit)
                    if let iconImg = UIImage(named: "EcoIconVipleMail") {
                        Image(uiImage: iconImg)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFill()
                            .frame(width: 98, height: 98)
                            .clipShape(RoundedRectangle(cornerRadius: 23, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 23, style: .continuous)
                                    .stroke(Color.white.opacity(0.38), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.50 : 0.26), radius: 20, x: 0, y: 10)
                    } else {
                        fallbackSplashBadge
                    }
                    #else
                    fallbackSplashBadge
                    #endif
                }
                .scaleEffect(splashEmblemAppeared ? 1.0 : 0.76)
                .opacity(splashEmblemAppeared ? 1.0 : 0.0)

                VStack(spacing: 7) {
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
                        Text("Connecté en direct au SSO Viple Live ID • MailRTE")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
                .offset(y: splashEmblemAppeared ? 0 : 14)
                .opacity(splashEmblemAppeared ? 1.0 : 0.0)

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.15)
                    .padding(.top, 8)
                    .opacity(splashEmblemAppeared ? 1.0 : 0.0)
            }
        }
    }

    private var fallbackSplashBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(colorScheme == .dark ? Color(red: 0.09, green: 0.14, blue: 0.24) : Color.white)
                .frame(width: 96, height: 96)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22), radius: 18, x: 0, y: 10)

            Image(systemName: "envelope.open.fill")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? VipleMailPalette.azureGlow : VipleMailPalette.primary)
        }
    }

    // MARK: - Interface Principale Authentifiée

    private var isDetailOverlayActive: Bool {
        vm.isReadingMessage || vm.openedMessage != nil || vm.isChatConversationOpen || vm.openedChatSession != nil
    }

    private var authenticatedShell: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                BetaCircadianAuroraBackdropView()

                // Couche 1 : Barre supérieure « Viple Mail » + Contenu de l'onglet actif (0 décalage garanti)
                VStack(spacing: 0) {
                    topBrandHeaderBar
                        .offset(y: isDetailOverlayActive ? -72 : 0)
                        .opacity(isDetailOverlayActive ? 0 : 1)

                    if !isDetailOverlayActive {
                        BetaUpcomingVisioCountdownBanner()
                    }

                    Group {
                        switch vm.selectedTab {
                        case 0:
                            InboxListView()
                        case 1:
                            MailChatView()
                        case 2:
                            MailAgendaView()
                        case 3:
                            MailFoldersView()
                        case 4:
                            MailContactsView()
                        default:
                            MailSettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Couche 2 : Lecture d'un courrier classique plein espace (sans recréer la NavigationStack lors du swipe entre mails)
                if vm.selectedTab == 0, let openedMsg = vm.openedMessage {
                    NavigationStack {
                        MessageDetailView(message: openedMsg)
                    }
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

                // Bouton Flottant « Nouveau » (masqué dans Chat, Agenda, en sélection multiple et pendant la lecture)
                if vm.selectedTab != 1 && vm.selectedTab != 2 && !vm.isSelectionMode && !isDetailOverlayActive {
                    Button {
                        vm.presentComposer(.newMail())
                    } label: {
                        HStack(spacing: VipleMailLayout.isCompactPhone ? 6 : 8) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: VipleMailLayout.isCompactPhone ? 15 : 17, weight: .bold))
                            Text("Nouveau")
                                .font(.system(size: VipleMailLayout.isCompactPhone ? 13.5 : 15, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 15 : 18)
                        .padding(.vertical, VipleMailLayout.isCompactPhone ? 11 : 14)
                        .background(
                            Capsule()
                                .fill(VipleMailPalette.heroGradient)
                                .shadow(color: VipleMailPalette.primary.opacity(0.42), radius: 14, x: 0, y: 7)
                        )
                    }
                    .padding(.trailing, VipleMailLayout.isCompactPhone ? 14 : 20)
                    .padding(.bottom, VipleMailLayout.isCompactPhone ? 12 : 18)
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(20)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomLeading) {
                BetaFloatingRadialWheelOverlay()
            }
            .clipped()

            // #020 : Tiroir flottant de référence mail
            BetaPinnedReferenceDrawerOverlay()

            // #021 : Barre de compte à rebours « Annuler l'envoi »
            if beta.isEnabled(.f021), let pending = outbox.pendingUndo {
                HStack(spacing: 10) {
                    ProgressView().tint(.white).scaleEffect(0.85)
                    Text("Envoi de « \(pending.subject.isEmpty ? "(Sans objet)" : pending.subject) » dans \(pending.secondsRemaining)s…")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer()
                    Button("Annuler") {
                        outbox.cancelPendingSendAndRestoreComposer(vm: vm)
                    }
                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.yellow))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color(red: 0.08, green: 0.12, blue: 0.22))
            }

            // #098 : Bannière d'annulation rapide de la dernière action de tri
            if beta.isEnabled(.f098), let snap = beta.lastUndoSnapshot, Date().timeIntervalSince(snap.timestamp) < 12 {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(.cyan)
                    Text("\(snap.description) (\(snap.messageIds.count))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Rétablir") {
                        let copy = snap
                        beta.lastUndoSnapshot = nil
                        Task {
                            for (mid, prevFolder) in copy.previousFolderByMessageId {
                                await vm.performMessageAction(messageIds: [mid], action: "move", targetFolder: prevFolder, toast: "Action annulée")
                            }
                        }
                    }
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(.cyan)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.84))
            }

            bottomNavigationBar
        }
    }

    // MARK: - En-tête Signature Viple Mail (Logo Horizontal en Haut à Gauche + Boîte Active + Actions)

    private var topBrandHeaderBar: some View {
        let compact = VipleMailLayout.isCompactPhone
        return HStack(spacing: compact ? 6 : 10) {
            VipleMailHorizontalLogoView(height: compact ? 29 : 36, showSubtitle: !compact)

            Spacer(minLength: 4)

            if beta.isEnabled(.f091) {
                Button {
                    beta.presentedFeatureWorkspace = .f091
                } label: {
                    Image(systemName: "command")
                        .font(.system(size: compact ? 13 : 14.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(width: compact ? 29 : 34, height: compact ? 29 : 34)
                        .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                        .overlay(Circle().stroke(VipleMailPalette.border, lineWidth: 1))
                }
                .accessibilityLabel("Palette de commandes universelle")
            }

            if beta.isEnabled(.f050) {
                Button {
                    withAnimation { beta.isPublicStealthMaskActive.toggle() }
                } label: {
                    Image(systemName: beta.isPublicStealthMaskActive ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: compact ? 13 : 14.5, weight: .bold))
                        .foregroundStyle(beta.isPublicStealthMaskActive ? .orange : VipleMailPalette.inkSecondary)
                        .frame(width: compact ? 29 : 34, height: compact ? 29 : 34)
                        .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                        .overlay(Circle().stroke(VipleMailPalette.border, lineWidth: 1))
                }
                .accessibilityLabel("Mode confidentialité discrète")
            }

            Button {
                vm.isShowingAcademyHelp = true
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: compact ? 17.5 : 20, weight: .bold))
                    .foregroundStyle(Color(red: 0.078, green: 0.325, blue: 0.275))
                    .frame(width: compact ? 31 : 36, height: compact ? 31 : 36)
                    .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                    .overlay(Circle().stroke(VipleMailPalette.border, lineWidth: 1))
            }
            .accessibilityLabel("Aide & Formation Cenelis Academy")

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

                    if !vm.sharedGuestMailboxes.isEmpty {
                        Section("Boîtes partagées (Accès Invité)") {
                            ForEach(vm.sharedGuestMailboxes) { grant in
                                let isActiveGuest = vm.isGuestMailboxActive && grant.ownerMailbox.lowercased() == vm.currentEmail.lowercased()
                                Button {
                                    Task {
                                        await vm.switchActiveMailbox(to: grant.ownerMailbox)
                                    }
                                } label: {
                                    Label(
                                        "\(grant.ownerMailbox) • ⏱ \(grant.formattedCountdown(compact: true))",
                                        systemImage: isActiveGuest ? "checkmark.circle.fill" : "key.fill"
                                    )
                                }
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
                        vm.isShowingGuestAccessSheet = true
                    } label: {
                        Label("Accès invité temporaire (1h–48h) & iMessage…", systemImage: "key.radiowaves.forward.fill")
                    }

                    Button {
                        vm.isShowingConnectedDevicesSheet = true
                    } label: {
                        Label("Appareils connectés Viple Live ID", systemImage: "iphone.gen3.radiowaves.left.and.right")
                    }

                    Button {
                        vm.presentAddExternalAccountSheet()
                    } label: {
                        Label("Ajouter une boîte e-mail externe…", systemImage: "plus.circle.fill")
                    }

                    Button {
                        vm.isShowingAcademyHelp = true
                    } label: {
                        Label("Aide & Cours (Cenelis Academy)", systemImage: "graduationcap.fill")
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            vm.selectedTab = 5
                        }
                    } label: {
                        Label("Réglages & Comptes", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    headerAccountPill(user: user, showDropdownChevron: true)
                }
            }
        }
        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 12 : 16)
        .padding(.vertical, VipleMailLayout.isCompactPhone ? 7 : 10)
        .background(
            VipleMailPalette.surface
                .overlay(alignment: .bottom) {
                    if colorScheme == .dark {
                        Rectangle()
                            .fill(VipleMailPalette.border)
                            .frame(height: 0.6)
                    }
                }
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.35) : VipleMailPalette.cobaltDeep.opacity(0.05),
                    radius: 8,
                    x: 0,
                    y: 3
                )
        )
    }

    private func headerAccountPill(user: VipleMailUser, showDropdownChevron: Bool) -> some View {
        let compact = VipleMailLayout.isCompactPhone
        return HStack(spacing: compact ? 6 : 8) {
            if vm.isGuestMailboxActive, let activeGrant = vm.activeGuestGrant, !compact {
                GuestCountdownBadgeView(grant: activeGrant, compact: true, filledStyle: true) {
                    vm.pruneAndExitExpiredGuestMailboxes()
                }
            }

            VStack(alignment: .trailing, spacing: 1) {
                Text(vm.isGuestMailboxActive
                     ? "Invité • \(vm.activeGuestGrant?.ownerDisplayName ?? vm.currentEmail)"
                     : (vm.isExternalMailboxActive ? (vm.activeExternalProviderName ?? user.displayName) : user.displayName))
                    .font(.system(size: compact ? 11.5 : 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    if !vm.isUnifiedInboxActive && vm.currentEmail.lowercased().hasSuffix("@cenelis.com") {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text(vm.activeMailboxDisplayLabel)
                        .font(.system(size: compact ? 9.5 : 10.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if showDropdownChevron {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
            }
            .frame(maxWidth: compact ? 114 : 185, alignment: .trailing)

            VipleMailAvatarView(
                name: user.displayName,
                email: vm.isUnifiedInboxActive ? vm.primaryHostedEmail : vm.currentEmail,
                avatarUrl: vm.isExternalMailboxActive ? nil : user.avatarUrl,
                size: compact ? 29 : 34,
                isVip: true
            )
        }
        .padding(.leading, compact ? 8 : 10)
        .padding(.trailing, compact ? 4 : 5)
        .padding(.vertical, compact ? 4 : 5)
        .background(
            Capsule()
                .fill(VipleMailPalette.surfaceSubtle)
        )
        .overlay(
            Capsule()
                .stroke(VipleMailPalette.border, lineWidth: 1)
        )
    }

    // MARK: - Barre de Navigation Inférieure Optimisée iOS (y compris iPhone SE 375pt)

    private var bottomNavigationBar: some View {
        let compact = VipleMailLayout.isCompactPhone
        let todayEventsCount = vm.agendaEvents.filter { Calendar.current.isDateInToday($0.startDate) }.count
        let contactsBadge = vm.incomingFriendRequests.count > 0
            ? vm.incomingFriendRequests.count
            : vm.contacts.filter { $0.isFavorite }.count

        return HStack(spacing: compact ? 0 : 2) {
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
                title: "Agenda",
                icon: "calendar",
                badge: todayEventsCount
            )
            tabBarItem(
                index: 3,
                title: "Dossiers",
                icon: "folder.fill",
                badge: 0
            )
            tabBarItem(
                index: 4,
                title: "Contacts",
                icon: "person.2.crop.square.stack.fill",
                badge: contactsBadge
            )
            tabBarItem(
                index: 5,
                title: "Réglages",
                icon: "slider.horizontal.3",
                badge: 0
            )
        }
        .padding(.horizontal, compact ? 2 : 6)
        .padding(.top, compact ? 6 : 8)
        .padding(.bottom, compact ? 4 : 6)
        .background(
            VipleMailPalette.surface
                .overlay(alignment: .top) {
                    if colorScheme == .dark {
                        Rectangle()
                            .fill(VipleMailPalette.border)
                            .frame(height: 0.6)
                    }
                }
                .shadow(
                    color: colorScheme == .dark ? Color.black.opacity(0.45) : VipleMailPalette.cobaltDeep.opacity(0.08),
                    radius: 14,
                    x: 0,
                    y: -4
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabBarItem(index: Int, title: String, icon: String, badge: Int) -> some View {
        let isSelected = vm.selectedTab == index
        let compact = VipleMailLayout.isCompactPhone
        return Button {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                vm.closeMessage()
                vm.closeChatSession()
                vm.selectedTab = index
            }
        } label: {
            VStack(spacing: compact ? 2.5 : 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 16 : 18, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                        .frame(width: compact ? 31 : 36, height: compact ? 22 : 25)
                        .background(
                            Capsule()
                                .fill(isSelected ? VipleMailPalette.primary.opacity(0.14) : Color.clear)
                        )

                    if badge > 0 {
                        Text(badge > 99 ? "99+" : "\(badge)")
                            .font(.system(size: compact ? 8.5 : 9.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, compact ? 4 : 4.5)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(index == 4 && vm.incomingFriendRequests.isEmpty ? VipleMailPalette.vipGold : VipleMailPalette.primary)
                            )
                            .offset(x: compact ? 5 : 6, y: -4)
                    }
                }

                Text(title)
                    .font(.system(size: compact ? 9.2 : 10, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.76)
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
                .fill(VipleMailPalette.toastSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(VipleMailPalette.azureGlow.opacity(colorScheme == .dark ? 0.28 : 0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.22), radius: 14, x: 0, y: 6)
        )
    }
}
