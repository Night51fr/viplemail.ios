import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(MessageUI)
import MessageUI
#endif

// MARK: - 1. Badge Temps Réel d'Expiration d'Accès Invité (Ticking 1s via TimelineView)

public struct GuestCountdownBadgeView: View {
    public let grant: GuestMailboxGrant
    public var compact: Bool = false
    public var filledStyle: Bool = false
    public var onExpired: (() -> Void)? = nil

    @State private var didNotifyExpiration: Bool = false

    public init(
        grant: GuestMailboxGrant,
        compact: Bool = false,
        filledStyle: Bool = false,
        onExpired: (() -> Void)? = nil
    ) {
        self.grant = grant
        self.compact = compact
        self.filledStyle = filledStyle
        self.onExpired = onExpired
    }

    private func badgeTint(for remainingSeconds: Int) -> Color {
        if remainingSeconds <= 900 { // <= 15 min
            return VipleMailPalette.danger
        }
        if remainingSeconds <= 3600 { // <= 1h
            return VipleMailPalette.warning
        }
        return VipleMailPalette.primary
    }

    public var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remSeconds = max(0, Int(floor(grant.remainingTimeInterval(at: context.date))))
            let label = grant.formattedCountdown(at: context.date, compact: compact)
            let tint = badgeTint(for: remSeconds)

            HStack(spacing: 4) {
                Image(systemName: remSeconds <= 900 ? "timer" : "clock.badge.checkmark.fill")
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .bold))
                Text(label)
                    .font(.system(size: compact ? 10.5 : 11.5, weight: .black, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(filledStyle ? Color.white : tint)
            .padding(.horizontal, compact ? 7 : 9)
            .padding(.vertical, compact ? 3 : 4.5)
            .background(
                Capsule()
                    .fill(filledStyle ? tint : tint.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(filledStyle ? Color.white.opacity(0.26) : tint.opacity(0.32), lineWidth: 0.9)
            )
            .onChange(of: remSeconds) { _, newValue in
                if newValue <= 0 && !didNotifyExpiration {
                    didNotifyExpiration = true
                    onExpired?()
                }
            }
            .onAppear {
                if remSeconds <= 0 && !didNotifyExpiration {
                    didNotifyExpiration = true
                    onExpired?()
                }
            }
        }
    }
}

// MARK: - 2. Ligne de Boîte Partagée avec Compte à Rebours dans la Liste des Boîtes Mail

public struct SharedGuestMailboxRowView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let grant: GuestMailboxGrant
    public let isActive: Bool
    public let onSelect: () -> Void

    public init(
        grant: GuestMailboxGrant,
        isActive: Bool,
        onSelect: @escaping () -> Void
    ) {
        self.grant = grant
        self.isActive = isActive
        self.onSelect = onSelect
    }

    public var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    VipleMailAvatarView(
                        name: grant.ownerDisplayName,
                        email: grant.ownerMailbox,
                        avatarUrl: grant.ownerAvatarUrl,
                        size: 40,
                        isVip: false
                    )

                    ZStack {
                        Circle()
                            .fill(VipleMailPalette.primarySolid)
                            .frame(width: 17, height: 17)
                        Image(systemName: "key.fill")
                            .font(.system(size: 8.5, weight: .black))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 3, y: 3)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(grant.ownerMailbox)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .lineLimit(1)

                        if isActive {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(VipleMailPalette.primary))
                        }
                    }

                    Text("Partagée par \(grant.ownerDisplayName) • \(grant.allowSend ? "Lecture & réponse" : "Lecture seule")")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                GuestCountdownBadgeView(grant: grant, compact: false) {
                    vm.pruneAndExitExpiredGuestMailboxes()
                }
            }
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(VipleMailPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(isActive ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.28), lineWidth: isActive ? 1.6 : 1.0)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 3. Bandeau Supérieur Actif & Barre Rapide de Boîtes Partagées (Boîte de Réception)

public struct ActiveGuestMailboxBannerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    public let grant: GuestMailboxGrant

    public init(grant: GuestMailboxGrant) {
        self.grant = grant
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "key.radiowaves.forward.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("ACCÈS INVITÉ TEMPORAIRE • \(grant.allowSend ? "LECTURE & ENVOI" : "LECTURE SEULE")")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)

                    Text("Boîte partagée de \(grant.ownerDisplayName) (\(grant.ownerMailbox))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                GuestCountdownBadgeView(grant: grant, compact: false, filledStyle: true) {
                    vm.pruneAndExitExpiredGuestMailboxes()
                }
            }

            HStack(spacing: 8) {
                if !vm.primaryHostedEmail.isEmpty {
                    Button {
                        Task {
                            await vm.switchActiveMailbox(to: vm.primaryHostedEmail)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Revenir à ma boîte (\(vm.primaryHostedEmail))")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(VipleMailPalette.primary.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(role: .destructive) {
                    Task {
                        _ = await vm.revokeGuestAccessGrant(grant.grantId)
                    }
                } label: {
                    Text("Fermer l'accès")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.danger)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(VipleMailPalette.danger.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VipleMailPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(VipleMailPalette.primary.opacity(0.34), lineWidth: 1.1)
        )
    }
}

public struct AvailableSharedMailboxesStripView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VipleMailPalette.primary)
                Text("BOÎTES PARTAGÉES AVEC VOUS (ACCÈS INVITÉ)")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                Spacer()
            }

            ForEach(vm.sharedGuestMailboxes) { grant in
                SharedGuestMailboxRowView(
                    grant: grant,
                    isActive: vm.isGuestMailboxActive && vm.currentEmail.lowercased() == grant.ownerMailbox.lowercased()
                ) {
                    Task {
                        await vm.switchActiveMailbox(to: grant.ownerMailbox)
                    }
                }
            }
        }
    }
}

// MARK: - 4. Feuille Native Apple iMessage (MFMessageComposeViewController + Fallback Universel)

#if canImport(MessageUI) && canImport(UIKit)
@MainActor
private struct NativeMFMessageComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String
    let onFinish: () -> Void

    @MainActor
    final class Coordinator: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true) { [onFinish] in
                onFinish()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.messageComposeDelegate = context.coordinator
        if !recipients.isEmpty {
            vc.recipients = recipients
        }
        vc.body = body
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}
}
#endif

