import SwiftUI

// MARK: - Carnet d'Adresses Viple Live & Contacts VIP « Viple Mail » (Synchronisé avec dbo.WL_Contacts)

public struct MailContactsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText: String = ""
    @State private var vipOnlyFilter: Bool = false
    @State private var sectionFilter: Int = 0 // 0: Tous (Amis + Contacts), 1: Amis Viple Live, 2: Contacts
    @State private var isShowingAddFriendSheet: Bool = false
    @State private var addFriendHandleOrEmail: String = ""

    // Création / Édition d'un contact
    @State private var editingContactId: String? = nil
    @State private var contactEmail: String = ""
    @State private var contactName: String = ""
    @State private var contactGroup: String = "Contacts"
    @State private var contactPhone: String = ""
    @State private var contactCompany: String = ""
    @State private var contactJobTitle: String = ""
    @State private var contactNotes: String = ""
    @State private var contactIsVip: Bool = true

    public init() {}

    private var filteredContacts: [VipleMailContact] {
        var list = vm.contacts
        if vipOnlyFilter {
            list = list.filter { $0.isFavorite }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.displayName.lowercased().contains(q) ||
                $0.contactEmail.lowercased().contains(q) ||
                $0.company.lowercased().contains(q) ||
                $0.groupName.lowercased().contains(q)
            }
        }
        return list
    }

    private var filteredAcceptedFriends: [VipleFriend] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.acceptedFriends }
        return vm.acceptedFriends.filter {
            $0.displayName.lowercased().contains(q) || $0.email.lowercased().contains(q)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            contactsHeader

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if sectionFilter == 0 || sectionFilter == 1 {
                        friendsSectionView
                    }
                    if sectionFilter == 0 || sectionFilter == 2 {
                        contactsSectionView
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .task {
            await vm.refreshAgendaAndFriends()
        }
        .sheet(isPresented: $vm.isShowingAddContactSheet) {
            addOrEditContactSheet
        }
        .sheet(isPresented: $isShowingAddFriendSheet) {
            addVipleFriendSheet
        }
    }

    private var friendsSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Amis Viple Live ID", systemImage: "person.2.wave.2.fill")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Button {
                    addFriendHandleOrEmail = ""
                    isShowingAddFriendSheet = true
                } label: {
                    Label("Ajouter un ami", systemImage: "person.badge.plus")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }

            if !vm.incomingFriendRequests.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DEMANDES D'AMIS REÇUES (\(vm.incomingFriendRequests.count))")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.warning)
                    ForEach(vm.incomingFriendRequests) { req in
                        HStack(spacing: 12) {
                            VipleMailAvatarView(name: req.displayName, email: req.email, avatarUrl: req.avatarUrl, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(req.displayName)
                                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.ink)
                                Text(req.email)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                            Spacer()
                            Button {
                                Task { await vm.respondToFriendRequest(req, action: "accept") }
                            } label: {
                                Text("Accepter")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(VipleMailPalette.success))
                            }
                            Button {
                                Task { await vm.respondToFriendRequest(req, action: "decline") }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.danger)
                                    .frame(width: 30, height: 30)
                                    .background(Circle().fill(VipleMailPalette.danger.opacity(0.12)))
                            }
                        }
                        .vipleMailCard(cornerRadius: 16, padding: 12)
                    }
                }
            }

            if filteredAcceptedFriends.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "video.badge.checkmark")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VipleMailPalette.indigo)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aucun ami Viple Live ID accepté")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Text("Ajoutez un membre Viple Live ID (ici, dans un mail ou dans un chat via « ... »). Une fois accepté, appelez-le en audio ou en Viple Visio !")
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                    }
                }
                .vipleMailCard(cornerRadius: 16, padding: 14)
            } else {
                ForEach(filteredAcceptedFriends) { friend in
                    friendCard(friend)
                }
            }

            if !vm.outgoingFriendRequests.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("EN ATTENTE D'ACCEPTATION (\(vm.outgoingFriendRequests.count))")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    ForEach(vm.outgoingFriendRequests) { outReq in
                        HStack(spacing: 10) {
                            VipleMailAvatarView(name: outReq.displayName, email: outReq.email, avatarUrl: outReq.avatarUrl, size: 34)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(outReq.displayName)
                                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.ink)
                                Text("Doit accepter votre ajout avant les appels Viple Visio")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VipleMailPalette.inkMuted)
                            }
                            Spacer()
                            Button("Annuler") {
                                Task { await vm.respondToFriendRequest(outReq, action: "cancel") }
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.danger)
                        }
                        .vipleMailCard(cornerRadius: 14, padding: 11)
                    }
                }
            }
        }
    }

    private func friendCard(_ friend: VipleFriend) -> some View {
        let compact = VipleMailLayout.isCompactPhone
        let btnDim: CGFloat = compact ? 31 : 36
        return HStack(spacing: compact ? 9 : 12) {
            VipleMailAvatarView(
                name: friend.displayName,
                email: friend.email,
                avatarUrl: friend.avatarUrl,
                size: compact ? 38 : 46,
                isVip: true
            )

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(friend.displayName)
                        .font(.system(size: compact ? 14 : 15, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("AMI")
                        .font(.system(size: 8.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(VipleMailPalette.success))
                        .fixedSize()
                }
                Text(friend.email)
                    .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 4)

            HStack(spacing: compact ? 5 : 7) {
                Button {
                    Task {
                        await vm.startVisioCall(to: friend.email, peerDisplayName: friend.displayName, audioOnly: true)
                    }
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: compact ? 12.5 : 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: btnDim, height: btnDim)
                        .background(Circle().fill(VipleMailPalette.success))
                }
                .accessibilityLabel("Appel classique audio")

                Button {
                    Task {
                        await vm.startVisioCall(to: friend.email, peerDisplayName: friend.displayName, audioOnly: false)
                    }
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: compact ? 12.5 : 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: btnDim, height: btnDim)
                        .background(Circle().fill(VipleMailPalette.indigo))
                }
                .accessibilityLabel("Appel Viple Visio")

                Button {
                    Task {
                        await vm.startOrOpenChat(with: friend.email)
                    }
                } label: {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: compact ? 12 : 13.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(width: btnDim, height: btnDim)
                        .background(Circle().fill(VipleMailPalette.primary.opacity(0.12)))
                }

                Menu {
                    Button {
                        vm.presentComposer(.newMail(to: friend.email, forceMail: true))
                    } label: {
                        Label("Envoyer un courrier", systemImage: "envelope.fill")
                    }
                    Button(role: .destructive) {
                        Task { await vm.respondToFriendRequest(friend, action: "remove") }
                    } label: {
                        Label("Retirer des amis", systemImage: "person.badge.minus")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: compact ? 13 : 14, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: compact ? 24 : 28, height: btnDim)
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: compact ? 11 : 13)
    }

    private var contactsSectionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Contacts (\(filteredContacts.count))", systemImage: "person.crop.rectangle.stack.fill")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
            }

            if filteredContacts.isEmpty {
                emptyContactsView
                    .frame(minHeight: 200)
            } else {
                ForEach(filteredContacts) { contact in
                    contactCard(contact)
                }
            }
        }
    }

    private var addVipleFriendSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("identifiant@viplemail.fr ou compte Viple Live ID", text: $addFriendHandleOrEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .vipleMailTextInput()
                } header: {
                    Text("Ajouter un membre Viple Live ID en ami")
                } footer: {
                    Text("Seuls les utilisateurs possédant un compte Viple Live ID peuvent être ajoutés. Une fois votre demande acceptée, vous pourrez l'appeler en appel classique (audio) ou en Viple Visio.")
                }
            }
            .navigationTitle("Ajouter en ami")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { isShowingAddFriendSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Envoyer") {
                        let target = addFriendHandleOrEmail
                        isShowingAddFriendSheet = false
                        Task {
                            await vm.requestAddVipleFriend(target)
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(addFriendHandleOrEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var contactsHeader: some View {
        let compact = VipleMailLayout.isCompactPhone
        return VStack(spacing: compact ? 8 : 10) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Amis & Contacts")
                        .font(.system(size: compact ? 19 : 22, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                    Text("Amis Viple Live (Visio) & Carnet d'adresses")
                        .font(.system(size: compact ? 11 : 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Menu {
                    Button {
                        addFriendHandleOrEmail = ""
                        isShowingAddFriendSheet = true
                    } label: {
                        Label("Ajouter un ami Viple Live ID…", systemImage: "person.2.wave.2.fill")
                    }
                    Button {
                        prepareNewContactForm()
                        vm.isShowingAddContactSheet = true
                    } label: {
                        Label("Nouveau contact d'adresse…", systemImage: "person.crop.circle.badge.plus")
                    }
                } label: {
                    Label("Ajouter", systemImage: "person.badge.plus")
                        .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(.white)
                        .padding(.horizontal, compact ? 11 : 13)
                        .padding(.vertical, compact ? 7 : 8)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }

            Picker("Section", selection: $sectionFilter) {
                Text("Tous").tag(0)
                Text("Amis (\(vm.acceptedFriends.count))").tag(1)
                Text("Contacts (\(vm.contacts.count))").tag(2)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField(
                        "Rechercher un contact...",
                        text: $searchText,
                        prompt: VipleMailPalette.prompt("Rechercher un contact...", scheme: colorScheme)
                    )
                        .font(.system(size: 14))
                        .vipleMailTextInput()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                Button {
                    withAnimation {
                        vipOnlyFilter.toggle()
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill")
                        Text("VIP")
                    }
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(vipOnlyFilter ? .white : VipleMailPalette.vipGold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(vipOnlyFilter ? VipleMailPalette.vipGold : VipleMailPalette.vipGold.opacity(0.14))
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VipleMailPalette.surface)
    }

    private func contactCard(_ contact: VipleMailContact) -> some View {
        let compact = VipleMailLayout.isCompactPhone
        let btnDim: CGFloat = compact ? 31 : 36
        return HStack(spacing: compact ? 9 : 14) {
            VipleMailAvatarView(
                name: contact.displayName,
                email: contact.contactEmail,
                avatarUrl: vm.resolveAvatarUrl(for: contact.contactEmail, explicitUrl: contact.avatarUrl),
                size: compact ? 38 : 48,
                isVip: contact.isFavorite
            )

            VStack(alignment: .leading, spacing: 2.5) {
                HStack(spacing: 5) {
                    Text(contact.displayName)
                        .font(.system(size: compact ? 14 : 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if contact.isFavorite {
                        Text("VIP")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VipleMailPalette.vipGold))
                            .fixedSize()
                    }
                }
                Text(contact.contactEmail)
                    .font(.system(size: compact ? 11.5 : 13, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    Text(contact.groupName)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .lineLimit(1)
                    if !contact.company.isEmpty {
                        Text("• \(contact.company)")
                            .font(.system(size: 10.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: compact ? 5 : 8) {
                Button {
                    Task {
                        await vm.toggleContactVip(contact)
                    }
                } label: {
                    Image(systemName: contact.isFavorite ? "crown.fill" : "crown")
                        .font(.system(size: compact ? 13.5 : 16, weight: .bold))
                        .foregroundStyle(contact.isFavorite ? VipleMailPalette.vipGold : VipleMailPalette.inkMuted)
                        .frame(width: btnDim, height: btnDim)
                        .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                }

                let isInternalChatPeer = contact.contactEmail.lowercased().hasSuffix("@viplemail.fr")
                    || contact.contactEmail.lowercased().hasSuffix("@cenelis.com")

                if isInternalChatPeer {
                    Button {
                        Task {
                            await vm.startOrOpenChat(with: contact.contactEmail)
                        }
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: compact ? 12 : 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: btnDim, height: btnDim)
                            .background(Circle().fill(VipleMailPalette.primary))
                    }
                    .accessibilityLabel("Démarrer un Chat")
                }

                Button {
                    vm.presentComposer(.newMail(
                        to: contact.contactEmail,
                        forceMail: isInternalChatPeer
                    ))
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .foregroundStyle(isInternalChatPeer ? VipleMailPalette.primary : .white)
                        .frame(width: btnDim, height: btnDim)
                        .background(
                            Circle().fill(
                                isInternalChatPeer
                                    ? VipleMailPalette.primary.opacity(0.12)
                                    : VipleMailPalette.primary
                            )
                        )
                }
                .accessibilityLabel("Envoyer un e-mail")

                Menu {
                    Button {
                        prepareEditContactForm(contact)
                        vm.isShowingAddContactSheet = true
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        Task {
                            await vm.deleteContact(contact)
                        }
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: compact ? 13.5 : 15, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: compact ? 24 : 32, height: btnDim)
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: compact ? 11 : 14)
    }

    private var emptyContactsView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(VipleMailPalette.vipGold.opacity(0.14))
                    .frame(width: 80, height: 80)
                Image(systemName: "person.2.crop.square.stack.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(VipleMailPalette.vipGold)
            }
            Text("Aucun contact dans cette vue")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Text("Ajoutez vos correspondants fréquents en Contacts VIP pour que leurs courriers arrivent en tête de votre boîte Prioritaire.")
                .font(.system(size: 13.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button {
                prepareNewContactForm()
                vm.isShowingAddContactSheet = true
            } label: {
                Label("Ajouter un contact VIP", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(VipleMailPalette.heroGradient))
            }
            Spacer()
        }
    }

    private var addOrEditContactSheet: some View {
        NavigationStack {
            Form {
                Section("Identité & Adresse e-mail") {
                    TextField("Nom complet", text: $contactName, prompt: VipleMailPalette.prompt("Nom complet", scheme: colorScheme))
                        .vipleMailTextInput()
                    TextField(
                        "Adresse e-mail (ex: nom@viplemail.fr ou agent@cenelis.com)",
                        text: $contactEmail,
                        prompt: VipleMailPalette.prompt("Adresse e-mail (ex: nom@viplemail.fr ou agent@cenelis.com)", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    Toggle(isOn: $contactIsVip) {
                        Label("Contact VIP (Prioritaire 👑)", systemImage: "crown.fill")
                            .foregroundStyle(VipleMailPalette.ink)
                    }
                }
                .listRowBackground(VipleMailPalette.resolvedSurface(for: colorScheme))

                Section("Informations professionnelles & Groupe") {
                    TextField(
                        "Groupe (ex: Famille, Équipe Viple, Amis)",
                        text: $contactGroup,
                        prompt: VipleMailPalette.prompt("Groupe (ex: Famille, Équipe Viple, Amis)", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                    TextField("Téléphone", text: $contactPhone, prompt: VipleMailPalette.prompt("Téléphone", scheme: colorScheme))
                        .vipleMailTextInput()
                        .keyboardType(.phonePad)
                    TextField(
                        "Société / Organisation",
                        text: $contactCompany,
                        prompt: VipleMailPalette.prompt("Société / Organisation", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                    TextField("Fonction", text: $contactJobTitle, prompt: VipleMailPalette.prompt("Fonction", scheme: colorScheme))
                        .vipleMailTextInput()
                    TextField("Notes", text: $contactNotes, prompt: VipleMailPalette.prompt("Notes", scheme: colorScheme))
                        .vipleMailTextInput()
                }
                .listRowBackground(VipleMailPalette.resolvedSurface(for: colorScheme))
            }
            .scrollContentBackground(.hidden)
            .background(VipleMailPalette.background)
            .navigationTitle(editingContactId == nil ? "Nouveau contact" : "Modifier le contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        vm.isShowingAddContactSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        Task {
                            let ok = await vm.saveContact(
                                contactId: editingContactId,
                                email: contactEmail,
                                displayName: contactName,
                                groupName: contactGroup,
                                isFavorite: contactIsVip,
                                phone: contactPhone,
                                company: contactCompany,
                                jobTitle: contactJobTitle,
                                notes: contactNotes
                            )
                            if ok {
                                vm.isShowingAddContactSheet = false
                            }
                        }
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(vm.preferredColorSchemeOverride)
    }

    private func prepareNewContactForm() {
        editingContactId = nil
        contactEmail = ""
        contactName = ""
        contactGroup = "Favoris VIP"
        contactPhone = ""
        contactCompany = ""
        contactJobTitle = ""
        contactNotes = ""
        contactIsVip = true
    }

    private func prepareEditContactForm(_ c: VipleMailContact) {
        editingContactId = c.id
        contactEmail = c.contactEmail
        contactName = c.displayName
        contactGroup = c.groupName
        contactPhone = c.phone
        contactCompany = c.company
        contactJobTitle = c.jobTitle
        contactNotes = c.notes
        contactIsVip = c.isFavorite
    }
}
