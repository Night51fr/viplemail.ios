import SwiftUI

// MARK: - Réglages & Compte Viple Live ID « Viple Mail » (Signature, Gestes de Balayage, Répondeur Automatique, Diagnostics & Déconnexion)

public struct MailSettingsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    @State private var displayNameField: String = ""
    @State private var personalMessageField: String = ""

    public init() {}

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                accountProfileCard
                inboxAndSwipeCustomizationCard
                signatureCard
                vacationResponderCard
                diagnosticsAndSignOutCard
            }
            .padding(16)
        }
        .background(VipleMailPalette.background)
        .navigationBarHidden(true)
        .onAppear {
            displayNameField = vm.currentUser?.displayName ?? ""
            personalMessageField = vm.currentUser?.personalMessage ?? ""
        }
    }

    // MARK: - Carte Profil Viple Live ID

    private var accountProfileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                VipleMailAvatarView(
                    name: vm.currentUser?.displayName ?? "Viple",
                    email: vm.currentEmail,
                    size: 58,
                    isVip: true
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vm.currentUser?.displayName ?? vm.currentEmail)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text(vm.currentEmail)
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Nom d'expéditeur affiché")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField("Votre nom complet", text: $displayNameField)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                Text("Statut Viple Live")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField("Votre message personnel Viple Live", text: $personalMessageField)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
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

            TextEditor(text: $vm.settings.signatureHtml)
                .font(.system(size: 13.5))
                .frame(minHeight: 75)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
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
                TextField("Objet de la réponse automatique", text: $vm.settings.vacationSubject)
                    .padding(11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                TextEditor(text: $vm.settings.vacationBody)
                    .font(.system(size: 13.5))
                    .frame(minHeight: 80)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
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
                    Text(vm.lastDiagnosticsPing != nil
                         ? "Connecté : \(vm.lastDiagnosticsPing!.host) • v\(vm.lastDiagnosticsPing!.version)"
                         : "Hôte : mail.live.viplenetwork.com • HTTPS actif")
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
