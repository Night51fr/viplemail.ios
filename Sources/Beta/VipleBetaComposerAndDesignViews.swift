import Foundation
import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
import Vision
import CoreHaptics
#endif

// MARK: - Coordinateur d'Expédition Avancée : Undo Send (#021) & Envoi Programmé (#022)

@MainActor
public final class BetaOutboxCoordinator: ObservableObject {
    public static let shared = BetaOutboxCoordinator()

    public struct PendingUndoItem: Identifiable, Equatable {
        public let id: String
        public let fromMailbox: String
        public let to: String
        public let cc: String
        public let bcc: String
        public let subject: String
        public let bodyText: String
        public let bodyHtml: String?
        public let priority: String
        public let attachments: [VipleMailAttachment]
        public let disableMailRte: Bool
        public var secondsRemaining: Int
    }

    @Published public var pendingUndo: PendingUndoItem? = nil
    private var undoTask: Task<Void, Never>? = nil
    private var schedulerLoopTask: Task<Void, Never>? = nil

    private init() {}

    public func enqueueWithUndoWindow(
        vm: VipleMailViewModel,
        fromMailbox: String,
        to: String,
        cc: String,
        bcc: String,
        subject: String,
        bodyText: String,
        bodyHtml: String?,
        priority: String,
        attachments: [VipleMailAttachment],
        disableMailRte: Bool
    ) {
        undoTask?.cancel()
        let delay = max(5, min(30, VipleBetaStore.shared.undoSendDelaySeconds))
        let item = PendingUndoItem(
            id: UUID().uuidString,
            fromMailbox: fromMailbox,
            to: to,
            cc: cc,
            bcc: bcc,
            subject: subject,
            bodyText: bodyText,
            bodyHtml: bodyHtml,
            priority: priority,
            attachments: attachments,
            disableMailRte: disableMailRte,
            secondsRemaining: delay
        )
        pendingUndo = item

        undoTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while let cur = self.pendingUndo, cur.id == item.id, cur.secondsRemaining > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                if var updated = self.pendingUndo, updated.id == item.id {
                    updated.secondsRemaining -= 1
                    self.pendingUndo = updated
                }
            }
            guard !Task.isCancelled, let finalItem = self.pendingUndo, finalItem.id == item.id else { return }
            self.pendingUndo = nil
            let sent = await vm.sendOrSaveMail(
                to: finalItem.to,
                cc: finalItem.cc,
                bcc: finalItem.bcc,
                subject: finalItem.subject,
                bodyText: finalItem.bodyText,
                bodyHtml: finalItem.bodyHtml,
                priority: finalItem.priority,
                threadId: nil,
                replyToMessageId: nil,
                draftId: nil,
                isDraft: false,
                attachments: finalItem.attachments,
                deliveryMode: "mail",
                fromMailbox: finalItem.fromMailbox,
                disableMailRte: finalItem.disableMailRte
            )
            if sent {
                VipleBetaStore.shared.triggerCelebrationParticles()
                BetaChoreographedHaptics.play(.sendCrystal)
            }
        }
    }

    public func cancelPendingSendAndRestoreComposer(vm: VipleMailViewModel) {
        guard let item = pendingUndo else { return }
        undoTask?.cancel()
        undoTask = nil
        pendingUndo = nil
        vm.showToast("↩️ Envoi annulé — réouverture de votre brouillon")
        vm.presentComposer(.newMail(
            to: item.to,
            subject: item.subject,
            body: item.bodyText,
            forceMail: true,
            preferredFromMailbox: item.fromMailbox
        ))
    }

    public func startScheduledOutboxWatcher(vm: VipleMailViewModel) {
        guard schedulerLoopTask == nil else { return }
        schedulerLoopTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                let store = VipleBetaStore.shared
                let now = Date()
                if store.isEnabled(.f022) {
                    let due = store.scheduledOutgoingMails.filter { $0.sendAt <= now }
                    for mail in due {
                        store.scheduledOutgoingMails.removeAll { $0.id == mail.id }
                        store.saveState()
                        _ = await vm.sendOrSaveMail(
                            to: mail.to,
                            cc: mail.cc,
                            bcc: mail.bcc,
                            subject: mail.subject,
                            bodyText: mail.bodyText,
                            bodyHtml: nil,
                            priority: "Normal",
                            threadId: nil,
                            replyToMessageId: nil,
                            draftId: nil,
                            isDraft: false,
                            attachments: [],
                            deliveryMode: "mail",
                            fromMailbox: mail.fromMailbox.isEmpty ? vm.defaultSendingMailbox : mail.fromMailbox
                        )
                    }
                }
                if store.isEnabled(.f058) {
                    let dueChats = store.scheduledChatMessages.filter { $0.sendAt <= now }
                    for chatItem in dueChats {
                        store.scheduledChatMessages.removeAll { $0.id == chatItem.id }
                        store.saveState()
                        _ = await vm.sendChatMessage(to: chatItem.peerEmail, text: chatItem.text, attachments: [])
                    }
                }
            }
        }
    }
}

// MARK: - Convertisseur Markdown (#024), Garde-Fou Pré-Envoi (#025) & Sondages Mail (#026)

