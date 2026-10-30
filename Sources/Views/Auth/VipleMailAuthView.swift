import SwiftUI
import AuthenticationServices

// MARK: - Authentification Native « Viple Mail » (SSO Viple Live ID, Création de boîte @viplemail.fr, Sign in with Apple & Détection Inter-App)

public struct VipleMailAuthView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public enum AuthTab: String, CaseIterable {
        case login = "Se connecter"
        case register = "Créer une boîte @viplemail.fr"
    }

    @State private var selectedTab: AuthTab = .login
    @State private var loginEmail: String = ""
    @State private var loginPassword: String = ""

    @State private var viplemailLocalUser: String = ""
    @State private var signupPassword: String = ""
    @State private var signupConfirmPassword: String = ""
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var displayName: String = ""
    @State private var localValidationError: String? = nil

    // Onboarding Sign in with Apple (@viplemail.fr obligatoire ou liaison compte existant)
    @State private var appleFirstName: String = ""
    @State private var appleLastName: String = ""
    @State private var appleDisplayName: String = ""
    @State private var appleViplemailUser: String = ""
    @State private var appleLinkExistingMode: Bool = false
    @State private var appleExistingEmail: String = ""
    @State private var appleExistingPassword: String = ""

    public init() {}

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    VipleMailPalette.cobaltDeep,
                    Color(red: 0.00, green: 0.32, blue: 0.72),
                    VipleMailPalette.background
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    brandHeader

                    if vm.pendingAppleOnboardingUserId != nil {
                        appleOnboardingCard
                    } else {
                        if let detected = vm.detectedCrossAppAccount {
                            crossAppSSOBanner(account: detected)
                        }

                        tabSelectorCard
                        appleSignInCard

                        if selectedTab == .login {
                            loginFormCard
                        } else {
                            registerFormCard
                        }

                        ecosystemFooterCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .onChange(of: vm.pendingAppleOnboardingUserId) { _, newValue in
            if newValue != nil {
                appleFirstName = vm.pendingAppleSuggestedFirstName
                appleLastName = vm.pendingAppleSuggestedLastName
                let suggested = "\(vm.pendingAppleSuggestedFirstName) \(vm.pendingAppleSuggestedLastName)".trimmingCharacters(in: .whitespaces)
                appleDisplayName = suggested
                if appleViplemailUser.isEmpty, !suggested.isEmpty {
                    appleViplemailUser = suggested
                        .folding(options: .diacriticInsensitive, locale: .current)
                        .lowercased()
                        .replacingOccurrences(of: " ", with: ".")
                        .filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" }
                }
            }
        }
    }

    // MARK: - En-tête Viple Mail × Viple Live ID

    private var brandHeader: some View {
        VStack(spacing: 14) {
            HStack {
                VipleMailHorizontalLogoView(height: 38, lightModeOnDarkBackground: true)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(VipleMailPalette.azureGlow)
                    Text("SSO Viple Live ID")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.16)))
            }

            VStack(spacing: 8) {
                Text("Votre messagerie officielle @viplemail.fr")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Synchronisation instantanée avec votre compte Viple Live ID, 5 Go de stockage Cloud SkyDrive, boîte de réception Prioritaire et carnet d'adresses VIP.")
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Détection Automatique SSO Inter-Applications (Livria Store / Livria Social / Viple)

    private func crossAppSSOBanner(account: VipleCrossAppAccount) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VipleMailAvatarView(
                    name: account.displayName,
                    email: account.email,
                    size: 48,
                    isVip: true
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(VipleMailPalette.primary)
                        Text("SESSION VIPLE LIVE ID DÉTECTÉE")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text(account.displayName)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("\(account.email) • Actif sur \(account.sourceApp ?? "l'écosystème Viple")")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer()
            }

            Button {
                Task {
                    await vm.acceptDetectedCrossAppAccount()
                }
            } label: {
                HStack(spacing: 8) {
                    if vm.isAcceptingCrossAppSSO {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "bolt.shield.fill")
                    }
                    Text("Ouvrir la boîte de \(account.displayName) en 1 toucher")
                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
            .disabled(vm.isAcceptingCrossAppSSO)
        }
        .vipleMailCard(cornerRadius: 22, padding: 16)
    }

    private var tabSelectorCard: some View {
        HStack(spacing: 8) {
            ForEach(AuthTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = tab
                        localValidationError = nil
                        vm.authErrorMessage = nil
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(selectedTab == tab ? VipleMailPalette.primary : Color.clear)
                        )
                        .foregroundStyle(selectedTab == tab ? Color.white : VipleMailPalette.ink)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(VipleMailPalette.surface)
        )
    }

    // MARK: - Sign in with Apple

    private var appleSignInCard: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handleAppleSignInResult(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Connexion instantanée avec votre compte Apple relié à Viple Live ID.")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .vipleMailCard(cornerRadius: 20, padding: 16)
    }

    // MARK: - Formulaire de Connexion Viple Live ID

    private var loginFormCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.title3)
                    .foregroundStyle(VipleMailPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connexion Viple Live ID")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Saisissez votre adresse @viplemail.fr ou votre identifiant Viple")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }

            if let err = localValidationError ?? vm.authErrorMessage {
                errorAlertBanner(err)
            }

            if let notice = vm.applePasswordSetupNotice {
                Text(notice)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(VipleMailPalette.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(VipleMailPalette.primary.opacity(0.10))
                    )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Adresse @viplemail.fr ou identifiant")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "at")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField("ex: prenom.nom@viplemail.fr", text: $loginEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mot de passe Viple Live ID")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(VipleMailPalette.primary)
                    SecureField("Votre mot de passe", text: $loginPassword)
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )
            }

            Button {
                submitLogin()
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                    }
                    Text("Accéder à ma boîte Viple Mail")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
            .disabled(vm.isLoading)
        }
        .vipleMailCard(cornerRadius: 22, padding: 18)
    }

    // MARK: - Formulaire de Création de Boîte @viplemail.fr

    private var registerFormCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.title3)
                    .foregroundStyle(VipleMailPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Créer votre boîte @viplemail.fr")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Crée simultanément votre compte unifié Viple Live ID")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
            }

            if let err = localValidationError ?? vm.authErrorMessage {
                errorAlertBanner(err)
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prénom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    TextField("Prénom", text: $firstName)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    TextField("Nom", text: $lastName)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Nom affiché dans vos courriers")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField("Ex : Marie Dupont", text: $displayName)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Choisissez votre adresse officielle @viplemail.fr")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 0) {
                    TextField("identifiant", text: $viplemailLocalUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                    Text("@viplemail.fr")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(VipleMailPalette.primary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Mot de passe (minimum 6 caractères)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                SecureField("Mot de passe", text: $signupPassword)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Confirmer le mot de passe")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                SecureField("Confirmer le mot de passe", text: $signupConfirmPassword)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
            }

            Button {
                submitRegister()
            } label: {
                HStack(spacing: 8) {
                    if vm.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "envelope.badge.fill")
                    }
                    Text("Activer ma boîte @viplemail.fr")
                        .font(.system(size: 15.5, weight: .bold, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                )
            }
            .disabled(vm.isLoading)
        }
        .vipleMailCard(cornerRadius: 22, padding: 18)
    }

    // MARK: - Finalisation Sign in with Apple (@viplemail.fr ou Liaison Compte)

    private var appleOnboardingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "apple.logo")
                    .font(.title2)
                    .foregroundStyle(VipleMailPalette.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(appleLinkExistingMode ? "Lier mon compte Viple Live ID" : "Votre adresse @viplemail.fr")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Finalisez votre connexion Apple avec Viple Mail")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer()
                Button {
                    vm.pendingAppleOnboardingUserId = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }
            }

            HStack(spacing: 8) {
                Button {
                    appleLinkExistingMode = false
                } label: {
                    Text("Nouvelle boîte @viplemail.fr")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(!appleLinkExistingMode ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle))
                        .foregroundStyle(!appleLinkExistingMode ? .white : VipleMailPalette.ink)
                }
                Button {
                    appleLinkExistingMode = true
                } label: {
                    Text("J'ai déjà un compte Viple")
                        .font(.system(size: 12.5, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(appleLinkExistingMode ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle))
                        .foregroundStyle(appleLinkExistingMode ? .white : VipleMailPalette.ink)
                }
            }

            if let err = localValidationError ?? vm.authErrorMessage {
                errorAlertBanner(err)
            }

            if appleLinkExistingMode {
                TextField("Adresse @viplemail.fr existante", text: $appleExistingEmail)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                SecureField("Mot de passe Viple Live ID", text: $appleExistingPassword)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                Button {
                    Task {
                        await vm.linkAppleToExistingAccount(email: appleExistingEmail, password: appleExistingPassword)
                    }
                } label: {
                    Text("Associer et ouvrir ma boîte")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.heroGradient))
                }
            } else {
                HStack(spacing: 10) {
                    TextField("Prénom", text: $appleFirstName)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                    TextField("Nom", text: $appleLastName)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))
                }

                TextField("Nom affiché", text: $appleDisplayName)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                HStack(spacing: 0) {
                    TextField("votre.nom", text: $appleViplemailUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                    Text("@viplemail.fr")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(VipleMailPalette.primary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.surfaceSubtle))

                Button {
                    Task {
                        await vm.completeAppleOnboarding(
                            firstName: appleFirstName,
                            lastName: appleLastName,
                            displayName: appleDisplayName.isEmpty ? "\(appleFirstName) \(appleLastName)" : appleDisplayName,
                            vipleMailUser: appleViplemailUser
                        )
                    }
                } label: {
                    Text("Créer ma boîte @viplemail.fr")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 13).fill(VipleMailPalette.heroGradient))
                }
            }
        }
        .vipleMailCard(cornerRadius: 22, padding: 18)
    }

    private var ecosystemFooterCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 22))
                .foregroundStyle(VipleMailPalette.azureGlow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Écosystème Viple Live 2026")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Un seul identifiant pour Viple Mail, Livria Store, Livria Social, Viple & Moi et SkyDrive.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.22), lineWidth: 1))
        )
    }

    private func errorAlertBanner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VipleMailPalette.danger)
            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(VipleMailPalette.danger)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VipleMailPalette.danger.opacity(0.10))
        )
    }

    // MARK: - Actions

    private func submitLogin() {
        localValidationError = nil
        let cleanEmail = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty else {
            localValidationError = "Veuillez saisir votre adresse @viplemail.fr ou votre identifiant Viple Live ID."
            return
        }
        guard !loginPassword.isEmpty else {
            localValidationError = "Veuillez saisir votre mot de passe."
            return
        }
        Task {
            await vm.signIn(email: cleanEmail, password: loginPassword)
        }
    }

    private func submitRegister() {
        localValidationError = nil
        let cleanLocal = viplemailLocalUser.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanLocal.count >= 2 else {
            localValidationError = "Veuillez choisir un identifiant d'au moins 2 caractères pour votre boîte @viplemail.fr."
            return
        }
        guard signupPassword.count >= 6 else {
            localValidationError = "Votre mot de passe doit contenir au moins 6 caractères."
            return
        }
        guard signupPassword == signupConfirmPassword else {
            localValidationError = "Les deux mots de passe ne correspondent pas."
            return
        }
        let fn = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ln = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let dn = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await vm.registerAccount(
                emailMode: "viplemail",
                emailUser: cleanLocal,
                customEmail: "\(cleanLocal)@viplemail.fr",
                password: signupPassword,
                firstName: fn.isEmpty ? cleanLocal.capitalized : fn,
                lastName: ln,
                displayName: dn.isEmpty ? "\(fn) \(ln)".trimmingCharacters(in: .whitespaces) : dn
            )
        }
    }

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let userId = credential.user
                let token = credential.identityToken.flatMap { String(data: $0, encoding: .utf8) }
                let email = credential.email
                let fn = credential.fullName?.givenName
                let ln = credential.fullName?.familyName
                Task {
                    await vm.handleSignInWithApple(
                        appleUserId: userId,
                        identityToken: token,
                        email: email,
                        firstName: fn,
                        lastName: ln
                    )
                }
            }
        case .failure(let error):
            vm.authErrorMessage = error.localizedDescription
        }
    }
}
