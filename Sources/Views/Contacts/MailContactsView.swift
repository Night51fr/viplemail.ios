import SwiftUI

// MARK: - Carnet d'Adresses Viple Live & Contacts VIP « Viple Mail » (Synchronisé avec dbo.WL_Contacts)

public struct MailContactsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var searchText: String = ""
    @State private var vipOnlyFilter: Bool = false

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

    public var body: some View {
        VStack(spacing: 0) {
            contactsHeader

            if filteredContacts.isEmpty {
                emptyContactsView
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredContacts) { contact in
                            contactCard(contact)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $vm.isShowingAddContactSheet) {
            addOrEditContactSheet
        }
    }

    private var contactsHeader: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Carnet d'adresses & VIP")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Synchronisé avec Viple Live Contacts (ABCH)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer()
                Button {
                    prepareNewContactForm()
                    vm.isShowingAddContactSheet = true
                } label: {
                    Label("Ajouter", systemImage: "person.badge.plus")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField("Rechercher un contact...", text: $searchText)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

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
        HStack(spacing: 14) {
            VipleMailAvatarView(
                name: contact.displayName,
                email: contact.contactEmail,
                size: 48,
                isVip: contact.isFavorite
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(contact.displayName)
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    if contact.isFavorite {
                        Text("VIP")
                            .font(.system(size: 9.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(VipleMailPalette.vipGold))
                    }
                }
                Text(contact.contactEmail)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)

                HStack(spacing: 8) {
                    Text(contact.groupName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    if !contact.company.isEmpty {
                        Text("• \(contact.company)")
                            .font(.system(size: 11))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task {
                        await vm.toggleContactVip(contact)
                    }
                } label: {
                    Image(systemName: contact.isFavorite ? "crown.fill" : "crown")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(contact.isFavorite ? VipleMailPalette.vipGold : VipleMailPalette.inkMuted)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VipleMailPalette.surfaceSubtle))
                }

                Button {
                    vm.presentComposer(.newMail(to: contact.contactEmail))
                } label: {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(VipleMailPalette.primary))
                }

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
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 32, height: 36)
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
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
                Section("Identité & Adresse @viplemail.fr") {
                    TextField("Nom complet", text: $contactName)
                    TextField("Adresse e-mail (ex: nom@viplemail.fr)", text: $contactEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    Toggle(isOn: $contactIsVip) {
                        Label("Contact VIP (Prioritaire 👑)", systemImage: "crown.fill")
                    }
                }

                Section("Informations professionnelles & Groupe") {
                    TextField("Groupe (ex: Famille, Équipe Viple, Amis)", text: $contactGroup)
                    TextField("Téléphone", text: $contactPhone)
                        .keyboardType(.phonePad)
                    TextField("Société / Organisation", text: $contactCompany)
                    TextField("Fonction", text: $contactJobTitle)
                    TextField("Notes", text: $contactNotes)
                }
            }
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