public enum BetaComposerIntelligence {
    public static func renderMarkdownToRichHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var htmlLines: [String] = []
        var inList = false

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                if !inList {
                    htmlLines.append("<ul style='padding-left:20px;margin:8px 0;'>")
                    inList = true
                }
                let content = inlineFormat(String(trimmed.dropFirst(2)))
                htmlLines.append("<li style='margin-bottom:4px;'>\(content)</li>")
                continue
            } else if inList {
                htmlLines.append("</ul>")
                inList = false
            }

            if trimmed.hasPrefix("### ") {
                htmlLines.append("<h3 style='color:#0078D4;margin:12px 0 6px;'>\(inlineFormat(String(trimmed.dropFirst(4))))</h3>")
            } else if trimmed.hasPrefix("## ") {
                htmlLines.append("<h2 style='color:#0F172A;margin:14px 0 6px;'>\(inlineFormat(String(trimmed.dropFirst(3))))</h2>")
            } else if trimmed.hasPrefix("# ") {
                htmlLines.append("<h1 style='color:#0078D4;font-size:21px;margin:16px 0 8px;'>\(inlineFormat(String(trimmed.dropFirst(2))))</h1>")
            } else if trimmed.hasPrefix("> ") {
                htmlLines.append("<blockquote style='border-left:3px solid #0078D4;padding-left:12px;color:#475569;margin:10px 0;'>\(inlineFormat(String(trimmed.dropFirst(2))))</blockquote>")
            } else if trimmed.isEmpty {
                htmlLines.append("<br/>")
            } else {
                htmlLines.append("<p style='margin:0 0 8px;line-height:1.55;'>\(inlineFormat(rawLine))</p>")
            }
        }
        if inList { htmlLines.append("</ul>") }
        return "<div data-cenelis-rich-mail='1' style='font-family:-apple-system,sans-serif;font-size:15px;'>\(htmlLines.joined())</div>"
    }

    private static func inlineFormat(_ text: String) -> String {
        var escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#,
            with: "<strong>$1</strong>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: #"\*(.+?)\*"#,
            with: "<em>$1</em>",
            options: .regularExpression
        )
        escaped = escaped.replacingOccurrences(
            of: #"`(.+?)`"#,
            with: "<code style='background:#F1F5F9;padding:2px 5px;border-radius:4px;font-family:monospace;'>$1</code>",
            options: .regularExpression
        )
        return escaped
    }

    public static func preSendAuditWarnings(subject: String, body: String, hasAttachments: Bool) -> [String] {
        var warnings: [String] = []
        let cleanSubj = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanSubj.isEmpty {
            warnings.append("L'objet du courrier est vide.")
        }
        let lowerBody = body.lowercased()
        let attachmentKeywords = ["ci-joint", "pièce jointe", "pieces jointes", "en annexe", "attached", "joint à ce mail"]
        if !hasAttachments && attachmentKeywords.contains(where: { lowerBody.contains($0) }) {
            warnings.append("Vous mentionnez une pièce jointe dans le texte mais aucun fichier n'est attaché.")
        }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 22 || hour < 6 {
            warnings.append("Il est \(hour)h : envisagez l'envoi programmé à 08h00 demain matin.")
        }
        return warnings
    }

    public static func applyTemplateVariables(
        template: String,
        recipientEmail: String,
        contacts: [VipleMailContact],
        friends: [VipleFriend]
    ) -> String {
        let cleanEmail = recipientEmail.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces).lowercased() } ?? ""
        let contact = contacts.first { $0.contactEmail.lowercased() == cleanEmail }
        let friend = friends.first { $0.allKnownEmails.contains(cleanEmail) }
        let fullName = contact?.displayName ?? friend?.displayName ?? cleanEmail.split(separator: "@").first.map(String.init)?.capitalized ?? "Madame, Monsieur"
        let firstName = fullName.split(separator: " ").first.map(String.init) ?? fullName
        let lastName = fullName.split(separator: " ").dropFirst().joined(separator: " ")
        let company = (contact?.company.isEmpty == false) ? contact!.company : BetaProductivityEngine.senderDomain(of: cleanEmail)
        let today = Date().formatted(date: .abbreviated, time: .omitted)

        return template
            .replacingOccurrences(of: "{{prenom}}", with: firstName)
            .replacingOccurrences(of: "{{nom}}", with: lastName.isEmpty ? fullName : lastName)
            .replacingOccurrences(of: "{{email}}", with: cleanEmail)
            .replacingOccurrences(of: "{{entreprise}}", with: company)
            .replacingOccurrences(of: "{{date}}", with: today)
    }
}

public struct ParsedBetaMailPoll: Identifiable, Equatable {
    public let id: String
    public let question: String
    public let options: [String]
}

public enum BetaMailPollParser {
    public static func buildTag(question: String, options: [String]) -> String {
        let cleanQ = question.replacingOccurrences(of: "|", with: "-")
        let cleanOpts = options.map { $0.replacingOccurrences(of: "|", with: "-").replacingOccurrences(of: "]", with: "") }
        return "#viplesondage[\(cleanQ)|\(cleanOpts.joined(separator: "|"))]"
    }

    public static func extract(from text: String, messageId: String) -> ParsedBetaMailPoll? {
        guard let r = text.range(of: #"#viplesondage\[([^\]]+)\]"#, options: .regularExpression) else { return nil }
        let raw = String(text[r])
        guard let open = raw.firstIndex(of: "["), let close = raw.lastIndex(of: "]") else { return nil }
        let parts = String(raw[raw.index(after: open)..<close]).split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count >= 3 else { return nil }
        return ParsedBetaMailPoll(id: "poll-\(messageId)", question: parts[0], options: Array(parts.dropFirst()))
    }
}

public struct BetaInteractiveMailPollCardView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    public let poll: ParsedBetaMailPoll

