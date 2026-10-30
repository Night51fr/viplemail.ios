import SwiftUI

// MARK: - Lecture de Courrier & Fil de Conversation « Viple Mail » (Pièces Jointes, Réponse Rapide & Actions Complètes)

public struct MessageDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: VipleMailViewModel
    public let message: VipleMailMessage

    @State private var quickReplyText: String = ""
    @State private var isSendingQuickReply: Bool = false
    @State private var showFullHeaders: Bool = false

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var currentMessage: VipleMailMessage {
        vm.messages.first(where: { $0.id == message.id }) ?? message
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    subjectAndBadgesHeader
                    senderMetadataCard

                    if vm.activeThreadMessages.count > 1 {
                        threadTimelineSection
                    } else {
                        messageBodyCard(currentMessage)
                    }

                    if !currentMessage.attachments.isEmpty {
                        attachmentsSection(currentMessage.attachments)
                    }

                    actionButtonsGrid
                }
                .padding(16)
            }

            quickReplyBottomBar
        }
        .background(VipleMailPalette.background)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await vm.performMessageAction(
                            messageIds: [currentMessage.id],
                            action: "toggle_star",
                            toast: currentMessage.isStarred ? "Retiré des favoris" : "Ajouté aux favoris ⭐"
                        )
                    }
                } label: {
                    Image(systemName: currentMessage.isStarred ? "star.fill" : "star")
                        .foregroundStyle(currentMessage.isStarred ? VipleMailPalette.starYellow : VipleMailPalette.ink)
                }

                Button {
                    Task {
                        await vm.performMessageAction(
                            messageIds: [currentMessage.id],
                            action: "archive",
                            toast: "Message archivé"
                        )
                        dismiss()
                    }
                } label: {
                    Image(systemName: "archivebox")
                }

                Button(role: .destructive) {
                    Task {
                        await vm.performMessageAction(
                            messageIds: [currentMessage.id],
                            action: "trash",
                            toast: "Déplacé dans la Corbeille"
                        )
                        dismiss()
                    }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(VipleMailPalette.danger)
                }
            }
        }
        .task {
            await vm.openMessageAndLoadThread(message)
        }
    }

    // MARK: - En-tête Objet & Badges

    private var subjectAndBadgesHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(currentMessage.folder)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))

                if currentMessage.isHighPriority {
                    Label("Priorité Haute", systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VipleMailPalette.danger.opacity(0.12)))
                }

                if currentMessage.isVipSender {
                    Label("Contact VIP", systemImage: "crown.fill")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.vipGold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(VipleMailPalette.vipGold.opacity(0.14)))
                }

                Spacer()
            }

            Text(currentMessage.subject)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
        }
    }

    // MARK: - Carte Expéditeur & Destinataires

    private var senderMetadataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VipleMailAvatarView(
                    name: currentMessage.senderName,
                    email: currentMessage.senderEmail,
                    size: 48,
                    isVip: currentMessage.isVipSender
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(currentMessage.senderName)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text(currentMessage.senderEmail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VipleMailPalette.primary)
                    Text(currentMessage.formattedFullDate)
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                Spacer()

                Button {
                    withAnimation {
                        showFullHeaders.toggle()
                    }
                } label: {
                    Image(systemName: showFullHeaders ? "chevron.up.circle.fill" : "info.circle")
                        .font(.title3)
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            if showFullHeaders {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    headerDetailRow(label: "De :", value: "\(currentMessage.senderName) <\(currentMessage.senderEmail)>")
                    headerDetailRow(label: "À :", value: currentMessage.recipientEmail)
                    if !currentMessage.ccEmail.isEmpty {
                        headerDetailRow(label: "Cc :", value: currentMessage.ccEmail)
                    }
                    headerDetailRow(label: "Taille :", value: currentMessage.formattedSize)
                    headerDetailRow(label: "Sécurité :", value: "Chiffrement TLS Viple Live ID vérifié")
                }
                .font(.system(size: 12))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func headerDetailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .fontWeight(.bold)
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .frame(width: 65, alignment: .leading)
            Text(value)
                .foregroundStyle(VipleMailPalette.ink)
                .textSelection(.enabled)
            Spacer()
        }
    }

    // MARK: - Corps du Message & Fil de Conversation

    private var threadTimelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(vm.activeThreadMessages.count) messages dans cette conversation", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                Spacer()
            }

            ForEach(vm.activeThreadMessages) { item in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(item.senderName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VipleMailPalette.ink)
                        Spacer()
                        Text(item.formattedRelativeDate)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                    Divider()
                    Text(item.plainBodyText)
                        .font(.system(size: 15))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineSpacing(4)
                        .textSelection(.enabled)
                }
                .vipleMailCard(cornerRadius: 18, padding: 16)
            }
        }
    }

    private func messageBodyCard(_ msg: VipleMailMessage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(msg.plainBodyText)
                .font(.system(size: 15.5))
                .foregroundStyle(VipleMailPalette.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .vipleMailCard(cornerRadius: 20, padding: 18)
    }

    // MARK: - Pièces Jointes

    private func attachmentsSection(_ list: [VipleMailAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Pièces jointes (\(list.count))", systemImage: "paperclip")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            ForEach(list) { att in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VipleMailPalette.primary.opacity(0.12))
                            .frame(width: 42, height: 42)
                        Image(systemName: att.iconName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(VipleMailPalette.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(att.fileName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Text("\(att.formattedSize) • Stocké sur Viple SkyDrive")
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }

                    Spacer()

                    if let url = URL(string: att.url), !att.url.isEmpty {
                        Link(destination: url) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                }
                .vipleMailCard(cornerRadius: 16, padding: 12)
            }
        }
    }

    // MARK: - Grille d'Actions

    private var actionButtonsGrid: some View {
        HStack(spacing: 10) {
            Button {
                vm.presentComposer(.reply(currentMessage))
            } label: {
                Label("Répondre", systemImage: "arrowshape.turn.up.left.fill")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VipleMailPalette.border, lineWidth: 1))
            }

            Button {
                vm.presentComposer(.replyAll(currentMessage))
            } label: {
                Label("Rép. à tous", systemImage: "arrowshape.turn.up.left.2.fill")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VipleMailPalette.border, lineWidth: 1))
            }

            Button {
                vm.presentComposer(.forward(currentMessage))
            } label: {
                Label("Transférer", systemImage: "arrowshape.turn.up.right.fill")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VipleMailPalette.border, lineWidth: 1))
            }
        }
        .foregroundStyle(VipleMailPalette.primary)
    }

    // MARK: - Barre de Réponse Rapide en Bas d'Écran

    private var quickReplyBottomBar: some View {
        HStack(spacing: 10) {
            TextField("Réponse rapide à \(currentMessage.senderName)...", text: $quickReplyText)
                .font(.system(size: 14))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(VipleMailPalette.surfaceSubtle)
                )

            Button {
                sendQuickReply()
            } label: {
                if isSendingQuickReply {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(VipleMailPalette.primary))
                } else {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? VipleMailPalette.inkMuted.opacity(0.4) : VipleMailPalette.primary)
                        )
                }
            }
            .disabled(quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingQuickReply)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            VipleMailPalette.surface
                .shadow(color: VipleMailPalette.cobaltDeep.opacity(0.06), radius: 10, x: 0, y: -3)
        )
    }

    private func sendQuickReply() {
        let text = quickReplyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSendingQuickReply = true
        let replySub = currentMessage.subject.lowercased().hasPrefix("re:") ? currentMessage.subject : "Re: \(currentMessage.subject)"
        Task {
            let ok = await vm.sendOrSaveMail(
                to: currentMessage.senderEmail,
                cc: "",
                bcc: "",
                subject: replySub,
                bodyText: text,
                bodyHtml: nil,
                priority: "Normal",
                threadId: currentMessage.threadId,
                replyToMessageId: currentMessage.id,
                draftId: nil,
                isDraft: false,
                attachments: []
            )
            isSendingQuickReply = false
            if ok {
                quickReplyText = ""
                await vm.openMessageAndLoadThread(currentMessage)
            }
        }
    }
}
