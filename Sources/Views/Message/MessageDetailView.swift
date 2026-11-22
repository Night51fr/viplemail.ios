import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

// MARK: - Lecture de Courrier Classique « Viple Mail » (Style Apple Mail / Client Mail Traditionnel — Zéro Bulle de Chat)

#if canImport(WebKit) && canImport(UIKit)
private struct VipleMailHTMLWebView: UIViewRepresentable {
    let htmlBody: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.isScrollEnabled = false
        wv.navigationDelegate = context.coordinator
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let wrapped = """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          html, body { margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', sans-serif; font-size: 15.5px; line-height: 1.58; color: #0f172a; word-wrap: break-word; overflow-wrap: anywhere; background: transparent; }
          img { max-width: 100% !important; height: auto !important; border-radius: 6px; }
          table { max-width: 100% !important; }
          blockquote { margin: 12px 0; padding-left: 12px; border-left: 2.5px solid #cbd5e1; color: #475569; }
          a { color: #0078D4; }
        </style>
        </head>
        <body>\(htmlBody)</body>
        </html>
        """
        if context.coordinator.lastLoadedHTML != wrapped {
            context.coordinator.lastLoadedHTML = wrapped
            uiView.loadHTMLString(wrapped, baseURL: URL(string: "https://mail.viplemail.fr"))
        }
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: VipleMailHTMLWebView
        var lastLoadedHTML: String = ""

        init(_ parent: VipleMailHTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor [weak self, weak webView] in
                guard let self, let webView else { return }
                if let result = try? await webView.evaluateJavaScript("document.documentElement.scrollHeight") {
                    if let num = result as? NSNumber {
                        let h = CGFloat(truncating: num)
                        if h > 0 {
                            self.parent.dynamicHeight = max(120, h + 16)
                        }
                    } else if let h = result as? CGFloat, h > 0 {
                        self.parent.dynamicHeight = max(120, h + 16)
                    }
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}
#endif

public struct MessageDetailView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let message: VipleMailMessage

    @State private var showFullHeaders: Bool = false
    @State private var showPreviousThreadEmails: Bool = false
    @State private var isShowingMoveFolderSheet: Bool = false
    @State private var htmlContentHeight: CGFloat = 220

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var currentMessage: VipleMailMessage {
        vm.messages.first(where: { $0.id == message.id }) ?? message
    }

    private var previousEmailsInThread: [VipleMailMessage] {
        vm.activeThreadMessages.filter { $0.id != currentMessage.id }
    }

    private var recipientSummaryLabel: String {
        let rcpt = currentMessage.recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if rcpt.isEmpty { return "À : moi" }
        if rcpt.lowercased() == vm.currentEmail.lowercased() {
            return "À : moi"
        }
        return "À : \(rcpt)"
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    classicSenderHeaderSection

                    Divider()
                        .padding(.leading, 16)

                    classicSubjectHeaderSection

                    if !currentMessage.attachments.isEmpty {
                        Divider()
                            .padding(.leading, 16)
                        classicAttachmentsSection(currentMessage.attachments)
                    }

                    Divider()

                    classicEmailBodySection(currentMessage)

                    if !previousEmailsInThread.isEmpty {
                        Divider()
                            .padding(.top, 12)
                        classicQuotedThreadSection
                    }
                }
                .background(VipleMailPalette.surface)
            }
            .background(VipleMailPalette.surface)