    public var body: some View {
        let chosenIdx = beta.pollVotesByPollId[poll.id]

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(VipleMailPalette.indigo)
                Text("SONDAGE INTERACTIF (#viplesondage)")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.indigo)
                Spacer()
            }
            Text(poll.question)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            ForEach(Array(poll.options.enumerated()), id: \.offset) { idx, opt in
                let isVoted = chosenIdx == idx
                Button {
                    beta.pollVotesByPollId[poll.id] = idx
                    beta.saveState()
                    BetaChoreographedHaptics.play(.tapCrisp)
                } label: {
                    HStack {
                        Image(systemName: isVoted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(isVoted ? VipleMailPalette.indigo : VipleMailPalette.inkMuted)
                        Text(opt)
                            .font(.system(size: 13.5, weight: isVoted ? .bold : .medium))
                            .foregroundStyle(VipleMailPalette.ink)
                        Spacer()
                        if chosenIdx != nil {
                            Text(isVoted ? "Votre choix (100%)" : "0%")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isVoted ? VipleMailPalette.indigo : VipleMailPalette.inkMuted)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(isVoted ? VipleMailPalette.indigo.opacity(0.14) : VipleMailPalette.surface)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isVoted ? VipleMailPalette.indigo : VipleMailPalette.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(VipleMailPalette.surfaceSubtle))
    }
}

// MARK: - Barre d'Outils Beta Intégrée dans ComposeMailView (#021..#030, #045, #047, #073, #083, #096)

public struct BetaComposerAugmentationBar: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    @Binding public var toField: String
    @Binding public var subjectField: String
    @Binding public var bodyField: String
    @Binding public var attachments: [VipleMailAttachment]
    @Binding public var markdownModeEnabled: Bool
    public let fromMailbox: String
    public let onDismissComposer: () -> Void

    @State private var showScheduleSheet: Bool = false
    @State private var showTemplatesSheet: Bool = false
    @State private var showPollSheet: Bool = false
    @State private var showSignaturesSheet: Bool = false
    @State private var showPhotoStudioSheet: Bool = false
    @State private var showOcrScannerSheet: Bool = false
    @State private var showMailMergeSheet: Bool = false
    @State private var showEphemeralPicker: Bool = false
    @State private var showSnippetsSheet: Bool = false
    @State private var showGroupsSheet: Bool = false
    @State private var showAliasSheet: Bool = false
    @State private var showMarkdownPreview: Bool = false

    public init(
        toField: Binding<String>,
        subjectField: Binding<String>,
        bodyField: Binding<String>,
        attachments: Binding<[VipleMailAttachment]>,
        markdownModeEnabled: Binding<Bool>,
        fromMailbox: String,
        onDismissComposer: @escaping () -> Void
    ) {
        self._toField = toField
        self._subjectField = subjectField
        self._bodyField = bodyField
        self._attachments = attachments
        self._markdownModeEnabled = markdownModeEnabled
        self.fromMailbox = fromMailbox
        self.onDismissComposer = onDismissComposer
    }

    private var hasAnyComposeBetaEnabled: Bool {
        let ids: [VipleBetaFeatureID] = [.f022, .f023, .f024, .f026, .f027, .f028, .f029, .f030, .f045, .f047, .f073, .f083, .f096]
        return ids.contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyComposeBetaEnabled {
            VStack(spacing: 6) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        if beta.isEnabled(.f022) {
                            composeChip("Programmer", icon: "clock.arrow.2.circlepath", tint: .purple) {
                                showScheduleSheet = true
                            }
                        }
                        if beta.isEnabled(.f023) {
                            composeChip("Modèles", icon: "doc.on.doc.fill", tint: VipleMailPalette.primary) {
                                showTemplatesSheet = true
                            }
                        }
                        if beta.isEnabled(.f024) {
                            composeChip(markdownModeEnabled ? "Markdown ON" : "Markdown", icon: "chevron.left.forwardslash.chevron.right", tint: markdownModeEnabled ? .green : .secondary) {
                                markdownModeEnabled.toggle()
                            }
                            if markdownModeEnabled {
                                composeChip("Aperçu HTML", icon: "eye.fill", tint: .teal) {
                                    showMarkdownPreview = true
                                }
                            }
                        }
                        if beta.isEnabled(.f026) {
                            composeChip("Sondage", icon: "chart.pie.fill", tint: VipleMailPalette.indigo) {
                                showPollSheet = true
                            }
                        }
                        if beta.isEnabled(.f027) {
                            composeChip("Signatures", icon: "signature", tint: .cyan) {
                                showSignaturesSheet = true
                            }
                        }
                        if beta.isEnabled(.f028) {
                            composeChip("Photo Éco/EXIF", icon: "photo.badge.checkmark.fill", tint: .orange) {
                                showPhotoStudioSheet = true
                            }
                        }
                        if beta.isEnabled(.f029) {
                            composeChip("Scan OCR", icon: "doc.viewfinder.fill", tint: .mint) {
                                showOcrScannerSheet = true
                            }
                        }
                        if beta.isEnabled(.f030) {
                            composeChip("Publipostage", icon: "person.3.sequence.fill", tint: .pink) {
                                showMailMergeSheet = true
                            }
                        }
                        if beta.isEnabled(.f073) {
                            composeChip("Mes créneaux", icon: "calendar.badge.checkmark", tint: .green) {
                                let slotsText = BetaAgendaFreeSlotsHelper.proposeThreeFreeSlotsText(existingEvents: vm.agendaEvents)
                                bodyField += (bodyField.isEmpty ? "" : "\n\n") + slotsText
                                vm.showToast("📅 3 créneaux libres insérés !")
                            }
                        }
                        if beta.isEnabled(.f045) {
                            composeChip("Éphémère", icon: "flame.fill", tint: .red) {
                                showEphemeralPicker = true
                            }
                        }
                        if beta.isEnabled(.f047) {
                            composeChip("Alias +", icon: "at.badge.plus", tint: .teal) {
                                showAliasSheet = true
                            }
                        }
                        if beta.isEnabled(.f083) {
                            composeChip("Groupes", icon: "person.3.fill", tint: .brown) {
                                showGroupsSheet = true
                            }
                        }
                        if beta.isEnabled(.f096) {
                            composeChip("Snippets", icon: "doc.on.clipboard.fill", tint: VipleMailPalette.primary) {
                                showSnippetsSheet = true
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
            }
            .background(VipleMailPalette.surfaceSubtle.opacity(0.65))
            .confirmationDialog("Durée avant auto-destruction (#vipleephemere)", isPresented: $showEphemeralPicker, titleVisibility: .visible) {
                Button("5 minutes") { appendEphemeral(minutes: 5) }
                Button("1 heure") { appendEphemeral(minutes: 60) }
                Button("24 heures") { appendEphemeral(minutes: 1440) }
                Button("7 jours") { appendEphemeral(minutes: 10080) }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showScheduleSheet) {
                BetaScheduleOutgoingSheet(
                    fromMailbox: fromMailbox,
                    to: toField,
                    subject: subjectField,
                    bodyText: bodyField,
                    onScheduled: onDismissComposer
                )
            }
            .sheet(isPresented: $showTemplatesSheet) {
                BetaTemplatesPickerSheet(recipientEmail: toField) { subj, renderedBody in
                    if subjectField.isEmpty && !subj.isEmpty { subjectField = subj }
                    bodyField += (bodyField.isEmpty ? "" : "\n\n") + renderedBody
                }
                .environmentObject(vm)
            }
            .sheet(isPresented: $showPollSheet) {
                BetaMailPollComposerSheet { tag in
                    bodyField += (bodyField.isEmpty ? "" : "\n\n") + tag + "\n"
                }
            }
            .sheet(isPresented: $showSignaturesSheet) {
                BetaSignaturesManagerSheet { chosenSig in
                    bodyField += "\n\n-- \n\(chosenSig)"
                }
            }
            .sheet(isPresented: $showPhotoStudioSheet) {
                BetaPhotoCompressorSanitizerSheet { uploaded in
                    attachments.append(uploaded)
                }
                .environmentObject(vm)
            }
            .sheet(isPresented: $showOcrScannerSheet) {
                BetaVisionOcrScannerSheet { recognized in
                    bodyField += (bodyField.isEmpty ? "" : "\n\n") + recognized
                }
            }
            .sheet(isPresented: $showMailMergeSheet) {
                BetaMailMergeAssistantSheet(initialSubject: subjectField, initialBody: bodyField, fromMailbox: fromMailbox)
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showSnippetsSheet) {
                BetaClipboardSnippetsVaultView { snippetText in
                    bodyField += (bodyField.isEmpty ? "" : "\n") + snippetText
                }
            }
            .sheet(isPresented: $showGroupsSheet) {
                BetaMailingGroupsPickerSheet { joinedEmails in
                    toField = toField.isEmpty ? joinedEmails : "\(toField), \(joinedEmails)"
                }
            }
            .sheet(isPresented: $showAliasSheet) {
                NavigationStack {
                    BetaCloakedAliasGeneratorView()
                        .environmentObject(vm)
                        .navigationTitle("Alias Cloisonné (#047)")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Fermer") { showAliasSheet = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showMarkdownPreview) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("APERÇU VISUEL FORMATÉ")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.primary)
                            if let mdAttr = try? AttributedString(markdown: bodyField, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                                Text(mdAttr)
                                    .font(.system(size: 15.5))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surfaceSubtle))
                            } else {
                                Text(bodyField)
                                    .font(.system(size: 15.5))
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surfaceSubtle))
                            }

                            Text("CODE HTML GÉNÉRÉ À L'ENVOI")
                                .font(.system(size: 11, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                            Text(BetaComposerIntelligence.renderMarkdownToRichHTML(bodyField))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                                .textSelection(.enabled)
                        }
                        .padding(16)
                    }
                    .navigationTitle("Aperçu Markdown → HTML")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") { showMarkdownPreview = false }
                        }
                    }
                }
            }
        }
    }

    private func appendEphemeral(minutes: Int) {
        let exp = Date().addingTimeInterval(Double(minutes * 60))
        let tag = "#vipleephemere[\(VipleCalendarParser.formatISOUtc(exp))]"
        bodyField += (bodyField.isEmpty ? "" : "\n\n") + tag
        vm.showToast("🔥 Auto-destruction attachée (\(minutes) min)")
    }

    private func composeChip(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 11.5, weight: .bold, design: .rounded)).lineLimit(1)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(tint.opacity(0.13)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vues Complètes Rédaction Pro (#022, #023, #026, #027, #028, #029, #030)

public struct BetaScheduleOutgoingSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let fromMailbox: String
    public let to: String
    public let subject: String
    public let bodyText: String
    public var onScheduled: (() -> Void)? = nil

    @State private var chosenDate: Date = Date().addingTimeInterval(3600)

    public init(fromMailbox: String = "", to: String = "", subject: String = "", bodyText: String = "", onScheduled: (() -> Void)? = nil) {
        self.fromMailbox = fromMailbox
        self.to = to
        self.subject = subject
        self.bodyText = bodyText
        self.onScheduled = onScheduled
    }

    public var body: some View {
        NavigationStack {
            Form {
                if !to.isEmpty {
                    Section("Programmer l'envoi de ce courrier") {
                        DatePicker("Date & Heure d'envoi", selection: $chosenDate, in: Date()...)
                        Button("Programmer l'expédition") {
                            let item = BetaScheduledOutgoingMail(
                                id: UUID().uuidString,
                                fromMailbox: fromMailbox,
                                to: to,
                                cc: "",
                                bcc: "",
                                subject: subject.isEmpty ? "(Sans objet)" : subject,
                                bodyText: bodyText,
                                sendAt: chosenDate
                            )
                            beta.scheduledOutgoingMails.append(item)
                            beta.saveState()
                            dismiss()
                            onScheduled?()
                        }
                        .fontWeight(.bold)
                    }
                }
                Section("File d'attente des courriers programmés (\(beta.scheduledOutgoingMails.count))") {
                    if beta.scheduledOutgoingMails.isEmpty {
                        Text("Aucun courrier en attente d'envoi différé.")
                            .font(.system(size: 13))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                    } else {
                        ForEach(beta.scheduledOutgoingMails) { item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.subject).font(.system(size: 14, weight: .bold))
                                Text("À : \(item.to) • Départ : \(item.sendAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VipleMailPalette.primary)
                            }
                        }
                        .onDelete { offsets in
                            beta.scheduledOutgoingMails.remove(atOffsets: offsets)
                            beta.saveState()
                        }
                    }
                }
            }
            .navigationTitle("Envoi Programmé")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaTemplatesPickerSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    public var recipientEmail: String = ""
    public var onSelect: ((String, String) -> Void)? = nil

    @State private var newName: String = ""
    @State private var newSubj: String = ""
    @State private var newBody: String = "Bonjour {{prenom}},\n\n"

    public init(recipientEmail: String = "", onSelect: ((String, String) -> Void)? = nil) {
        self.recipientEmail = recipientEmail
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Insérer un modèle dynamique") {
                    ForEach(beta.mailTemplates) { tpl in
                        Button {
                            let renderedSubj = BetaComposerIntelligence.applyTemplateVariables(
                                template: tpl.subjectTemplate,
                                recipientEmail: recipientEmail,
                                contacts: vm.contacts,
                                friends: vm.acceptedFriends
                            )
                            let renderedBody = BetaComposerIntelligence.applyTemplateVariables(
                                template: tpl.bodyTemplate,
                                recipientEmail: recipientEmail,
                                contacts: vm.contacts,
                                friends: vm.acceptedFriends
                            )
                            onSelect?(renderedSubj, renderedBody)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tpl.name).font(.system(size: 14, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                Text(tpl.bodyTemplate).font(.system(size: 12)).foregroundStyle(VipleMailPalette.inkSecondary).lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        beta.mailTemplates.remove(atOffsets: offsets)
                        beta.saveState()
                    }
                }
                Section("Créer un nouveau modèle ({{prenom}}, {{entreprise}}, {{date}})") {
                    TextField("Titre du modèle", text: $newName)
                    TextField("Objet type", text: $newSubj)
                    TextEditor(text: $newBody).frame(minHeight: 80)
                    Button("Enregistrer le modèle") {
                        beta.mailTemplates.append(BetaMailTemplate(id: UUID().uuidString, name: newName, subjectTemplate: newSubj, bodyTemplate: newBody))
                        beta.saveState()
                        newName = ""; newSubj = ""
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Modèles Dynamiques")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaMailPollComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var onInsert: (String) -> Void
    @State private var question: String = ""
    @State private var opt1: String = "Oui, parfait"
    @State private var opt2: String = "À décaler"
    @State private var opt3: String = "Besoin d'un point Visio"

    public init(onInsert: @escaping (String) -> Void) {
        self.onInsert = onInsert
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Question du sondage") {
                    TextField("Ex: Quel créneau préférez-vous ?", text: $question)
                }
                Section("Options de vote") {
                    TextField("Option 1", text: $opt1)
                    TextField("Option 2", text: $opt2)
                    TextField("Option 3 (optionnelle)", text: $opt3)
                }
            }
            .navigationTitle("Sondage #viplesondage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insérer") {
                        let opts = [opt1, opt2, opt3].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                        let q = question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Votre avis ?" : question
                        onInsert(BetaMailPollParser.buildTag(question: q, options: opts))
                        dismiss()
                    }
                }
            }
        }
    }
}

public struct BetaSignaturesManagerSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public var onPickSignature: ((String) -> Void)? = nil

    @State private var label: String = ""
    @State private var content: String = ""

    public init(onPickSignature: ((String) -> Void)? = nil) {
        self.onPickSignature = onPickSignature
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Profils de signatures disponibles") {
                    ForEach(beta.signatureProfiles) { sig in
                        Button {
                            beta.selectedSignatureProfileId = sig.id
                            beta.saveState()
                            onPickSignature?(sig.content)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sig.label).font(.system(size: 14, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                    Text(sig.content).font(.system(size: 12)).foregroundStyle(VipleMailPalette.inkSecondary).lineLimit(2)
                                }
                                Spacer()
                                if beta.selectedSignatureProfileId == sig.id {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(VipleMailPalette.primary)
                                }
                            }
                        }
                    }
                    .onDelete { offsets in
                        beta.signatureProfiles.remove(atOffsets: offsets)
                        beta.saveState()
                    }
                }
                Section("Nouvelle signature contextuelle") {
                    TextField("Nom (ex: Signature Anglais)", text: $label)
                    TextEditor(text: $content).frame(minHeight: 70)
                    Button("Ajouter la signature") {
                        beta.signatureProfiles.append(BetaSignatureProfile(id: UUID().uuidString, label: label, content: content))
                        beta.saveState()
                        label = ""; content = ""
                    }
                    .disabled(label.isEmpty || content.isEmpty)
                }
            }
            .navigationTitle("Multi-Signatures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaPhotoCompressorSanitizerSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss
    public var onUploaded: ((VipleMailAttachment) -> Void)? = nil

    @State private var pickerItem: PhotosPickerItem? = nil
    #if canImport(UIKit)
    @State private var originalImage: UIImage? = nil
    #endif
    @State private var originalSizeBytes: Int = 0
    @State private var qualityPreset: Int = 1 // 0: Eco, 1: Standard, 2: HD
    @State private var redactBottomBanner: Bool = false
    @State private var isUploading: Bool = false

    public init(onUploaded: ((VipleMailAttachment) -> Void)? = nil) {
        self.onUploaded = onUploaded
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("1. Sélectionner une photo") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Choisir une image dans Photos", systemImage: "photo.on.rectangle")
                    }
                }
                #if canImport(UIKit)
                if let img = originalImage {
                    Section("2. Compression & Purge GPS EXIF") {
                        Picker("Profil", selection: $qualityPreset) {
                            Text("Éco (640px)").tag(0)
                            Text("Standard (1280px)").tag(1)
                            Text("HD (1920px)").tag(2)
                        }
                        .pickerStyle(.segmented)
                        Toggle("Masquer le bandeau inférieur (caviardage)", isOn: $redactBottomBanner)

                        let sanitized = renderSanitizedJpeg(img)
                        Text("Taille d'origine : \(ByteCountFormatter.string(fromByteCount: Int64(originalSizeBytes), countStyle: .file)) → Optimisée sans EXIF : \(ByteCountFormatter.string(fromByteCount: Int64(sanitized.count), countStyle: .file))")
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.success)

                        Button {
                            Task {
                                isUploading = true
                                if let att = await vm.uploadAttachment(
                                    fileName: "photo_sanitized_\(Int(Date().timeIntervalSince1970)).jpg",
                                    mimeType: "image/jpeg",
                                    data: sanitized
                                ) {
                                    onUploaded?(att)
                                    dismiss()
                                }
                                isUploading = false
                            }
                        } label: {
                            if isUploading { ProgressView() } else { Text("Joindre l'image assainie au courrier").fontWeight(.bold) }
                        }
                        .disabled(isUploading)
                    }
                }
                #endif
            }
            .navigationTitle("Studio Photo & Purge EXIF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self) {
                        originalSizeBytes = d.count
                        #if canImport(UIKit)
                        originalImage = UIImage(data: d)
                        #endif
                    }
                }
            }
        }
    }

    #if canImport(UIKit)
    private func renderSanitizedJpeg(_ source: UIImage) -> Data {
        let maxDim: CGFloat = qualityPreset == 0 ? 640 : (qualityPreset == 1 ? 1280 : 1920)
        let quality: CGFloat = qualityPreset == 0 ? 0.48 : (qualityPreset == 1 ? 0.68 : 0.82)
        let scale = min(1.0, maxDim / max(source.size.width, source.size.height))
        let targetSize = CGSize(width: max(1, source.size.width * scale), height: max(1, source.size.height * scale))

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let cleanImage = renderer.image { ctx in
            source.draw(in: CGRect(origin: .zero, size: targetSize))
            if redactBottomBanner {
                UIColor.black.setFill()
                ctx.fill(CGRect(x: 0, y: targetSize.height * 0.82, width: targetSize.width, height: targetSize.height * 0.18))
            }
        }
        return cleanImage.jpegData(compressionQuality: quality) ?? Data()
    }
    #endif
}

