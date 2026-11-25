import SwiftUI

// MARK: - Boîte de Réception & Liste des Courriers « Viple Mail » (Prioritaire/Autres, Puces de Filtre, Balayages Configurables & Sélection Multiple)

public struct InboxListView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var moveTargetSheetMessageIds: [String] = []
    @State private var isShowingMoveFolderSheet: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            folderAndSearchHeader
            BetaInboxQuickStripView()

            if vm.isGuestMailboxActive, let activeGrant = vm.activeGuestGrant, !vm.isSelectionMode {
                ActiveGuestMailboxBannerView(grant: activeGrant)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if !vm.sharedGuestMailboxes.isEmpty && vm.activeFolderId == "Inbox" && vm.searchQuery.isEmpty && !vm.isSelectionMode {
                AvailableSharedMailboxesStripView()
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if vm.shouldShowCenelisInboxProposalBanner && vm.activeFolderId == "Inbox" && vm.searchQuery.isEmpty && !vm.isSelectionMode {
                cenelisAgentProposalBanner
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if vm.isSelectionMode {
                bulkSelectionHeaderBar
            }

            if vm.displayedMessages.isEmpty {
                emptyMailboxState
            } else {
                List {
                    if !vm.pinnedDisplayedMessages.isEmpty {
                        Section {
                            ForEach(vm.pinnedDisplayedMessages) { msg in
                                messageRowWithNavigationAndSwipes(msg)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Image(systemName: "pin.fill")
                                    .foregroundStyle(VipleMailPalette.primary)
                                Text("ÉPINGLÉS")
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                        }
                    }

                    Section {
                        ForEach(vm.unpinnedDisplayedMessages) { msg in
                            messageRowWithNavigationAndSwipes(msg)
                        }
                    } header: {
                        if !vm.pinnedDisplayedMessages.isEmpty {
                            Text("MESSAGES RÉCENTS")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(VipleMailPalette.background)
                .refreshable {
                    await vm.refreshBootstrap()
                }
            }

            if vm.isSelectionMode && !vm.selectedMessageIds.isEmpty {
                bulkActionsBottomBar
            }
        }
        .background(VipleMailPalette.background)
        .sheet(isPresented: $isShowingMoveFolderSheet) {
            moveToFolderPickerSheet
        }
        .onChange(of: vm.unreadInboxCount) { oldCount, newCount in
            if beta.isEnabled(.f033) && oldCount > 0 && newCount == 0 {
                beta.triggerCelebrationParticles()
                BetaChoreographedHaptics.play(.sendCrystal)
            }
        }
    }

    // MARK: - En-tête Dossier Actif, Recherche, Prioritaire/Autres & Puces de Filtre

    private var folderAndSearchHeader: some View {
        let compact = VipleMailLayout.isCompactPhone
        return VStack(spacing: compact ? 8 : 10) {
            HStack(spacing: compact ? 6 : 10) {
                Menu {
                    ForEach(vm.folders) { folder in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                                vm.activeFolderId = folder.id
                            }
                        } label: {
                            Label(
                                folder.unreadCount > 0 ? "\(folder.name) (\(folder.unreadCount))" : folder.name,
                                systemImage: folder.icon
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(vm.activeFolderTitle)
                            .font(.system(size: compact ? 18.5 : 22, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.system(size: compact ? 13.5 : 15, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }

                Spacer(minLength: 4)

                if vm.activeFolderId == "Trash" || vm.activeFolderId == "Spam" {
                    Button(role: .destructive) {
                        Task {
                            await vm.emptyFolder(vm.activeFolderId)
                        }
                    } label: {
                        Label("Vider", systemImage: "trash.slash.fill")
                            .font(.system(size: compact ? 11.5 : 12.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                            .foregroundStyle(VipleMailPalette.danger)
                            .padding(.horizontal, compact ? 9 : 11)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(VipleMailPalette.danger.opacity(0.12)))
                    }
                }

                Button {
                    Task {
                        await vm.markCurrentFolderAllRead()
                    }
                } label: {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: compact ? 13 : 14, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(width: compact ? 31 : 34, height: compact ? 31 : 34)
                        .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                }
                .accessibilityLabel("Tout marquer comme lu")

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        vm.isSelectionMode.toggle()
                        if !vm.isSelectionMode {
                            vm.selectedMessageIds.removeAll()
                        }
                    }
                } label: {
                    Text(vm.isSelectionMode ? "OK" : "Sélectionner")
                        .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(vm.isSelectionMode ? .white : VipleMailPalette.primary)
                        .padding(.horizontal, compact ? 10 : 12)
                        .padding(.vertical, compact ? 6 : 7)
                        .background(
                            Capsule()
                                .fill(vm.isSelectionMode ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle)
                        )
                }
            }

            // Barre de recherche instantanée
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VipleMailPalette.primary)
                TextField(
                    "Rechercher par objet, expéditeur, contenu...",
                    text: $vm.searchQuery,
                    prompt: VipleMailPalette.prompt("Rechercher par objet, expéditeur, contenu...", scheme: colorScheme)
                )
                    .font(.system(size: 14.5))
                    .vipleMailTextInput()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !vm.searchQuery.isEmpty {
                    Button {
                        vm.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme))
            )

            // #092 : Puces d'opérateurs booléens Pro lors de la recherche
            if beta.isEnabled(.f092) && !vm.searchQuery.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(["is:unread", "has:attachment", "is:vip", "is:starred", "domain:cenelis.com"], id: \.self) { op in
                            Button {
                                if !vm.searchQuery.contains(op) {
                                    vm.searchQuery += (vm.searchQuery.hasSuffix(" ") ? "" : " ") + op
                                }
                            } label: {
                                Text(op)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(VipleMailPalette.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                            }
                        }
                    }
                }
            }

            // Onglets Prioritaire / Autres (Focused Inbox)
            if vm.activeFolderId == "Inbox" && vm.settings.focusedInboxEnabled && vm.searchQuery.isEmpty {
                HStack(spacing: 8) {
                    focusedSegmentButton(index: 0, title: "Prioritaire", icon: "sparkles")
                    focusedSegmentButton(index: 1, title: "Autres", icon: "tray")
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )
            }

            // Puces de filtres rapides
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MailFilterChip.allCases) { chip in
                        let selected = vm.activeFilterChip == chip
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                vm.activeFilterChip = chip
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: chip.iconName)
                                    .font(.system(size: 11.5, weight: .bold))
                                Text(chip.rawValue)
                                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(selected ? .white : VipleMailPalette.inkSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle)
                            )
                        }
                    }
                }
            }
        }
        .padding(.horizontal, VipleMailLayout.isCompactPhone ? 12 : 16)
        .padding(.vertical, VipleMailLayout.isCompactPhone ? 9 : 12)
        .background(
            VipleMailPalette.surface
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(VipleMailPalette.border)
                        .frame(height: 0.6)
                }
        )
    }

    private var cenelisAgentProposalBanner: some View {
        let proposedAddress = vm.cenelisMailboxAddress ?? "\(vm.suggestedCenelisLocalPart)@cenelis.com"
        let alreadyAssigned = vm.cenelisMailboxAddress != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text("AGENT HABILITÉ GROUPE CENELIS")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                        Spacer()
                        Button {
                            vm.dismissCenelisInboxProposalBanner()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                                .padding(4)
                        }
                        .accessibilityLabel("Masquer la suggestion @cenelis.com")
                    }

                    Text("Votre boîte professionnelle \(proposedAddress) est disponible")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)

                    Text("Ouvrez directement votre messagerie @cenelis.com (sceau « Vérifiée : Cenelis SA » & Cenelis MailRTE) ou réunissez vos deux boîtes.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }

            HStack(spacing: 8) {
                Button {
                    Task {
                        if let existing = vm.cenelisMailboxAddress {
                            await vm.switchActiveMailbox(to: existing)
                        } else {
                            _ = await vm.claimOrCustomizeCenelisMailbox(switchImmediately: true)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if vm.isSwitchingMailbox || vm.isClaimingCenelisMailbox {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                        }
                        Text(alreadyAssigned ? "Ouvrir \(proposedAddress)" : "Activer \(proposedAddress)")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(VipleMailPalette.heroGradient)
                    )
                }
                .disabled(vm.isSwitchingMailbox || vm.isClaimingCenelisMailbox)

                if alreadyAssigned {
                    Button {
                        Task {
                            await vm.switchActiveMailbox(to: "__all__")
                        }
                    } label: {
                        Label("Les 2 boîtes", systemImage: "tray.2.fill")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.vertical, 9)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(VipleMailPalette.primary.opacity(0.11))
                            )
                    }
                    .disabled(vm.isSwitchingMailbox)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VipleMailPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VipleMailPalette.primary.opacity(0.28), lineWidth: 1)
        )
    }

    private func focusedSegmentButton(index: Int, title: String, icon: String) -> some View {
        let active = vm.focusedInboxSegment == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                vm.focusedInboxSegment = index
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(active ? VipleMailPalette.surfaceElevated : Color.clear)
                    .shadow(color: active ? Color.black.opacity(colorScheme == .dark ? 0.28 : 0.06) : .clear, radius: 4, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(active && colorScheme == .dark ? VipleMailPalette.border : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(active ? VipleMailPalette.primary : VipleMailPalette.inkSecondary)
        }
    }

    // MARK: - Ligne de Courrier avec Balayages Gauche/Droite & Menu Contextuel

    @ViewBuilder
    private func messageRowWithNavigationAndSwipes(_ msg: VipleMailMessage) -> some View {
        Group {
            if vm.isSelectionMode {
                Button {
                    if vm.selectedMessageIds.contains(msg.id) {
                        vm.selectedMessageIds.remove(msg.id)
                    } else {
                        vm.selectedMessageIds.insert(msg.id)
                    }
                } label: {
                    messageRowContent(msg)
                }
            } else if msg.folder.lowercased() == "drafts" {
                Button {
                    vm.presentComposer(.editDraft(msg))
                } label: {
                    messageRowContent(msg)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    vm.openMessage(msg)
                } label: {
                    messageRowContent(msg)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    await vm.executeConfiguredSwipe(for: msg, isRightSwipe: true)
                }
            } label: {
                Label(
                    msg.isRead ? "Non lu" : "Lu",
                    systemImage: msg.isRead ? "envelope.badge.fill" : "envelope.open.fill"
                )
            }
            .tint(VipleMailPalette.primary)

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "toggle_pin",
                        toast: msg.isPinned ? "Message désépinglé" : "Message épinglé 📌"
                    )
                }
            } label: {
                Label(msg.isPinned ? "Désépingler" : "Épingler", systemImage: "pin.fill")
            }
            .tint(VipleMailPalette.indigo)

            if beta.isEnabled(.f001) {
                Button {
                    let wake = Date().addingTimeInterval(14 * 3600)
                    beta.snoozedMails[msg.id] = BetaSnoozedMail(
                        messageId: msg.id,
                        subject: msg.subject,
                        senderName: msg.senderName,
                        wakeAt: wake
                    )
                    beta.saveState()
                    vm.showToast("😴 Courrier mis en sommeil jusqu'à demain")
                } label: {
                    Label("Snooze", systemImage: "moon.zzz.fill")
                }
                .tint(.purple)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "trash",
                        toast: "Déplacé dans la Corbeille"
                    )
                }
            } label: {
                Label("Supprimer", systemImage: "trash.fill")
            }

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "archive",
                        toast: "Message archivé"
                    )
                }
            } label: {
                Label("Archiver", systemImage: "archivebox.fill")
            }
            .tint(Color.gray)

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "toggle_star",
                        toast: msg.isStarred ? "Retiré des favoris" : "Ajouté aux favoris ⭐"
                    )
                }
            } label: {
                Label("Favori", systemImage: "star.fill")
            }
            .tint(VipleMailPalette.starYellow)
        }
        .contextMenu {
            Button {
                vm.presentComposer(.reply(msg))
            } label: {
                Label("Répondre", systemImage: "arrowshape.turn.up.left.fill")
            }
            Button {
                vm.presentComposer(.replyAll(msg))
            } label: {
                Label("Répondre à tous", systemImage: "arrowshape.turn.up.left.2.fill")
            }
            Button {
                vm.presentComposer(.forward(msg))
            } label: {
                Label("Transférer", systemImage: "arrowshape.turn.up.right.fill")
            }
            if !msg.isLockedByCenelisPin {
                Button {
                    Task {
                        await vm.shareMessageViaIMessage(msg)
                    }
                } label: {
                    Label("Envoyer le lien direct par iMessage", systemImage: "message.badge.filled.fill")
                }
            }
            Divider()
            Button {
                Task {
                    await vm.performMessageAction(messageIds: [msg.id], action: "toggle_read")
                }
            } label: {
                Label(msg.isRead ? "Marquer comme non lu" : "Marquer comme lu", systemImage: msg.isRead ? "envelope.badge" : "envelope.open")
            }
            Button {
                Task {
                    await vm.performMessageAction(messageIds: [msg.id], action: "toggle_star")
                }
            } label: {
                Label(msg.isStarred ? "Retirer des favoris" : "Ajouter aux favoris", systemImage: "star")
            }
            Button {
                Task {
                    await vm.performMessageAction(messageIds: [msg.id], action: "toggle_pin")
                }
            } label: {
                Label(msg.isPinned ? "Désépingler" : "Épingler en haut", systemImage: "pin")
            }
            Button {
                moveTargetSheetMessageIds = [msg.id]
                isShowingMoveFolderSheet = true
            } label: {
                Label("Déplacer vers un dossier...", systemImage: "folder")
            }
            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "spam",
                        toast: "Signalé comme indésirable"
                    )
                }
            } label: {
                Label("Déplacer dans Indésirables", systemImage: "exclamationmark.shield")
            }
            Divider()
            Button(role: .destructive) {
                Task {
                    await vm.performMessageAction(
                        messageIds: [msg.id],
                        action: "trash",
                        toast: "Message supprimé"
                    )
                }
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func messageRowContent(_ msg: VipleMailMessage) -> some View {
        let isSelected = vm.selectedMessageIds.contains(msg.id)
        let compact = VipleMailLayout.isCompactPhone
        return HStack(alignment: .top, spacing: compact ? 10 : 12) {
            if vm.isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 20 : 22, weight: .bold))
                    .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                    .padding(.top, 8)
            }

            VipleMailAvatarView(
                name: msg.folder == "Sent" ? msg.recipientEmail : msg.senderName,
                email: msg.folder == "Sent" ? msg.recipientEmail : msg.senderEmail,
                avatarUrl: msg.folder == "Sent"
                    ? vm.resolveAvatarUrl(for: msg.recipientEmail, explicitUrl: msg.recipientAvatarUrl)
                    : vm.resolveAvatarUrl(for: msg.senderEmail, explicitUrl: msg.senderAvatarUrl),
                size: compact ? 40 : 46,
                isVip: msg.isVipSender,
                isUnread: !msg.isRead
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 5) {
                    if msg.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    if msg.isHighPriority {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VipleMailPalette.danger)
                    }
                    Text(msg.folder == "Sent" ? "À : \(msg.recipientEmail)" : msg.senderName)
                        .font(.system(size: compact ? 14.2 : 15, weight: msg.isRead ? .semibold : .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                        .layoutPriority(1)

                    if msg.folder != "Sent" && msg.shouldShowVerifiedSenderBadge {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }

                    if msg.isVipSender {
                        Text("VIP")
                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VipleMailPalette.vipGold))
                    }

                    if msg.requiresCenelisPin == true {
                        HStack(spacing: 3) {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("PIN")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.31, green: 0.27, blue: 0.90),
                                        Color(red: 0.01, green: 0.52, blue: 0.78)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        )
                    }

                    Spacer()

                    if msg.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }

                    Text(msg.formattedRelativeDate)
                        .font(.system(size: 12, weight: msg.isRead ? .medium : .bold, design: .rounded))
                        .foregroundStyle(msg.isRead ? VipleMailPalette.inkMuted : VipleMailPalette.primary)
                }

                HStack(spacing: 5) {
                    Text(beta.isEnabled(.f050) && beta.isPublicStealthMaskActive ? "••••••••••••" : msg.subject)
                        .font(.system(size: 14, weight: msg.isRead ? .medium : .bold))
                        .foregroundStyle(msg.isRead ? VipleMailPalette.inkSecondary : VipleMailPalette.ink)
                        .lineLimit(1)

                    if beta.isEnabled(.f007), beta.stickyNotesByMessage[msg.id] != nil {
                        Image(systemName: "note.text")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }

                if !(beta.isEnabled(.f034) && beta.listDensityMode == .compact) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(beta.isEnabled(.f050) && beta.isPublicStealthMaskActive
                             ? "Aperçu masqué en Mode Confidentialité Discrète"
                             : (msg.snippet.isEmpty ? msg.plainBodyText : msg.snippet))
                            .font(.system(size: 12.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(beta.isEnabled(.f034) && beta.listDensityMode == .magazine ? 3 : 2)

                        Spacer(minLength: 4)

                        Button {
                            Task {
                                await vm.performMessageAction(
                                    messageIds: [msg.id],
                                    action: "toggle_star"
                                )
                            }
                        } label: {
                            Image(systemName: msg.isStarred ? "star.fill" : "star")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(msg.isStarred ? VipleMailPalette.starYellow : VipleMailPalette.inkMuted.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if vm.isUnifiedInboxActive, let mbxEmail = msg.mailboxEmail, !mbxEmail.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: msg.isExternalMailbox == true ? "globe.europe.africa.fill" : "envelope.badge.shield.half.filled")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(mbxEmail)
                            .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                    .padding(.top, 1)
                }

                if !msg.attachments.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(msg.attachments.prefix(2)) { att in
                            HStack(spacing: 4) {
                                Image(systemName: att.iconName)
                                    .font(.system(size: 10, weight: .bold))
                                Text(att.fileName)
                                    .font(.system(size: 10.5, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(VipleMailPalette.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(
                                Capsule()
                                    .fill(VipleMailPalette.primary.opacity(0.10))
                            )
                        }
                        if msg.attachments.count > 2 {
                            Text("+\(msg.attachments.count - 2)")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isSelected
                        ? VipleMailPalette.primary.opacity(colorScheme == .dark ? 0.16 : 0.09)
                        : (msg.isRead ? VipleMailPalette.surface : VipleMailPalette.surfaceElevated)
                )
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(msg.isRead ? 0.24 : 0.38)
                        : VipleMailPalette.cobaltDeep.opacity(msg.isRead ? 0.03 : 0.08),
                    radius: 10,
                    x: 0,
                    y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    (beta.isEnabled(.f035) && (msg.isVipSender || msg.shouldShowVerifiedSenderBadge))
                        ? AnyShapeStyle(LinearGradient(colors: [.yellow, .cyan, VipleMailPalette.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(
                            isSelected
                                ? VipleMailPalette.primary
                                : (!msg.isRead ? VipleMailPalette.primary.opacity(colorScheme == .dark ? 0.44 : 0.32) : VipleMailPalette.border)
                        ),
                    lineWidth: (beta.isEnabled(.f035) && msg.isVipSender) ? 1.8 : (!msg.isRead || isSelected ? 1.4 : 1)
                )
        )
    }

    // MARK: - Barres de Sélection Multiple

    private var bulkSelectionHeaderBar: some View {
        HStack {
            Button {
                let allIds = vm.displayedMessages.map { $0.id }
                if vm.selectedMessageIds.count == allIds.count {
                    vm.selectedMessageIds.removeAll()
                } else {
                    vm.selectedMessageIds = Set(allIds)
                }
            } label: {
                Text(vm.selectedMessageIds.count == vm.displayedMessages.count ? "Tout désélectionner" : "Tout sélectionner")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VipleMailPalette.primary)
            }
            Spacer()
            Text("\(vm.selectedMessageIds.count) sélectionné(s)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(VipleMailPalette.surfaceSubtle)
    }

    private var bulkActionsBottomBar: some View {
        HStack(spacing: 16) {
            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: Array(vm.selectedMessageIds),
                        action: "mark_read",
                        toast: "Messages marqués comme lus"
                    )
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "envelope.open.fill")
                    Text("Lus")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: Array(vm.selectedMessageIds),
                        action: "archive",
                        toast: "Messages archivés"
                    )
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "archivebox.fill")
                    Text("Archiver")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }

            Button {
                moveTargetSheetMessageIds = Array(vm.selectedMessageIds)
                isShowingMoveFolderSheet = true
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "folder.fill")
                    Text("Déplacer")
                        .font(.system(size: 11, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }

            Button(role: .destructive) {
                Task {
                    await vm.performMessageAction(
                        messageIds: Array(vm.selectedMessageIds),
                        action: "trash",
                        toast: "Messages supprimés"
                    )
                }
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: "trash.fill")
                    Text("Supprimer")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(VipleMailPalette.danger)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VipleMailPalette.surface)
    }

    private var emptyMailboxState: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(VipleMailPalette.primary.opacity(0.10))
                    .frame(width: 82, height: 82)
                Image(systemName: "tray.fill")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(VipleMailPalette.primary)
            }
            Text("Aucun message dans « \(vm.activeFolderTitle) »")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text(vm.isExternalMailboxActive
                 ? "Votre boîte externe \(vm.currentEmail) est synchronisée en direct via IMAP sécurisé."
                 : "Votre boîte est synchronisée en direct (\(vm.activeMailboxDisplayLabel)).")
                .font(.system(size: 13.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            HStack(spacing: 10) {
                Button {
                    Task {
                        await vm.refreshBootstrap()
                    }
                } label: {
                    Label("Actualiser", systemImage: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }

                if vm.externalAccounts.isEmpty {
                    Button {
                        vm.presentAddExternalAccountSheet()
                    } label: {
                        Label("Boîte externe", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(VipleMailPalette.primary))
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var moveToFolderPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(vm.folders.filter { $0.id != "Unread" && $0.id != "Starred" && $0.id != "VIP" }) { folder in
                    Button {
                        isShowingMoveFolderSheet = false
                        Task {
                            await vm.performMessageAction(
                                messageIds: moveTargetSheetMessageIds,
                                action: "move",
                                targetFolder: folder.id,
                                toast: "Déplacé vers \(folder.name)"
                            )
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: folder.icon)
                                .foregroundStyle(VipleMailPalette.colorFromHex(folder.colorHex))
                            Text(folder.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.ink)
                            Spacer()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VipleMailPalette.background)
            .navigationTitle("Déplacer vers...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isShowingMoveFolderSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(vm.preferredColorSchemeOverride)
    }
}
