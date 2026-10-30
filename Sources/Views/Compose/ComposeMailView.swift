import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Compositeur de Courrier « Viple Mail » (Auto-complétion Contacts, Cc/Cci, Priorité, Pièces Jointes Photo/Fichier & Brouillons)

public struct ComposeMailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: VipleMailViewModel

    public let mode: MailComposeMode

    @State private var toField: String = ""
    @State private var ccField: String = ""
    @State private var bccField: String = ""
    @State private var showCcBcc: Bool = false
    @State private var subjectField: String = ""
    @State private var bodyField: String = ""
    @State private var priority: String = "Normal"
    @State private var attachments: [VipleMailAttachment] = []
    @State private var draftId: String? = nil
    @State private var threadId: String? = nil
    @State private var replyToMessageId: String? = nil

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingFileImporter: Bool = false
    @State private var isUploadingAttachment: Bool = false

    public init(mode: MailComposeMode) {
        self.mode = mode
    }

    private var matchingContacts: [VipleMailContact] {
        let lastToken = toField.split(separator: ",").last.map { String($0).trimmingCharacters(in: .whitespaces) } ?? toField
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
                    VStack(alignment: .leading, spacing: 14) {
                        senderAndPriorityHeader
                        recipientsCard
                        subjectAndTemplatesCard
                        attachmentsBar
                        editorCard
                        if vm.settings.signatureEnabled && !vm.settings.signatureHtml.isEmpty {
                            signaturePreviewCard
                        }
                    }
                    .padding(16)
                }
            }
            .background(VipleMailPalette.background)
            .navigationTitle("Nouveau courrier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        Button {
                            saveAsDraftAndDismiss()
                        } label: {
                            Label("Enregistrer dans les Brouillons", systemImage: "doc.badge.plus")
                        }
                        Button(role: .destructive) {
                            dismiss()
                        } label: {
                            Label("Ne pas enregistrer", systemImage: "trash")
                        }
                    } label: {
                        Text("Fermer")
                            .fontWeight(.semibold)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        sendMailNow()
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isSendingMail {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "paperplane.fill")
                            }
                            Text("Envoyer")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(toField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? VipleMailPalette.inkMuted : VipleMailPalette.primary)
                        )
                    }
                    .disabled(toField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isSendingMail)
                }
            }
            .onAppear {
                populateInitialFields()
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

    // MARK: - Expéditeur & Priorité

    private var senderAndPriorityHeader: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundStyle(VipleMailPalette.primary)
                Text("De : \(vm.currentEmail)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            }
            Spacer()
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
                HStack(spacing: 5) {
                    Image(systemName: priority == "High" ? "exclamationmark.circle.fill" : "flag.fill")
                    Text("Priorité : \(priority == "High" ? "Haute" : (priority == "Low" ? "Basse" : "Normale"))")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(priority == "High" ? VipleMailPalette.danger : VipleMailPalette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill((priority == "High" ? VipleMailPalette.danger : VipleMailPalette.primary).opacity(0.12))
                )
            }
        }
    }

    // MARK: - Destinataires À / Cc / Cci + Auto-complétion Carnet d'Adresses

    private var recipientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("À :")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .frame(width: 34, alignment: .leading)

                TextField("destinataire@viplemail.fr", text: $toField)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                Button {
                    withAnimation {
                        showCcBcc.toggle()
                    }
                } label: {
                    Text("Cc/Cci")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.10)))
                }
            }

            if !matchingContacts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(matchingContacts.prefix(6)) { contact in
                            Button {
                                toField = contact.contactEmail
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: contact.isFavorite ? "crown.fill" : "person.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(contact.isFavorite ? VipleMailPalette.vipGold : VipleMailPalette.primary)
                                    Text("\(contact.displayName) (\(contact.contactEmail))")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(VipleMailPalette.ink)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(VipleMailPalette.surfaceSubtle))
                            }
                        }
                    }
                }
            }

            if showCcBcc {
                Divider()
                HStack(spacing: 10) {
                    Text("Cc :")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 34, alignment: .leading)
                    TextField("Copie carbone", text: $ccField)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                Divider()
                HStack(spacing: 10) {
                    Text("Cci :")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .frame(width: 34, alignment: .leading)
                    TextField("Copie carbone invisible", text: $bccField)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }

    // MARK: - Objet & Modèles Rapides

    private var subjectAndTemplatesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Objet :")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField("Objet de votre courrier", text: $subjectField)
                    .font(.system(size: 15, weight: .semibold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quickTemplateChip(title: "📅 Réunion", subject: "Invitation réunion", body: "Bonjour,\n\nJe vous propose d'organiser un point rapide cette semaine.\nQuelles sont vos disponibilités ?\n\nBien cordialement,")
                    quickTemplateChip(title: "📎 Envoi document", subject: "Transmission de document", body: "Bonjour,\n\nVeuillez trouver ci-joint le document demandé.\nN'hésitez pas à revenir vers moi pour toute question.\n\nCordialement,")
                    quickTemplateChip(title: "🙏 Remerciement", subject: "Merci pour notre échange", body: "Bonjour,\n\nJe tenais à vous remercier pour la qualité de notre échange d'aujourd'hui.\n\nÀ très bientôt,")
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }

    private func quickTemplateChip(title: String, subject: String, body: String) -> some View {
        Button {
            if subjectField.isEmpty { subjectField = subject }
            if bodyField.isEmpty { bodyField = body }
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(VipleMailPalette.primary.opacity(0.10)))
        }
    }

    // MARK: - Barre de Pièces Jointes (PhotosPicker & Fichiers)

    private var attachmentsBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Joindre une photo", systemImage: "photo.badge.plus")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.surface))
                        .overlay(Capsule().stroke(VipleMailPalette.border, lineWidth: 1))
                }

                Button {
                    isShowingFileImporter = true
                } label: {
                    Label("Joindre un fichier", systemImage: "paperclip.badge.ellipsis")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.surface))
                        .overlay(Capsule().stroke(VipleMailPalette.border, lineWidth: 1))
                }

                if isUploadingAttachment {
                    ProgressView()
                        .scaleEffect(0.85)
                }

                Spacer()
            }

            if !attachments.isEmpty {
                ForEach(attachments) { att in
                    HStack(spacing: 10) {
                        Image(systemName: att.iconName)
                            .foregroundStyle(VipleMailPalette.primary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(att.fileName)
                                .font(.system(size: 13, weight: .bold))
                                .lineLimit(1)
                            Text(att.formattedSize)
                                .font(.system(size: 11))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Spacer()
                        Button {
                            attachments.removeAll { $0.id == att.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VipleMailPalette.danger)
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surface))
                }
            }
        }
    }

    // MARK: - Éditeur de Message & Signature

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $bodyField)
                .font(.system(size: 15.5))
                .frame(minHeight: 210)
                .scrollContentBackground(.hidden)
        }
        .vipleMailCard(cornerRadius: 20, padding: 14)
    }

    private var signaturePreviewCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SIGNATURE AUTOMATIQUE")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)
            Text(vm.settings.signatureHtml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(VipleMailPalette.inkSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surfaceSubtle))
    }

    // MARK: - Logique d'Initialisation, Upload & Envoi

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
            showCcBcc = !msg.ccEmail.isEmpty
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
            showCcBcc = !draft.ccEmail.isEmpty || !draft.bccEmail.isEmpty
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