public struct BetaVisionOcrScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    public var onRecognized: (String) -> Void

    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var extractedText: String = ""
    @State private var isScanning: Bool = false

    public init(onRecognized: @escaping (String) -> Void) {
        self.onRecognized = onRecognized
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Scanner un document ou une photo (Apple Vision OCR)") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Sélectionner une photo de document", systemImage: "doc.viewfinder.fill")
                    }
                    if isScanning {
                        HStack { ProgressView(); Text("Reconnaissance optique en cours…") }
                    }
                }
                if !extractedText.isEmpty {
                    Section("Texte reconnu (modifiable)") {
                        TextEditor(text: $extractedText).frame(minHeight: 160)
                        Button("Insérer ce texte") {
                            onRecognized(extractedText)
                            dismiss()
                        }
                        .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("Scanner OCR Vision")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    isScanning = true
                    let recognized = await Self.recognizeTextInImageData(data)
                    extractedText = recognized.isEmpty ? "Aucun texte imprimé détecté sur cette image." : recognized
                    isScanning = false
                }
            }
        }
    }

    public static func recognizeTextInImageData(_ data: Data) async -> String {
        #if canImport(UIKit)
        guard let uiImg = UIImage(data: data), let cgImg = uiImg.cgImage else { return "" }
        return await Task.detached(priority: .userInitiated) {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            req.recognitionLanguages = ["fr-FR", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImg, options: [:])
            try? handler.perform([req])
            let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
        #else
        return ""
        #endif
    }
}

public struct BetaMailMergeAssistantSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEmails: Set<String> = []
    @State private var subjectTemplate: String
    @State private var bodyTemplate: String
    public let fromMailbox: String
    @State private var isSendingBatch: Bool = false
    @State private var sentCount: Int = 0

    public init(initialSubject: String = "", initialBody: String = "", fromMailbox: String = "") {
        _subjectTemplate = State(initialValue: initialSubject.isEmpty ? "Information personnalisée — {{prenom}}" : initialSubject)
        _bodyTemplate = State(initialValue: initialBody.isEmpty ? "Bonjour {{prenom}},\n\nVoici votre point personnalisé du {{date}}.\n\nCordialement," : initialBody)
        self.fromMailbox = fromMailbox
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("1. Destinataires individuels (\(selectedEmails.count) sélectionné(s))") {
                    ForEach(vm.contacts) { c in
                        let sel = selectedEmails.contains(c.contactEmail)
                        Button {
                            if sel { selectedEmails.remove(c.contactEmail) } else { selectedEmails.insert(c.contactEmail) }
                        } label: {
                            HStack {
                                Image(systemName: sel ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(sel ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                                Text("\(c.displayName) (\(c.contactEmail))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(VipleMailPalette.ink)
                            }
                        }
                    }
                }
                Section("2. Modèle personnalisé ({{prenom}}, {{entreprise}})") {
                    TextField("Objet", text: $subjectTemplate)
                    TextEditor(text: $bodyTemplate).frame(minHeight: 100)
                }
                Section {
                    Button {
                        Task { await runMailMerge() }
                    } label: {
                        if isSendingBatch {
                            Text("Envoi individuel en cours (\(sentCount)/\(selectedEmails.count))…")
                        } else {
                            Text("Envoyer \(selectedEmails.count) courrier(s) individuel(s)")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(selectedEmails.isEmpty || isSendingBatch)
                }
            }
            .navigationTitle("Publipostage (Mail Merge)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }

    private func runMailMerge() async {
        isSendingBatch = true
        sentCount = 0
        let mbx = fromMailbox.isEmpty ? vm.defaultSendingMailbox : fromMailbox
        for email in selectedEmails {
            let subj = BetaComposerIntelligence.applyTemplateVariables(template: subjectTemplate, recipientEmail: email, contacts: vm.contacts, friends: vm.acceptedFriends)
            let body = BetaComposerIntelligence.applyTemplateVariables(template: bodyTemplate, recipientEmail: email, contacts: vm.contacts, friends: vm.acceptedFriends)
            _ = await vm.sendOrSaveMail(
                to: email,
                cc: "",
                bcc: "",
                subject: subj,
                bodyText: body,
                bodyHtml: nil,
                priority: "Normal",
                threadId: nil,
                replyToMessageId: nil,
                draftId: nil,
                isDraft: false,
                attachments: [],
                deliveryMode: "mail",
                fromMailbox: mbx
            )
            sentCount += 1
        }
        isSendingBatch = false
        vm.showToast("📬 Publipostage terminé : \(sentCount) courrier(s) personnalisé(s) envoyé(s)")
        dismiss()
    }
}

// MARK: - Lot 4 : Design, Thèmes Dynamiques, Motion 120 Hz & CoreHaptics (#031..#040)

@MainActor
public enum BetaChoreographedHaptics {
    public enum PatternKind {
        case sendCrystal
        case tapCrisp
        case vipPulse
    }

    #if canImport(UIKit)
    private static var engine: CHHapticEngine? = nil
    #endif

    public static func play(_ kind: PatternKind) {
        guard VipleBetaStore.shared.isEnabled(.f040) else { return }
        #if canImport(UIKit)
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        do {
            if engine == nil {
                engine = try CHHapticEngine()
                try engine?.start()
            }
            let events: [CHHapticEvent]
            switch kind {
            case .sendCrystal:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 0.65), .init(parameterID: .hapticSharpness, value: 0.8)], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 1.0), .init(parameterID: .hapticSharpness, value: 0.95)], relativeTime: 0.09)
                ]
            case .tapCrisp:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 0.55), .init(parameterID: .hapticSharpness, value: 0.9)], relativeTime: 0)
                ]
            case .vipPulse:
                events = [
                    CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 0.8), .init(parameterID: .hapticSharpness, value: 0.5)], relativeTime: 0),
                    CHHapticEvent(eventType: .hapticTransient, parameters: [.init(parameterID: .hapticIntensity, value: 0.8), .init(parameterID: .hapticSharpness, value: 0.7)], relativeTime: 0.14)
                ]
            }
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        #endif
    }
}

