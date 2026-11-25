import Foundation
import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Lot 9 : Contacts, Réseau Relationnel & CRM Personnel (#081..#090)

public enum BetaCrmIntelligence {
    public static func warmthScore(for email: String, messages: [VipleMailMessage]) -> Int {
        let clean = email.lowercased()
        let related = messages.filter {
            $0.senderEmail.lowercased() == clean || $0.recipientEmail.lowercased().contains(clean)
        }
        guard !related.isEmpty else { return 12 }
        let iso = ISO8601DateFormatter()
        let mostRecentDays: Double = related.compactMap { iso.date(from: $0.receivedAt) }
            .map { Date().timeIntervalSince($0) / 86400.0 }
            .min() ?? 60.0
        let recencyPts = max(0, 65 - Int(mostRecentDays * 2.0))
        let volumePts = min(35, related.count * 7)
        return min(100, max(10, recencyPts + volumePts))
    }

    public static func localTimeBadge(for tzIdentifier: String) -> (clock: String, reachable: Bool) {
        let tz = TimeZone(identifier: tzIdentifier) ?? .current
        let df = DateFormatter()
        df.timeZone = tz
        df.dateFormat = "HH:mm"
        var cal = Calendar.current
        cal.timeZone = tz
        let hr = cal.component(.hour, from: Date())
        return (df.string(from: Date()), hr >= 8 && hr < 20)
    }

    public static func exportContactsVCard(_ contacts: [VipleMailContact]) -> String {
        contacts.map { c in
            """
            BEGIN:VCARD
            VERSION:3.0
            FN:\(c.displayName)
            EMAIL;TYPE=INTERNET:\(c.contactEmail)
            TEL;TYPE=CELL:\(c.phone)
            ORG:\(c.company)
            TITLE:\(c.jobTitle)
            NOTE:\(c.notes)
            END:VCARD
            """
        }.joined(separator: "\n")
    }
}

public struct BetaContactsCrmToolbarStrip: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var activeModal: VipleBetaFeatureID? = nil

    public init() {}

    private var hasAnyCrmBeta: Bool {
        [.f081, .f082, .f083, .f084, .f085, .f086, .f087, .f088].contains(where: { beta.isEnabled($0) })
    }

    public var body: some View {
        if hasAnyCrmBeta {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    if beta.isEnabled(.f084) {
                        crmPill("Scan Carte OCR", icon: "creditcard.viewfinder", color: .mint) { activeModal = .f084 }
                    }
                    if beta.isEnabled(.f083) {
                        crmPill("Groupes (\(beta.mailingGroups.count))", icon: "person.3.fill", color: VipleMailPalette.primary) { activeModal = .f083 }
                    }
                    if beta.isEnabled(.f088) {
                        crmPill("Graphe Réseau", icon: "point.3.connected.trianglepath.dotted", color: VipleMailPalette.indigo) { activeModal = .f088 }
                    }
                    if beta.isEnabled(.f086) {
                        crmPill("Doublons", icon: "arrow.triangle.merge", color: .orange) { activeModal = .f086 }
                    }
                    if beta.isEnabled(.f085) {
                        crmPill("vCard .vcf", icon: "arrow.up.arrow.down.square.fill", color: .teal) { activeModal = .f085 }
                    }
                    if beta.isEnabled(.f087) {
                        crmPill("Anniversaires", icon: "gift.fill", color: .pink) { activeModal = .f087 }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
            .background(VipleMailPalette.surface)
            .sheet(item: $activeModal) { fid in
                VipleBetaWorkspaceRouterSheet(featureId: fid)
                    .environmentObject(vm)
                    .preferredColorScheme(vm.preferredColorSchemeOverride)
            }
        }
    }

    private func crmPill(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(label).font(.system(size: 11.5, weight: .bold, design: .rounded))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }
}

public struct BetaContactCrm360Sheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @ObservedObject private var voiceRec = BetaChatVoiceRecorder.shared
    @Environment(\.dismiss) private var dismiss

    public let contactEmail: String
    public let displayName: String

    @State private var newPrivateNote: String = ""
    @State private var selectedTimezone: String = "Europe/Paris"

    public init(contactEmail: String, displayName: String) {
        self.contactEmail = contactEmail.lowercased()
        self.displayName = displayName
    }

    private var exchangedMessages: [VipleMailMessage] {
        vm.messages.filter {
            $0.senderEmail.lowercased() == contactEmail || $0.recipientEmail.lowercased().contains(contactEmail)
        }
    }

    private var privateNotes: [BetaContactCrmNote] {
        beta.contactCrmNotes.filter { $0.contactEmail.lowercased() == contactEmail }
    }

    public var body: some View {
        let warmth = BetaCrmIntelligence.warmthScore(for: contactEmail, messages: vm.messages)
        let tzId = beta.contactTimezonesByEmail[contactEmail] ?? selectedTimezone
        let timeBadge = BetaCrmIntelligence.localTimeBadge(for: tzId)

        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        VipleMailAvatarView(name: displayName, email: contactEmail, size: 54, isVip: true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayName).font(.system(size: 17, weight: .black, design: .rounded))
                            Text(contactEmail).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(VipleMailPalette.primary)
                            HStack(spacing: 8) {
                                if beta.isEnabled(.f082) {
                                    Text("🔥 Chaleur \(warmth)°")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(warmth >= 50 ? VipleMailPalette.success : .orange)
                                }
                                if beta.isEnabled(.f089) {
                                    Text("🕒 \(timeBadge.clock) (\(timeBadge.reachable ? "Ouvré" : "Nuit"))")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(timeBadge.reachable ? VipleMailPalette.primary : VipleMailPalette.inkMuted)
                                }
                            }
                        }
                    }
                }

                if beta.isEnabled(.f089) {
                    Section("Fuseau horaire du correspondant (#089)") {
                        Picker("Fuseau", selection: Binding(
                            get: { beta.contactTimezonesByEmail[contactEmail] ?? "Europe/Paris" },
                            set: { newTz in
                                beta.contactTimezonesByEmail[contactEmail] = newTz
                                beta.saveState()
                            }
                        )) {
                            Text("Paris (CET)").tag("Europe/Paris")
                            Text("Londres (GMT)").tag("Europe/London")
                            Text("New York (EST)").tag("America/New_York")
                            Text("Montréal").tag("America/Toronto")
                            Text("Tokyo (JST)").tag("Asia/Tokyo")
                        }
                    }
                }

                if beta.isEnabled(.f090) {
                    Section("Notes privées & Mémos vocaux (#090)") {
                        HStack {
                            TextField("Ajouter une note confidentielle…", text: $newPrivateNote)
                            Button("Noter") {
                                guard !newPrivateNote.isEmpty else { return }
                                beta.contactCrmNotes.insert(BetaContactCrmNote(id: UUID().uuidString, contactEmail: contactEmail, text: newPrivateNote, audioFileName: nil, createdAt: Date()), at: 0)
                                beta.saveState()
                                newPrivateNote = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        Button {
                            Task {
                                if voiceRec.isRecording {
                                    if let d = voiceRec.finishAndReadData() {
                                        let fname = "crm_memo_\(Int(Date().timeIntervalSince1970)).m4a"
                                        let docUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fname)
                                        if let docUrl { try? d.write(to: docUrl) }
                                        beta.contactCrmNotes.insert(BetaContactCrmNote(id: UUID().uuidString, contactEmail: contactEmail, text: "🎙️ Mémo vocal (\(voiceRec.durationSeconds)s)", audioFileName: fname, createdAt: Date()), at: 0)
                                        beta.saveState()
                                    }
                                } else {
                                    _ = await voiceRec.startRecording()
                                }
                            }
                        } label: {
                            Label(voiceRec.isRecording ? "Arrêter l'enregistrement (\(voiceRec.durationSeconds)s)" : "Enregistrer un mémo vocal privé", systemImage: voiceRec.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundStyle(voiceRec.isRecording ? .red : VipleMailPalette.primary)
                        }

                        ForEach(privateNotes) { note in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.text).font(.system(size: 13.5, weight: .medium))
                                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 11))
                                        .foregroundStyle(VipleMailPalette.inkMuted)
                                }
                                Spacer()
                                if let fname = note.audioFileName,
                                   let docUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(fname) {
                                    Button {
                                        Task { await voiceRec.togglePlayAudio(key: note.id, url: docUrl) }
                                    } label: {
                                        Image(systemName: voiceRec.playingAudioKey == note.id ? "stop.circle.fill" : "play.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(VipleMailPalette.primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Section("Chronologie des courriers échangés (\(exchangedMessages.count))") {
                    if exchangedMessages.isEmpty {
                        Text("Aucun courrier récent avec ce correspondant.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    } else {
                        ForEach(exchangedMessages.prefix(20)) { m in
                            Button {
                                dismiss()
                                vm.selectedTab = 0
                                vm.openMessage(m)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.subject).font(.system(size: 13.5, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                    Text("\(m.formattedRelativeDate) • \(m.snippet)").font(.system(size: 12)).foregroundStyle(VipleMailPalette.inkSecondary).lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fiche CRM 360°")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaMailingGroupsPickerSheet: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public var onSelectGroupEmails: ((String) -> Void)? = nil

    @State private var groupName: String = ""
    @State private var emailsRaw: String = ""

    public init(onSelectGroupEmails: ((String) -> Void)? = nil) {
        self.onSelectGroupEmails = onSelectGroupEmails
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Listes de diffusion (#083)") {
                    if beta.mailingGroups.isEmpty {
                        Text("Créez ci-dessous votre première liste de diffusion.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(VipleMailPalette.inkMuted)
                    } else {
                        ForEach(beta.mailingGroups) { grp in
                            Button {
                                onSelectGroupEmails?(grp.memberEmails.joined(separator: ", "))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(grp.name).font(.system(size: 14, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                    Text(grp.memberEmails.joined(separator: ", ")).font(.system(size: 12)).foregroundStyle(VipleMailPalette.primary).lineLimit(1)
                                }
                            }
                        }
                        .onDelete { offsets in
                            beta.mailingGroups.remove(atOffsets: offsets)
                            beta.saveState()
                        }
                    }
                }
                Section("Nouvelle liste d'envoi groupé") {
                    TextField("Nom du groupe (ex: Comité Direction)", text: $groupName)
                    TextField("Adresses séparées par virgule", text: $emailsRaw)
                        .textInputAutocapitalization(.never)
                    Button("Créer le groupe") {
                        let list = emailsRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { $0.contains("@") }
                        guard !groupName.isEmpty, !list.isEmpty else { return }
                        beta.mailingGroups.append(BetaMailingGroup(id: UUID().uuidString, name: groupName, memberEmails: list, colorHex: "#0078D4"))
                        beta.saveState()
                        groupName = ""; emailsRaw = ""
                    }
                }
            }
            .navigationTitle("Groupes de Diffusion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaBusinessCardOcrScannerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem? = nil
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var company: String = ""
    @State private var isScanning: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Section("1. Photographier ou choisir une carte de visite (#084)") {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("Importer la photo de la carte", systemImage: "creditcard.viewfinder")
                }
                if isScanning { ProgressView("Extraction Vision OCR…") }
            }
            Section("2. Informations détectées") {
                TextField("Nom complet", text: $name)
                TextField("Adresse e-mail", text: $email).textInputAutocapitalization(.never)
                TextField("Téléphone", text: $phone)
                TextField("Entreprise", text: $company)
                Button("Enregistrer dans mes Contacts Viple") {
                    Task {
                        let ok = await vm.saveContact(
                            email: email,
                            displayName: name.isEmpty ? email : name,
                            groupName: "Contacts",
                            isFavorite: true,
                            phone: phone,
                            company: company,
                            jobTitle: "",
                            notes: "Importé par Scanner Carte OCR"
                        )
                        if ok { dismiss() }
                    }
                }
                .fontWeight(.bold)
                .disabled(!email.contains("@"))
            }
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                isScanning = true
                let raw = await BetaVisionOcrScannerSheet.recognizeTextInImageData(data)
                let lines = raw.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if let em = BetaProductivityEngine.regexMatches(in: raw, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#).first {
                    email = em.lowercased()
                }
                if let ph = BetaProductivityEngine.regexMatches(in: raw, pattern: #"(?:\+33|0)[1-9](?:[\s.-]?\d{2}){4}"#).first {
                    phone = ph
                }
                if let firstLine = lines.first(where: { !$0.contains("@") && $0.filter(\.isNumber).count < 4 }) {
                    name = firstLine
                }
                if lines.count >= 2 {
                    company = lines[1]
                }
                isScanning = false
            }
        }
    }
}

public struct BetaVCardImportExportView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var pastedVcf: String = ""

    public init() {}

    public var body: some View {
        let vcfExport = BetaCrmIntelligence.exportContactsVCard(vm.contacts)
        Form {
            Section("Exporter tous mes contacts (.vcf RFC 6350)") {
                Text("\(vm.contacts.count) fiche(s) prête(s) à l'export.")
                    .font(.system(size: 13))
                ShareLink(item: vcfExport, preview: SharePreview("Contacts_VipleMail.vcf")) {
                    Label("Partager / Enregistrer le fichier .vcf", systemImage: "square.and.arrow.up")
                }
            }
            Section("Importer depuis un contenu vCard (.vcf)") {
                TextEditor(text: $pastedVcf).frame(minHeight: 100)
                Button("Analyser et importer") {
                    Task {
                        let cards = pastedVcf.components(separatedBy: "BEGIN:VCARD")
                        var imported = 0
                        for card in cards {
                            let fn = BetaProductivityEngine.regexMatches(in: card, pattern: #"FN:(.+)"#, captureGroup: 1).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            let em = BetaProductivityEngine.regexMatches(in: card, pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#).first ?? ""
                            if !em.isEmpty {
                                _ = await vm.saveContact(email: em, displayName: fn.isEmpty ? em : fn, groupName: "Import vCard", isFavorite: false, phone: "", company: "", jobTitle: "", notes: "")
                                imported += 1
                            }
                        }
                        pastedVcf = ""
                        vm.showToast("📇 \(imported) contact(s) importé(s) !")
                    }
                }
                .disabled(pastedVcf.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

public struct BetaDuplicateContactsMergerView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    private var duplicateGroups: [[VipleMailContact]] {
        let byName = Dictionary(grouping: vm.contacts) { $0.displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return byName.values.filter { $0.count > 1 }
    }

    public var body: some View {
        List {
            Section("Doublons détectés (\(duplicateGroups.count))") {
                if duplicateGroups.isEmpty {
                    Text("Votre carnet d'adresses ne comporte aucun doublon de nom.")
                        .font(.system(size: 13))
                        .foregroundStyle(VipleMailPalette.inkSecondary)
                } else {
                    ForEach(Array(duplicateGroups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group[0].displayName).font(.system(size: 14.5, weight: .bold))
                            Text("\(group.count) fiches trouvées : \(group.map(\.contactEmail).joined(separator: ", "))")
                                .font(.system(size: 12))
                                .foregroundStyle(VipleMailPalette.inkSecondary)
                            Button("Fusionner en une fiche unique") {
                                Task {
                                    for extra in group.dropFirst() {
                                        await vm.deleteContact(extra)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

public struct BetaContactBirthdaysView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEmail: String = ""
    @State private var chosenDate: Date = Date()

    public init() {}

    public var body: some View {
        Form {
            Section("Associer une date clé / anniversaire (#087)") {
                Picker("Contact", selection: $selectedEmail) {
                    Text("Choisir…").tag("")
                    ForEach(vm.contacts) { c in
                        Text(c.displayName).tag(c.contactEmail.lowercased())
                    }
                }
                DatePicker("Date", selection: $chosenDate, displayedComponents: .date)
                Button("Enregistrer") {
                    guard !selectedEmail.isEmpty else { return }
                    beta.contactBirthdaysByEmail[selectedEmail] = chosenDate
                    beta.saveState()
                }
                .disabled(selectedEmail.isEmpty)
            }
            Section("Dates enregistrées (\(beta.contactBirthdaysByEmail.count))") {
                ForEach(beta.contactBirthdaysByEmail.keys.sorted(), id: \.self) { em in
                    if let d = beta.contactBirthdaysByEmail[em] {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(em).font(.system(size: 13.5, weight: .bold))
                                Text(d.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 12)).foregroundStyle(VipleMailPalette.primary)
                            }
                            Spacer()
                            Button("Envoyer vœux") {
                                dismiss()
                                vm.presentComposer(.newMail(
                                    to: em,
                                    subject: "Joyeux anniversaire ! 🎂",
                                    body: "Bonjour,\n\nJe vous souhaite un très joyeux anniversaire et une excellente journée !\n\nBien amicalement,",
                                    forceMail: true
                                ))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}

public struct BetaNetworkDomainGraphView: View {
    @EnvironmentObject private var vm: VipleMailViewModel

    public init() {}

    private var domainClusters: [(domain: String, count: Int)] {
        let emails = vm.messages.map(\.senderEmail) + vm.contacts.map(\.contactEmail)
        let grouped = Dictionary(grouping: emails.filter { $0.contains("@") }) { BetaProductivityEngine.senderDomain(of: $0) }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { $0 }
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text("Graphe Relationnel par Organisation (#088)")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .padding(.top, 10)

            GeometryReader { geo in
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    let radius = min(size.width, size.height) * 0.36
                    for (idx, cluster) in domainClusters.enumerated() {
                        let angle = Double(idx) * (2.0 * .pi / Double(max(1, domainClusters.count)))
                        let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
                        var line = Path()
                        line.move(to: center)
                        line.addLine(to: pt)
                        ctx.stroke(line, with: .color(VipleMailPalette.primary.opacity(0.32)), lineWidth: 1.5)

                        let nodeR = CGFloat(min(30, 14 + cluster.count * 2))
                        ctx.fill(Path(ellipseIn: CGRect(x: pt.x - nodeR, y: pt.y - nodeR, width: nodeR * 2, height: nodeR * 2)), with: .color(VipleMailPalette.indigo.opacity(0.85)))
                        ctx.draw(Text(cluster.domain.prefix(12)).font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white), at: pt)
                    }
                    ctx.fill(Path(ellipseIn: CGRect(x: center.x - 28, y: center.y - 28, width: 56, height: 56)), with: .color(VipleMailPalette.primary))
                    ctx.draw(Text("MOI").font(.system(size: 11, weight: .black)).foregroundStyle(.white), at: center)
                }
            }
            .frame(height: 290)

            List(domainClusters, id: \.domain) { item in
                HStack {
                    Text("@\(item.domain)").font(.system(size: 13.5, weight: .bold))
                    Spacer()
                    Text("\(item.count) interactions").font(.system(size: 12)).foregroundStyle(VipleMailPalette.primary)
                }
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Lot 10 : Fonctions Avancées, Power-Tools & Écosystème (#091..#100)

extension Notification.Name {
    public static let vipleDeviceDidShake = Notification.Name("viple.mail.beta.deviceDidShake")
}

#if canImport(UIKit)
extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        super.motionEnded(motion, with: event)
        if motion == .motionShake {
            NotificationCenter.default.post(name: .vipleDeviceDidShake, object: nil)
        }
    }
}
#endif

public enum BetaBooleanSearchParser {
    /// Filtre par opérateurs booléens Pro (#092) : from:, to:, subject:, domain:, has:attachment, is:unread, is:starred, is:vip, before:, after:
    public static func filterMessages(_ list: [VipleMailMessage], rawQuery: String) -> [VipleMailMessage]? {
        let q = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let operatorPrefixes = ["from:", "to:", "subject:", "domain:", "has:", "is:", "before:", "after:"]
        guard operatorPrefixes.contains(where: { q.lowercased().contains($0) }) else {
            return nil
        }

        let tokens = q.split(separator: " ").map(String.init)
        return list.filter { m in
            let datePrefix = String(m.receivedAt.prefix(10))
            for tok in tokens {
                let low = tok.lowercased()
                if low.hasPrefix("from:") {
                    let v = String(low.dropFirst(5))
                    if !m.senderEmail.lowercased().contains(v) && !m.senderName.lowercased().contains(v) { return false }
                } else if low.hasPrefix("to:") {
                    let v = String(low.dropFirst(3))
                    if !m.recipientEmail.lowercased().contains(v) { return false }
                } else if low.hasPrefix("subject:") {
                    let v = String(low.dropFirst(8))
                    if !m.subject.lowercased().contains(v) { return false }
                } else if low.hasPrefix("domain:") {
                    let v = String(low.dropFirst(7))
                    if !m.senderEmail.lowercased().contains(v) { return false }
                } else if low.hasPrefix("before:") {
                    let v = String(low.dropFirst(7))
                    if datePrefix >= v { return false }
                } else if low.hasPrefix("after:") {
                    let v = String(low.dropFirst(6))
                    if datePrefix <= v { return false }
                } else if low == "has:attachment" && !m.hasAttachments {
                    return false
                } else if low == "is:unread" && m.isRead {
                    return false
                } else if low == "is:starred" && !m.isStarred {
                    return false
                } else if low == "is:vip" && !m.isVipSender {
                    return false
                } else if !operatorPrefixes.contains(where: { low.hasPrefix($0) }) {
                    let hay = "\(m.subject) \(m.senderName) \(m.plainBodyText)".lowercased()
                    if !hay.contains(low) { return false }
                }
            }
            return true
        }
    }
}

public struct BetaUniversalCommandPaletteView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""

    public init() {}

    public var body: some View {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let matchingFeatures = VipleBetaFeatureCatalog.all.filter {
            q.isEmpty || $0.title.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }.prefix(10)
        let matchingMails = vm.messages.filter {
            !q.isEmpty && ($0.subject.lowercased().contains(q) || $0.senderName.lowercased().contains(q))
        }.prefix(6)

        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "command").foregroundStyle(VipleMailPalette.primary)
                    TextField("Taper une action, un courrier ou un numéro #Beta…", text: $query)
                        .textInputAutocapitalization(.never)
                }
                .padding(14)
                .background(VipleMailPalette.surfaceSubtle)

                List {
                    Section("Actions Rapides") {
                        Button("✉️ Rédiger un nouveau courrier") { dismiss(); vm.presentComposer(.newMail()) }
                        Button("☀️ Ouvrir le Briefing Matinal Viple Pulse") { beta.presentedFeatureWorkspace = .f100 }
                        Button("⚡ Lancer Triage Express Inbox Zero") { beta.presentedFeatureWorkspace = .f002 }
                        Button("🔄 Synchroniser la boîte aux lettres") { dismiss(); Task { await vm.refreshBootstrap() } }
                    }
                    if !matchingMails.isEmpty {
                        Section("Courriers correspondants") {
                            ForEach(matchingMails) { m in
                                Button {
                                    dismiss()
                                    vm.selectedTab = 0
                                    vm.openMessage(m)
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(m.subject).font(.system(size: 13.5, weight: .bold))
                                        Text(m.senderEmail).font(.caption).foregroundStyle(VipleMailPalette.primary)
                                    }
                                }
                            }
                        }
                    }
                    Section("Outils du Laboratoire Beta") {
                        ForEach(matchingFeatures) { f in
                            Button {
                                if !beta.isEnabled(f.id) { beta.setEnabled(f.id, true) }
                                beta.presentedFeatureWorkspace = f.id
                            } label: {
                                HStack {
                                    Text(f.code).font(.system(size: 11, weight: .black, design: .monospaced))
                                    Text(f.title).font(.system(size: 13.5, weight: .semibold))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Palette Universelle ⌘K")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaAutomationRulesBuilderView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared

    @State private var name: String = ""
    @State private var matchField: String = "domain"
    @State private var matchQuery: String = ""
    @State private var actionPin: Bool = true
    @State private var actionStar: Bool = false
    @State private var actionMarkRead: Bool = false

    public init() {}

    public var body: some View {
        Form {
            Section("Nouvelle règle automatique « Si → Alors » (#093)") {
                TextField("Nom de la règle", text: $name)
                Picker("Si le champ", selection: $matchField) {
                    Text("Domaine expéditeur").tag("domain")
                    Text("Adresse expéditeur").tag("sender")
                    Text("Objet contient").tag("subject")
                }
                TextField("Valeur recherchée (ex: cenelis.com)", text: $matchQuery)
                    .textInputAutocapitalization(.never)
                Toggle("Alors → Épingler en haut", isOn: $actionPin)
                Toggle("Alors → Ajouter aux Favoris ⭐", isOn: $actionStar)
                Toggle("Alors → Marquer comme lu", isOn: $actionMarkRead)

                Button("Enregistrer la règle") {
                    beta.automationRules.append(BetaAutomationRule(
                        id: UUID().uuidString,
                        name: name,
                        matchField: matchField,
                        matchQuery: matchQuery.lowercased(),
                        actionPin: actionPin,
                        actionStar: actionStar,
                        actionMarkRead: actionMarkRead,
                        targetFolder: nil,
                        isEnabled: true
                    ))
                    beta.saveState()
                    name = ""; matchQuery = ""
                }
                .disabled(name.isEmpty || matchQuery.isEmpty)
            }

            Section("Règles actives (\(beta.automationRules.count))") {
                Button("Exécuter toutes les règles sur mes courriers actuels") {
                    Task { await executeRulesNow() }
                }
                .fontWeight(.bold)

                ForEach(beta.automationRules) { rule in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.name).font(.system(size: 14, weight: .bold))
                        Text("Si \(rule.matchField) contient « \(rule.matchQuery) »")
                            .font(.system(size: 12))
                            .foregroundStyle(VipleMailPalette.primary)
                    }
                }
                .onDelete { offsets in
                    beta.automationRules.remove(atOffsets: offsets)
                    beta.saveState()
                }
            }
        }
    }

    private func executeRulesNow() async {
        var matchedTotal = 0
        for rule in beta.automationRules where rule.isEnabled {
            let matchingIds = vm.messages.filter { m in
                switch rule.matchField {
                case "domain", "sender": return m.senderEmail.lowercased().contains(rule.matchQuery)
                default: return m.subject.lowercased().contains(rule.matchQuery)
                }
            }.map(\.id)
            guard !matchingIds.isEmpty else { continue }
            matchedTotal += matchingIds.count
            if rule.actionPin { await vm.performMessageAction(messageIds: matchingIds, action: "toggle_pin") }
            if rule.actionStar { await vm.performMessageAction(messageIds: matchingIds, action: "toggle_star") }
            if rule.actionMarkRead { await vm.performMessageAction(messageIds: matchingIds, action: "mark_read") }
        }
        vm.showToast("⚙️ Automatisation appliquée sur \(matchedTotal) courrier(s)")
    }
}

public struct BetaSovereignExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let message: VipleMailMessage

    public init(message: VipleMailMessage) {
        self.message = message
    }

    private var emlContent: String {
        """
        From: \(message.senderName) <\(message.senderEmail)>
        To: \(message.recipientEmail)
        Subject: \(message.subject)
        Date: \(message.receivedAt)
        Message-ID: <\(message.id)@viplemail.fr>
        MIME-Version: 1.0
        Content-Type: text/plain; charset=utf-8

        \(message.plainBodyText)
        """
    }

    private var jsonArchive: String {
        if let data = try? JSONEncoder().encode(message), let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "{}"
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Export standard RFC 5322 (.eml)") {
                    ShareLink(item: emlContent, preview: SharePreview("\(message.subject).eml")) {
                        Label("Exporter en fichier .eml universel", systemImage: "envelope.badge.shield.half.filled")
                    }
                }
                Section("Impression & Export PDF iOS") {
                    Button {
                        #if canImport(UIKit)
                        let printController = UIPrintInteractionController.shared
                        let info = UIPrintInfo(dictionary: nil)
                        info.outputType = .general
                        info.jobName = message.subject
                        printController.printInfo = info
                        let html = "<h2>\(message.subject)</h2><p><b>De :</b> \(message.senderName) &lt;\(message.senderEmail)&gt;<br/><b>Date :</b> \(message.formattedFullDate)</p><hr/><pre style='white-space:pre-wrap;font-family:-apple-system,sans-serif;'>\(message.plainBodyText)</pre>"
                        printController.printFormatter = UIMarkupTextPrintFormatter(markupText: html)
                        printController.present(animated: true)
                        #endif
                    } label: {
                        Label("Imprimer / Enregistrer en PDF", systemImage: "printer.fill")
                    }
                }
                Section("Archive JSON vérifiable") {
                    ShareLink(item: jsonArchive, preview: SharePreview("mail_\(message.id).json")) {
                        Label("Exporter l'archive JSON brute", systemImage: "curlybraces")
                    }
                }
            }
            .navigationTitle("Export Souverain (#094)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

private final class SimpleRssXmlParser: NSObject, XMLParserDelegate {
    let feedTitle: String
    var articles: [BetaRssArticle] = []
    private var insideItem = false
    private var currentElement = ""
    private var titleBuf = ""
    private var linkBuf = ""
    private var descBuf = ""
    private var dateBuf = ""

    init(feedTitle: String) { self.feedTitle = feedTitle }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        if currentElement == "item" || currentElement == "entry" {
            insideItem = true
            titleBuf = ""; linkBuf = ""; descBuf = ""; dateBuf = ""
        }
        if insideItem && currentElement == "link", let href = attributeDict["href"], linkBuf.isEmpty {
            linkBuf = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard insideItem else { return }
        switch currentElement {
        case "title": titleBuf += string
        case "link": linkBuf += string
        case "description", "summary", "content": descBuf += string
        case "pubdate", "updated", "published": dateBuf += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let el = elementName.lowercased()
        if el == "item" || el == "entry" {
            insideItem = false
            let cleanDesc = descBuf.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            articles.append(BetaRssArticle(
                id: UUID().uuidString,
                feedTitle: feedTitle,
                title: titleBuf.trimmingCharacters(in: .whitespacesAndNewlines),
                link: linkBuf.trimmingCharacters(in: .whitespacesAndNewlines),
                summary: String(cleanDesc.prefix(260)),
                pubDate: dateBuf.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
        }
    }
}

public struct BetaRssNewsreaderView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @State private var newTitle: String = ""
    @State private var newUrl: String = ""
    @State private var isLoading: Bool = false

    public init() {}

    public var body: some View {
        List {
            Section("Ajouter un flux RSS / Atom (#095)") {
                TextField("Nom du flux", text: $newTitle)
                TextField("https://exemple.fr/rss.xml", text: $newUrl)
                    .textInputAutocapitalization(.never)
                HStack {
                    Button("S'abonner") {
                        beta.rssFeeds.append(BetaRssFeedSource(id: UUID().uuidString, title: newTitle, feedUrl: newUrl))
                        beta.saveState()
                        newTitle = ""; newUrl = ""
                        Task { await refreshAllFeeds() }
                    }
                    .disabled(!newUrl.hasPrefix("http"))
                    Spacer()
                    Button {
                        Task { await refreshAllFeeds() }
                    } label: {
                        if isLoading { ProgressView() } else { Label("Actualiser", systemImage: "arrow.clockwise") }
                    }
                }
            }
            Section("Articles récents (\(beta.rssArticles.count))") {
                ForEach(beta.rssArticles) { art in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(art.feedTitle).font(.system(size: 10.5, weight: .black)).foregroundStyle(VipleMailPalette.primary)
                        Text(art.title).font(.system(size: 14, weight: .bold))
                        if !art.summary.isEmpty {
                            Text(art.summary).font(.system(size: 12)).foregroundStyle(VipleMailPalette.inkSecondary).lineLimit(3)
                        }
                        if let u = URL(string: art.link) {
                            Link("Lire l'article complet ↗", destination: u)
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .task {
            if beta.rssArticles.isEmpty {
                await refreshAllFeeds()
            }
        }
    }

    private func refreshAllFeeds() async {
        isLoading = true
        var collected: [BetaRssArticle] = []
        for feed in beta.rssFeeds {
            guard let u = URL(string: feed.feedUrl),
                  let (data, _) = try? await URLSession.shared.data(from: u) else { continue }
            let delegate = SimpleRssXmlParser(feedTitle: feed.title)
            let xml = XMLParser(data: data)
            xml.delegate = delegate
            _ = xml.parse()
            collected.append(contentsOf: delegate.articles.prefix(8))
        }
        beta.rssArticles = collected
        isLoading = false
    }
}

public struct BetaClipboardSnippetsVaultView: View {
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public var onPick: ((String) -> Void)? = nil

    @State private var title: String = ""
    @State private var content: String = ""

    public init(onPick: ((String) -> Void)? = nil) {
        self.onPick = onPick
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Capturer ou ajouter un extrait (#096)") {
                    Button("Capturer le presse-papiers iOS actuel") {
                        #if canImport(UIKit)
                        if let str = UIPasteboard.general.string, !str.isEmpty {
                            beta.clipboardSnippets.insert(BetaClipboardSnippet(id: UUID().uuidString, title: String(str.prefix(28)), content: str, isPinned: false, createdAt: Date()), at: 0)
                            beta.saveState()
                        }
                        #endif
                    }
                    TextField("Titre court", text: $title)
                    TextField("Contenu à mémoriser", text: $content)
                    Button("Ajouter au coffre Snippets") {
                        beta.clipboardSnippets.insert(BetaClipboardSnippet(id: UUID().uuidString, title: title.isEmpty ? "Extrait" : title, content: content, isPinned: true, createdAt: Date()), at: 0)
                        beta.saveState()
                        title = ""; content = ""
                    }
                    .disabled(content.isEmpty)
                }
                Section("Mes Snippets enregistrés (\(beta.clipboardSnippets.count))") {
                    ForEach(beta.clipboardSnippets) { item in
                        Button {
                            if let onPick {
                                onPick(item.content)
                                dismiss()
                            } else {
                                #if canImport(UIKit)
                                UIPasteboard.general.string = item.content
                                #endif
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title).font(.system(size: 13.5, weight: .bold)).foregroundStyle(VipleMailPalette.ink)
                                Text(item.content).font(.system(size: 12)).foregroundStyle(VipleMailPalette.inkSecondary).lineLimit(2)
                            }
                        }
                    }
                    .onDelete { offsets in
                        beta.clipboardSnippets.remove(atOffsets: offsets)
                        beta.saveState()
                    }
                }
            }
            .navigationTitle("Coffre de Snippets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
        }
    }
}

public struct BetaLiveNetworkConsoleView: View {
    @State private var samplesMs: [Int] = []
    @State private var logLines: [String] = []
    @State private var isProbing: Bool = false

    public init() {}

    public var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Console Réseau & Latence Serveurs (#097)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                Spacer()
                Button(isProbing ? "Mesure…" : "Lancer 5 sondes") {
                    Task { await runBurstProbes() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isProbing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            Canvas { ctx, size in
                guard samplesMs.count > 1 else { return }
                let maxVal = CGFloat(max(80, samplesMs.max() ?? 80))
                var p = Path()
                for (i, val) in samplesMs.enumerated() {
                    let x = size.width * CGFloat(i) / CGFloat(samplesMs.count - 1)
                    let y = size.height - (CGFloat(val) / maxVal) * (size.height - 16) - 8
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
                ctx.stroke(p, with: .color(VipleMailPalette.success), lineWidth: 2.5)
            }
            .frame(height: 120)
            .background(RoundedRectangle(cornerRadius: 14).fill(VipleMailPalette.surfaceSubtle))
            .padding(.horizontal, 16)

            List(logLines, id: \.self) { line in
                Text(line).font(.system(size: 11.5, design: .monospaced))
            }
            .listStyle(.plain)
        }
        .task {
            if samplesMs.isEmpty { await runBurstProbes() }
        }
    }

    private func runBurstProbes() async {
        isProbing = true
        guard let url = URL(string: "https://mail.viplemail.fr/health") else { isProbing = false; return }
        for i in 1...5 {
            let t0 = CFAbsoluteTimeGetCurrent()
            if let (_, resp) = try? await URLSession.shared.data(from: url),
               let http = resp as? HTTPURLResponse {
                let ms = max(1, Int((CFAbsoluteTimeGetCurrent() - t0) * 1000))
                samplesMs.append(ms)
                logLines.insert("[\(Date().formatted(date: .omitted, time: .standard))] Sonde #\(i) mail.viplemail.fr → HTTP \(http.statusCode) en \(ms) ms", at: 0)
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        isProbing = false
    }
}

public struct BetaOfflineStorageDeduplicatorView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @State private var prefetchedCount: Int = 0
    @State private var isPrefetching: Bool = false

    public init() {}

    public var body: some View {
        let totalMailBytes = vm.messages.reduce(0) { $0 + $1.sizeBytes }
        let allAttachments = vm.messages.flatMap(\.attachments)
        let dupAttachments = Dictionary(grouping: allAttachments) { "\($0.fileName)|\($0.sizeBytes)" }
            .filter { $0.value.count > 1 }

        Form {
            Section("Empreinte locale & Pièces jointes (#099)") {
                HStack {
                    Text("Courriers en cache mémoire")
                    Spacer()
                    Text("\(vm.messages.count) (\(ByteCountFormatter.string(fromByteCount: Int64(totalMailBytes), countStyle: .file)))")
                        .fontWeight(.bold)
                }
                HStack {
                    Text("Pièces jointes dupliquées détectées")
                    Spacer()
                    Text("\(dupAttachments.count)").fontWeight(.bold).foregroundStyle(.orange)
                }
            }
            Section("Mode Avion & Synchronisation Hors-Ligne") {
                Button {
                    Task {
                        isPrefetching = true
                        prefetchedCount = 0
                        for m in vm.messages.prefix(25) {
                            await vm.openMessageAndLoadThread(m)
                            prefetchedCount += 1
                        }
                        isPrefetching = false
                        vm.showToast("✈️ \(prefetchedCount) courriers complets prêts pour le mode Avion")
                    }
                } label: {
                    if isPrefetching {
                        Text("Préchargement hors-ligne (\(prefetchedCount))…")
                    } else {
                        Label("Précharger les 25 derniers courriers complets", systemImage: "airplane")
                    }
                }
                .disabled(isPrefetching)
            }
        }
    }
}

public struct BetaMorningPulseBriefingView: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        let unreadVip = vm.messages.filter { !$0.isRead && $0.isVipSender }
        let unreadTotal = vm.messages.filter { !$0.isRead && $0.folder == "Inbox" }.count
        let todayEvents = vm.agendaEvents.filter { Calendar.current.isDateInToday($0.startDate) }
        let openTasks = beta.actionTasks.filter { !$0.isDone }
        let dueFollowUps = beta.followUpItems.filter { !$0.completed && $0.dueAt <= Date().addingTimeInterval(86400) }

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("BRIEFING EXÉCUTIF • VIPLE PULSE")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                    Text("Bonjour \(vm.currentUser?.displayName ?? "")")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("\(unreadTotal) courrier(s) non lu(s) • \(todayEvents.count) RDV aujourd'hui • \(openTasks.count) tâche(s) active(s)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(VipleMailPalette.heroGradient))

                VStack(alignment: .leading, spacing: 8) {
                    Text("👑 Courriers VIP non lus (\(unreadVip.count))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    if unreadVip.isEmpty {
                        Text("Aucun courrier VIP en attente.").font(.system(size: 13)).foregroundStyle(VipleMailPalette.inkSecondary)
                    } else {
                        ForEach(unreadVip.prefix(5)) { m in
                            Button {
                                dismiss()
                                vm.selectedTab = 0
                                vm.openMessage(m)
                            } label: {
                                HStack {
                                    Text(m.senderName.isEmpty ? m.senderEmail : m.senderName).font(.system(size: 13.5, weight: .bold))
                                    Spacer()
                                    Text(m.subject).font(.system(size: 12.5)).lineLimit(1)
                                }
                            }
                        }
                    }
                }
                .vipleMailCard(cornerRadius: 18, padding: 14)

                VStack(alignment: .leading, spacing: 8) {
                    Text("📅 Agenda du jour (\(todayEvents.count)) & Relances (\(dueFollowUps.count))")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    ForEach(todayEvents) { ev in
                        Text("• \(ev.startDate.formatted(date: .omitted, time: .shortened)) — \(ev.title)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    ForEach(dueFollowUps) { fu in
                        Text("⏰ Relancer : \(fu.subject) (\(fu.recipientOrSenderEmail))")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                .vipleMailCard(cornerRadius: 18, padding: 14)
            }
            .padding(16)
        }
    }
}

// MARK: - Routeur Universel des 100 Espaces Interactifs « VipleBetaWorkspaceRouterSheet »

public struct VipleBetaWorkspaceRouterSheet: View {
    @EnvironmentObject private var vm: VipleMailViewModel
    @ObservedObject private var beta = VipleBetaStore.shared
    @Environment(\.dismiss) private var dismiss
    public let featureId: VipleBetaFeatureID

    public init(featureId: VipleBetaFeatureID) {
        self.featureId = featureId
    }

    public var body: some View {
        let spec = featureId.spec
        NavigationStack {
            Group {
                switch featureId {
                case .f001: BetaSnoozeQueueView()
                case .f002: BetaTriageExpressDeckView()
                case .f003: BetaMailKanbanBoardView()
                case .f004: BetaScreenerQuarantineView()
                case .f005: BetaFollowUpCenterView()
                case .f006: BetaNewsletterUnsubscribeView()
                case .f008: BetaSmartViewBuilderView()
                case .f009: BetaBatchFocusConfigView()
                case .f010: BetaMailAnalyticsDashboardView()
                case .f016: BetaHighlightQuotesNotebookView()
                case .f018: BetaInvoiceCsvAccountingView()
                case .f022: BetaScheduleOutgoingSheet()
                case .f023: BetaTemplatesPickerSheet()
                case .f027: BetaSignaturesManagerSheet()
                case .f028: BetaPhotoCompressorSanitizerSheet()
                case .f029: BetaVisionOcrScannerSheet { txt in
                    #if canImport(UIKit)
                    UIPasteboard.general.string = txt
                    #endif
                    vm.showToast("Texte OCR copié dans le presse-papiers")
                }
                case .f030: BetaMailMergeAssistantSheet()
                case .f031, .f032, .f033, .f034, .f035, .f036, .f037, .f038, .f039, .f040:
                    BetaDesignStudioConfigView()
                case .f044: BetaEncryptedVaultManagerView()
                case .f046, .f049: BetaSecurityAuditLogView()
                case .f047: BetaCloakedAliasGeneratorView()
                case .f075: BetaPomodoroStudioView()
                case .f077: BetaActionTasksManagerView()
                case .f078: BetaWorldClockPlannerView()
                case .f079: BetaRecurringSeriesCreatorView()
                case .f080: BetaWeeklyTimeBalanceView()
                case .f081, .f082, .f089, .f090:
                    if let firstContact = vm.contacts.first {
                        BetaContactCrm360Sheet(contactEmail: firstContact.contactEmail, displayName: firstContact.displayName)
                    } else {
                        BetaContactCrm360Sheet(contactEmail: vm.primaryHostedEmail, displayName: vm.currentUser?.displayName ?? "Mon Profil")
                    }
                case .f083: BetaMailingGroupsPickerSheet()
                case .f084: BetaBusinessCardOcrScannerView()
                case .f085: BetaVCardImportExportView()
                case .f086: BetaDuplicateContactsMergerView()
                case .f087: BetaContactBirthdaysView()
                case .f088: BetaNetworkDomainGraphView()
                case .f091: BetaUniversalCommandPaletteView()
                case .f093: BetaAutomationRulesBuilderView()
                case .f095: BetaRssNewsreaderView()
                case .f096: BetaClipboardSnippetsVaultView()
                case .f097: BetaLiveNetworkConsoleView()
                case .f099: BetaOfflineStorageDeduplicatorView()
                case .f100: BetaMorningPulseBriefingView()
                default:
                    contextualFeatureQuickJumpCard(spec: spec)
                }
            }
            .navigationTitle("\(spec.code) • \(spec.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
    }

    private func contextualFeatureQuickJumpCard(spec: VipleBetaFeatureSpec) -> some View {
        VStack(spacing: 16) {
            Image(systemName: spec.icon)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(spec.category.accentColor)
            Text(spec.title)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text(spec.summary)
                .font(.system(size: 14))
                .foregroundStyle(VipleMailPalette.inkSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                Text(spec.locationHint)
            }
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(spec.category.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(spec.category.accentColor.opacity(0.12)))

            Button("Y accéder directement maintenant") {
                dismiss()
                switch spec.category {
                case .productivity, .reading:
                    vm.selectedTab = 0
                    if let first = vm.displayedMessages.first, spec.category == .reading {
                        vm.openMessage(first)
                    }
                case .composer:
                    vm.presentComposer(.newMail())
                case .chat:
                    vm.selectedTab = 1
                case .visio, .agenda:
                    vm.selectedTab = 2
                case .contactsCrm:
                    vm.selectedTab = 4
                case .security, .designMotion, .powerTools:
                    vm.selectedTab = 0
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