public struct VipleIMessagePresenterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var vm: VipleMailViewModel
    public let payload: IMessageComposePayload

    @State private var copiedLink: Bool = false

    public init(payload: IMessageComposePayload) {
        self.payload = payload
    }

    private var canUseNativeMessageComposer: Bool {
        #if canImport(MessageUI) && canImport(UIKit)
        return MFMessageComposeViewController.canSendText()
        #else
        return false
        #endif
    }

    public var body: some View {
        #if canImport(MessageUI) && canImport(UIKit)
        if canUseNativeMessageComposer {
            NativeMFMessageComposeView(
                recipients: payload.recipients,
                body: payload.body
            ) {
                dismiss()
            }
            .ignoresSafeArea()
        } else {
            fallbackIMessageCardSheet
        }
        #else
        fallbackIMessageCardSheet
        #endif
    }

    private var fallbackIMessageCardSheet: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.16, green: 0.78, blue: 0.36), Color(red: 0.04, green: 0.52, blue: 0.99)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 52, height: 52)
                            Image(systemName: "message.badge.filled.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Viple Mail × iMessage")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(VipleMailPalette.ink)
                            Text("Aperçu de la bulle iMessage prête à envoyer")
                                .font(.system(size: 13))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                        }
                        Spacer()
                    }

                    // Aperçu style bulle bleue iMessage
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(payload.body)
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                            )
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        Text("iMessage • Redirection directe vers Viple Mail")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(VipleMailPalette.surfaceSubtle)
                    )

                    VStack(spacing: 10) {
                        Button {
                            openMessagesURLScheme()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                Text("Ouvrir dans Messages (iMessage)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                            )
                        }

                        ShareLink(item: payload.body) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Partager via la feuille iOS…")
                                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(VipleMailPalette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VipleMailPalette.primary.opacity(0.12))
                            )
                        }

                        Button {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = payload.shareUrl ?? payload.body
                            #endif
                            copiedLink = true
                            vm.showToast("Lien direct compatible iMessage copié !")
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: copiedLink ? "checkmark.circle.fill" : "doc.on.doc")
                                Text(copiedLink ? "Lien direct copié !" : "Copier le lien direct")
                                    .font(.system(size: 14.5, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(VipleMailPalette.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(VipleMailPalette.surfaceSubtle)
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(VipleMailPalette.background)
            .navigationTitle("Envoyer par iMessage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func openMessagesURLScheme() {
        #if canImport(UIKit)
        let rcpt = payload.recipients.first ?? ""
        let encodedBody = payload.body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let raw = rcpt.isEmpty ? "sms:&body=\(encodedBody)" : "sms:\(rcpt)&body=\(encodedBody)"
        if let url = URL(string: raw) {
            UIApplication.shared.open(url)
        }
        #endif
        dismiss()
    }
}

// MARK: - 5. Studio de Gestion des Accès Invités Temporaires (1h, 8h, 24h, 48h) & iMessage

public struct GuestMailboxAccessManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var vm: VipleMailViewModel

    @State private var selectedMailbox: String = ""
    @State private var selectedDuration: GuestMailboxDuration = .eightHours
    @State private var guestEmailInput: String = ""
    @State private var allowGuestToSend: Bool = false
    @State private var labelNoteInput: String = ""
    @State private var latestCreatedResponse: GuestMailboxCreateResponse? = nil

    public init() {}

    private var effectiveOwnerMailbox: String {
        if !selectedMailbox.isEmpty {
            return selectedMailbox
        }
        return vm.hostedMailboxes.first ?? vm.primaryHostedEmail
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    heroHeaderCard
                    createGrantCard

                    if let created = latestCreatedResponse, let grant = created.grant {
                        latestInviteReadyCard(grant: grant, imessageText: created.imessageText)
                    }

                    if !vm.sharedGuestMailboxes.isEmpty {
                        incomingSharedMailboxesCard
                    }

                    outgoingGrantsCard
                }
                .padding(16)
            }
            .background(VipleMailPalette.background)
            .navigationTitle("Accès Invité & iMessage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                selectedMailbox = vm.hostedMailboxes.first(where: { $0.lowercased() == vm.currentEmail.lowercased() })
                    ?? vm.hostedMailboxes.first
                    ?? vm.primaryHostedEmail
                Task {
                    await vm.refreshGuestAccessGrants(silent: true)
                }
            }
        }
    }

    private var heroHeaderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: "key.radiowaves.forward.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Accès Invité Temporaire")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Partagez votre boîte mail pendant 1h, 8h, 24h ou 48h")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.90))
                }
                Spacer()
            }

            Text("Votre invité voit apparaître votre boîte dans sa liste de boîtes Viple Mail avec un badge affichant le temps restant en direct, puis l'accès disparaît automatiquement à expiration.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.88))
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(VipleMailPalette.heroGradient)
                .shadow(color: VipleMailPalette.primary.opacity(0.30), radius: 14, x: 0, y: 6)
        )
    }

    private var createGrantCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Accorder un nouvel accès temporaire", systemImage: "clock.badge.plus.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            if vm.hostedMailboxes.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BOÎTE À PARTAGER")
                        .font(.system(size: 10.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.inkMuted)

                    Menu {
                        ForEach(vm.hostedMailboxes, id: \.self) { mbx in
                            Button {
                                selectedMailbox = mbx
                            } label: {
                                Label(
                                    mbx,
                                    systemImage: mbx.lowercased() == effectiveOwnerMailbox.lowercased() ? "checkmark.circle.fill" : "envelope.fill"
                                )
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "envelope.badge.shield.half.filled.fill")
                                .foregroundStyle(VipleMailPalette.primary)
                            Text(effectiveOwnerMailbox)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(VipleMailPalette.ink)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VipleMailPalette.surfaceSubtle))
                    }
                }
            }

            // Sélecteur de durée 1h / 8h / 24h / 48h
            VStack(alignment: .leading, spacing: 8) {
                Text("DURÉE DE L'ACCÈS INVITÉ")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkMuted)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(GuestMailboxDuration.allCases) { dur in
                        let selected = selectedDuration == dur
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                selectedDuration = dur
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: dur.iconName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(selected ? .white : VipleMailPalette.primary)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(dur.title)
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundStyle(selected ? .white : VipleMailPalette.ink)
                                    Text(dur.subtitle)
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(selected ? .white.opacity(0.86) : VipleMailPalette.inkMuted)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(11)
                            .background(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(VipleMailPalette.heroGradient) : AnyShapeStyle(VipleMailPalette.surfaceSubtle))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(selected ? Color.clear : VipleMailPalette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Destinataire optionnel (ou lien iMessage direct)
            VStack(alignment: .leading, spacing: 6) {
                Text("INVITÉ (ADRESSE VIPLE MAIL OU LIEN iMESSAGE)")
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.inkMuted)

                HStack(spacing: 8) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField(
                        "Optionnel : contact@viplemail.fr (sinon lien iMessage)",
                        text: $guestEmailInput,
                        prompt: VipleMailPalette.prompt("Optionnel : contact@viplemail.fr", scheme: colorScheme)
                    )
                    .font(.system(size: 14))
                    .vipleMailTextInput()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                    if !guestEmailInput.isEmpty {
                        Button {
                            guestEmailInput = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(VipleMailPalette.surfaceSubtle))

                if !vm.contacts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(vm.contacts.prefix(8)) { c in
                                Button {
                                    guestEmailInput = c.contactEmail
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: c.isFavorite ? "crown.fill" : "person.crop.circle")
                                            .font(.system(size: 10.5))
                                        Text(c.displayName.isEmpty ? c.contactEmail : c.displayName)
                                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(VipleMailPalette.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.10)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Toggle(isOn: $allowGuestToSend) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autoriser l'invité à répondre / envoyer")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text(allowGuestToSend ? "L'invité peut lire et répondre (suppression bloquée)" : "Lecture seule sécurisée (recommandé)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }
            .tint(VipleMailPalette.primary)

            HStack(spacing: 10) {
                Button {
                    Task {
                        if let created = await vm.createGuestAccessGrant(
                            mailbox: effectiveOwnerMailbox,
                            durationHours: selectedDuration.rawValue,
                            guestEmail: guestEmailInput,
                            allowSend: allowGuestToSend,
                            labelNote: labelNoteInput
                        ) {
                            latestCreatedResponse = created
                            if let grant = created.grant {
                                let text = created.imessageText ?? "🔑 Je te partage un accès invité temporaire (\(grant.durationHours)h) à ma boîte \(grant.ownerMailbox) sur Viple Mail :\n\(grant.inviteUrl)"
                                let rcpts = vm.preferredIMessageRecipients(for: guestEmailInput)
                                dismiss()
                                try? await Task.sleep(nanoseconds: 280_000_000)
                                vm.presentIMessageComposer(
                                    recipients: rcpts,
                                    body: text,
                                    shareUrl: grant.inviteUrl,
                                    subjectLabel: "Accès invité \(grant.durationHours)h"
                                )
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isProcessingGuestAction {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "message.badge.filled.fill")
                                .font(.system(size: 15, weight: .bold))
                        }
                        Text("Activer (\(selectedDuration.shortLabel)) & Envoyer par iMessage")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(VipleMailPalette.heroGradient)
                    )
                }
                .disabled(vm.isProcessingGuestAction)
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func latestInviteReadyCard(grant: GuestMailboxGrant, imessageText: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Lien d'accès invité actif (\(grant.durationHours)h)", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.success)
                Spacer()
                GuestCountdownBadgeView(grant: grant, compact: true)
            }

            Text(grant.inviteUrl)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = grant.inviteUrl
                    #endif
                    vm.showToast("Lien d'accès invité copié !")
                } label: {
                    Label("Copier", systemImage: "doc.on.doc")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }

                ShareLink(item: imessageText ?? grant.inviteUrl) {
                    Label("Partager…", systemImage: "square.and.arrow.up")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }

    private var incomingSharedMailboxesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BOÎTES PARTAGÉES AVEC MOI")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)

            ForEach(vm.sharedGuestMailboxes) { grant in
                SharedGuestMailboxRowView(
                    grant: grant,
                    isActive: vm.isGuestMailboxActive && vm.currentEmail.lowercased() == grant.ownerMailbox.lowercased()
                ) {
                    dismiss()
                    Task {
                        vm.selectedTab = 0
                        await vm.switchActiveMailbox(to: grant.ownerMailbox)
                    }
                }
            }
        }
    }

    private var outgoingGrantsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACCÈS INVITÉS ACTIFS SUR MES BOÎTES")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)

            if vm.outgoingGuestGrants.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(VipleMailPalette.success)
                    Text("Aucun accès invité temporaire n'est actuellement actif sur vos boîtes mail.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    Spacer()
                }
                .vipleMailCard(cornerRadius: 16, padding: 14)
            } else {
                ForEach(vm.outgoingGuestGrants) { grant in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grant.guestEmail ?? "Invitation par lien iMessage")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.ink)
                                Text("Boîte : \(grant.ownerMailbox) • \(grant.allowSend ? "Lecture & envoi" : "Lecture seule")")
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(VipleMailPalette.inkSecondary)
                            }
                            Spacer()
                            GuestCountdownBadgeView(grant: grant, compact: false) {
                                vm.pruneAndExitExpiredGuestMailboxes()
                            }
                        }

                        HStack(spacing: 8) {
                            Button {
                                let msg = "🔑 Accès invité temporaire (\(grant.durationHours)h) à ma boîte \(grant.ownerMailbox) sur Viple Mail :\n\(grant.inviteUrl)"
                                dismiss()
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 250_000_000)
                                    vm.presentIMessageComposer(
                                        recipients: vm.preferredIMessageRecipients(for: grant.guestEmail ?? ""),
                                        body: msg,
                                        shareUrl: grant.inviteUrl
                                    )
                                }
                            } label: {
                                Label("Renvoyer par iMessage", systemImage: "message.fill")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.primary)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(role: .destructive) {
                                Task {
                                    _ = await vm.revokeGuestAccessGrant(grant.grantId)
                                }
                            } label: {
                                Label("Révoquer", systemImage: "xmark.shield.fill")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(VipleMailPalette.danger)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(VipleMailPalette.danger.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .vipleMailCard(cornerRadius: 16, padding: 13)
                }
            }
        }
    }
}