public struct BetaCircadianAuroraBackdropView: View {
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    public var body: some View {
        if beta.isEnabled(.f031) {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                Canvas { ctx, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    let hour = Calendar.current.component(.hour, from: timeline.date)
                    let palette: [Color]
                    if hour >= 5 && hour < 10 {
                        palette = [Color.orange.opacity(0.16), Color.pink.opacity(0.14), Color.cyan.opacity(0.12)]
                    } else if hour >= 10 && hour < 18 {
                        palette = [beta.selectedChromaticTheme.primaryColor.opacity(0.15), Color.cyan.opacity(0.13), Color.indigo.opacity(0.10)]
                    } else if hour >= 18 && hour < 22 {
                        palette = [Color.purple.opacity(0.16), Color.orange.opacity(0.13), Color.blue.opacity(0.12)]
                    } else {
                        palette = [Color.indigo.opacity(0.18), Color.teal.opacity(0.12), Color.blue.opacity(0.14)]
                    }

                    for i in 0..<palette.count {
                        let cx = size.width * CGFloat(0.25 + 0.5 * (0.5 + 0.5 * sin(t * 0.35 + Double(i) * 2.1)))
                        let cy = size.height * CGFloat(0.15 + 0.25 * cos(t * 0.28 + Double(i) * 1.7))
                        let r = max(size.width, size.height) * 0.48
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                            with: .radialGradient(Gradient(colors: [palette[i], .clear]), center: CGPoint(x: cx, y: cy), startRadius: 4, endRadius: r)
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
    }
}

public struct BetaCelebrationParticlesOverlay: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var burstStart: Date? = nil

    public init() {}

    public var body: some View {
        Group {
            if beta.isEnabled(.f033), let start = burstStart {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(start)
                    if elapsed < 1.6 {
                        Canvas { ctx, size in
                            let colors: [Color] = [.cyan, .yellow, .green, .pink, .orange, VipleMailPalette.primary]
                            for i in 0..<36 {
                                let angle = Double(i) * (2.0 * .pi / 36.0)
                                let speed = 130.0 + Double((i * 19) % 140)
                                let x = size.width * 0.5 + CGFloat(cos(angle) * speed * elapsed)
                                let y = size.height * 0.38 + CGFloat(sin(angle) * speed * elapsed + 190 * elapsed * elapsed)
                                let alpha = max(0, 1.0 - elapsed / 1.5)
                                let rect = CGRect(x: x - 4, y: y - 4, width: 8, height: 8)
                                ctx.fill(Path(ellipseIn: rect), with: .color(colors[i % colors.count].opacity(alpha)))
                            }
                        }
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                    }
                }
            }
        }
        .onChange(of: beta.activeParticleBurstTrigger) { _, _ in
            burstStart = Date()
        }
    }
}

public struct BetaFloatingRadialWheelOverlay: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var dragOffset: CGSize = .zero
    @State private var savedOffset: CGSize = .zero