            classicMailBottomToolbar
        }
        .background(VipleMailPalette.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    vm.closeMessage()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .semibold))
                        Text(vm.activeFolderTitle)
                            .font(.system(size: 15.5, weight: .regular))
                            .lineLimit(1)
                    }
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    Task {
                        await vm.performMessageAction(
                            messageIds: [currentMessage.id],
                            action: "toggle_read",
                            toast: "Marqué comme non lu"
                        )
                        vm.closeMessage()
                    }
                } label: {
                    Image(systemName: "envelope.badge")
                }
                .accessibilityLabel("Marquer comme non lu")

                Menu {
                    Button {
                        vm.presentComposer(.reply(currentMessage))
                    } label: {
                        Label("Répondre", systemImage: "arrowshape.turn.up.left")
                    }

                    Button {
                        vm.presentComposer(.replyAll(currentMessage))
                    } label: {
                        Label("Répondre à tous", systemImage: "arrowshape.turn.up.left.2")
                    }

                    Button {
                        vm.presentComposer(.forward(currentMessage))
                    } label: {
                        Label("Transférer", systemImage: "arrowshape.turn.up.right")
                    }

                    Divider()

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "toggle_star",
                                toast: currentMessage.isStarred ? "Retiré des favoris" : "Ajouté aux favoris"
                            )
                        }
                    } label: {
                        Label(
                            currentMessage.isStarred ? "Retirer le drapeau" : "Ajouter un drapeau",
                            systemImage: currentMessage.isStarred ? "flag.slash" : "flag"
                        )
                    }

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "toggle_pin",
                                toast: currentMessage.isPinned ? "Courrier désépinglé" : "Courrier épinglé"
                            )
                        }
                    } label: {
                        Label(
                            currentMessage.isPinned ? "Désépingler" : "Épingler en haut",
                            systemImage: currentMessage.isPinned ? "pin.slash" : "pin"
                        )
                    }

                    Button {
                        isShowingMoveFolderSheet = true
                    } label: {
                        Label("Déplacer vers un dossier…", systemImage: "folder")
                    }

                    Button {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "spam",
                                toast: "Déplacé dans Indésirables"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        Label("Déplacer dans Indésirables", systemImage: "exclamationmark.shield")
                    }

                    Divider()

                    Button(role: .destructive) {
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "trash",
                                toast: "Déplacé dans la Corbeille"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        Label("Supprimer le courrier", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isShowingMoveFolderSheet) {
            moveToFolderPickerSheet
        }
        .gesture(
            DragGesture(minimumDistance: 24, coordinateSpace: .local)
                .onEnded { value in
                    if value.startLocation.x < 44 && value.translation.width > 70 && abs(value.translation.height) < 90 {
                        vm.closeMessage()
                    }
                }
        )
        .task {
            await vm.openMessageAndLoadThread(message)
        }
    }

    // MARK: - 1. En-tête Expéditeur / Destinataire Style Apple Mail

    private var classicSenderHeaderSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VipleMailAvatarView(
                    name: currentMessage.senderName,
                    email: currentMessage.senderEmail,
                    avatarUrl: vm.resolveAvatarUrl(for: currentMessage.senderEmail, explicitUrl: currentMessage.senderAvatarUrl),
                    size: 42,
                    isVip: currentMessage.isVipSender
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(currentMessage.senderName.isEmpty ? currentMessage.senderEmail : currentMessage.senderName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)

                        if currentMessage.isVipSender {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(VipleMailPalette.vipGold)
                        }

                        Spacer(minLength: 6)

                        Text(currentMessage.formattedRelativeDate)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }

                    HStack(alignment: .center, spacing: 6) {
                        Text(recipientSummaryLabel)
                            .font(.system(size: 13.5))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineLimit(1)

                        if !currentMessage.ccEmail.isEmpty {
                            Text("• Cc")
                                .font(.system(size: 12.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }

                        Spacer(minLength: 6)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showFullHeaders.toggle()
                            }
                        } label: {
                            Text(showFullHeaders ? "Masquer" : "Détails")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                }
            }

            if showFullHeaders {
                VStack(alignment: .leading, spacing: 6) {
                    rfcHeaderRow(label: "De :", value: "\(currentMessage.senderName) <\(currentMessage.senderEmail)>")
                    rfcHeaderRow(label: "À :", value: currentMessage.recipientEmail)
                    if !currentMessage.ccEmail.isEmpty {
                        rfcHeaderRow(label: "Cc :", value: currentMessage.ccEmail)
                    }
                    rfcHeaderRow(label: "Date :", value: currentMessage.formattedFullDate)
                    rfcHeaderRow(label: "Dossier :", value: "\(currentMessage.folder) • \(currentMessage.formattedSize)")
                    rfcHeaderRow(label: "Sécurité :", value: "TLS chiffré • DKIM vérifié (imap.viplemail.fr)")
                }
                .font(.system(size: 12.5))
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle.opacity(0.75))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func rfcHeaderRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .foregroundStyle(VipleMailPalette.inkMuted)
                .frame(width: 68, alignment: .trailing)
            Text(value)
                .foregroundStyle(VipleMailPalette.ink)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 2. Ligne Objet Classique + Drapeau / Priorité

    private var classicSubjectHeaderSection: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentMessage.subject)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VipleMailPalette.ink)
                    .textSelection(.enabled)

                if currentMessage.isHighPriority || currentMessage.folder.lowercased() != "inbox" {
                    HStack(spacing: 8) {
                        if currentMessage.isHighPriority {
                            Label("Importance haute", systemImage: "exclamationmark.circle.fill")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.danger)
                        }
                        if currentMessage.folder.lowercased() != "inbox" {
                            Text(currentMessage.folder)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(VipleMailPalette.surfaceSubtle)
                                )
                        }
                    }
                }
            }

            Spacer(minLength: 6)

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "toggle_star",
                        toast: currentMessage.isStarred ? "Drapeau retiré" : "Drapeau ajouté"
                    )
                }
            } label: {
                Image(systemName: currentMessage.isStarred ? "flag.fill" : "flag")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(currentMessage.isStarred ? Color.orange : VipleMailPalette.inkMuted)
                    .padding(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - 3. Bandeau Pièces Jointes Classique

    private func classicAttachmentsSection(_ list: [VipleMailAttachment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(list) { att in
                HStack(spacing: 10) {
                    Image(systemName: att.iconName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VipleMailPalette.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(VipleMailPalette.primary.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(att.fileName)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)
                        Text(att.formattedSize)
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }

                    Spacer()

                    if let url = URL(string: att.url), !att.url.isEmpty {
                        Link(destination: url) {
                            Label("Ouvrir", systemImage: "arrow.down.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(VipleMailPalette.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - 4. Corps du Courrier Pleine Largeur (Zéro Carte / Zéro Bulle)

    private func hasRichHTML(_ raw: String) -> Bool {
        let lower = raw.lowercased()
        return lower.contains("<div") || lower.contains("<table") || lower.contains("<p") || lower.contains("<img") || lower.contains("<a ") || lower.contains("<ul") || lower.contains("<blockquote") || lower.contains("<h1") || lower.contains("<h2") || lower.contains("<style")
    }

    private func classicEmailBodySection(_ msg: VipleMailMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            #if canImport(WebKit) && canImport(UIKit)
            if hasRichHTML(msg.bodyHtml) {
                VipleMailHTMLWebView(htmlBody: msg.bodyHtml, dynamicHeight: $htmlContentHeight)
                    .frame(height: htmlContentHeight)
            } else {
                Text(msg.plainBodyText)
                    .font(.system(size: 15.5))
                    .foregroundStyle(VipleMailPalette.ink)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            #else
            Text(msg.plainBodyText)
                .font(.system(size: 15.5))
                .foregroundStyle(VipleMailPalette.ink)
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
    }

    // MARK: - 5. Historique Replié des Courriers Précédents (Style Citations Mail)

    private var classicQuotedThreadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPreviousThreadEmails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: showPreviousThreadEmails ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                    Text("\(previousEmailsInThread.count) courrier(s) précédent(s) dans cet objet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(VipleMailPalette.surfaceSubtle.opacity(0.55))
            }
            .buttonStyle(.plain)

            if showPreviousThreadEmails {
                ForEach(previousEmailsInThread) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        HStack {
                            Text("De : \(item.senderName) <\(item.senderEmail)>")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.formattedFullDate)
                                .font(.system(size: 11.5))
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                        Text(item.plainBodyText)
                            .font(.system(size: 14))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                            .lineSpacing(4)
                            .padding(.leading, 10)
                            .overlay(alignment: .leading) {
                                Rectangle()
                                    .fill(VipleMailPalette.border)
                                    .frame(width: 2.5)
                            }
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - 6. Barre d'Actions Inférieure Classique Style Apple Mail

    private var classicMailBottomToolbar: some View {
        HStack {
            Button(role: .destructive) {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "trash",
                        toast: "Déplacé dans la Corbeille"
                    )
                    vm.closeMessage()
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Supprimer")

            Spacer()

            Button {
                Task {
                    await vm.performMessageAction(
                        messageIds: [currentMessage.id],
                        action: "archive",
                        toast: "Courrier archivé"
                    )
                    vm.closeMessage()
                }
            } label: {
                Image(systemName: "archivebox")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Archiver")

            Spacer()

            Button {
                isShowingMoveFolderSheet = true
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Déplacer vers un dossier")

            Spacer()

            Menu {
                Button {
                    // Répond toujours en mode Mail classique (même si l'expéditeur est @viplemail.fr)
                    vm.presentComposer(.reply(currentMessage))
                } label: {
                    Label("Répondre", systemImage: "arrowshape.turn.up.left")
                }

                Button {
                    vm.presentComposer(.replyAll(currentMessage))
                } label: {
                    Label("Répondre à tous", systemImage: "arrowshape.turn.up.left.2")
                }

                Button {
                    vm.presentComposer(.forward(currentMessage))
                } label: {
                    Label("Transférer", systemImage: "arrowshape.turn.up.right")
                }
            } label: {
                Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Répondre ou transférer")

            Spacer()

            Button {
                vm.presentComposer(.newMail())
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(width: 44, height: 38)
            }
            .accessibilityLabel("Nouveau message")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(
            VipleMailPalette.surfaceSubtle.opacity(0.92)
                .overlay(alignment: .top) {
                    Divider()
                }
        )
    }

    private var moveToFolderPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(vm.folders.filter { $0.id != "Starred" && $0.id != "Flagged" && $0.id != "Unread" && $0.id != "VIP" }) { folder in
                    Button {
                        isShowingMoveFolderSheet = false
                        Task {
                            await vm.performMessageAction(
                                messageIds: [currentMessage.id],
                                action: "move",
                                targetFolder: folder.id,
                                toast: "Déplacé vers \(folder.name)"
                            )
                            vm.closeMessage()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: folder.icon)
                                .foregroundStyle(VipleMailPalette.colorFromHex(folder.colorHex))
                                .frame(width: 28)
                            Text(folder.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VipleMailPalette.ink)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Déplacer vers…")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isShowingMoveFolderSheet = false
                    }
                }
            }
        }
    }
}
