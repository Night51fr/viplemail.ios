import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Onglet « Chat » & Sessions de Discussion Instantanée @viplemail.fr

public struct MailChatView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var searchQuery: String = ""
    @State private var isShowingNewChatSheet: Bool = false
    @State private var newChatAddress: String = ""

    public init() {}

    private var vipleMailContacts: [VipleMailContact] {
        vm.contacts.filter { $0.contactEmail.lowercased().hasSuffix("@viplemail.fr") }
    }

    private var filteredSessions: [VipleChatSession] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.chatSessions }
        return vm.chatSessions.filter {
            $0.peerDisplayName.lowercased().contains(q) ||
            $0.peerEmail.lowercased().contains(q) ||
            $0.lastMessageSnippet.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            chatHeaderBar

            if !vipleMailContacts.isEmpty && searchQuery.isEmpty {
                quickVipleContactsStrip
            }

            if filteredSessions.isEmpty {
                emptyChatStateView
            } else {
                List {
                    ForEach(filteredSessions) { session in
                        Button {
                            vm.openChatSession(session)
                        } label: {
                            chatSessionRow(session)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await vm.deleteChatSession(session)
                                }
                            } label: {
                                Label("Supprimer", systemImage: "trash.fill")
                            }

                            Button {
                                vm.presentComposer(.newMail(to: session.peerEmail, forceMail: true))
                            } label: {
                                Label("Mail", systemImage: "envelope.fill")
                            }
                            .tint(VipleMailPalette.primary)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await vm.refreshChatSessions()
                }
            }
        }
        .background(VipleMailPalette.background)
        .sheet(isPresented: $isShowingNewChatSheet) {
            newChatStartSheet
        }
        .task {
            await vm.refreshChatSessions()
        }
    }

    // MARK: - En-tête Onglet Chat

    private var chatHeaderBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Discussions instantanées @viplemail.fr")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }

                Spacer()

                Button {
                    newChatAddress = ""
                    isShowingNewChatSheet = true
                } label: {
                    Label("Nouveau chat", systemImage: "plus.bubble.fill")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VipleMailPalette.primary)
                TextField("Rechercher une discussion @viplemail.fr…", text: $searchQuery)
                    .font(.system(size: 14.5))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
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
                    .fill(VipleMailPalette.surfaceSubtle)
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VipleMailPalette.surface)
    }

    private var quickVipleContactsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(vipleMailContacts.prefix(12)) { contact in
                    Button {
                        Task {
                            await vm.startOrOpenChat(with: contact.contactEmail)
                        }
                    } label: {
                        VStack(spacing: 5) {
                            VipleMailAvatarView(
                                name: contact.displayName,
                                email: contact.contactEmail,
                                avatarUrl: vm.resolveAvatarUrl(for: contact.contactEmail, explicitUrl: contact.avatarUrl),
                                size: 46,
                                isVip: contact.isFavorite
                            )
                            Text(contact.displayName.split(separator: " ").first.map(String.init) ?? contact.displayName)
                                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)
                                .lineLimit(1)
                                .frame(width: 64)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(VipleMailPalette.surface.opacity(0.75))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func chatSessionRow(_ session: VipleChatSession) -> some View {
        let isSentByMe = session.lastSenderEmail.lowercased() == vm.currentEmail.lowercased()
        let previewText = session.lastMessageSnippet.isEmpty
            ? "Nouvelle discussion @viplemail.fr"
            : (isSentByMe ? "Vous : \(session.lastMessageSnippet)" : session.lastMessageSnippet)

        return HStack(spacing: 12) {
            VipleMailAvatarView(
                name: session.peerDisplayName,
                email: session.peerEmail,
                avatarUrl: vm.resolveAvatarUrl(for: session.peerEmail, explicitUrl: session.peerAvatarUrl),
                size: 50,
                isVip: session.isVipPeer,
                isUnread: session.unreadCount > 0
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(session.peerDisplayName)
                        .font(.system(size: 15.5, weight: session.unreadCount > 0 ? .black : .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)

                    Spacer()

                    Text(session.formattedRelativeDate)
                        .font(.system(size: 12, weight: session.unreadCount > 0 ? .bold : .medium, design: .rounded))
                        .foregroundStyle(session.unreadCount > 0 ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                }

                Text(session.peerEmail)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(previewText)
                        .font(.system(size: 13.5, weight: session.unreadCount > 0 ? .semibold : .regular))
                        .foregroundStyle(session.unreadCount > 0 ? VipleMailPalette.ink : VipleMailPalette.inkSecondary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if session.unreadCount > 0 {
                        Text("\(session.unreadCount)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(VipleMailPalette.primary))
                    }
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 13)
    }

    private var emptyChatStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(VipleMailPalette.primary.opacity(0.12))
                    .frame(width: 82, height: 82)
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(VipleMailPalette.primary)
            }
            Text("Aucune discussion pour le moment")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text("Lorsque vous écrivez à une adresse @viplemail.fr en mode « Chat », votre conversation instantanée s'affiche ici.")
                .font(.system(size: 13.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            Button {
                newChatAddress = ""
                isShowingNewChatSheet = true
            } label: {
                Label("Démarrer un Chat @viplemail.fr", systemImage: "plus.bubble.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(VipleMailPalette.heroGradient))
            }
            Spacer()
        }
    }

    private var newChatStartSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Destinataire @viplemail.fr")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 8) {
                    Image(systemName: "at")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField("identifiant ou nom@viplemail.fr", text: $newChatAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(13)
                .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.surface))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(VipleMailPalette.border, lineWidth: 1))

                Button {
                    var clean = newChatAddress.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    guard !clean.isEmpty else { return }
                    if !clean.contains("@") {
                        clean = "\(clean)@viplemail.fr"
                    }
                    guard clean.hasSuffix("@viplemail.fr") else {
                        vm.showToast("Le Chat instantané est réservé aux adresses @viplemail.fr.")
                        return
                    }
                    isShowingNewChatSheet = false
                    Task {
                        await vm.startOrOpenChat(with: clean)
                    }
                } label: {
                    Text("Ouvrir la session de Chat")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.heroGradient))
                }

                if !vipleMailContacts.isEmpty {
                    Text("VOS CONTACTS @VIPLEMAIL.FR")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .padding(.top, 6)

                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(vipleMailContacts) { c in
                                Button {
                                    isShowingNewChatSheet = false
                                    Task {
                                        await vm.startOrOpenChat(with: c.contactEmail)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        VipleMailAvatarView(
                                            name: c.displayName,
                                            email: c.contactEmail,
                                            avatarUrl: vm.resolveAvatarUrl(for: c.contactEmail, explicitUrl: c.avatarUrl),
                                            size: 38,
                                            isVip: c.isFavorite
                                        )
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(c.displayName)
                                                .font(.system(size: 14.5, weight: .bold))
                                                .foregroundStyle(VipleMailPalette.ink)
                                            Text(c.contactEmail)
                                                .font(.system(size: 12.5))
                                                .foregroundStyle(VipleMailPalette.primary)
                                        }
                                        Spacer()
                                        Image(systemName: "bubble.right.fill")
                                            .foregroundStyle(VipleMailPalette.primary)
                                    }
                                    .padding(11)
                                    .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.surface))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .background(VipleMailPalette.background)
            .navigationTitle("Nouvelle discussion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        isShowingNewChatSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Vue Conversation Instantanée Plein Écran « MailChatConversationView »

public struct MailChatConversationView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let session: VipleChatSession

    @State private var draftText: String = ""
    @State private var stagedAttachments: [VipleMailAttachment] = []
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingFileImporter: Bool = false
    @State private var isUploadingAttachment: Bool = false

    public init(session: VipleChatSession) {
        self.session = session
    }

    private var activeSession: VipleChatSession {
        vm.openedChatSession ?? session
    }

    private var canSend: Bool {
        (!draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !stagedAttachments.isEmpty)
            && !vm.isSendingChatMessage
            && !isUploadingAttachment
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        if vm.activeChatMessages.isEmpty {
                            emptyConversationBanner
                        } else {
                            ForEach(Array(vm.activeChatMessages.enumerated()), id: \.element.id) { idx, msg in
                                let prevDay = idx > 0 ? vm.activeChatMessages[idx - 1].formattedDayKey : ""
                                if msg.formattedDayKey != prevDay {
                                    daySeparatorPill(msg.formattedDayKey)
                                }
                                chatBubbleRow(msg)
                                    .id(msg.id)
                            }
                        }
                        Color.clear
                            .frame(height: 4)
                            .id("__CHAT_BOTTOM__")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .background(VipleMailPalette.background)
                .onChange(of: vm.activeChatMessages.count) { _, _ in
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo("__CHAT_BOTTOM__", anchor: .bottom)
                    }
                }
                .task {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    proxy.scrollTo("__CHAT_BOTTOM__", anchor: .bottom)
                }
            }

            if !stagedAttachments.isEmpty || isUploadingAttachment {
                stagedAttachmentsBar
            }

            chatInputBottomBar
        }
        .background(VipleMailPalette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    vm.closeChatSession()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                        Text("Chat")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                }
            }

            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    VipleMailAvatarView(
                        name: activeSession.peerDisplayName,
                        email: activeSession.peerEmail,
                        avatarUrl: vm.resolveAvatarUrl(for: activeSession.peerEmail, explicitUrl: activeSession.peerAvatarUrl),
                        size: 30,
                        isVip: activeSession.isVipPeer
                    )
                    VStack(alignment: .leading, spacing: 0) {
                        Text(activeSession.peerDisplayName)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Text(activeSession.peerEmail)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.primary)
                            .lineLimit(1)
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        vm.presentComposer(.newMail(to: activeSession.peerEmail, forceMail: true))
                    } label: {
                        Label("Envoyer un e-mail classique", systemImage: "envelope.fill")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            await vm.deleteChatSession(activeSession)
                        }
                    } label: {
                        Label("Supprimer la discussion", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    if value.startLocation.x < 44 && value.translation.width > 70 && abs(value.translation.height) < 90 {
                        vm.closeChatSession()
                    }
                }
        )
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                await handleSelectedPhoto(newItem)
            }
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
        .task(id: activeSession.id) {
            await vm.reloadActiveChatMessages(silent: false)
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                await vm.reloadActiveChatMessages(silent: true)
            }
        }
    }

    private var emptyConversationBanner: some View {
        VStack(spacing: 10) {
            VipleMailAvatarView(
                name: activeSession.peerDisplayName,
                email: activeSession.peerEmail,
                avatarUrl: vm.resolveAvatarUrl(for: activeSession.peerEmail, explicitUrl: activeSession.peerAvatarUrl),
                size: 62,
                isVip: activeSession.isVipPeer
            )
            Text(activeSession.peerDisplayName)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text("Session de Chat chiffrée avec \(activeSession.peerEmail)")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private func daySeparatorPill(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(VipleMailPalette.inkMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
            .padding(.vertical, 4)
    }

    private func chatBubbleRow(_ msg: VipleChatMessage) -> some View {
        let isMine = msg.senderEmail.lowercased() == vm.currentEmail.lowercased()

        return HStack(alignment: .bottom, spacing: 8) {
            if isMine {
                Spacer(minLength: 52)
            } else {
                VipleMailAvatarView(
                    name: msg.senderName,
                    email: msg.senderEmail,
                    avatarUrl: vm.resolveAvatarUrl(for: msg.senderEmail, explicitUrl: msg.senderAvatarUrl),
                    size: 28
                )
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 3) {
                VStack(alignment: .leading, spacing: 6) {
                    if !msg.bodyText.isEmpty {
                        Text(msg.bodyText)
                            .font(.system(size: 15.5))
                            .foregroundStyle(isMine ? Color.white : VipleMailPalette.ink)
                            .textSelection(.enabled)
                    }

                    if !msg.attachments.isEmpty {
                        ForEach(msg.attachments) { att in
                            if let url = URL(string: att.url), !att.url.isEmpty {
                                Link(destination: url) {
                                    HStack(spacing: 8) {
                                        Image(systemName: att.iconName)
                                            .font(.system(size: 14, weight: .bold))
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(att.fileName)
                                                .font(.system(size: 12.5, weight: .semibold))
                                                .lineLimit(1)
                                            Text(att.formattedSize)
                                                .font(.system(size: 10.5))
                                                .opacity(0.85)
                                        }
                                        Image(systemName: "arrow.down.circle.fill")
                                            .font(.system(size: 15))
                                    }
                                    .foregroundStyle(isMine ? Color.white : VipleMailPalette.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .fill(isMine ? Color.white.opacity(0.18) : VipleMailPalette.primary.opacity(0.10))
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            isMine
                                ? AnyShapeStyle(VipleMailPalette.heroGradient)
                                : AnyShapeStyle(VipleMailPalette.surface)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isMine ? Color.clear : VipleMailPalette.border, lineWidth: 1)
                )

                HStack(spacing: 4) {
                    Text(msg.formattedTime)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    if isMine {
                        Image(systemName: msg.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(msg.isRead ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                    }
                }
                .padding(.horizontal, 4)
            }

            if !isMine {
                Spacer(minLength: 52)
            }
        }
    }

    private var stagedAttachmentsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if isUploadingAttachment {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.horizontal, 6)
                }
                ForEach(stagedAttachments) { att in
                    HStack(spacing: 6) {
                        Image(systemName: att.iconName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                        Text(att.fileName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Button {
                            stagedAttachments.removeAll { $0.id == att.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .background(VipleMailPalette.surface)
        .overlay(alignment: .top) { Divider() }
    }

    private var chatInputBottomBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 32, height: 34)
            }
            .padding(.bottom, 2)

            Button {
                isShowingFileImporter = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 28, height: 34)
            }
            .padding(.bottom, 2)

            TextField("Message @viplemail.fr…", text: $draftText, axis: .vertical)
                .font(.system(size: 15.5))
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )

            Button {
                sendChatNow()
            } label: {
                if vm.isSendingChatMessage {
                    ProgressView()
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(canSend ? VipleMailPalette.primary : VipleMailPalette.inkMuted.opacity(0.4))
                }
            }
            .disabled(!canSend)
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            VipleMailPalette.surface
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }

    private func sendChatNow() {
        let text = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        let atts = stagedAttachments
        guard !text.isEmpty || !atts.isEmpty else { return }
        draftText = ""
        stagedAttachments = []
        Task {
            _ = await vm.sendChatMessage(
                to: activeSession.peerEmail,
                text: text,
                attachments: atts
            )
        }
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem) async {
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        if let data = try? await item.loadTransferable(type: Data.self) {
            let fileName = "chat_photo_\(Int(Date().timeIntervalSince1970)).jpg"
            if let uploaded = await vm.uploadAttachment(fileName: fileName, mimeType: "image/jpeg", data: data) {
                stagedAttachments.append(uploaded)
            }
        }
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let first = urls.first else { return }
        let accessed = first.startAccessingSecurityScopedResource()
        defer {
            if accessed { first.stopAccessingSecurityScopedResource() }
        }
        guard let data = try? Data(contentsOf: first) else { return }
        let fileName = first.lastPathComponent
        isUploadingAttachment = true
        Task {
            if let uploaded = await vm.uploadAttachment(fileName: fileName, mimeType: "application/octet-stream", data: data) {
                stagedAttachments.append(uploaded)
            }
            isUploadingAttachment = false
        }
    }
}
