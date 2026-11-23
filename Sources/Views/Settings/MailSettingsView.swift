import SwiftUI

// MARK: - Réglages & Compte Viple Live ID « Viple Mail » (Signature, Gestes de Balayage, Répondeur Automatique, Diagnostics & Déconnexion)

public struct MailSettingsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var notifManager = VipleMailNotificationManager.shared

    @State private var displayNameField: String = ""
    @State private var personalMessageField: String = ""
    @State private var newImapPasswordField: String = ""
    @State private var cenelisCustomHandleField: String = ""
    @State private var isEditingCenelisHandle: Bool = false
    @State private var accountPendingDeletion: ExternalMailAccount? = nil

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                accountProfileCard
                if vm.isApprovedCenelisAgent {
                    cenelisAgentMailboxCard
                }
                appearanceCustomizationCard
                externalAccountsCard
                notificationsControlCard
                officialMailServersCard
                inboxAndSwipeCustomizationCard
                signatureCard
                vacationResponderCard
                diagnosticsAndSignOutCard
            }
            .padding(16)
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .alert(
            "Retirer cette boîte externe ?",
            isPresented: Binding(
                get: { accountPendingDeletion != nil },
                set: { if !$0 { accountPendingDeletion = nil } }
            ),
            presenting: accountPendingDeletion
        ) { acc in
            Button("Retirer de Viple Mail", role: .destructive) {
                accountPendingDeletion = nil
                Task {
                    await vm.removeExternalAccount(acc)
                }
            }
            Button("Annuler", role: .cancel) {
                accountPendingDeletion = nil
            }
        } message: { acc in
            Text("L'adresse \(acc.email) ne sera plus affichée dans Viple Mail. Aucun e-mail ne sera supprimé sur le serveur \(acc.providerName).")
        }
        .onAppear {
            displayNameField = vm.currentUser?.displayName ?? ""
            personalMessageField = vm.currentUser?.personalMessage ?? ""
            cenelisCustomHandleField = vm.suggestedCenelisLocalPart
            Task {
                await notifManager.refreshAuthorizationStatus()
            }
        }
    }

    // MARK: - Carte Profil Viple Live ID

    private var accountProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VipleMailAvatarView(
                    name: vm.currentUser?.displayName ?? "Viple",
                    email: vm.primaryHostedEmail,
                    avatarUrl: vm.currentUser?.avatarUrl,
                    size: 58,
                    isVip: true
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.currentUser?.displayName ?? vm.primaryHostedEmail)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        if vm.isApprovedCenelisAgent
                            || vm.primaryHostedEmail.lowercased().hasSuffix("@cenelis.com")
                            || vm.primaryHostedEmail.lowercased().hasSuffix("@viplenetwork.com") {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(VipleMailPalette.primary)
                        }
                    }
                    Text(vm.activeMailboxDisplayLabel)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                    if let cid = vm.currentUser?.cid, !cid.isEmpty {
                        Text("Viple Live ID • CID \(cid)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }
                Spacer()
            }

            if (vm.hostedMailboxes.count + vm.externalAccounts.count) > 1 {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Boîtes Viple & Vue unifiée", systemImage: "tray.2.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.inkSecondary)
                        Spacer()
                        if vm.isSwitchingMailbox {
                            ProgressView()
                                .scaleEffect(0.75)
                        }
                    }

                    Button {
                        Task {
                            await vm.switchActiveMailbox(to: "__all__")
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: vm.isUnifiedInboxActive ? "checkmark.circle.fill" : "tray.2.fill")
                                .foregroundStyle(vm.isUnifiedInboxActive ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                            Text("Toutes les boîtes de réception")
                                .font(.system(size: 13.5, weight: vm.isUnifiedInboxActive ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(vm.isUnifiedInboxActive ? VipleMailPalette.primary : VipleMailPalette.ink)
                            Spacer()
                            if vm.isUnifiedInboxActive {
                                Text("ACTIVE")
                                    .font(.system(size: 9.5, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(VipleMailPalette.primary))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(vm.isUnifiedInboxActive ? VipleMailPalette.primary.opacity(0.10) : VipleMailPalette.surfaceSubtle)
                        )
                    }
                    .disabled(vm.isSwitchingMailbox)

                    ForEach(vm.hostedMailboxes, id: \.self) { mbx in
                        let isActive = !vm.isUnifiedInboxActive && mbx.lowercased() == vm.currentEmail.lowercased()
                        let isCenelis = mbx.lowercased().hasSuffix("@cenelis.com")
                        Button {
                            Task {
                                await vm.switchActiveMailbox(to: mbx)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isActive ? "checkmark.circle.fill" : (isCenelis ? "checkmark.seal.fill" : "circle"))
                                    .foregroundStyle((isActive || isCenelis) ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                                Text(mbx)
                                    .font(.system(size: 13.5, weight: isActive ? .bold : .semibold, design: .monospaced))
                                    .foregroundStyle(isActive ? VipleMailPalette.primary : VipleMailPalette.ink)
                                if isCenelis {
                                    Text("CENELIS")
                                        .font(.system(size: 9, weight: .black, design: .rounded))
                                        .foregroundStyle(VipleMailPalette.primary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                                }
                                Spacer()
                                if isActive {
                                    Text("ACTIVE")
                                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(VipleMailPalette.primary))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(isActive ? VipleMailPalette.primary.opacity(0.10) : VipleMailPalette.surfaceSubtle)
                            )
                        }
                        .disabled(vm.isSwitchingMailbox)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Nom d'expéditeur affiché")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField(
                    "Votre nom complet",
                    text: $displayNameField,
                    prompt: VipleMailPalette.prompt("Votre nom complet", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                Text("Statut Viple Live")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField(
                    "Votre message personnel Viple Live",
                    text: $personalMessageField,
                    prompt: VipleMailPalette.prompt("Votre message personnel Viple Live", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Espace Agent Groupe Cenelis (Boîte Professionnelle Officielle @cenelis.com)

    private var cenelisAgentMailboxCard: some View {
        let cenAddr = vm.cenelisMailboxAddress
        let displayAddr = cenAddr ?? "\(vm.suggestedCenelisLocalPart)@cenelis.com"
        let isCurrentlyOpen = !vm.isUnifiedInboxActive && (cenAddr != nil) && vm.currentEmail.lowercased() == cenAddr?.lowercased()

        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Adresse officielle @cenelis.com", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                Text("AGENT CENELIS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
            }

            Text("En tant qu'agent habilité du Groupe Cenelis, vous disposez de votre boîte professionnelle @cenelis.com certifiée (« Vérifiée : Cenelis SA ») et protégée par Cenelis MailRTE.")
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayAddr)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                    Text(cenAddr != nil
                         ? "Active sur Stalwart • Chiffrement Cenelis MailRTE"
                         : "Prête à être activée sur votre compte")
                        .font(.system(size: 11))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                Spacer()

                if isCurrentlyOpen {
                    Text("OUVERTE")
                        .font(.system(size: 9.5, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VipleMailPalette.primary))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VipleMailPalette.primary.opacity(0.07))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(VipleMailPalette.primary.opacity(0.30), lineWidth: 1)
            )

            if let activeCenelis = cenAddr {
                HStack(spacing: 8) {
                    Button {
                        Task {
                            vm.selectedTab = 0
                            await vm.switchActiveMailbox(to: activeCenelis)
                        }
                    } label: {
                        Label(isCurrentlyOpen ? "Aller à la boîte" : "Ouvrir @cenelis.com", systemImage: "tray.full.fill")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(VipleMailPalette.heroGradient)
                            )
                    }
                    .disabled(vm.isSwitchingMailbox)

                    Button {
                        vm.presentComposer(.newMail(preferredFromMailbox: activeCenelis))
                    } label: {
                        Label("Écrire avec", systemImage: "square.and.pencil")
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(VipleMailPalette.primary.opacity(0.11))
                            )
                    }
                }
            } else {
                Button {
                    Task {
                        _ = await vm.claimOrCustomizeCenelisMailbox(
                            desiredLocalPart: cenelisCustomHandleField,
                            switchImmediately: true
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isClaimingCenelisMailbox {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.seal.fill")
                        }
                        Text("Activer mon adresse \(displayAddr)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(VipleMailPalette.heroGradient)
                    )
                }
                .disabled(vm.isClaimingCenelisMailbox)
            }

            DisclosureGroup(
                isExpanded: $isEditingCenelisHandle,
                content: {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 0) {
                            TextField(
                                "prenom.nom",
                                text: $cenelisCustomHandleField,
                                prompt: VipleMailPalette.prompt("prenom.nom", scheme: colorScheme)
                            )
                                .vipleMailTextInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 14, design: .monospaced))
                                .padding(11)
                            Text("@cenelis.com")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 11)
                                .background(VipleMailPalette.primary)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                        Button {
                            Task {
                                let ok = await vm.claimOrCustomizeCenelisMailbox(
                                    desiredLocalPart: cenelisCustomHandleField,
                                    switchImmediately: true
                                )
                                if ok {
                                    isEditingCenelisHandle = false
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if vm.isClaimingCenelisMailbox {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Text("Attribuer cet identifiant @cenelis.com")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 11).fill(VipleMailPalette.primary))
                        }
                        .disabled(vm.isClaimingCenelisMailbox)
                    }
                    .padding(.top, 8)
                },
                label: {
                    Text("Personnaliser mon identifiant @cenelis.com")
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                }
            )
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Apparence, Thème Clair / Sombre OLED & Rendu des Courriers HTML

    private var appearanceCustomizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Apparence & Mode sombre", systemImage: "moon.stars.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                Text(vm.appearanceMode.title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3.5)
                    .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
            }

            HStack(spacing: 10) {
                ForEach(VipleMailAppearanceMode.allCases) { mode in
                    appearanceModeTile(mode)
                }
            }

            Text(vm.appearanceMode.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(VipleMailPalette.inkSecondary)

            Divider()

            Toggle(isOn: $vm.adaptHtmlEmailsInDarkMode) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Adapter les courriers HTML au mode sombre")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Convertit automatiquement les fonds clairs des e-mails reçus pour un confort nocturne optimal (un bouton ☀️/🌙 reste accessible dans chaque courrier)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func appearanceModeTile(_ mode: VipleMailAppearanceMode) -> some View {
        let isSelected = vm.appearanceMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                vm.appearanceMode = mode
            }
        } label: {
            VStack(spacing: 9) {
                // Aperçu visuel miniature Clair / Sombre / Auto
                ZStack {
                    switch mode {
                    case .light:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.95, green: 0.97, blue: 1.00))
                            .overlay(
                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.00, green: 0.47, blue: 0.83))
                                        .frame(width: 24, height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white)
                                        .frame(height: 11)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white)
                                        .frame(height: 11)
                                }
                                .padding(7)
                            )
                    case .dark:
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.03, green: 0.04, blue: 0.08))
                            .overlay(
                                VStack(alignment: .leading, spacing: 4) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.26, green: 0.82, blue: 1.00))
                                        .frame(width: 24, height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.09, green: 0.13, blue: 0.21))
                                        .frame(height: 11)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(red: 0.09, green: 0.13, blue: 0.21))
                                        .frame(height: 11)
                                }
                                .padding(7)
                            )
                    case .system:
                        HStack(spacing: 0) {
                            Color(red: 0.95, green: 0.97, blue: 1.00)
                            Color(red: 0.03, green: 0.04, blue: 0.08)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.16, green: 0.56, blue: 1.00))
                        )
                    }
                }
                .frame(height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: 1)
                )

                HStack(spacing: 4) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : mode.iconName)
                        .font(.system(size: 11.5, weight: .bold))
                    Text(mode.title)
                        .font(.system(size: 12, weight: isSelected ? .bold : .semibold, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(isSelected ? VipleMailPalette.primary : VipleMailPalette.inkSecondary)
            }
            .padding(9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? VipleMailPalette.primary.opacity(0.11) : VipleMailPalette.surfaceSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? VipleMailPalette.primary : VipleMailPalette.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comptes E-Mail Externes (Gmail, Outlook, iCloud, Orange, OVH, Pro...)

    private var externalAccountsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Boîtes e-mail externes", systemImage: "globe.europe.africa.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                if !vm.externalAccounts.isEmpty {
                    Text("\(vm.externalAccounts.count)")
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }

            if vm.externalAccounts.isEmpty {
                Text("Ajoutez vos autres adresses e-mail (Gmail, Outlook, iCloud, Yahoo, Orange, Free, SFR, OVH ou professionnelles) pour lire et gérer tous vos courriers dans Viple Mail.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(vm.externalAccounts) { ext in
                        let isActive = !vm.isUnifiedInboxActive && ext.email.lowercased() == vm.currentEmail.lowercased()
                        let tint = VipleMailPalette.colorFromHex(ext.colorHex)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(tint.opacity(0.14))
                                        .frame(width: 38, height: 38)
                                    Image(systemName: ext.providerIcon)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(tint)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(ext.email)
                                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                                            .foregroundStyle(VipleMailPalette.ink)
                                            .lineLimit(1)
                                        if isActive {
                                            Text("ACTIVE")
                                                .font(.system(size: 9, weight: .black, design: .rounded))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(VipleMailPalette.primary))
                                        }
                                    }
                                    Text("\(ext.providerName) • \(ext.imapHost):\(ext.imapPort) • \(ext.canSendSmtp ? "Lecture & Envoi" : "Lecture seule")")
                                        .font(.system(size: 11))
                                        .foregroundStyle(VipleMailPalette.inkMuted)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }

                            HStack(spacing: 8) {
                                Button {
                                    Task {
                                        vm.selectedTab = 0
                                        await vm.switchActiveMailbox(to: ext.email)
                                    }
                                } label: {
                                    Label(isActive ? "Ouvrir la boîte" : "Lire les e-mails", systemImage: "envelope.open.fill")
                                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(isActive ? .white : VipleMailPalette.primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(isActive ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.11))
                                        )
                                }

                                Button {
                                    vm.presentAddExternalAccountSheet(editing: ext)
                                } label: {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VipleMailPalette.inkSecondary)
                                        .frame(width: 36, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.surface))
                                }
                                .accessibilityLabel("Modifier les serveurs")

                                Button(role: .destructive) {
                                    accountPendingDeletion = ext
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(VipleMailPalette.danger)
                                        .frame(width: 36, height: 34)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.danger.opacity(0.10)))
                                }
                                .accessibilityLabel("Retirer cette boîte externe")
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isActive ? VipleMailPalette.primary.opacity(0.07) : VipleMailPalette.surfaceSubtle)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isActive ? VipleMailPalette.primary.opacity(0.35) : VipleMailPalette.border, lineWidth: 1)
                        )
                    }
                }
            }

            Button {
                vm.presentAddExternalAccountSheet()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text(vm.externalAccounts.isEmpty ? "Ajouter une adresse e-mail externe" : "Ajouter une autre boîte externe")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Notifications Push, Badges & Synchronisation d'Arrière-Plan

    private var notificationsControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Label("Notifications & Arrière-plan", systemImage: "bell.badge.fill")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(notifManager.isOsAuthorized && vm.settings.pushNotificationsEnabled
                              ? VipleMailPalette.success
                              : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(notifManager.osStatusLabel)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(notifManager.isOsAuthorized ? VipleMailPalette.success : Color.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((notifManager.isOsAuthorized ? VipleMailPalette.success : Color.orange).opacity(0.12))
                )
            }

            Toggle(isOn: Binding(
                get: { vm.settings.pushNotificationsEnabled },
                set: { newVal in
                    vm.settings.pushNotificationsEnabled = newVal
                    Task {
                        if newVal {
                            let granted = await notifManager.requestPermissionIfNeeded(promptIfNotDetermined: true)
                            if !granted && notifManager.authorizationStatus == .denied {
                                vm.showToast("Activez les notifications Viple Mail dans les Réglages iOS.")
                            }
                        }
                        await vm.saveMailSettings(
                            displayName: displayNameField,
                            personalMessage: personalMessageField
                        )
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Activer les notifications instantanées")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Bannières riches avec avatar, actions rapides (Répondre, Lu, Archiver) et actualisation en arrière-plan")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            if notifManager.authorizationStatus == .denied {
                Button {
                    notifManager.openSystemNotificationSettings()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "gear.badge")
                        Text("Ouvrir les Réglages de notifications iOS")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange))
                }
            }

            if vm.settings.pushNotificationsEnabled {
                Divider()

                Toggle(isOn: Binding(
                    get: { vm.settings.vipNotificationsOnly },
                    set: { newVal in
                        vm.settings.vipNotificationsOnly = newVal
                        Task {
                            await vm.saveMailSettings(
                                displayName: displayNameField,
                                personalMessage: personalMessageField
                            )
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uniquement mes Contacts VIP 👑")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Filtre les bannières sonores pour ne signaler que vos expéditeurs favoris")
                            .font(.system(size: 11.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    }
                }

                Toggle("Son de notification", isOn: $notifManager.soundEnabled)
                    .font(.system(size: 14, weight: .semibold))

                Toggle("Pastille du nombre de non-lus sur l'icône", isOn: $notifManager.badgeEnabled)
                    .font(.system(size: 14, weight: .semibold))

                Button {
                    Task {
                        let ok = await notifManager.sendTestNotification(mailboxEmail: vm.currentEmail)
                        if ok {
                            vm.showToast("Notification de test envoyée !")
                        } else {
                            vm.showToast("Veuillez autoriser les notifications dans iOS.")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.and.waves.left.and.right.fill")
                        Text("Envoyer une notification de test")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary.opacity(0.11)))
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Serveurs Officiels viplemail.fr (IMAP / SMTP / Autodiscover)

    private var officialMailServersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Serveurs officiels viplemail.fr & cenelis.com", systemImage: "server.rack")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            VStack(spacing: 8) {
                serverRow(title: "API Mobile & Webmail", value: "mail.viplemail.fr")
                serverRow(title: "Serveur IMAP (SSL/TLS)", value: "\(VipleMailAPIClient.shared.imapHost) : \(VipleMailAPIClient.shared.imapPort)")
                serverRow(title: "Serveur SMTP (STARTTLS / SSL)", value: "\(VipleMailAPIClient.shared.smtpHost) : \(VipleMailAPIClient.shared.smtpStartTlsPort) / \(VipleMailAPIClient.shared.smtpImplicitTlsPort)")
                serverRow(title: "SSO Viple / Cenelis", value: "identity-v2.viple.digital / sso.prod.cenelis.com")
                serverRow(title: "Autodiscover", value: VipleMailAPIClient.shared.autodiscoverHost)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

            if let profileUrl = VipleMailAPIClient.shared.appleProfileDownloadURL(for: vm.currentEmail) {
                Link(destination: profileUrl) {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward")
                        Text("Installer le profil Apple Mail (.mobileconfig)")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(VipleMailPalette.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.primary.opacity(0.10)))
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Mot de passe IMAP / SMTP (pour clients externes)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 8) {
                    SecureField(
                        "Nouveau mot de passe (min. 8 car.)",
                        text: $newImapPasswordField,
                        prompt: VipleMailPalette.prompt("Nouveau mot de passe (min. 8 car.)", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                    Button {
                        let pw = newImapPasswordField
                        Task {
                            if await vm.updatePersonalImapPassword(pw) {
                                newImapPasswordField = ""
                            }
                        }
                    } label: {
                        Text("Activer")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.primary))
                    }
                    .disabled(newImapPasswordField.trimmingCharacters(in: .whitespacesAndNewlines).count < 8)
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func serverRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VipleMailPalette.inkSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(VipleMailPalette.ink)
                .textSelection(.enabled)
        }
    }

    // MARK: - Boîte Prioritaire & Gestes de Balayage

    private var inboxAndSwipeCustomizationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Boîte de réception & Gestes de balayage", systemImage: "hand.draw.fill")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)

            Toggle(isOn: $vm.settings.focusedInboxEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Boîte de réception Prioritaire")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sépare automatiquement vos courriers importants et VIP des autres notifications")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            Divider()

            HStack {
                Text("Balayage vers la droite")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Balayage droite", selection: $vm.settings.swipeRightAction) {
                    Text("Lu / Non lu").tag("ToggleRead")
                    Text("Favori ⭐").tag("Star")
                    Text("Épingler 📌").tag("Pin")
                    Text("Archiver").tag("Archive")
                }
                .pickerStyle(.menu)
            }

            HStack {
                Text("Balayage vers la gauche")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("Balayage gauche", selection: $vm.settings.swipeLeftAction) {
                    Text("Corbeille 🗑️").tag("Trash")
                    Text("Archiver").tag("Archive")
                    Text("Indésirable").tag("Spam")
                    Text("Favori ⭐").tag("Star")
                }
                .pickerStyle(.menu)
            }

            Toggle("Notifications réservées aux Contacts VIP 👑", isOn: $vm.settings.vipNotificationsOnly)
                .font(.system(size: 14, weight: .semibold))
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Signature Personnalisée

    private var signatureCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Signature électronique", systemImage: "signature")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Toggle("", isOn: $vm.settings.signatureEnabled)
                    .labelsHidden()
            }

            VipleMailMultiLineEditor(
                text: $vm.settings.signatureHtml,
                placeholder: "Votre signature électronique Viple Mail…",
                fontSize: 13.5,
                minHeight: 75,
                horizontalInset: 12,
                verticalInset: 10
            )
            .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Répondeur Automatique d'Absence

    private var vacationResponderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Réponse automatique d'absence", systemImage: "airplane.departure")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Toggle("", isOn: $vm.settings.vacationEnabled)
                    .labelsHidden()
            }

            if vm.settings.vacationEnabled {
                TextField(
                    "Objet de la réponse automatique",
                    text: $vm.settings.vacationSubject,
                    prompt: VipleMailPalette.prompt("Objet de la réponse automatique", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                VipleMailMultiLineEditor(
                    text: $vm.settings.vacationBody,
                    placeholder: "Message envoyé automatiquement à vos correspondants pendant votre absence…",
                    fontSize: 13.5,
                    minHeight: 80,
                    horizontalInset: 12,
                    verticalInset: 10
                )
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            Button {
                Task {
                    await vm.saveMailSettings(
                        displayName: displayNameField,
                        personalMessage: personalMessageField
                    )
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Enregistrer toutes mes préférences")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.heroGradient))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Diagnostics Serveur & Déconnexion

    private var diagnosticsAndSignOutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Serveur Viple Mail & SSO Viple Live ID")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text(vm.lastDiagnosticsPing != nil
                         ? "Connecté : \(vm.lastDiagnosticsPing!.host) • \(vm.lastDiagnosticsPing!.version)"
                         : "Hôte : mail.viplemail.fr • IMAP 993 / SMTP 587 TLS")
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.success)
                }
                Spacer()
                Button {
                    Task {
                        await vm.runDiagnosticsPing()
                    }
                } label: {
                    Label("Tester", systemImage: "waveform.path.ecg")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(VipleMailPalette.primary.opacity(0.12)))
                }
            }

            Divider()

            Button(role: .destructive) {
                vm.signOut()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Se déconnecter de Viple Mail")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .foregroundStyle(VipleMailPalette.danger)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.danger.opacity(0.10)))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }
}
