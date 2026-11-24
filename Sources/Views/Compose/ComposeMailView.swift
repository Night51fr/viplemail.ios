import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Compositeur Unifié « Viple Mail » (Bascule Automatique Chat / Mail pour @viplemail.fr + Mode Mail Classique Apple Mail)

public struct ComposeMailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var vm: VipleMailViewModel

    public let mode: MailComposeMode

    @State private var toField: String = ""
    @State private var ccField: String = ""
    @State private var bccField: String = ""
    @State private var senderMailbox: String = ""
    @State private var isExpandedCcBccFrom: Bool = false
    @State private var subjectField: String = ""
    @State private var bodyField: String = ""
    @State private var priority: String = "Normal"
    @State private var includeSignature: Bool = true
    @State private var disableMailRteForThisMail: Bool = false
    @State private var isShowingMailRteHelp: Bool = false
    @State private var attachments: [VipleMailAttachment] = []
    @State private var draftId: String? = nil
    @State private var threadId: String? = nil
    @State private var replyToMessageId: String? = nil

    // Mode Chat / Mail intelligent pour les destinataires @viplemail.fr
    @State private var deliveryChannel: ComposeDeliveryChannel = .mail
    @State private var hasManualChannelChoice: Bool = false

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isShowingFileImporter: Bool = false
    @State private var isUploadingAttachment: Bool = false
    @State private var isShowingCancelDialog: Bool = false
    @State private var isShowingContactPicker: Bool = false
    @State private var contactPickerTarget: RecipientTarget = .to

    @FocusState private var focusedField: ComposeField?
    @State private var isBodyFocused: Bool = false

    private enum ComposeField: Hashable {
        case to, cc, bcc, subject
    }

    private enum RecipientTarget {
        case to, cc, bcc
    }

    public init(mode: MailComposeMode) {
        self.mode = mode
    }

    /// Les réponses, transferts et brouillons d'un mail restent toujours en mode Mail classique (comme un e-mail externe)
    private var isLockedClassicMailFlow: Bool {
        switch mode {
        case .newMail:
            return false
        case .reply, .replyAll, .forward, .editDraft:
            return true
        }
    }

    private var effectiveSenderEmail: String {
        let trimmed = senderMailbox.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? vm.defaultSendingMailbox : trimmed
    }

    /// Extrait l'adresse @viplemail.fr unique saisie dans « À : » lorsqu'aucune copie Cc/Cci n'est renseignée et que l'expéditeur est une boîte interne Viple/Cenelis
    private var detectedVipleMailRecipient: String? {
        guard !isLockedClassicMailFlow,
              vm.isInternalMailbox(effectiveSenderEmail),
              ccField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              bccField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        let parts = toField
            .split(whereSeparator: { $0 == "," || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard parts.count == 1 else { return nil }
        var candidate = parts[0]
        if let openIdx = candidate.firstIndex(of: "<"),
           let closeIdx = candidate.firstIndex(of: ">"),
           openIdx < closeIdx {
            candidate = String(candidate[candidate.index(after: openIdx)..<closeIdx])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lower = candidate.lowercased()
        guard (lower.hasSuffix("@viplemail.fr") || lower.hasSuffix("@cenelis.com")),
              let atIdx = lower.firstIndex(of: "@"),
              lower.distance(from: lower.startIndex, to: atIdx) >= 1,
              !lower.contains(" ") else {
            return nil
        }
        return lower
    }

    private var isShowingChatMailToggle: Bool {
        detectedVipleMailRecipient != nil
    }

    private var isEffectiveChatMode: Bool {
        isShowingChatMailToggle && deliveryChannel == .chat
    }

    private var modeDefaultTitle: String {
        if isEffectiveChatMode {
            return "Nouveau Chat"
        }
        switch mode {
        case .newMail:
            return "Nouveau courrier"
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
        if isEffectiveChatMode {
            if let peer = detectedVipleMailRecipient {
                return "Chat • \(peer)"
            }
            return "Nouveau Chat"
        }
        let trimmed = subjectField.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? modeDefaultTitle : trimmed
    }

    private var isBusySending: Bool {
        vm.isSendingMail || vm.isSendingChatMessage
    }

    private var canSend: Bool {
        guard !isBusySending else { return false }
        if isEffectiveChatMode {
            return detectedVipleMailRecipient != nil &&
                (!bodyField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !attachments.isEmpty)
        }
        return !toField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        // 1. Lignes d'en-tête avec bouton dynamique « Chat | Mail » dès qu'une adresse @viplemail.fr est saisie
                        appleMailRecipientHeaders

                        // 2. Suggestions d'auto-complétion de contacts
                        if !matchingContacts.isEmpty {
                            contactSuggestionsList
                        }

                        // 3. Pièces jointes (si présentes ou en cours d'envoi)
                        if !attachments.isEmpty || isUploadingAttachment {
                            attachmentsSection
                        }

                        // 4. Corps du message (Chat instantané ou Mail classique)
                        appleMailBodyEditor

                        // 5. Aperçu de la signature uniquement en mode Mail classique
                        if !isEffectiveChatMode && vm.settings.signatureEnabled && !vm.settings.signatureHtml.isEmpty {
                            signatureBlock
                        }
                    }
                }
                .background(VipleMailPalette.resolvedSurface(for: colorScheme))

                appleMailBottomToolbar
            }
            .background(VipleMailPalette.resolvedSurface(for: colorScheme).ignoresSafeArea())
            .navigationTitle(headerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        if hasUnsavedChanges && !isEffectiveChatMode {
                            isShowingCancelDialog = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        submitNow()
                    } label: {
                        if isBusySending {
                            ProgressView()
                        } else {
                            Image(systemName: isEffectiveChatMode ? "paperplane.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 28, weight: .bold))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(canSend ? VipleMailPalette.primary : VipleMailPalette.inkMuted.opacity(0.45))
                        }
                    }
                    .disabled(!canSend)
                    .accessibilityLabel(isEffectiveChatMode ? "Envoyer dans le Chat" : "Envoyer le courrier")
                }
            }
            .confirmationDialog(
                "Que souhaitez-vous faire de ce courrier ?",
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
                vm.applyWindowInterfaceStyle()
                populateInitialFields()
                includeSignature = vm.settings.signatureEnabled
                syncChannelWithRecipient()
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    if toField.isEmpty {
                        isBodyFocused = false
                        focusedField = .to
                    } else if isEffectiveChatMode {
                        focusedField = nil
                        isBodyFocused = true
                    } else if subjectField.isEmpty {
                        isBodyFocused = false
                        focusedField = .subject
                    } else {
                        focusedField = nil
                        isBodyFocused = true
                    }
                }
            }
            .onChange(of: focusedField) { _, newFocus in
                if newFocus != nil {
                    isBodyFocused = false
                }
            }
            .onChange(of: toField) { _, _ in
                syncChannelWithRecipient()
            }
            .onChange(of: ccField) { _, _ in
                syncChannelWithRecipient()
            }
            .onChange(of: bccField) { _, _ in
                syncChannelWithRecipient()
            }
            .onChange(of: senderMailbox) { _, _ in
                syncChannelWithRecipient()
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

    private func syncChannelWithRecipient() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            if isLockedClassicMailFlow {
                deliveryChannel = .mail
                return
            }
            if detectedVipleMailRecipient != nil {
                if !hasManualChannelChoice {
                    deliveryChannel = .chat
                }
            } else {
                deliveryChannel = .mail
                hasManualChannelChoice = false
            }
        }
    }

    // MARK: - En-têtes (À : + Bascule « Chat | Mail » à côté de l'adresse @viplemail.fr)

    private var appleMailRecipientHeaders: some View {
        VStack(spacing: 0) {
            // Ligne « À : » avec sélecteur « Chat / Mail » juste à côté dès que l'adresse se termine par @viplemail.fr
            HStack(spacing: 8) {
                Text("À :")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                    .frame(width: 34, alignment: .leading)

                TextField(
                    "destinataire@domaine.fr",
                    text: $toField,
                    prompt: VipleMailPalette.prompt("destinataire@domaine.fr", scheme: colorScheme)
                )
                    .font(.system(size: 15))
                    .vipleMailTextInput()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .to)

                if isShowingChatMailToggle {
                    chatMailInlineToggle
                        .transition(.scale.combined(with: .opacity))
                }

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
            .padding(.vertical, 12)

            Divider()
                .padding(.leading, 16)

            if isEffectiveChatMode {
                if vm.sendCapableMailboxes.count > 1 || (vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil) {
                    directSenderPickerRow
                    Divider()
                        .padding(.leading, 16)
                }

                // Bandeau d'information Chat instantané @viplemail.fr / @cenelis.com
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Session de Chat Viple / Cenelis par défaut")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Text("Sera retrouvée dans l'onglet Chat. Touchez « Mail » ci-dessus pour envoyer un courrier classique.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(VipleMailPalette.primary.opacity(0.08))

                Divider()
            } else {
                // Mode Mail Classique : Sélecteur rapide « De : » (si plusieurs adresses ou Agent Cenelis) + Cc/Cci + Priorité + Objet
                if !isExpandedCcBccFrom && ccField.isEmpty && bccField.isEmpty {
                    if vm.sendCapableMailboxes.count > 1 || (vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil) {
                        directSenderPickerRow
                        Divider()
                            .padding(.leading, 16)
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            isExpandedCcBccFrom = true
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text((vm.sendCapableMailboxes.count > 1 || vm.isApprovedCenelisAgent) ? "Cc/Cci, Priorité" : "Cc/Cci, De :")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(VipleMailPalette.inkSecondary)

                            if vm.sendCapableMailboxes.count <= 1 && !vm.isApprovedCenelisAgent {
                                Text(effectiveSenderEmail)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(VipleMailPalette.inkSecondary)
                                    .lineLimit(1)
                            }

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
                    HStack(spacing: 10) {
                        Text("Cc :")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .frame(width: 44, alignment: .leading)

                        TextField(
                            "Copie carbone",
                            text: $ccField,
                            prompt: VipleMailPalette.prompt("Copie carbone", scheme: colorScheme)
                        )
                            .font(.system(size: 15.5))
                            .vipleMailTextInput()
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

                    HStack(spacing: 10) {
                        Text("Cci :")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .frame(width: 44, alignment: .leading)

                        TextField(
                            "Copie carbone invisible",
                            text: $bccField,
                            prompt: VipleMailPalette.prompt("Copie carbone invisible", scheme: colorScheme)
                        )
                            .font(.system(size: 15.5))
                            .vipleMailTextInput()
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

                    HStack(spacing: 10) {
                        Text("De :")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .frame(width: 44, alignment: .leading)

                        if let user = vm.currentUser {
                            VipleMailAvatarView(
                                name: user.displayName,
                                email: effectiveSenderEmail,
                                avatarUrl: vm.resolveAvatarUrl(for: effectiveSenderEmail, explicitUrl: vm.isInternalMailbox(effectiveSenderEmail) ? user.avatarUrl : nil),
                                size: 24,
                                isVip: true
                            )
                            if vm.sendCapableMailboxes.count > 1 {
                                Menu {
                                    ForEach(vm.sendCapableMailboxes, id: \.self) { mbx in
                                        let isCen = mbx.lowercased().hasSuffix("@cenelis.com")
                                        Button {
                                            senderMailbox = mbx
                                        } label: {
                                            Label(
                                                isCen ? "\(user.displayName) <\(mbx)> (Agent Cenelis)" : "\(user.displayName) <\(mbx)>",
                                                systemImage: mbx.lowercased() == effectiveSenderEmail.lowercased()
                                                    ? "checkmark.circle.fill"
                                                    : (isCen ? "checkmark.seal.fill" : "envelope")
                                            )
                                        }
                                    }

                                    if vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil {
                                        Divider()
                                        Button {
                                            Task {
                                                let ok = await vm.claimOrCustomizeCenelisMailbox(switchImmediately: false)
                                                if ok, let cen = vm.cenelisMailboxAddress {
                                                    senderMailbox = cen
                                                }
                                            }
                                        } label: {
                                            Label(
                                                "Activer \(vm.suggestedCenelisLocalPart)@cenelis.com",
                                                systemImage: "checkmark.seal.fill"
                                            )
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Text("\(user.displayName) <\(effectiveSenderEmail)>")
                                            .font(.system(size: 14.5, weight: .medium))
                                            .foregroundStyle(VipleMailPalette.primary)
                                            .lineLimit(1)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(VipleMailPalette.primary)
                                    }
                                }
                            } else {
                                Text("\(user.displayName) <\(effectiveSenderEmail)>")
                                    .font(.system(size: 14.5, weight: .medium))
                                    .foregroundStyle(VipleMailPalette.ink)
                                    .lineLimit(1)
                            }
                        } else {
                            Text(effectiveSenderEmail)
                                .font(.system(size: 15))
                                .foregroundStyle(VipleMailPalette.ink)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.leading, 16)

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

                    TextField(
                        "Objet du courrier",
                        text: $subjectField,
                        prompt: VipleMailPalette.prompt("Objet du courrier", scheme: colorScheme)
                    )
                        .font(.system(size: 15.5, weight: .semibold))
                        .vipleMailTextInput()
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

                if vm.isInternalMailbox(effectiveSenderEmail) {
                    mailRteOptionRow
                    Divider()
                }
            }
        }
    }

    private var mailRteOptionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: disableMailRteForThisMail ? "exclamationmark.shield.fill" : "lock.shield.fill")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(disableMailRteForThisMail ? VipleMailPalette.warning : VipleMailPalette.primary)

                Text("Désactiver MailRTE pour ce mail")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineLimit(1)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        isShowingMailRteHelp.toggle()
                    }
                } label: {
                    Image(systemName: isShowingMailRteHelp ? "questionmark.circle.fill" : "questionmark.circle")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aide Cenelis MailRTE")

                Spacer(minLength: 4)

                Toggle("Désactiver MailRTE pour ce mail", isOn: $disableMailRteForThisMail)
                    .labelsHidden()
                    .scaleEffect(0.88)
                    .tint(VipleMailPalette.warning)
            }

            if disableMailRteForThisMail && !isShowingMailRteHelp {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VipleMailPalette.warning)
                    Text("Cenelis MailRTE est désactivé pour cet envoi uniquement.")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.warning)
                }
            }

            if isShowingMailRteHelp {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Il est recommandé de ne pas désactiver Cenelis MailRTE")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)

                        Text("Par défaut, Cenelis MailRTE est toujours activé : il chiffre et protège toutes les données contenues dans ce mail (objet, corps du message, métadonnées associées et pièces jointes).")
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(VipleMailPalette.primary.opacity(0.24), lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme).opacity(0.45))
    }

    private var chatMailInlineToggle: some View {
        HStack(spacing: 2) {
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    hasManualChannelChoice = true
                    deliveryChannel = .chat
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Chat")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(deliveryChannel == .chat ? Color.white : VipleMailPalette.inkSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(deliveryChannel == .chat ? VipleMailPalette.primary : Color.clear)
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    hasManualChannelChoice = true
                    deliveryChannel = .mail
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Mail")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundStyle(deliveryChannel == .mail ? Color.white : VipleMailPalette.inkSecondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(deliveryChannel == .mail ? VipleMailPalette.primary : Color.clear)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(2.5)
        .background(
            Capsule()
                .fill(VipleMailPalette.surfaceSubtle)
        )
        .overlay(
            Capsule()
                .stroke(VipleMailPalette.border, lineWidth: 1)
        )
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

    // MARK: - Auto-complétion des Contacts

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
                                if contact.contactEmail.lowercased().hasSuffix("@viplemail.fr")
                                    || contact.contactEmail.lowercased().hasSuffix("@cenelis.com") {
                                    Text("Chat")
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundStyle(VipleMailPalette.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 1.5)
                                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
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
                        Text("Envoi en cours…")
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

    // MARK: - Corps du Message

    private var appleMailBodyEditor: some View {
        VipleMailMultiLineEditor(
            text: $bodyField,
            placeholder: isEffectiveChatMode ? "Écrivez votre message instantané…" : "Rédigez votre courrier…",
            fontSize: 16,
            minHeight: 320,
            horizontalInset: 18,
            verticalInset: 16,
            isFocused: $isBodyFocused
        )
        .background(VipleMailPalette.resolvedSurface(for: colorScheme))
    }

    // MARK: - Bloc Signature Automatique (Mail uniquement)

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

    // MARK: - Barre d'Outils Inférieure

    private var appleMailBottomToolbar: some View {
        HStack(spacing: 0) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            Button {
                isShowingFileImporter = true
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            Button {
                contactPickerTarget = .to
                isShowingContactPicker = true
            } label: {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 18, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }

            if !isEffectiveChatMode {
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
                } label: {
                    Image(systemName: "textformat.alt")
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }

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

                Button {
                    saveAsDraftAndDismiss()
                } label: {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
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
                            if contactPickerTarget == .to && toField.trimmingCharacters(in: .whitespaces).isEmpty {
                                toField = contact.contactEmail
                            } else {
                                appendRecipient(contact.contactEmail, to: contactPickerTarget)
                            }
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
            .scrollContentBackground(.hidden)
            .background(VipleMailPalette.background)
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
        .preferredColorScheme(vm.preferredColorSchemeOverride)
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
        focusedField = nil
        isBodyFocused = true
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

    private var directSenderPickerRow: some View {
        HStack(spacing: 10) {
            Text("De :")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .frame(width: 34, alignment: .leading)

            if let user = vm.currentUser {
                Menu {
                    ForEach(vm.sendCapableMailboxes, id: \.self) { mbx in
                        let isCen = mbx.lowercased().hasSuffix("@cenelis.com")
                        Button {
                            senderMailbox = mbx
                        } label: {
                            Label(
                                isCen ? "\(mbx) • Agent Cenelis" : mbx,
                                systemImage: mbx.lowercased() == effectiveSenderEmail.lowercased()
                                    ? "checkmark.circle.fill"
                                    : (isCen ? "checkmark.seal.fill" : "envelope.fill")
                            )
                        }
                    }

                    if vm.isApprovedCenelisAgent && vm.cenelisMailboxAddress == nil {
                        Divider()
                        Button {
                            Task {
                                let ok = await vm.claimOrCustomizeCenelisMailbox(switchImmediately: false)
                                if ok, let cen = vm.cenelisMailboxAddress {
                                    senderMailbox = cen
                                }
                            }
                        } label: {
                            Label(
                                "Activer \(vm.suggestedCenelisLocalPart)@cenelis.com",
                                systemImage: "checkmark.seal.fill"
                            )
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if effectiveSenderEmail.lowercased().hasSuffix("@cenelis.com") {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                        Text(effectiveSenderEmail)
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.primary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(VipleMailPalette.primary.opacity(0.10))
                    )
                }

                Spacer()

                if vm.isApprovedCenelisAgent,
                   let cenAddr = vm.cenelisMailboxAddress,
                   effectiveSenderEmail.lowercased() != cenAddr.lowercased() {
                    Button {
                        senderMailbox = cenAddr
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 10.5, weight: .bold))
                            Text("@cenelis.com")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .strokeBorder(VipleMailPalette.primary.opacity(0.35), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                } else if vm.isApprovedCenelisAgent,
                          effectiveSenderEmail.lowercased().hasSuffix("@cenelis.com"),
                          let vipAddr = vm.viplePersonalMailboxAddress,
                          effectiveSenderEmail.lowercased() != vipAddr.lowercased() {
                    Button {
                        senderMailbox = vipAddr
                    } label: {
                        Text("@viplemail.fr")
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(VipleMailPalette.surfaceSubtle)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func populateInitialFields() {
        disableMailRteForThisMail = false
        isShowingMailRteHelp = false
        let fallbackSender = vm.defaultSendingMailbox
        switch mode {
        case .newMail(let to, let subject, let forceMail, let preferredFromMailbox):
            if let pref = preferredFromMailbox?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
               !pref.isEmpty {
                senderMailbox = pref
            } else {
                senderMailbox = fallbackSender
            }
            toField = to
            subjectField = subject
            if forceMail {
                hasManualChannelChoice = true
                deliveryChannel = .mail
            } else {
                hasManualChannelChoice = false
            }
        case .reply(let msg):
            senderMailbox = vm.sendCapableMailboxes.contains(msg.effectiveMailboxEmail(fallback: fallbackSender).lowercased())
                ? msg.effectiveMailboxEmail(fallback: fallbackSender)
                : fallbackSender
            toField = msg.senderEmail
            subjectField = msg.subject.lowercased().hasPrefix("re:") ? msg.subject : "Re: \(msg.subject)"
            threadId = msg.threadId
            replyToMessageId = msg.replyToMessageId
            hasManualChannelChoice = true
            deliveryChannel = .mail
            bodyField = "\n\n--- Le \(msg.formattedFullDate), \(msg.senderName) <\(msg.senderEmail)> a écrit : ---\n\(msg.plainBodyText)"
        case .replyAll(let msg):
            senderMailbox = vm.sendCapableMailboxes.contains(msg.effectiveMailboxEmail(fallback: fallbackSender).lowercased())
                ? msg.effectiveMailboxEmail(fallback: fallbackSender)
                : fallbackSender
            toField = msg.senderEmail
            ccField = msg.ccEmail
            isExpandedCcBccFrom = !msg.ccEmail.isEmpty
            subjectField = msg.subject.lowercased().hasPrefix("re:") ? msg.subject : "Re: \(msg.subject)"
            threadId = msg.threadId
            replyToMessageId = msg.replyToMessageId
            hasManualChannelChoice = true
            deliveryChannel = .mail
            bodyField = "\n\n--- Le \(msg.formattedFullDate), \(msg.senderName) <\(msg.senderEmail)> a écrit : ---\n\(msg.plainBodyText)"
        case .forward(let msg):
            senderMailbox = vm.sendCapableMailboxes.contains(msg.effectiveMailboxEmail(fallback: fallbackSender).lowercased())
                ? msg.effectiveMailboxEmail(fallback: fallbackSender)
                : fallbackSender
            subjectField = msg.subject.lowercased().hasPrefix("tr:") ? msg.subject : "Tr: \(msg.subject)"
            threadId = msg.threadId
            attachments = msg.attachments
            hasManualChannelChoice = true
            deliveryChannel = .mail
            bodyField = "\n\n---------- Message transféré ----------\nDe : \(msg.senderName) <\(msg.senderEmail)>\nDate : \(msg.formattedFullDate)\nObjet : \(msg.subject)\nÀ : \(msg.recipientEmail)\n\n\(msg.plainBodyText)"
        case .editDraft(let draft):
            senderMailbox = draft.effectiveMailboxEmail(fallback: fallbackSender)
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
            hasManualChannelChoice = true
            deliveryChannel = .mail
        }
    }

    private func submitNow() {
        if isEffectiveChatMode, let peer = detectedVipleMailRecipient {
            Task {
                if let session = await vm.sendChatMessage(
                    to: peer,
                    text: bodyField,
                    attachments: attachments,
                    fromMailbox: effectiveSenderEmail
                ) {
                    vm.closeMessage()
                    vm.selectedTab = 1
                    vm.openChatSession(session)
                    await vm.reloadActiveChatMessages(silent: true)
                    dismiss()
                }
            }
            return
        }

        Task {
            let finalBodyText: String
            if includeSignature && vm.settings.signatureEnabled && !vm.settings.signatureHtml.isEmpty {
                let cleanSig = vm.settings.signatureHtml.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                finalBodyText = bodyField + "\n\n-- \n" + cleanSig
            } else {
                finalBodyText = bodyField
            }

            let ok = await vm.sendOrSaveMail(
                to: toField,
                cc: ccField,
                bcc: bccField,
                subject: subjectField,
                bodyText: finalBodyText,
                bodyHtml: nil,
                priority: priority,
                threadId: threadId,
                replyToMessageId: replyToMessageId,
                draftId: draftId,
                isDraft: false,
                attachments: attachments,
                deliveryMode: "mail",
                fromMailbox: effectiveSenderEmail,
                disableMailRte: disableMailRteForThisMail
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
                attachments: attachments,
                deliveryMode: "mail",
                fromMailbox: effectiveSenderEmail,
                disableMailRte: disableMailRteForThisMail
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
