import SwiftUI

// MARK: - Feuille d'Ajout & Configuration de Boîte E-Mail Externe (Gmail, Outlook, iCloud, Yahoo, Orange, Free, SFR, OVH, IMAP/SMTP)

public struct AddExternalAccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var vm: VipleMailViewModel

    private struct QuickProviderPreset: Identifiable {
        let id: String
        let label: String
        let icon: String
        let colorHex: String
        let sampleDomain: String
        let imapHost: String
        let imapPort: Int
        let imapSecurity: String
        let smtpHost: String
        let smtpPort: Int
        let smtpSecurity: String
        let hint: String?
    }

    private static let presets: [QuickProviderPreset] = [
        QuickProviderPreset(
            id: "gmail", label: "Gmail", icon: "envelope.badge.shield.half.filled.fill", colorHex: "#EA4335",
            sampleDomain: "gmail.com",
            imapHost: "imap.gmail.com", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.gmail.com", smtpPort: 587, smtpSecurity: "starttls",
            hint: "Si la validation en 2 étapes est activée sur Google, saisissez un « Mot de passe d'application » à 16 caractères (Compte Google > Sécurité > Mots de passe des applications)."
        ),
        QuickProviderPreset(
            id: "outlook", label: "Outlook", icon: "building.2.crop.circle.fill", colorHex: "#0078D4",
            sampleDomain: "outlook.fr",
            imapHost: "outlook.office365.com", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.office365.com", smtpPort: 587, smtpSecurity: "starttls",
            hint: "Vérifiez que l'accès IMAP est activé dans les paramètres de votre boîte Outlook / Hotmail / Microsoft 365."
        ),
        QuickProviderPreset(
            id: "icloud", label: "iCloud", icon: "icloud.fill", colorHex: "#0284C7",
            sampleDomain: "icloud.com",
            imapHost: "imap.mail.me.com", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.mail.me.com", smtpPort: 587, smtpSecurity: "starttls",
            hint: "Pour iCloud Mail, utilisez un « Mot de passe pour application » généré sur appleid.apple.com (section Connexion et sécurité)."
        ),
        QuickProviderPreset(
            id: "yahoo", label: "Yahoo", icon: "at.circle.fill", colorHex: "#7C3AED",
            sampleDomain: "yahoo.fr",
            imapHost: "imap.mail.yahoo.com", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.mail.yahoo.com", smtpPort: 465, smtpSecurity: "ssl",
            hint: "Générez un mot de passe d'application dans les paramètres de sécurité de votre compte Yahoo."
        ),
        QuickProviderPreset(
            id: "orange", label: "Orange", icon: "globe.europe.africa.fill", colorHex: "#F97316",
            sampleDomain: "orange.fr",
            imapHost: "imap.orange.fr", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.orange.fr", smtpPort: 465, smtpSecurity: "ssl",
            hint: "Activez « Accès depuis une application » dans les paramètres de votre boîte Mail Orange."
        ),
        QuickProviderPreset(
            id: "free", label: "Free", icon: "network", colorHex: "#DC2626",
            sampleDomain: "free.fr",
            imapHost: "imap.free.fr", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.free.fr", smtpPort: 465, smtpSecurity: "ssl",
            hint: nil
        ),
        QuickProviderPreset(
            id: "sfr", label: "SFR", icon: "antenna.radiowaves.left.and.right", colorHex: "#E11D48",
            sampleDomain: "sfr.fr",
            imapHost: "imap.sfr.fr", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "smtp.sfr.fr", smtpPort: 465, smtpSecurity: "ssl",
            hint: nil
        ),
        QuickProviderPreset(
            id: "ovh", label: "OVH / Pro", icon: "server.rack", colorHex: "#0050D7",
            sampleDomain: "",
            imapHost: "ssl0.ovh.net", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "ssl0.ovh.net", smtpPort: 465, smtpSecurity: "ssl",
            hint: "Compatible avec tous les hébergeurs pro (OVHcloud, IONOS, Infomaniak, Gandi, cPanel, Plesk). Les serveurs sont détectés automatiquement selon votre domaine."
        ),
        QuickProviderPreset(
            id: "custom", label: "Autre IMAP", icon: "slider.horizontal.3", colorHex: "#2563EB",
            sampleDomain: "",
            imapHost: "", imapPort: 993, imapSecurity: "ssl",
            smtpHost: "", smtpPort: 587, smtpSecurity: "starttls",
            hint: "Renseignez les serveurs IMAP et SMTP fournis par votre opérateur de messagerie."
        )
    ]

    @State private var selectedPresetId: String = "gmail"
    @State private var emailField: String = ""
    @State private var passwordField: String = ""
    @State private var displayNameField: String = ""
    @State private var providerName: String = "Google Gmail"
    @State private var colorHex: String = "#EA4335"
    @State private var providerHint: String? = nil

    @State private var canSendSmtp: Bool = true
    @State private var isShowingAdvancedServers: Bool = false
    @State private var hasCustomizedServersManually: Bool = false

    @State private var imapHost: String = "imap.gmail.com"
    @State private var imapPortText: String = "993"
    @State private var imapSecurity: String = "ssl"
    @State private var imapUsername: String = ""

    @State private var smtpHost: String = "smtp.gmail.com"
    @State private var smtpPortText: String = "587"
    @State private var smtpSecurity: String = "starttls"
    @State private var smtpUsername: String = ""
    @State private var smtpPassword: String = ""

    @State private var isTestingConnection: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var statusBannerText: String? = nil
    @State private var statusBannerIsSuccess: Bool = false
    @State private var autodiscoverTask: Task<Void, Never>? = nil

    public init() {}

    private var isEditingExisting: Bool {
        vm.editingExternalAccount != nil
    }

    private var canSubmit: Bool {
        let cleanEmail = emailField.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEmail = cleanEmail.contains("@") && !cleanEmail.hasSuffix("@")
        let hasPass = isEditingExisting || !passwordField.isEmpty
        let hasImap = !imapHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasEmail && hasPass && hasImap && !isSubmitting && !isTestingConnection
    }

    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    headerIntroBanner

                    if !isEditingExisting {
                        providerQuickPickerSection
                    }

                    credentialsCard

                    if let hint = providerHint, !hint.isEmpty {
                        guidanceCallout(text: hint)
                    }

                    smtpModeAndAdvancedCard

                    if let status = statusBannerText, !status.isEmpty {
                        statusBanner(text: status, isSuccess: statusBannerIsSuccess)
                    }

                    actionButtonsSection
                }
                .padding(16)
            }
            .background(VipleMailPalette.background.ignoresSafeArea())
            .navigationTitle(isEditingExisting ? "Modifier la boîte externe" : "Ajouter une boîte externe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        vm.editingExternalAccount = nil
                        dismiss()
                    }
                }
            }
            .onAppear {
                populateInitialState()
            }
            .onChange(of: emailField) { _, newValue in
                guard !isEditingExisting else { return }
                handleTypedEmailChange(newValue)
            }
        }
    }

    // MARK: - Sections UI

    private var headerIntroBanner: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VipleMailPalette.primary.opacity(0.14))
                    .frame(width: 48, height: 48)
                Image(systemName: "tray.2.fill")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(VipleMailPalette.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Lisez toutes vos boîtes dans Viple Mail")
                    .font(.system(size: 15.5, weight: .black, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Text("Connectez vos adresses Gmail, Outlook, iCloud, Orange, Free, SFR, OVH ou professionnelles en IMAP/SMTP sécurisé.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            }
        }
        .vipleMailCard(cornerRadius: 18, padding: 14)
    }

    private var providerQuickPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FOURNISSEUR DE MESSAGERIE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(VipleMailPalette.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.presets) { preset in
                        let selected = selectedPresetId == preset.id
                        let tint = VipleMailPalette.colorFromHex(preset.colorHex)
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                applyQuickPreset(preset)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 12.5, weight: .bold))
                                Text(preset.label)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(selected ? .white : VipleMailPalette.ink)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 8.5)
                            .background(
                                Capsule()
                                    .fill(selected ? tint : VipleMailPalette.surface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selected ? tint : VipleMailPalette.border, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Identifiants du compte externe", systemImage: "person.badge.key.fill")
                    .font(.system(size: 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Spacer()
                Text(providerName)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.colorFromHex(colorHex))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(VipleMailPalette.colorFromHex(colorHex).opacity(0.12))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Adresse e-mail externe")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                TextField(
                    "prenom.nom@gmail.com",
                    text: $emailField,
                    prompt: VipleMailPalette.prompt("prenom.nom@gmail.com", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(isEditingExisting)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(isEditingExisting ? "Nouveau mot de passe (laisser vide pour conserver l'actuel)" : "Mot de passe ou mot de passe d'application")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                SecureField(
                    isEditingExisting ? "••••••••••••" : "Mot de passe de la boîte mail",
                    text: $passwordField,
                    prompt: VipleMailPalette.prompt(isEditingExisting ? "••••••••••••" : "Mot de passe de la boîte mail", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Nom affiché pour cette boîte")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                TextField(
                    "Votre nom complet",
                    text: $displayNameField,
                    prompt: VipleMailPalette.prompt("Votre nom complet", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func guidanceCallout(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(VipleMailPalette.primary)
                .padding(.top, 1)

            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(VipleMailPalette.primary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(VipleMailPalette.primary.opacity(0.22), lineWidth: 1)
        )
    }

    private var smtpModeAndAdvancedCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Toggle(isOn: $canSendSmtp) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Autoriser aussi l'envoi d'e-mails (SMTP)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Désactivez si vous souhaitez uniquement lire les e-mails reçus sur cette boîte")
                        .font(.system(size: 11.5))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            Divider()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                    isShowingAdvancedServers.toggle()
                }
            } label: {
                HStack {
                    Label("Serveurs IMAP / SMTP", systemImage: "server.rack")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Spacer()
                    Text(imapHost.isEmpty ? "Configurer" : "\(imapHost):\(imapPortText)")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(VipleMailPalette.primary)
                        .lineLimit(1)
                    Image(systemName: isShowingAdvancedServers ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }
            .buttonStyle(.plain)

            if isShowingAdvancedServers {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    Text("SERVEUR ENTRANT (IMAP)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.primary)

                    HStack(spacing: 8) {
                        TextField("imap.domaine.fr", text: $imapHost, prompt: VipleMailPalette.prompt("imap.domaine.fr", scheme: colorScheme))
                            .vipleMailTextInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: imapHost) { _, _ in hasCustomizedServersManually = true }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                        TextField("993", text: $imapPortText, prompt: VipleMailPalette.prompt("993", scheme: colorScheme))
                            .vipleMailTextInput()
                            .keyboardType(.numberPad)
                            .frame(width: 70)
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                    }

                    Picker("Sécurité IMAP", selection: $imapSecurity) {
                        Text("SSL/TLS (993)").tag("ssl")
                        Text("STARTTLS (143)").tag("starttls")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: imapSecurity) { _, newSec in
                        if newSec == "ssl" && imapPortText == "143" { imapPortText = "993" }
                        if newSec == "starttls" && imapPortText == "993" { imapPortText = "143" }
                    }

                    TextField(
                        "Identifiant IMAP (par défaut l'adresse e-mail)",
                        text: $imapUsername,
                        prompt: VipleMailPalette.prompt("Identifiant IMAP (par défaut l'adresse e-mail)", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                    if canSendSmtp {
                        Divider()

                        Text("SERVEUR SORTANT (SMTP)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)

                        HStack(spacing: 8) {
                            TextField("smtp.domaine.fr", text: $smtpHost, prompt: VipleMailPalette.prompt("smtp.domaine.fr", scheme: colorScheme))
                                .vipleMailTextInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: smtpHost) { _, _ in hasCustomizedServersManually = true }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                            TextField("587", text: $smtpPortText, prompt: VipleMailPalette.prompt("587", scheme: colorScheme))
                                .vipleMailTextInput()
                                .keyboardType(.numberPad)
                                .frame(width: 70)
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                        }

                        Picker("Sécurité SMTP", selection: $smtpSecurity) {
                            Text("STARTTLS (587)").tag("starttls")
                            Text("SSL/TLS (465)").tag("ssl")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: smtpSecurity) { _, newSec in
                            if newSec == "ssl" && smtpPortText == "587" { smtpPortText = "465" }
                            if newSec == "starttls" && smtpPortText == "465" { smtpPortText = "587" }
                        }

                        TextField(
                            "Identifiant SMTP (optionnel)",
                            text: $smtpUsername,
                            prompt: VipleMailPalette.prompt("Identifiant SMTP (optionnel)", scheme: colorScheme)
                        )
                            .vipleMailTextInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                        SecureField(
                            "Mot de passe SMTP distinct (optionnel)",
                            text: $smtpPassword,
                            prompt: VipleMailPalette.prompt("Mot de passe SMTP distinct (optionnel)", scheme: colorScheme)
                        )
                            .vipleMailTextInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                    }
                }
            }
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    private func statusBanner(text: String, isSuccess: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(isSuccess ? VipleMailPalette.success : VipleMailPalette.danger)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSuccess ? VipleMailPalette.success : VipleMailPalette.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill((isSuccess ? VipleMailPalette.success : VipleMailPalette.danger).opacity(0.10))
        )
    }

    private var actionButtonsSection: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await runLiveTest()
                }
            } label: {
                HStack(spacing: 8) {
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                    }
                    Text("Tester la connexion IMAP\(canSendSmtp ? " / SMTP" : "")")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundStyle(VipleMailPalette.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.primary.opacity(0.11))
                )
            }
            .disabled(!canSubmit)

            Button {
                Task {
                    await submitExternalAccount()
                }
            } label: {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text(isEditingExisting ? "Enregistrer les modifications" : "Connecter et lire cette boîte mail")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(canSubmit ? AnyShapeStyle(VipleMailPalette.heroGradient) : AnyShapeStyle(Color.gray.opacity(0.45)))
                )
            }
            .disabled(!canSubmit)
        }
    }

    // MARK: - Logique d'Auto-Découverte & Validation

    private func populateInitialState() {
        if let editing = vm.editingExternalAccount {
            emailField = editing.email
            displayNameField = editing.displayName
            providerName = editing.providerName
            colorHex = editing.colorHex
            imapHost = editing.imapHost
            imapPortText = "\(editing.imapPort)"
            imapSecurity = editing.imapSecurity
            imapUsername = editing.imapUsername
            canSendSmtp = editing.canSendSmtp
            smtpHost = editing.smtpHost
            smtpPortText = "\(editing.smtpPort)"
            smtpSecurity = editing.smtpSecurity
            smtpUsername = editing.smtpUsername
            isShowingAdvancedServers = true
        } else {
            displayNameField = vm.currentUser?.displayName ?? ""
            if let first = Self.presets.first {
                applyQuickPreset(first)
            }
        }
    }

    private func applyQuickPreset(_ preset: QuickProviderPreset) {
        selectedPresetId = preset.id
        providerName = preset.label == "Autre IMAP" ? "IMAP personnalisé" : preset.label
        colorHex = preset.colorHex
        providerHint = preset.hint
        hasCustomizedServersManually = false
        imapHost = preset.imapHost
        imapPortText = "\(preset.imapPort)"
        imapSecurity = preset.imapSecurity
        smtpHost = preset.smtpHost
        smtpPortText = "\(preset.smtpPort)"
        smtpSecurity = preset.smtpSecurity
        if preset.id == "custom" || preset.id == "ovh" {
            isShowingAdvancedServers = true
        }
    }

    private func handleTypedEmailChange(_ raw: String) {
        let clean = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if imapUsername.isEmpty || imapUsername == emailField.lowercased() {
            // Leave imapUsername empty so it defaults cleanly to emailField
        }
        guard let atIdx = clean.lastIndex(of: "@") else { return }
        let dom = String(clean[clean.index(after: atIdx)...])
        guard dom.contains("."), dom.count >= 4 else { return }

        // 1. Correspondance locale immédiate
        if let matched = Self.presets.first(where: { !($0.sampleDomain.isEmpty) && dom == $0.sampleDomain }) {
            selectedPresetId = matched.id
            providerName = matched.label
            colorHex = matched.colorHex
            providerHint = matched.hint
            if !hasCustomizedServersManually {
                imapHost = matched.imapHost
                imapPortText = "\(matched.imapPort)"
                imapSecurity = matched.imapSecurity
                smtpHost = matched.smtpHost
                smtpPortText = "\(matched.smtpPort)"
                smtpSecurity = matched.smtpSecurity
            }
            return
        }

        // 2. Découverte serveur DNS MX (Google Workspace, Microsoft 365, OVH, IONOS, Infomaniak, Gandi, Zoho...)
        autodiscoverTask?.cancel()
        autodiscoverTask = Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            if let auto = await vm.autodiscoverExternalMail(email: clean) {
                guard !Task.isCancelled else { return }
                providerName = auto.providerName
                colorHex = auto.colorHex
                providerHint = auto.helpHint
                if !hasCustomizedServersManually {
                    imapHost = auto.imapHost
                    imapPortText = "\(auto.imapPort)"
                    imapSecurity = auto.imapSecurity
                    smtpHost = auto.smtpHost
                    smtpPortText = "\(auto.smtpPort)"
                    smtpSecurity = auto.smtpSecurity
                }
            }
        }
    }

    private func runLiveTest() async {
        statusBannerText = nil
        isTestingConnection = true
        defer { isTestingConnection = false }

        let cleanEmail = emailField.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parsedImapPort = Int(imapPortText) ?? 993
        let parsedSmtpPort = Int(smtpPortText) ?? 587
        let effImapUser = imapUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? cleanEmail : imapUsername
        let effSmtpUser = smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? effImapUser : smtpUsername

        let res = await vm.testExternalMailConnection(
            externalEmail: cleanEmail,
            imapHost: imapHost,
            imapPort: parsedImapPort,
            imapSecurity: imapSecurity,
            imapUsername: effImapUser,
            imapPassword: passwordField,
            canSendSmtp: canSendSmtp,
            smtpHost: smtpHost,
            smtpPort: parsedSmtpPort,
            smtpSecurity: smtpSecurity,
            smtpUsername: effSmtpUser,
            smtpPassword: smtpPassword
        )

        statusBannerIsSuccess = res.ok
        statusBannerText = res.message
    }

    private func submitExternalAccount() async {
        statusBannerText = nil
        isSubmitting = true
        defer { isSubmitting = false }

        let cleanEmail = emailField.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parsedImapPort = Int(imapPortText) ?? 993
        let parsedSmtpPort = Int(smtpPortText) ?? 587
        let effImapUser = imapUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? cleanEmail : imapUsername
        let effSmtpUser = smtpUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? effImapUser : smtpUsername

        let res = await vm.addOrUpdateExternalAccount(
            externalEmail: cleanEmail,
            displayName: displayNameField,
            providerName: providerName,
            colorHex: colorHex,
            imapHost: imapHost,
            imapPort: parsedImapPort,
            imapSecurity: imapSecurity,
            imapUsername: effImapUser,
            imapPassword: passwordField,
            canSendSmtp: canSendSmtp,
            smtpHost: smtpHost,
            smtpPort: parsedSmtpPort,
            smtpSecurity: smtpSecurity,
            smtpUsername: effSmtpUser,
            smtpPassword: smtpPassword,
            openImmediately: !isEditingExisting
        )

        if res.ok {
            vm.editingExternalAccount = nil
            dismiss()
        } else {
            statusBannerIsSuccess = false
            statusBannerText = res.error ?? "Impossible de connecter cette boîte externe."
        }
    }
}
