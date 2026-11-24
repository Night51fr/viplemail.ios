import SwiftUI
import AuthenticationServices

// MARK: - Authentification Native « Viple Mail » (SSO Viple Live ID, Création de boîte @viplemail.fr, Sign in with Apple & Détection Inter-App)

public struct VipleMailAuthView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.colorScheme) private var colorScheme

    public enum AuthTab: String, CaseIterable {
        case login = "Se connecter"
        case register = "Créer un Viple Live ID"
    }

    @State private var selectedTab: AuthTab = .login
    @State private var isShowingLiveIDCreationStudio: Bool = false
    @State private var studioOrbPulse: Bool = false
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
            VipleMailPalette.authBackdropGradient(for: colorScheme)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    brandHeader

                    if vm.pendingAppleOnboardingUserId != nil {
                        appleOnboardingCard
                    } else {
                        if !vm.isAuthenticated, let detected = vm.detectedCrossAppAccount {
                            crossAppSSOBanner(account: detected)
                        }

                        tabSelectorCard
                        appleSignInCard

                        if selectedTab == .login {
                            loginFormCard
                            vipleLiveIDStudioPromoCard
                        } else {
                            vipleLiveIDStudioPromoCard
                        }

                        ecosystemFooterCard
                        authLegalLinksFooter
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .fullScreenCover(isPresented: $isShowingLiveIDCreationStudio) {
            VipleLiveIDCreationFlowView()
                .environmentObject(vm)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true)) {
                studioOrbPulse = true
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
                Text("Votre messagerie officielle @viplemail.fr & @cenelis.com")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Connectée en direct à mail.viplemail.fr (Stalwart Mail Server), au SSO Viple Live ID et à Cenelis Connect, avec 5 Go de stockage, boîte Prioritaire et carnet VIP.")
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
                    if tab == .register {
                        isShowingLiveIDCreationStudio = true
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
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .id(colorScheme)
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
                    Text("Connexion Viple Live ID & Cenelis")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Saisissez votre adresse @viplemail.fr, @cenelis.com ou votre identifiant SSO")
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

            VStack(alignment: .leading, spacing: 8) {
                Text("Adresse @viplemail.fr, @cenelis.com ou identifiant")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                if let wsHint = vm.detectedWorkspaceEmailHint,
                   vm.detectedCrossAppAccount == nil,
                   loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != wsHint {
                    Button {
                        loginEmail = wsHint
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Utiliser la session Cenelis Workspace : \(wsHint)")
                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.down.left.circle.fill")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(VipleMailPalette.primary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(VipleMailPalette.primary.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 10) {
                    Image(systemName: "at")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField(
                        "ex: prenom@viplemail.fr ou agent@cenelis.com",
                        text: $loginEmail,
                        prompt: VipleMailPalette.prompt("ex: prenom@viplemail.fr ou agent@cenelis.com", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme))
                )

                HStack(spacing: 8) {
                    loginDomainQuickPill(domain: "viplemail.fr", label: "@viplemail.fr", icon: "envelope.fill")
                    loginDomainQuickPill(domain: "cenelis.com", label: "@cenelis.com • Agent Cenelis", icon: "checkmark.seal.fill")
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mot de passe Viple Live ID")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(VipleMailPalette.primary)
                    SecureField(
                        "Votre mot de passe",
                        text: $loginPassword,
                        prompt: VipleMailPalette.prompt("Votre mot de passe", scheme: colorScheme)
                    )
                        .vipleMailTextInput()
                }
                .padding(13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme))
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
                    TextField("Prénom", text: $firstName, prompt: VipleMailPalette.prompt("Prénom", scheme: colorScheme))
                        .vipleMailTextInput()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Nom")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                    TextField("Nom", text: $lastName, prompt: VipleMailPalette.prompt("Nom", scheme: colorScheme))
                        .vipleMailTextInput()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Nom affiché dans vos courriers")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                TextField("Ex : Marie Dupont", text: $displayName, prompt: VipleMailPalette.prompt("Ex : Marie Dupont", scheme: colorScheme))
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Choisissez votre adresse officielle @viplemail.fr")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)

                HStack(spacing: 0) {
                    TextField("identifiant", text: $viplemailLocalUser, prompt: VipleMailPalette.prompt("identifiant", scheme: colorScheme))
                        .vipleMailTextInput()
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
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VipleMailPalette.primary)
                    Text("Agent habilité Groupe Cenelis ? Votre boîte professionnelle @cenelis.com vous est automatiquement proposée dès l'ouverture de l'application.")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(VipleMailPalette.primary.opacity(0.08)))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Mot de passe (minimum 6 caractères)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                SecureField("Mot de passe", text: $signupPassword, prompt: VipleMailPalette.prompt("Mot de passe", scheme: colorScheme))
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Confirmer le mot de passe")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
                SecureField(
                    "Confirmer le mot de passe",
                    text: $signupConfirmPassword,
                    prompt: VipleMailPalette.prompt("Confirmer le mot de passe", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
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
                TextField(
                    "Adresse @viplemail.fr ou @cenelis.com existante",
                    text: $appleExistingEmail,
                    prompt: VipleMailPalette.prompt("Adresse @viplemail.fr ou @cenelis.com existante", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                SecureField(
                    "Mot de passe Viple Live ID",
                    text: $appleExistingPassword,
                    prompt: VipleMailPalette.prompt("Mot de passe Viple Live ID", scheme: colorScheme)
                )
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

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
                    TextField("Prénom", text: $appleFirstName, prompt: VipleMailPalette.prompt("Prénom", scheme: colorScheme))
                        .vipleMailTextInput()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                    TextField("Nom", text: $appleLastName, prompt: VipleMailPalette.prompt("Nom", scheme: colorScheme))
                        .vipleMailTextInput()
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))
                }

                TextField("Nom affiché", text: $appleDisplayName, prompt: VipleMailPalette.prompt("Nom affiché", scheme: colorScheme))
                    .vipleMailTextInput()
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

                HStack(spacing: 0) {
                    TextField("votre.nom", text: $appleViplemailUser, prompt: VipleMailPalette.prompt("votre.nom", scheme: colorScheme))
                        .vipleMailTextInput()
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
                .background(RoundedRectangle(cornerRadius: 12).fill(VipleMailPalette.resolvedSurfaceSubtle(for: colorScheme)))

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

    private var vipleLiveIDStudioPromoCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(VipleMailPalette.primary.opacity(0.16))
                        .frame(width: 52, height: 52)
                        .scaleEffect(studioOrbPulse ? 1.08 : 0.94)

                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(VipleMailPalette.heroGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: VipleMailPalette.primarySolid.opacity(0.32), radius: 8, y: 4)

                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("NOUVEAU • STUDIO INTERACTIF")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                    Text("Créer un Viple Live ID")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                    Text("Parcours animé en 4 étapes avec passeport holographique et boîte @viplemail.fr de 5 Go.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                }
                Spacer(minLength: 0)
            }

            Button {
                isShowingLiveIDCreationStudio = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .bold))
                    Text("Lancer la création étape par étape")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13.5)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.04, green: 0.48, blue: 0.94),
                                    Color(red: 0.30, green: 0.28, blue: 0.94)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .vipleMailCard(cornerRadius: 22, padding: 18)
    }

    private var authLegalLinksFooter: some View {
        HStack(spacing: 14) {
            if let privUrl = URL(string: "https://mail.viplemail.fr/privacy") {
                Link("Politique de confidentialité", destination: privUrl)
            }
            Text("•").foregroundStyle(.white.opacity(0.45))
            if let termsUrl = URL(string: "https://mail.viplemail.fr/terms") {
                Link("Conditions (EULA)", destination: termsUrl)
            }
            Text("•").foregroundStyle(.white.opacity(0.45))
            if let supUrl = URL(string: "https://mail.viplemail.fr/support") {
                Link("Assistance", destination: supUrl)
            }
        }
        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.86))
        .multilineTextAlignment(.center)
        .padding(.top, 2)
    }

    private var ecosystemFooterCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 22))
                .foregroundStyle(VipleMailPalette.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Écosystème Viple Live & Groupe Cenelis")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(VipleMailPalette.ink)
                Text("Un seul identifiant pour Viple Mail, Cenelis Workspace, Livria Store, Livria Social, Viple & Moi et SkyDrive.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(VipleMailPalette.inkSecondary)
            }
            Spacer()
        }
        .vipleMailCard(cornerRadius: 16, padding: 14)
    }

    private func loginDomainQuickPill(domain: String, label: String, icon: String) -> some View {
        let currentLower = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSelected = currentLower.hasSuffix("@\(domain)")
        return Button {
            let trimmed = loginEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            let localPart = trimmed.split(separator: "@").first.map(String.init) ?? ""
            if localPart.isEmpty {
                loginEmail = "@\(domain)"
            } else {
                loginEmail = "\(localPart.lowercased())@\(domain)"
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10.5, weight: .bold))
                Text(label)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isSelected ? .white : VipleMailPalette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? VipleMailPalette.primary : VipleMailPalette.primary.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
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
            localValidationError = "Veuillez saisir votre adresse @viplemail.fr, @cenelis.com ou votre identifiant Viple Live ID."
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