    public init() {}

    public var body: some View {
        if beta.isEnabled(.f036) {
            ZStack(alignment: .bottomLeading) {
                if beta.isRadialWheelExpanded {
                    Color.black.opacity(0.28)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                beta.isRadialWheelExpanded = false
                            }
                        }
                }

                VStack(alignment: .leading, spacing: 10) {
                    if beta.isRadialWheelExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            radialActionBtn("Nouveau courrier", icon: "square.and.pencil", color: VipleMailPalette.primary) {
                                beta.isRadialWheelExpanded = false
                                vm.presentComposer(.newMail())
                            }
                            radialActionBtn("Palette universelle ⌘K", icon: "command", color: .indigo) {
                                beta.isRadialWheelExpanded = false
                                beta.presentedFeatureWorkspace = .f091
                            }
                            radialActionBtn("Triage Express", icon: "rectangle.stack.badge.checkmark", color: .teal) {
                                beta.isRadialWheelExpanded = false
                                beta.presentedFeatureWorkspace = .f002
                            }
                            radialActionBtn("Briefing Viple Pulse", icon: "sun.max.fill", color: .orange) {
                                beta.isRadialWheelExpanded = false
                                beta.presentedFeatureWorkspace = .f100
                            }
                            radialActionBtn("Fonctions Beta", icon: "flask.fill", color: .pink) {
                                beta.isRadialWheelExpanded = false
                                vm.selectedTab = 5
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            beta.isRadialWheelExpanded.toggle()
                        }
                        BetaChoreographedHaptics.play(.tapCrisp)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(beta.selectedChromaticTheme.primaryColor)
                                .frame(width: 46, height: 46)
                                .shadow(color: .black.opacity(0.28), radius: 8, y: 4)
                            Image(systemName: beta.isRadialWheelExpanded ? "xmark" : "circle.hexagongrid.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .offset(dragOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                dragOffset = CGSize(width: savedOffset.width + val.translation.width, height: savedOffset.height + val.translation.height)
                            }
                            .onEnded { _ in
                                savedOffset = dragOffset
                            }
                    )
                }
                .padding(.leading, 16)
                .padding(.bottom, 76)
            }
        }
    }

    private func radialActionBtn(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(color))
                Text(label)
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(VipleMailPalette.surface))
            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

