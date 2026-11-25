import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Écran Officiel « Fonctions Beta » (100 Fonctionnalités avec Cases à Cocher 1 par 1 + « Tout activer »)

public struct VipleBetaSettingsView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    public enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Toutes (100)"
        case enabledOnly = "Activées"
        case disabledOnly = "Désactivées"
        public var id: String { rawValue }
    }

    @State private var searchQuery: String = ""
    @State private var selectedCategory: VipleBetaCategory? = nil
    @State private var statusFilter: StatusFilter = .all

    public init() {}

    private var filteredFeatures: [VipleBetaFeatureSpec] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return VipleBetaFeatureCatalog.all.filter { item in
            if let cat = selectedCategory, item.category != cat {
                return false
            }
            switch statusFilter {
            case .all:
                break
            case .enabledOnly:
                if !beta.isEnabled(item.id) { return false }
            case .disabledOnly:
                if beta.isEnabled(item.id) { return false }
            }
            if !q.isEmpty {
                let haystack = "\(item.code) \(item.number) \(item.title) \(item.summary) \(item.locationHint) \(item.category.title)".lowercased()
                return haystack.contains(q)
            }
            return true
        }
    }

    private var groupedCategories: [VipleBetaCategory] {
        if let cat = selectedCategory {
            return [cat]
        }
        return VipleBetaCategory.allCases.filter { cat in
            filteredFeatures.contains(where: { $0.category == cat })
        }
    }

    public var body: some View {
        let compact = VipleMailLayout.isCompactPhone

        NavigationStack {
            VStack(spacing: 0) {
                topMasterControlHeader(compact: compact)

                ScrollView(showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if filteredFeatures.isEmpty {
                            emptySearchState
                        } else {
                            ForEach(groupedCategories) { category in
                                let items = filteredFeatures.filter { $0.category == category }
                                if !items.isEmpty {
                                    categorySectionView(category: category, items: items, compact: compact)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, compact ? 12 : 16)
                    .padding(.vertical, 14)
                    .padding(.bottom, 28)
                }
            }
            .background(VipleMailPalette.background.ignoresSafeArea())
            .navigationTitle("Fonctions Beta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(beta.enabledCount)/100")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(beta.enabledCount > 0 ? .white : VipleMailPalette.inkSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(beta.enabledCount > 0 ? VipleMailPalette.primary : VipleMailPalette.surfaceSubtle)
                        )
                }
            }
            .sheet(item: $beta.presentedFeatureWorkspace) { featureId in
                VipleBetaWorkspaceRouterSheet(featureId: featureId)
                    .environmentObject(vm)
                    .preferredColorScheme(vm.preferredColorSchemeOverride)
            }
        }
    }

    // MARK: - En-tête Global (« Tout activer » / « Tout désactiver », Recherche & Filtres)

    private func topMasterControlHeader(compact: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: compact ? 9 : 11) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.20), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(beta.enabledCount) / 100.0)
                            .stroke(Color.white, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text("\(beta.enabledCount)")
                            .font(.system(size: compact ? 13 : 14.5, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                    }
                    .frame(width: compact ? 44 : 50, height: compact ? 44 : 50)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Laboratoire Viple Mail Beta")
                            .font(.system(size: compact ? 15 : 16.5, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(beta.enabledCount == 0
                             ? "100 fonctions prêtes • Toutes désactivées par défaut"
                             : "\(beta.enabledCount) fonction\(beta.enabledCount > 1 ? "s" : "") active\(beta.enabledCount > 1 ? "s" : "") sur 100")
                            .font(.system(size: compact ? 11.2 : 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 4)
                }

                HStack(spacing: 8) {
                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            beta.enableAll()
                        }
                        vm.showToast("✨ Les 100 Fonctions Beta sont maintenant activées !")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.square.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Tout activer (100)")
                                .font(.system(size: compact ? 12 : 13, weight: .black, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(VipleMailPalette.cobaltDeep)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white)
                        )
                    }

                    Button {
                        #if canImport(UIKit)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                            beta.disableAll()
                        }
                        vm.showToast("Les 100 Fonctions Beta ont été désactivées.")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square")
                                .font(.system(size: 14, weight: .bold))
                            Text("Tout désactiver")
                                .font(.system(size: compact ? 12 : 13, weight: .bold, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.white.opacity(0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }
                }
            }
            .padding(compact ? 12 : 15)
            .background(VipleMailPalette.heroGradient)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VipleMailPalette.primary)
                    TextField("Rechercher parmi les 100 fonctions (#001, Visio, OCR, Snooze…)", text: $searchQuery)
                        .font(.system(size: 13.5))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchQuery.isEmpty {
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(VipleMailPalette.inkMuted)
                        }
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(VipleMailPalette.surfaceSubtle)
                )

                Picker("État", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { st in
                        Text(st.rawValue).tag(st)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        categoryChipButton(category: nil, title: "Toutes (100)", icon: "square.grid.2x2.fill")
                        ForEach(VipleBetaCategory.allCases) { cat in
                            let countInCat = beta.enabledCount(in: cat)
                            categoryChipButton(
                                category: cat,
                                title: "\(cat.indexNumber). \(cat.shortTitle) (\(countInCat)/10)",
                                icon: cat.icon
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, 9)
            .background(VipleMailPalette.surface)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }

    private func categoryChipButton(category: VipleBetaCategory?, title: String, icon: String) -> some View {
        let isSel = selectedCategory == category
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(isSel ? .white : VipleMailPalette.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSel ? (category?.accentColor ?? VipleMailPalette.primary) : VipleMailPalette.surfaceSubtle)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section d'une Catégorie (10 Fonctions avec Case à Cocher Individuelle)

    private func categorySectionView(category: VipleBetaCategory, items: [VipleBetaFeatureSpec], compact: Bool) -> some View {
        let catActive = beta.enabledCount(in: category)
        let allCatEnabled = catActive == 10

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(category.accentColor.opacity(0.15))
                        .frame(width: 28, height: 28)
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(category.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("\(category.indexNumber). \(category.title)")
                        .font(.system(size: compact ? 14 : 15.5, weight: .black, design: .rounded))
                        .foregroundStyle(VipleMailPalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("\(catActive)/10 cochées dans cette catégorie")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VipleMailPalette.inkMuted)
                }

                Spacer(minLength: 4)

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                        beta.setCategory(category, enabled: !allCatEnabled)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: allCatEnabled ? "checkmark.square.fill" : "square")
                            .font(.system(size: 12, weight: .bold))
                        Text(allCatEnabled ? "Décocher 10" : "Cocher 10")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(category.accentColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(category.accentColor.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 8) {
                ForEach(items) { item in
                    featureCheckboxCard(item: item, compact: compact)
                }
            }
        }
    }

    private func featureCheckboxCard(item: VipleBetaFeatureSpec, compact: Bool) -> some View {
        let checked = beta.isEnabled(item.id)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 11) {
                // Case à cocher explicite 1 par 1
                Button {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                        beta.toggle(item.id)
                    }
                } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(checked ? item.category.accentColor : VipleMailPalette.inkMuted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(checked ? "Désactiver" : "Activer") \(item.title)")

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.code)
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundStyle(checked ? .white : item.category.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(checked ? item.category.accentColor : item.category.accentColor.opacity(0.14))
                            )

                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(item.category.accentColor)

                        Text(item.title)
                            .font(.system(size: compact ? 13.5 : 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(VipleMailPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(item.summary)
                        .font(.system(size: 12))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                        Text(item.locationHint)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if checked {
                            Button {
                                beta.presentedFeatureWorkspace = item.id
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Ouvrir / Configurer")
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                    Image(systemName: "arrow.up.right.circle.fill")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                                .foregroundStyle(item.category.accentColor)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(item.category.accentColor.opacity(0.13)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                    beta.toggle(item.id)
                }
            }
        }
        .padding(compact ? 11 : 13)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(VipleMailPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            checked ? item.category.accentColor.opacity(0.55) : VipleMailPalette.border,
                            lineWidth: checked ? 1.5 : 1
                        )
                )
        )
    }

    private var emptySearchState: some View {
        VStack(spacing: 10) {
            Image(systemName: "flask.fill")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(VipleMailPalette.primary)
            Text("Aucune fonction Beta ne correspond à ce filtre")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(VipleMailPalette.ink)
            Button("Réinitialiser les filtres") {
                searchQuery = ""
                selectedCategory = nil
                statusFilter = .all
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(VipleMailPalette.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }
}
