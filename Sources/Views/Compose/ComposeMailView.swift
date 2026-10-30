import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Compositeur de Courrier Plein Écran « Viple Mail » (Style Apple Mail iOS : Lignes À / Cc / Cci / De /Priorité / Objet, Auto-complétion avec Avatars, Carnet de Contacts, Pièces Jointes, Barre d'Outils & Brouillons)

public struct ComposeMailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: VipleMailViewModel

    public let mode: MailComposeMode

    @State private var toField: String = ""
    @State private var ccField: String = ""
    @State private var bccField: String = ""
    @State private var isExpandedCcBccFrom: Bool = false
    @State private var subjectField: String = ""
    @State private var bodyField: String = ""
    @State private var priority: String = "Normal"
    @State private var includeSignature: Bool = true
    @State private var attachments: [VipleMailAttachment] = []
    @State private var draftId: String? = nil
    @State private var threadId: String? = nil
    @State private var replyToMessageId: String? = nil

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingFileImporter: Bool = false
    @State private var isUploadingAttachment: Bool = false
    @State private var isShowingCancelDialog: Bool = false
    @State private var isShowingContactPicker: Bool = false
    @State private var contactPickerTarget: RecipientTarget = .to

    @FocusState private var focusedField: ComposeField?

    private enum ComposeField: Hashable {
        case to, cc, bcc, subject, body
    }

    private enum RecipientTarget {
        case to, cc, bcc
    }

    public init(mode: MailComposeMode) {
        self.mode = mode
    }

    private var modeDefaultTitle: String {
        switch mode {
        case .newMail:
            return "Nouveau message"
        case .reply:
            return "Répondre"
        case .replyAll:
            return "Répondre à tous"
        case .forward:
            return "Transférer"
        case .editDraft:
            return "Brouillon"
        }
    }

    private var headerTitle: String {
        let trimmed = subjectField.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? modeDefaultTitle : trimmed
    }

    private var canSend: Bool {
        !toField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isSendingMail
    }

    private var hasUnsavedChanges: Bool {
        !toField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !ccField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !bccField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !subjectField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !bodyField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !attachments.isEmpty
    }

    private var matchingContacts: [VipleMailContact] {
        let activeRaw: String
        switch focusedField {
        case .cc:
            activeRaw = ccField
        case .bcc:
            activeRaw = bccField
        default:
            activeRaw = toField
        }
        let lastToken = activeRaw.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? activeRaw
        guard !lastToken.isEmpty, !lastToken.contains("@") else { return [] }
        let q = lastToken.lowercased()
        return vm.contacts.filter {
            $0.displayName.lowercased().contains(q) || $0.contactEmail.lowercased().contains(q)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Lignes d'en-tête style Apple Mail (À, Cc/Cci/De, Objet)
                        appleMailRecipientHeaders

                        // 2. Suggestions d'auto-complétion de contacts avec photo synchronisée
                        if !matchingContacts.isEmpty {
                            contactSuggestionsList
                        }

                        // 3. Pièces jointes (si présentes ou en cours d'envoi)
                        if !attachments.isEmpty || isUploadingAttachment {
                            attachmentsSection
                        }

                        // 4. Corps du message plein écran style Apple Mail
                        appleMailBodyEditor

                        // 5. Aperçu de la signature automatique Viple Mail
                        if vm.settings.signatureEnabled && !vm.settings.signatureHtml.isEmpty {
                            signatureBlock
                        }
                    }
                }
                .background(VipleMailPalette.surface)

                // Barre d'outils inférieure complète style Apple Mail (Formatage, Pièces jointes, Photos, Modèles, Priorité)
                appleMailBottomToolbar
            }
            .background(VipleMailPalette.surface.ignoresSafeArea())
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        if hasUnsavedChanges {
                            isShowingCancelDialog = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendMailNow()
                    } label: {
                        if vm.isSendingMail {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28, weight: .bold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(canSend ? VipleMailPalette.primary : VipleMailPalette.inkMuted.opacity(0.45))
                        }
                    }
                    .disabled(!canSend)
                    .accessibilityLabel("Envoyer le courrier")
                }
            }
            .confirmationDialog(
                "Que souhaitez-vous faire de ce message ?",
                isPresented: $isShowingCancelDialog,
                titleVisibility: .visible
            ) {
                Button("Supprimer le brouillon", role: .destructive) {
                    dismiss()
                }
                Button("Enregistrer le brouillon") {
                    saveAsDraftAndDismiss()
                }
                Button("Continuer la rédaction", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingContactPicker) {
                contactPickerSheet
            }
            .onAppear {
                populateInitialFields()
                includeSignature = vm.settings.signatureEnabled
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    if toField.isEmpty {
                        focusedField = .to
                    } else if subjectField.isEmpty {
                        focusedField = .subject
                    } else {
                        focusedField = .body
                    }
                }
            }
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
        }
    }

    // MARK: - En-têtes Style Apple Mail (À :, Cc/Cci, De :, Priorité :, Objet :)

    private var appleMailRecipientHeaders: some View {
        VStack(spacing: 0) {
            // Ligne « À : »
            HStack(spacing: 10) {
                Text("À :")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .frame(width: 44, alignment: .leading)

                TextField("destinataire@viplemail.fr", text: $toField)
                    .font(.system(size: 15.5))
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .to)

                Button {
                    contactPickerTarget = .to
                    isShowingContactPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundStyle(VipleMailPalette.primary)
                }
                .accessibilityLabel("Ajouter un contact")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()
                .padding(.leading, 16)

            // Ligne « Cc/Cci, De : » pliée ou dépliée (comportement natif Apple Mail)
            if !isExpandedCcBccFrom && ccField.isEmpty && bccField.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                        isExpandedCcBccFrom = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Cc/Cci, De :")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkSecondary)

                        Text(vm.currentEmail)
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineLimit(1)

                        Spacer()

                        if priority != "Normal" {
                            priorityPillBadge
                        }

                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 16)
            } else {
                // Ligne « Cc : »
                HStack(spacing: 10) {
                    Text("Cc :")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 44, alignment: .leading)

                    TextField("Copie carbone", text: $ccField)
                        .font(.system(size: 15.5))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .cc)

                    Button {
                        contactPickerTarget = .cc
                        isShowingContactPicker = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Divider()
                    .padding(.leading, 16)

                // Ligne « Cci : »
                HStack(spacing: 10) {
                    Text("Cci :")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 44, alignment: .leading)

                    TextField("Copie carbone invisible", text: $bccField)
                        .font(.system(size: 15.5))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .bcc)

                    Button {
                        contactPickerTarget = .bcc
                        isShowingContactPicker = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Divider()
                    .padding(.leading, 16)

                // Ligne « De : » avec photo de profil synchronisée
                HStack(spacing: 10) {
                    Text("De :")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 44, alignment: .leading)

                    if let user = vm.currentUser {
                        VipleMailAvatarView(
                            name: user.displayName,
                            email: user.primaryAddress,
                            avatarUrl: vm.resolveAvatarUrl(for: user.primaryAddress, explicitUrl: user.avatarUrl),
                            size: 24,
                            isVip: true
                        )
                        Text("\(user.displayName) <\(user.primaryAddress)>")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                    } else {
                        Text(vm.currentEmail)
                            .font(.system(size: 15))
                            .foregroundStyle(VipleMailPalette.ink)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 16)

                // Ligne « Priorité : » (style Apple Mail)
                HStack(spacing: 10) {
                    Text("Priorité :")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(VipleMailPalette.inkSecondary)

                    Spacer()

                    Picker("Priorité", selection: $priority) {
                        Text("Basse ↓").tag("Low")
                        Text("Normale").tag("Normal")
                        Text("Haute ❗").tag("High")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 240)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                Divider()
                    .padding(.leading, 16)
            }

            // Ligne « Objet : »
            HStack(spacing: 10) {
                Text("Objet :")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .frame(width: 54, alignment: .leading)

                TextField("Objet du message", text: $subjectField)
                    .font(.system(size: 15.5, weight: .semibold))
                    .focused($focusedField, equals: .subject)

                if priority != "Normal" && !isExpandedCcBccFrom {
                    priorityPillBadge
                }

                Menu {
                    Button {
                        applyTemplate(
                            subject: "Invitation réunion",
                            body: "Bonjour,\n\nJe vous propose d'organiser un point rapide cette semaine.\nQuelles sont vos disponibilités ?\n\nBien cordialement,"
                        )
                    } label: {
                        Label("Réunion / Rendez-vous", systemImage: "calendar")
                    }
                    Button {
                        applyTemplate(
                            subject: "Transmission de document",
                            body: "Bonjour,\n\nVeuillez trouver ci-joint le document demandé.\nN'hésitez pas à revenir vers moi pour toute question.\n\nCordialement,"
                        )
                    } label: {
                        Label("Envoi de document", systemImage: "doc.text")
                    }
                    Button {
                        applyTemplate(
                            subject: "Merci pour notre échange",
                            body: "Bonjour,\n\nJe tenais à vous remercier pour la qualité de notre échange d'aujourd'hui.\n\nÀ très bientôt,"
                        )
                    } label: {
                        Label("Remerciement", systemImage: "hand.thumbsup")
                    }
                    Button {
                        applyTemplate(
                            subject: "Suivi de votre demande",
                            body: "Bonjour,\n\nJe me permets de revenir vers vous concernant notre précédent échange afin de savoir si vous avez pu avancer sur ce sujet.\n\nBien à vous,"
                        )
                    } label: {
                        Label("Relance courtoise", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)
                }
                .accessibilityLabel("Modèles rapides")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            Divider()
        }
    }

    private var priorityPillBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: priority == "High" ? "exclamationmark.circle.fill" : "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .bold))
            Text(priority == "High" ? "Priorité haute" : "Priorité basse")
                .font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(priority == "High" ? VipleMailPalette.danger : VipleMailPalette.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill((priority == "High" ? VipleMailPalette.danger : VipleMailPalette.primary).opacity(0.12))
        )
    }

    // MARK: - Auto-complétion des Contacts avec Photo Synchronisée

    private var contactSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(matchingContacts.prefix(5)) { contact in
                Button {
                    selectSuggestedContact(contact)
                } label: {
                    HStack(spacing: 12) {
                        VipleMailAvatarView(
                            name: contact.displayName,
                            email: contact.contactEmail,
                            avatarUrl: vm.resolveAvatarUrl(for: contact.contactEmail, explicitUrl: contact.avatarUrl),
                            size: 36,
                            isVip: contact.isFavorite
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(contact.displayName)
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.ink)
                                if contact.isFavorite {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(VipleMailPalette.vipGold)
                                }
                            }
                            Text(contact.contactEmail)
                                .font(.system(size: 12.5))
                                .foregroundStyle(VipleMailPalette.primary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.left.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(VipleMailPalette.surfaceSubtle.opacity(0.65))
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 64)
            }
        }
    }

    // MARK: - Section Pièces Jointes

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Pièces jointes (\(attachments.count))", systemImage: "paperclip")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                Spacer()
                if isUploadingAttachment {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.75)
                        Text("Envoi sur SkyDrive...")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(attachments) { att in
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(VipleMailPalette.primary.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: att.iconName)
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }

                            VStack(alignment: .leading, spacing: 1) {
                                Text(att.fileName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(VipleMailPalette.ink)
                                    .lineLimit(1)
                                Text(att.formattedSize)
                                    .font(.system(size: 11))
                                    .foregroundStyle(VipleMailPalette.inkMuted)
                            }

                            Button {
                                attachments.removeAll { $0.id == att.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 17))
                                    .foregroundStyle(VipleMailPalette.inkMuted)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(VipleMailPalette.surfaceSubtle)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(VipleMailPalette.border, lineWidth: 1)
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VipleMailPalette.surface)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Corps du Message Plein Écran (Style Apple Mail)

    private var appleMailBodyEditor: some View {
        ZStack(alignment: .topLeading) {
            if bodyField.isEmpty {
                Text("Rédigez votre message...")
                    .font(.system(size: 16))
                    .foregroundStyle(VipleMailPalette.inkMuted.opacity(0.65))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $bodyField)
                .font(.system(size: 16))
                .foregroundStyle(VipleMailPalette.ink)
                .focused($focusedField, equals: .body)
                .frame(minHeight: 360)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Bloc Signature Automatique

    private var signatureBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
                .padding(.bottom, 4)

            HStack {
                Text("SIGNATURE VIPLE MAIL")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkMuted)
                Spacer()
                Button {
                    withAnimation {
                        includeSignature.toggle()
                    }
                } label: {
                    Text(includeSignature ? "Masquer" : "Inclure")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }
            }

            if includeSignature {
                Text(vm.settings.signatureHtml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                    .font(.system(size: 13.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Barre d'Outils Inférieure Style Apple Mail

    private var appleMailBottomToolbar: some View {
        HStack(spacing: 0) {
            // 1. Formatage & Listes
            Menu {
                Button {
                    insertAtEndOfBody("\n• ")
                } label: {
                    Label("Liste à puces", systemImage: "list.bullet")
                }
                Button {
                    insertAtEndOfBody("\n1. ")
                } label: {
                    Label("Liste numérotée", systemImage: "list.number")
                }
                Button {
                    insertAtEndOfBody("\n> ")
                } label: {
                    Label("Citation", systemImage: "text.quote")
                }
                Divider()
                Button {
                    let df = DateFormatter()
                    df.locale = Locale(identifier: "fr_FR")
                    df.dateStyle = .full
                    df.timeStyle = .short
                    insertAtEndOfBody("\n\(df.string(from: Date()))")
                } label: {
                    Label("Insérer la date et l'heure", systemImage: "clock")
                }
            } label: {
                Image(systemName: "textformat.alt")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            // 2. Joindre une photo (PhotosPicker)
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            // 3. Joindre un fichier (iCloud Drive / Fichiers)
            Button {
                isShowingFileImporter = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            // 4. Carnet de contacts VIP
            Button {
                contactPickerTarget = .to
                isShowingContactPicker = true
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            // 5. Drapeau de Priorité
            Menu {
                Button {
                    priority = "High"
                } label: {
                    Label("Priorité Haute ❗", systemImage: "exclamationmark.circle.fill")
                }
                Button {
                    priority = "Normal"
                } label: {
                    Label("Priorité Normale", systemImage: "equal.circle")
                }
                Button {
                    priority = "Low"
                } label: {
                    Label("Priorité Basse ↓", systemImage: "arrow.down.circle")
                }
            } label: {
                Image(systemName: priority == "High" ? "flag.fill" : "flag")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(priority == "High" ? VipleMailPalette.danger : VipleMailPalette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            // 6. Enregistrer en brouillon
            Button {
                saveAsDraftAndDismiss()
            } label: {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .foregroundStyle(VipleMailPalette.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            VipleMailPalette.surfaceSubtle
                .overlay(alignment: .top) {
                    Divider()
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Feuille de Sélection de Contacts Viple Mail

    private var contactPickerSheet: some View {
        NavigationStack {
            List {
                if vm.contacts.isEmpty {
                    Text("Aucun contact enregistré dans votre carnet Viple Mail.")
                        .font(.system(size: 14))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                        .padding(.vertical, 12)
                } else {
                    ForEach(vm.contacts) { contact in
                        Button {
                            appendRecipient(contact.contactEmail, to: contactPickerTarget)
                            isShowingContactPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                VipleMailAvatarView(
                                    name: contact.displayName,
                                    email: contact.contactEmail,
                                    avatarUrl: vm.resolveAvatarUrl(for: contact.contactEmail, explicitUrl: contact.avatarUrl),
                                    size: 40,
                                    isVip: contact.isFavorite
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.displayName)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(VipleMailPalette.ink)
                                    Text(contact.contactEmail)
                                        .font(.system(size: 13))
                                        .foregroundStyle(VipleMailPalette.primary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choisir un destinataire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        isShowingContactPicker = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers & Actions

    private func applyTemplate(subject: String, body: String) {
        if subjectField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            subjectField = subject
        }
        if bodyField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            bodyField = body
        } else {
            bodyField = body + "\n\n" + bodyField
        }
    }

    private func insertAtEndOfBody(_ text: String) {
        bodyField += text
        focusedField = .body
    }

    private func selectSuggestedContact(_ contact: VipleMailContact) {
        switch focusedField {
        case .cc:
            ccField = replaceLastToken(in: ccField, with: contact.contactEmail)
        case .bcc:
            bccField = replaceLastToken(in: bccField, with: contact.contactEmail)
        default:
            toField = replaceLastToken(in: toField, with: contact.contactEmail)
        }
    }

    private func replaceLastToken(in current: String, with email: String) -> String {
        var parts = current.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        if !parts.isEmpty {
            parts.removeLast()
        }
        parts.append(email)
        return parts.joined(separator: ", ")
    }

    private func appendRecipient(_ email: String, to target: RecipientTarget) {
        switch target {
        case .to:
            toField = toField.trimmingCharacters(in: .whitespaces).isEmpty ? email : "\(toField), \(email)"
        case .cc:
            ccField = ccField.trimmingCharacters(in: .whitespaces).isEmpty ? email : "\(ccField), \(email)"
        case .bcc:
            bccField = bccField.trimmingCharacters(in: .whitespaces).isEmpty ? email : "\(bccField), \(email)"
        }
    }

    private func populateInitialFields() {
        switch mode {
        case .newMail(let to, let subject):
            toField = to
            subjectField = subject
        case .reply(let msg):
            toField = msg.senderEmail
            subjectField = msg.subject.lowercased().hasPrefix("re:") ? msg.subject : "Re: \(msg.subject)"
            threadId = msg.threadId
            replyToMessageId = msg.id
            bodyField = "\n\n--- Le \(msg.formattedFullDate), \(msg.senderName) <\(msg.senderEmail)> a écrit : ---\n\(msg.plainBodyText)"
        case .replyAll(let msg):
            toField = msg.senderEmail
            ccField = msg.ccEmail
            isExpandedCcBccFrom = !msg.ccEmail.isEmpty
            subjectField = msg.subject.lowercased().hasPrefix("re:") ? msg.subject : "Re: \(msg.subject)"
            threadId = msg.threadId
            replyToMessageId = msg.id
            bodyField = "\n\n--- Le \(msg.formattedFullDate), \(msg.senderName) <\(msg.senderEmail)> a écrit : ---\n\(msg.plainBodyText)"
        case .forward(let msg):
            subjectField = msg.subject.lowercased().hasPrefix("tr:") ? msg.subject : "Tr: \(msg.subject)"
            threadId = msg.threadId
            attachments = msg.attachments
            bodyField = "\n\n---------- Message transféré ----------\nDe : \(msg.senderName) <\(msg.senderEmail)>\nDate : \(msg.formattedFullDate)\nObjet : \(msg.subject)\nÀ : \(msg.recipientEmail)\n\n\(msg.plainBodyText)"
        case .editDraft(let draft):
            draftId = draft.id
            toField = draft.recipientEmail
            ccField = draft.ccEmail
            bccField = draft.bccEmail
            isExpandedCcBccFrom = !draft.ccEmail.isEmpty || !draft.bccEmail.isEmpty
            subjectField = draft.subject == "(Sans objet)" ? "" : draft.subject
            bodyField = draft.plainBodyText
            priority = draft.priority
            attachments = draft.attachments
            threadId = draft.threadId
        }
    }

    private func sendMailNow() {
        Task {
            let ok = await vm.sendOrSaveMail(
                to: toField,
                cc: ccField,
                bcc: bccField,
                subject: subjectField,
                bodyText: bodyField,
                bodyHtml: nil,
                priority: priority,
                threadId: threadId,
                replyToMessageId: replyToMessageId,
                draftId: draftId,
                isDraft: false,
                attachments: attachments
            )
            if ok {
                dismiss()
            }
        }
    }

    private func saveAsDraftAndDismiss() {
        Task {
            _ = await vm.sendOrSaveMail(
                to: toField,
                cc: ccField,
                bcc: bccField,
                subject: subjectField,
                bodyText: bodyField,
                bodyHtml: nil,
                priority: priority,
                threadId: threadId,
                replyToMessageId: replyToMessageId,
                draftId: draftId,
                isDraft: true,
                attachments: attachments
            )
            dismiss()
        }
    }

    private func handleSelectedPhoto(_ item: PhotosPickerItem) async {
        isUploadingAttachment = true
        defer { isUploadingAttachment = false }
        if let data = try? await item.loadTransferable(type: Data.self) {
            let fileName = "photo_\(Int(Date().timeIntervalSince1970)).jpg"
            if let uploaded = await vm.uploadAttachment(fileName: fileName, mimeType: "image/jpeg", data: data) {
                attachments.append(uploaded)
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
                attachments.append(uploaded)
            }
            isUploadingAttachment = false
        }
    }
}