public struct BetaAmberNightShieldOverlay: View {
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    public var body: some View {
        if beta.isEnabled(.f039) && beta.amberNightFilterIntensity > 0.01 {
            Color(red: 1.0, green: 0.58, blue: 0.12)
                .opacity(min(0.55, beta.amberNightFilterIntensity))
                .blendMode(.multiply)
                .allowsHitTesting(false)
                .ignoresSafeArea()
        }
    }
}

public struct BetaDesignStudioConfigView: View {
    @ObservedObject private var beta = VipleBetaStore.shared

    public init() {}

    public var body: some View {
        Form {
            Section("Palette Chromatique (#032)") {
                ForEach(BetaChromaticTheme.allCases) { theme in
                    Button {
                        beta.selectedChromaticTheme = theme
                        beta.saveState()
                    } label: {
                        HStack {
                            Circle().fill(theme.primaryColor).frame(width: 20, height: 20)
                            Text(theme.rawValue).foregroundStyle(VipleMailPalette.ink)
                            Spacer()
                            if beta.selectedChromaticTheme == theme {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.primaryColor)
                            }
                        }
                    }
                }
            }
            Section("Densité de la Boîte & Vignettes PJ (#034)") {
                Picker("Densité", selection: $beta.listDensityMode) {
                    ForEach(BetaListDensityMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: beta.listDensityMode) { _, _ in beta.saveState() }
            }
            Section("Transition Swipe entre Mails (#037)") {
                Picker("Style", selection: $beta.mailSwipeTransitionStyle) {
                    ForEach(BetaMailSwipeTransitionStyle.allCases) { st in
                        Text(st.rawValue).tag(st)
                    }
                }
                .onChange(of: beta.mailSwipeTransitionStyle) { _, _ in beta.saveState() }
            }
            Section("Confort Nocturne OLED & Filtre Ambre (#039)") {
                Toggle("Fond Noir Pur OLED en mode sombre", isOn: $beta.oledPureBlackEnabled)
                VStack(alignment: .leading) {
                    Text("Intensité Filtre Ambre : \(Int(beta.amberNightFilterIntensity * 100)) %")
                        .font(.system(size: 13, weight: .semibold))
                    Slider(value: $beta.amberNightFilterIntensity, in: 0...0.55)
                        .onChange(of: beta.amberNightFilterIntensity) { _, _ in beta.saveState() }
                }
            }
            Section("Testeur CoreHaptics & Particules (#033, #040)") {
                Button("Tester la signature haptique Envoi Cristallin") {
                    BetaChoreographedHaptics.play(.sendCrystal)
                }
                Button("Déclencher une célébration de particules 60 fps") {
                    beta.triggerCelebrationParticles()
                }
            }
        }
    }
}
