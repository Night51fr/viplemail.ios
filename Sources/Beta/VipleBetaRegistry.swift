import Foundation
import SwiftUI
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 1. Catégories Officielles du Laboratoire « Fonctions Beta » (10 Catégories × 10 Fonctions = 100 Fonctions)

public enum VipleBetaCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case productivity = "productivity"
    case reading = "reading"
    case composer = "composer"
    case designMotion = "designMotion"
    case security = "security"
    case chat = "chat"
    case visio = "visio"
    case agenda = "agenda"
    case contactsCrm = "contactsCrm"
    case powerTools = "powerTools"

    public var id: String { rawValue }

    public var indexNumber: Int {
        switch self {
        case .productivity: return 1
        case .reading: return 2
        case .composer: return 3
        case .designMotion: return 4
        case .security: return 5
        case .chat: return 6
        case .visio: return 7
        case .agenda: return 8
        case .contactsCrm: return 9
        case .powerTools: return 10
        }
    }

    public var title: String {
        switch self {
        case .productivity: return "Productivité & Tri Intelligent"
        case .reading: return "Lecture Augmentée & Accessibilité"
        case .composer: return "Rédaction Pro & Compositeur"
        case .designMotion: return "Design, Thèmes & Motion 120 Hz"
        case .security: return "Sécurité Souveraine & MailRTE+"
        case .chat: return "Chat Instantané Augmenté"
        case .visio: return "Viple Visio Natif & Studio Pro"
        case .agenda: return "Agenda, Temps & #viplecalandar"
        case .contactsCrm: return "Contacts & CRM Relationnel"
        case .powerTools: return "Fonctions Avancées & Power-Tools"
        }
    }

    public var shortTitle: String {
        switch self {
        case .productivity: return "Productivité"
        case .reading: return "Lecture"
        case .composer: return "Rédaction"
        case .designMotion: return "Design & Motion"
        case .security: return "Sécurité"
        case .chat: return "Chat"
        case .visio: return "Viple Visio"
        case .agenda: return "Agenda"
        case .contactsCrm: return "Contacts CRM"
        case .powerTools: return "Power-Tools"
        }
    }

    public var icon: String {
        switch self {
        case .productivity: return "tray.2.fill"
        case .reading: return "text.magnifyingglass"
        case .composer: return "wand.and.stars"
        case .designMotion: return "sparkles.rectangle.stack.fill"
        case .security: return "lock.shield.fill"
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .visio: return "video.badge.waveform.fill"
        case .agenda: return "calendar.badge.clock"
        case .contactsCrm: return "person.crop.rectangle.stack.fill"
        case .powerTools: return "terminal.fill"
        }
    }

    public var accentColor: Color {
        switch self {
        case .productivity: return Color(red: 0.00, green: 0.47, blue: 0.84)
        case .reading: return Color(red: 0.08, green: 0.56, blue: 0.46)
        case .composer: return Color(red: 0.48, green: 0.28, blue: 0.92)
        case .designMotion: return Color(red: 0.90, green: 0.34, blue: 0.58)
        case .security: return Color(red: 0.12, green: 0.62, blue: 0.38)
        case .chat: return Color(red: 0.04, green: 0.58, blue: 0.88)
        case .visio: return Color(red: 0.35, green: 0.31, blue: 0.94)
        case .agenda: return Color(red: 0.86, green: 0.46, blue: 0.08)
        case .contactsCrm: return Color(red: 0.76, green: 0.52, blue: 0.10)
        case .powerTools: return Color(red: 0.22, green: 0.34, blue: 0.54)
        }
    }
}

// MARK: - 2. Identifiants Typés des 100 Fonctionnalités Beta (#001 à #100)

public enum VipleBetaFeatureID: Int, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    // 1. Productivité & Tri Intelligent (1..10)
    case f001 = 1, f002, f003, f004, f005, f006, f007, f008, f009, f010
    // 2. Lecture Augmentée & Accessibilité (11..20)
    case f011 = 11, f012, f013, f014, f015, f016, f017, f018, f019, f020
    // 3. Rédaction Pro & Compositeur (21..30)
    case f021 = 21, f022, f023, f024, f025, f026, f027, f028, f029, f030
    // 4. Design, Thèmes & Motion 120 Hz (31..40)
    case f031 = 31, f032, f033, f034, f035, f036, f037, f038, f039, f040
    // 5. Sécurité Souveraine & MailRTE+ (41..50)
    case f041 = 41, f042, f043, f044, f045, f046, f047, f048, f049, f050
    // 6. Chat Instantané Augmenté (51..60)
    case f051 = 51, f052, f053, f054, f055, f056, f057, f058, f059, f060
    // 7. Viple Visio Natif & Studio Pro (61..70)
    case f061 = 61, f062, f063, f064, f065, f066, f067, f068, f069, f070
    // 8. Agenda, Temps & #viplecalandar (71..80)
    case f071 = 71, f072, f073, f074, f075, f076, f077, f078, f079, f080
    // 9. Contacts & CRM Relationnel (81..90)
    case f081 = 81, f082, f083, f084, f085, f086, f087, f088, f089, f090
    // 10. Fonctions Avancées & Power-Tools (91..100)
    case f091 = 91, f092, f093, f094, f095, f096, f097, f098, f099, f100

    public var id: Int { rawValue }

    public var formattedCode: String {
        String(format: "#%03d", rawValue)
    }

    public var spec: VipleBetaFeatureSpec {
        VipleBetaFeatureCatalog.spec(for: self)
    }
}

public struct VipleBetaFeatureSpec: Identifiable, Equatable, Sendable {
    public let id: VipleBetaFeatureID
    public let category: VipleBetaCategory
    public let title: String
    public let summary: String
    public let locationHint: String
    public let icon: String

    public var number: Int { id.rawValue }
    public var code: String { id.formattedCode }
}

// MARK: - 3. Catalogue Exhaustif des 100 Fonctionnalités Beta

public enum VipleBetaFeatureCatalog {
    public static let all: [VipleBetaFeatureSpec] = [
        // --- LOT 1 : PRODUCTIVITÉ & TRI INTELLIGENT (001..010) ---
        .init(id: .f001, category: .productivity, title: "Snooze & Mise en Sommeil Intelligente", summary: "Masque un courrier jusqu'à une échéance choisie (Ce soir, Demain 9h, Ce week-end, Semaine prochaine, Date libre) et le réveille automatiquement en tête de boîte.", locationHint: "Boîte de réception (balayage / barre Beta) & Lecteur de courrier", icon: "moon.zzz.fill"),
        .init(id: .f002, category: .productivity, title: "Mode Triage Express « Inbox Zero »", summary: "Studio plein écran de tri rapide en pile de cartes tactiles (Droite = Archiver, Gauche = Snooze, Haut = Favori, Bas = Corbeille) avec compteur de progression.", locationHint: "Boîte de réception > Barre Beta « Triage Express »", icon: "rectangle.stack.badge.checkmark"),
        .init(id: .f003, category: .productivity, title: "Tableau Kanban des Courriers", summary: "Organise vos courriers en 4 colonnes métier (À traiter, En cours, En attente, Terminé) avec déplacement instantané et ouverture directe.", locationHint: "Boîte de réception > Bascule Liste / Kanban", icon: "square.split.3x1.fill"),
        .init(id: .f004, category: .productivity, title: "Sas de Quarantaine des Nouveaux Expéditeurs", summary: "Filtre les premiers expéditeurs inconnus dans un sas de validation permettant d'Autoriser ou Bloquer définitivement leur adresse en 1 toucher.", locationHint: "Boîte de réception > Bannière Screener", icon: "person.badge.shield.checkmark.fill"),
        .init(id: .f005, category: .productivity, title: "Suivi des Réponses Attendues & Relances Auto", summary: "Suit les mails nécessitant une réponse avec échéance (J+2, J+5, J+7) et génère en 1 clic un brouillon de relance poli et contextualisé.", locationHint: "Lecteur de mail & Boîte > Panneau Relances", icon: "arrow.uturn.forward.circle.fill"),
        .init(id: .f006, category: .productivity, title: "Centre de Désabonnement 1-Clic & Newsletters", summary: "Regroupe automatiquement les newsletters et envois commerciaux détectés avec désabonnement RFC 8058 / mailto et archivage groupé.", locationHint: "Boîte de réception > Centre Newsletters", icon: "newspaper.fill"),
        .init(id: .f007, category: .productivity, title: "Notes Post-it Privées & Étiquettes Couleur", summary: "Épingle une note adhésive privée (Jaune, Azur, Menthe, Corail) et des étiquettes personnalisées sur n'importe quel mail sans modifier l'original.", locationHint: "Lecteur de courrier & Badges dans la Boîte", icon: "note.text"),
        .init(id: .f008, category: .productivity, title: "Dossiers Dynamiques & Vues Intelligentes", summary: "Crée des vues filtrées multi-critères dynamiques (ex: PDF non lus, domaine spécifique, courriers lourds > 1 Mo) recalculées en direct.", locationHint: "Boîte de réception & Onglet Dossiers", icon: "sparkles.tv.fill"),
        .init(id: .f009, category: .productivity, title: "Livraison par Lots & Mode Concentration", summary: "Retient silencieusement les courriers non-VIP hors de vos créneaux choisis (ex: 09h, 13h, 18h) pour protéger votre concentration, avec déblocage 1-clic.", locationHint: "Boîte de réception > Bandeau Batch Focus", icon: "bell.and.waves.left.and.right.fill"),
        .init(id: .f010, category: .productivity, title: "Tableau de Bord Analytique & Hygiène Mail", summary: "Statistiques temps réel de votre messagerie : top expéditeurs, répartition horaire, taux de lecture, poids des pièces jointes et score Inbox Zero.", locationHint: "Boîte de réception & Dossiers > Analytique", icon: "chart.bar.xaxis"),

        // --- LOT 2 : LECTURE AUGMENTÉE & ACCESSIBILITÉ (011..020) ---
        .init(id: .f011, category: .reading, title: "Lecteur Audio & Mode Podcast des Mails (TTS)", summary: "Lit à voix haute vos courriers ou toute votre file non lue via synthèse vocale native iOS avec contrôle Play/Pause, vitesse (0.75x à 2x) et saut.", locationHint: "Lecteur de courrier & Boîte > Mode Podcast", icon: "headphones"),
        .init(id: .f012, category: .reading, title: "Synthèse Exécutive Structurée (TL;DR & Actions)", summary: "Extrait en haut du mail l'essentiel en points clés, les questions posées, les montants financiers et les dates d'échéance détectés.", locationHint: "Lecteur de courrier > Carte TL;DR", icon: "list.bullet.clipboard.fill"),
        .init(id: .f013, category: .reading, title: "Extracteur Intelligent (OTP, Colis, IBAN, Liens)", summary: "Détecte codes de vérification à 6 chiffres, numéros de colis, IBAN, téléphones et liens clés avec boutons d'action et copie en 1 toucher.", locationHint: "Lecteur de courrier > Barre d'entités détectées", icon: "shippingbox.and.arrow.backward.fill"),
        .init(id: .f014, category: .reading, title: "Mode Lecture Bionic, Dyslexie & Papier Sépia", summary: "Affiche le courrier en typographie de confort : préfixes lexicaux gras (Bionic Reading), taille/interlignage réglables, police accessible et fond Sépia/Crème.", locationHint: "Lecteur de courrier > Bouton Lecture Zen", icon: "book.pages.fill"),
        .init(id: .f015, category: .reading, title: "Traducteur Bilingue Côte-à-Côte Intégré", summary: "Détecte automatiquement la langue du courrier et propose une vue bilingue paragraphe par paragraphe (FR, EN, ES, DE, IT) directement dans le lecteur.", locationHint: "Lecteur de courrier > Panneau Traduction", icon: "character.bubble.fill"),
        .init(id: .f016, category: .reading, title: "Surligneur Multi-Couleurs & Carnet de Citations", summary: "Surligne des extraits importants d'un courrier en 4 couleurs persistantes et centralise toutes vos citations annotées dans un carnet exportable.", locationHint: "Lecteur de courrier > Surligneur & Carnet", icon: "highlighter"),
        .init(id: .f017, category: .reading, title: "Recherche Intra-Courrier avec Saut (1/N)", summary: "Barre de recherche locale dans le mail ouvert surlignant instantanément chaque occurrence trouvée avec navigation Précédent / Suivant.", locationHint: "Lecteur de courrier > Loupe intra-mail", icon: "doc.text.magnifyingglass"),
        .init(id: .f018, category: .reading, title: "Extracteur Comptable de Factures & Export CSV", summary: "Recense automatiquement toutes les factures, reçus et abonnements présents dans vos mails avec montants TTC détectés et export CSV comptable.", locationHint: "Boîte & Lecteur > Coffre Factures CSV", icon: "eurosign.circle.fill"),
        .init(id: .f019, category: .reading, title: "Mode Téléprompteur Mains-Libres", summary: "Défilement vertical automatique et fluide des longs courriers et newsletters à vitesse réglable (Lente, Normale, Rapide) avec pause tactile.", locationHint: "Lecteur de courrier > Barre Téléprompteur", icon: "arrow.down.doc.fill"),
        .init(id: .f020, category: .reading, title: "Fenêtre Flottante de Référence (Lecture Croisée)", summary: "Épingle un courrier en mini-tiroir flottant consultable tout en lisant un autre mail ou en rédigeant une réponse dans le compositeur.", locationHint: "Lecteur de courrier & Compositeur > Tiroir Référence", icon: "pip.enter"),

        // --- LOT 3 : RÉDACTION PRO & COMPOSITEUR AVANCÉ (021..030) ---
        .init(id: .f021, category: .composer, title: "Fenêtre « Annuler l'Envoi » (Undo Send 5s–30s)", summary: "Retient l'envoi réel pendant un compte à rebours configurable (5s à 30s) avec bouton « Annuler » rappelant immédiatement votre brouillon.", locationHint: "Compositeur & Bandeau d'envoi en bas d'écran", icon: "arrow.uturn.backward.circle.fill"),
        .init(id: .f022, category: .composer, title: "Envoi Programmé & File d'Envoi Différé", summary: "Planifie l'expédition d'un courrier à la date et l'heure exactes souhaitées (Demain 8h, Lundi 9h, Date libre) avec file d'attente modifiable.", locationHint: "Compositeur > Horloge d'envoi programmé", icon: "clock.arrow.2.circlepath"),
        .init(id: .f023, category: .composer, title: "Modèles Dynamiques à Variables ({{prenom}})", summary: "Bibliothèque de modèles réutilisables injectant automatiquement {{prenom}}, {{nom}}, {{email}}, {{date}} et {{entreprise}} selon le destinataire.", locationHint: "Compositeur > Barre Beta « Modèles »", icon: "doc.on.doc.fill"),
        .init(id: .f024, category: .composer, title: "Éditeur Markdown Temps Réel vers HTML Stylisé", summary: "Rédigez en Markdown (# Titres, **gras**, listes, citations, code, tableaux) avec aperçu live et conversion en HTML élégant lors de l'envoi.", locationHint: "Compositeur > Mode Markdown Live", icon: "chevron.left.forwardslash.chevron.right"),
        .init(id: .f025, category: .composer, title: "Garde-Fou Pré-Envoi (Pièce Jointe, Objet, Nuit)", summary: "Vérifie avant expédition si vous mentionnez « ci-joint » sans fichier attaché, si l'objet manque ou si vous écrivez tard la nuit.", locationHint: "Compositeur > Audit automatique à l'envoi", icon: "checkmark.shield.fill"),
        .init(id: .f026, category: .composer, title: "Sondages Interactifs par Mail (#viplesondage)", summary: "Insère un sondage multi-options dans votre courrier, rendu sous forme de carte de vote interactive en direct dans le lecteur Viple Mail.", locationHint: "Compositeur & Lecteur de courrier", icon: "chart.pie.fill"),
        .init(id: .f027, category: .composer, title: "Gestionnaire Multi-Signatures Contextuelles", summary: "Crée plusieurs signatures (Direction, Courte Mobile, Anglais, Perso) et bascule instantanément de signature dans le compositeur.", locationHint: "Compositeur > Sélecteur de Signature", icon: "signature"),
        .init(id: .f028, category: .composer, title: "Compresseur Photo, Purge EXIF & Caviardage", summary: "Optimise le poids des images jointes (Éco / Standard / HD), supprime les coordonnées GPS EXIF et permet de masquer des zones sensibles.", locationHint: "Compositeur > Studio Photo Pré-Envoi", icon: "photo.badge.checkmark.fill"),
        .init(id: .f029, category: .composer, title: "Scanner Caméra & Extraction OCR Vision", summary: "Reconnaît instantanément le texte imprimé d'une photo ou d'un document papier via Apple Vision pour l'insérer dans votre brouillon.", locationHint: "Compositeur > Scanner OCR Texte", icon: "doc.viewfinder.fill"),
        .init(id: .f030, category: .composer, title: "Publipostage Individuel Personnalisé (Mail Merge)", summary: "Expédie un courrier personnalisé individuellement à plusieurs contacts (chacun reçoit son propre mail avec son prénom, sans copie visible).", locationHint: "Compositeur > Assistant Publipostage", icon: "person.3.sequence.fill"),

        // --- LOT 4 : DESIGN, THÈMES DYNAMIQUES & MOTION 120 HZ (031..040) ---
        .init(id: .f031, category: .designMotion, title: "Fond Vivant Aurora Circadien 60/120 Hz", summary: "Anime un halo atmosphérique GPU fluide dont les teintes s'harmonisent automatiquement avec le cycle solaire (Aube, Midi, Crépuscule, Nuit).", locationHint: "Coquille principale & En-têtes Viple Mail", icon: "sun.and.horizon.fill"),
        .init(id: .f032, category: .designMotion, title: "Studio de Palettes & Accents Chromatiques", summary: "Personnalise la couleur maîtresse et les dégradés parmi 8 thèmes (Cobalt, Émeraude, Ambre, Violet Cosmique, Rubis, E-Ink, Cyber, Or Rose).", locationHint: "Coquille globale & Studio Chromatique", icon: "paintpalette.fill"),
        .init(id: .f033, category: .designMotion, title: "Célébrations Cinématiques de Particules 60 fps", summary: "Déclenche une gerbe physique de particules lumineuses lors de l'envoi d'un courrier ou lorsque vous atteignez Inbox Zero (0 non lu).", locationHint: "Envoi de courrier & Boîte de réception", icon: "sparkles"),
        .init(id: .f034, category: .designMotion, title: "Sélecteur de Densité & Vignettes Pièces Jointes", summary: "Bascule la liste entre Ultra-Compact (1 ligne), Standard et Magazine Enrichi affichant directement les puces de fichiers joints sous l'extrait.", locationHint: "Boîte de réception > Cellules de courriers", icon: "rectangle.grid.1x2.fill"),
        .init(id: .f035, category: .designMotion, title: "Cartes Holographiques VIP à Reflet Dynamique", summary: "Sublime les courriers issus de vos contacts VIP et entités vérifiées avec un contour irisé animé et un relief lumineux.", locationHint: "Boîte de réception & Lecteur (courriers VIP)", icon: "crown.fill"),
        .init(id: .f036, category: .designMotion, title: "Roue d'Actions Rapides Flottante (Radial Wheel)", summary: "Bouton orbital déplaçable déployant en éventail radial 6 raccourcis instantanés (Nouveau, Chat, Visio, Triage, Palette, Briefing).", locationHint: "Écran principal > Bulle orbitale flottante", icon: "circle.hexagongrid.fill"),
        .init(id: .f037, category: .designMotion, title: "Transitions Cinématiques 3D Entre Courriers", summary: "Enrichit le swipe horizontal entre courriers avec un choix d'animations physiques : Rotation Cube 3D, Page Éditoriale ou Zoom Fluide.", locationHint: "Lecteur de courrier (swipe gauche/droite)", icon: "cube.transparent.fill"),
        .init(id: .f038, category: .designMotion, title: "Avatars Vivants avec Halos de Statut", summary: "Ajoute aux avatars un anneau lumineux d'activité/domaine, un indicateur VIP pulsé et un rendu haute précision dans toute l'application.", locationHint: "Boîte, Lecteur, Chat & Contacts", icon: "person.crop.circle.badge.moon.fill"),
        .init(id: .f039, category: .designMotion, title: "Mode Nuit OLED Pur & Filtre Ambre Réglable", summary: "Active un fond OLED noir pur et superpose un filtre thermique anti-lumière bleue réglable (10 % à 60 %) pour protéger vos yeux le soir.", locationHint: "Superposition globale & Réglages rapides", icon: "eye.circle.fill"),
        .init(id: .f040, category: .designMotion, title: "Moteur Haptique Riche Chorégraphié (CoreHaptics)", summary: "Génère des retours haptiques ciselés par CoreHaptics pour chaque geste (envoi, changement de mail, archivage, alerte VIP).", locationHint: "Toute l'application & Testeur Haptique", icon: "iphone.radiowaves.left.and.right"),

        // --- LOT 5 : SÉCURITÉ SOUVERAINE, CONFIDENTIALITÉ & MAILRTE+ (041..050) ---
        .init(id: .f041, category: .security, title: "Verrouillage Biométrique Face ID & Voile Multitâche", summary: "Exige Face ID / Touch ID ou le code de l'appareil à l'ouverture et floute automatiquement Viple Mail dans le sélecteur multitâche iOS.", locationHint: "Ouverture & Mise en arrière-plan de l'app", icon: "faceid"),
        .init(id: .f042, category: .security, title: "Scanner Anti-Phishing, Homoglyphes & Confiance", summary: "Calcule un score de confiance 0–100 sur chaque courrier en vérifiant usurpation de nom, domaines cousins IDN, liens suspects et fraude IBAN.", locationHint: "Lecteur de courrier > Badge Score Confiance", icon: "shield.lefthalf.filled.badge.checkmark"),
        .init(id: .f043, category: .security, title: "Inspecteur Technique RFC & Chaîne Cryptographique", summary: "Analyse complète des en-têtes techniques, alignement SPF/DKIM/DMARC/BIMI, chiffrement MailRTE/TLS, taille brute MIME et identifiants.", locationHint: "Lecteur de courrier > Inspecteur RFC", icon: "network.badge.shield.half.filled"),
        .init(id: .f044, category: .security, title: "Coffre-Fort Local Chiffré AES-256-GCM Hors-Ligne", summary: "Archive vos courriers sensibles dans un coffre local chiffré par CryptoKit (AES-256-GCM + HKDF) accessible uniquement via votre phrase secrète.", locationHint: "Lecteur de mail & Dossiers > Coffre AES-256", icon: "lock.doc.fill"),
        .init(id: .f045, category: .security, title: "Courriers Éphémères à Auto-Destruction (#vipleephemere)", summary: "Attache une durée de vie (5 min, 1h, 24h, 7j) avec compte à rebours visible et suppression automatique dès l'expiration.", locationHint: "Compositeur & Lecteur de courrier", icon: "flame.fill"),
        .init(id: .f046, category: .security, title: "Bouclier Anti-Pixels Espions & Nettoyeur d'URLs", summary: "Détecte et bloque les pixels invisibles de tracking (1×1) dans les mails HTML et nettoie automatiquement utm_*, fbclid et gclid des liens.", locationHint: "Lecteur de courrier > Bouclier Confidentialité", icon: "hand.raised.shield.fill"),
        .init(id: .f047, category: .security, title: "Générateur d'Alias Cloisonnés (+service@viplemail.fr)", summary: "Crée et suit des adresses alias dédiées par site marchand (prenom+boutique@viplemail.fr) avec désactivation/blocage en 1 clic.", locationHint: "Compositeur & Réglages > Registre d'Alias", icon: "at.badge.plus"),
        .init(id: .f048, category: .security, title: "Filigrane Dynamique Anti-Fuite (Watermark)", summary: "Superpose en diagonale l'identité du lecteur, l'appareil et l'horodatage UTC sur le corps des courriers pour dissuader toute capture photo.", locationHint: "Lecteur de courrier (surimpression)", icon: "checkerboard.shield"),
        .init(id: .f049, category: .security, title: "Journal d'Audit Sécurité & Preuve SHA-256", summary: "Conserve un journal horodaté des événements de sécurité et génère des certificats d'intégrité cryptographique SHA-256 pour tout courrier.", locationHint: "Lecteur & Réglages > Journal d'Audit", icon: "checkmark.seal.text.page.fill"),
        .init(id: .f050, category: .security, title: "Mode Confidentialité Discrète (Anti-Regard Public)", summary: "Masque en 1 clic dans l'en-tête les noms d'expéditeurs, objets et extraits dans les transports ou lieux publics jusqu'à votre déverrouillage.", locationHint: "En-tête supérieur > Icône Mode Discret", icon: "eye.slash.fill"),

        // --- LOT 6 : CHAT INSTANTANÉ AUGMENTÉ @VIPLEMAIL.FR (051..060) ---
        .init(id: .f051, category: .chat, title: "Messages Vocaux Natifs (Onde Live & Vitesse 1x–2x)", summary: "Enregistre des notes vocales AAC directement dans le Chat avec vumètre animé et lecteur intégré à vitesse variable (1x, 1.5x, 2x).", locationHint: "Conversation Chat > Bouton Microphone", icon: "waveform.circle.fill"),
        .init(id: .f052, category: .chat, title: "Réactions Émojis Animées sur les Bulles", summary: "Ajoute des réactions rapides (👍 ❤️ 😂 🔥 👏 ✅) par maintien appuyé ou menu contextuel sous n'importe quelle bulle de conversation.", locationHint: "Conversation Chat > Bulles de messages", icon: "face.smiling.inverse"),
        .init(id: .f053, category: .chat, title: "Réponse Citée par Glissement (Swipe-to-Reply)", summary: "Glissez une bulle de chat vers la droite pour citer précisément ce message et sauter à l'original d'un toucher sur la citation.", locationHint: "Conversation Chat (glissement sur bulle)", icon: "arrowshape.turn.up.left.circle.fill"),
        .init(id: .f054, category: .chat, title: "Sondages Instantanés dans le Chat", summary: "Crée et publie des sondages interactifs directement dans une conversation Chat avec barres de votes calculées en direct.", locationHint: "Conversation Chat > Menu + Sondage", icon: "chart.bar.doc.horizontal.fill"),
        .init(id: .f055, category: .chat, title: "Cartes Structurées (Checklist, Code, Lieu)", summary: "Envoie dans le Chat des listes de tâches cochables en direct, des blocs de code formatés copiables et des fiches de lieu/coordonnées.", locationHint: "Conversation Chat > Menu + Cartes", icon: "checklist"),
        .init(id: .f056, category: .chat, title: "Messages Épinglés en Haut de Conversation", summary: "Épingle les messages importants dans une barre fixe en haut du salon Chat pour y revenir instantanément.", locationHint: "Conversation Chat > Bandeau Épinglés", icon: "pin.circle.fill"),
        .init(id: .f057, category: .chat, title: "Traduction Instantanée des Bulles de Chat", summary: "Traduit à la volée n'importe quel message de chat en français, anglais, espagnol ou allemand directement sous la bulle.", locationHint: "Conversation Chat > Action Traduire", icon: "translate"),
        .init(id: .f058, category: .chat, title: "Brouillons Auto par Salon & Chat Programmé", summary: "Mémorise automatiquement le brouillon propre à chaque conversation et permet de programmer l'envoi différé d'un message de chat.", locationHint: "Conversation Chat > Zone de saisie", icon: "clock.badge.checkmark.fill"),
        .init(id: .f059, category: .chat, title: "Mode Messages Éphémères dans le Chat", summary: "Active un minuteur d'auto-effacement par conversation (1 min, 1h, 24h) avec compte à rebours visible sur les bulles temporaires.", locationHint: "Conversation Chat > En-tête Minuteur", icon: "timer"),
        .init(id: .f060, category: .chat, title: "Galerie Médias, Fichiers & Liens du Chat", summary: "Inspecteur centralisé listant toutes les photos, pièces jointes et URLs partagées dans la conversation avec filtre rapide.", locationHint: "Conversation Chat > En-tête Galerie", icon: "photo.on.rectangle.angled"),

        // --- LOT 7 : VIPLE VISIO NATIF & STUDIO AUDIO/VIDÉO PRO (061..070) ---
        .init(id: .f061, category: .visio, title: "Tableau Blanc Collaboratif Temps Réel en Visio", summary: "Canevas de dessin partagé multi-couleurs synchronisé en direct via WebSocket entre tous les participants de l'appel Viple Visio.", locationHint: "Studio d'appel Viple Visio > Barre Pro", icon: "pencil.and.scribble"),
        .init(id: .f062, category: .visio, title: "Sous-Titres & Transcription Live (Speech Natif)", summary: "Transcrit la voix en direct sur l'appareil et affiche les sous-titres synchronisés pour tous les participants de l'appel audio/vidéo.", locationHint: "Studio d'appel Viple Visio > Bouton CC", icon: "captions.bubble.fill"),
        .init(id: .f063, category: .visio, title: "Réactions Émojis Flottantes & Lever la Main", summary: "Envoie des réactions animées (👍 ❤️ 👏 🔥 🎉) et le signal « Main levée ✋ » diffusés en temps réel à tous les participants du salon.", locationHint: "Studio d'appel Viple Visio > Barre Réactions", icon: "hand.raised.palm.facing.fill"),
        .init(id: .f064, category: .visio, title: "Chat Texte Latéral Temps Réel Pendant l'Appel", summary: "Tiroir de messagerie instantanée intégré au salon Viple Visio pour partager liens, notes et chiffres sans interrompre l'appel.", locationHint: "Studio d'appel Viple Visio > Chat de salon", icon: "text.bubble.fill"),
        .init(id: .f065, category: .visio, title: "Filtres Caméra CoreImage Temps Réel & Flou", summary: "Applique en direct sur votre flux caméra des traitements GPU CoreImage : Éclat Studio, Cinéma Chaud, Monochrome Pro ou Mode Discrétion.", locationHint: "Studio d'appel Viple Visio > Filtres Vidéo", icon: "camera.filters"),
        .init(id: .f066, category: .visio, title: "Notes d'Appel Horodatées & Envoi Auto du CR", summary: "Prend des notes horodatées pendant la réunion ([03:45] Décision...) et ouvre en 1 clic le courrier de compte-rendu prêt à envoyer.", locationHint: "Studio d'appel Viple Visio > Notes CR", icon: "doc.append.fill"),
        .init(id: .f067, category: .visio, title: "Mode Bas-Débit 3G/Train & Moniteur Réseau Live", summary: "Optimise la bande passante en mobilité difficile pour prioriser l'audio HD et affiche débit Ko/s, FPS et latence WebSocket en direct.", locationHint: "Studio d'appel Viple Visio > Mode Éco / HUD", icon: "antenna.radiowaves.left.and.right"),
        .init(id: .f068, category: .visio, title: "Boost Clarté Vocale & Anti-Bruit (AVAudioUnitEQ)", summary: "Active un étage d'égalisation vocale haute intelligibilité (coupe-bas anti-bruit + présence 2.5 kHz) dans le moteur audio natif.", locationHint: "Studio d'appel Viple Visio > Voix HD", icon: "waveform.badge.magnifyingglass"),
        .init(id: .f069, category: .visio, title: "Minuteur d'Ordre du Jour Synchronisé (Timebox)", summary: "Affiche un compte à rebours partagé entre tous les participants (5, 15, 30, 45 min) pour rythmer l'ordre du jour de la réunion.", locationHint: "Studio d'appel Viple Visio > Timebox", icon: "hourglass"),
        .init(id: .f070, category: .visio, title: "Sas Miroir Pré-Appel « Green Room »", summary: "Écran de vérification avant d'entrer dans un salon Visio : aperçu cadrage caméra, vumètre micro en direct et choix muet/caméra.", locationHint: "Ouverture d'un salon Viple Visio", icon: "person.crop.square.filled.and.at.rectangle"),

        // --- LOT 8 : AGENDA, TEMPS & RÉUNIONS #VIPLECALANDAR (071..080) ---
        .init(id: .f071, category: .agenda, title: "Grille Mensuelle Thermique & Frise Horaire 24h", summary: "Ajoute à l'Agenda une vue Calendrier Mensuel complète avec intensité thermique des journées et une frise chronologique heure par heure.", locationHint: "Onglet Agenda > Sélecteur Semaine / Mois / 24h", icon: "calendar"),
        .init(id: .f072, category: .agenda, title: "Détecteur Proactif de Conflits d'Horaires", summary: "Vérifie instantanément les chevauchements avec vos événements existants sur chaque invitation #viplecalandar et création de RDV.", locationHint: "Onglet Agenda & Cartes #viplecalandar", icon: "exclamationmark.triangle.fill"),
        .init(id: .f073, category: .agenda, title: "Proposeur de Créneaux Libres en 1 Clic", summary: "Analyse votre Agenda pour calculer vos 3 prochaines plages disponibles (09h–18h) et les insérer proprement dans votre courrier.", locationHint: "Compositeur & Onglet Agenda", icon: "calendar.badge.checkmark"),
        .init(id: .f074, category: .agenda, title: "Pont Calendrier Apple iOS (EventKit) & Export .ics", summary: "Ajoute vos rendez-vous Viple Agenda directement dans le Calendrier natif d'iOS ou génère un fichier .ics universel partageable.", locationHint: "Onglet Agenda > Menu d'un événement", icon: "square.and.arrow.up.on.square.fill"),
        .init(id: .f075, category: .agenda, title: "Studio Pomodoro & Deep Work Lié à l'Agenda", summary: "Minuteur de concentration 25/5 et 50/10 avec anneau animé, suivi des sessions accomplies et liaison directe à une tâche ou un mail.", locationHint: "Onglet Agenda > Studio Deep Work", icon: "brain.head.profile"),
        .init(id: .f076, category: .agenda, title: "Bannière Compte à Rebours « Réunion Imminente »", summary: "Affiche automatiquement en haut de l'écran un compte à rebours lorsqu'une session Visio débute dans moins de 60 min avec accès 1-clic.", locationHint: "En-tête principal Viple Mail", icon: "bell.badge.fill"),
        .init(id: .f077, category: .agenda, title: "Gestionnaire de Tâches & Conversion Mail → Tâche", summary: "Convertit n'importe quel courrier en tâche avec priorité, échéance, sous-étapes et lien de réouverture directe du mail d'origine.", locationHint: "Lecteur de mail & Onglet Agenda > Tâches", icon: "checkmark.circle.badge.questionmark.fill"),
        .init(id: .f078, category: .agenda, title: "Planificateur Multi-Fuseaux International", summary: "Compare simultanément l'heure d'une réunion à Paris, Londres, New York, Montréal, Dubaï et Tokyo via un curseur horaire interactif.", locationHint: "Onglet Agenda & Compositeur", icon: "globe.americas.fill"),
        .init(id: .f079, category: .agenda, title: "Générateur de Réunions Récurrentes", summary: "Planifie en une seule validation une série de rendez-vous ou salons Visio quotidiens, hebdomadaires ou mensuels dans votre Agenda.", locationHint: "Onglet Agenda > Série récurrente", icon: "repeat.circle.fill"),
        .init(id: .f080, category: .agenda, title: "Bilan Hebdomadaire Réunions vs Temps Calme", summary: "Mesure votre charge hebdomadaire de réunions, votre temps disponible en travail profond et identifie vos journées surchargées.", locationHint: "Onglet Agenda > Bilan Temps", icon: "chart.xyaxis.line"),

        // --- LOT 9 : CONTACTS, RÉSEAU RELATIONNEL & CRM PERSONNEL (081..090) ---
        .init(id: .f081, category: .contactsCrm, title: "Fiche CRM 360° par Contact (Chronologie Unifiée)", summary: "Réunit sur une seule fiche tous les courriers échangés, discussions Chat, rendez-vous Agenda, pièces jointes et notes d'un contact.", locationHint: "Onglet Contacts > Toucher un contact", icon: "person.text.rectangle.fill"),
        .init(id: .f082, category: .contactsCrm, title: "Score de Chaleur Relationnelle & Rappels VIP", summary: "Calcule l'indice d'activité (0–100 °) de chaque relation et vous alerte lorsqu'un contact VIP n'a pas eu de nouvelles depuis longtemps.", locationHint: "Onglet Contacts > Badges Chaleur & Relances", icon: "thermometer.sun.fill"),
        .init(id: .f083, category: .contactsCrm, title: "Listes de Diffusion & Groupes d'Envoi Rapides", summary: "Crée des listes nommées (Direction, Équipe, Clients, Famille) insérables d'un seul toucher dans À, Cc ou Cci du compositeur.", locationHint: "Onglet Contacts & Compositeur", icon: "person.3.fill"),
        .init(id: .f084, category: .contactsCrm, title: "Scanner OCR de Carte de Visite Papier", summary: "Analyse par Apple Vision la photo d'une carte de visite pour extraire automatiquement Nom, Email, Téléphone, Société et Fonction.", locationHint: "Onglet Contacts > Scanner Carte", icon: "creditcard.viewfinder"),
        .init(id: .f085, category: .contactsCrm, title: "Import & Export Universel vCard (.vcf)", summary: "Exporte votre carnet d'adresses en fichier standard .vcf partageable et importe en masse des contacts depuis n'importe quel .vcf.", locationHint: "Onglet Contacts > Barre Outils CRM", icon: "arrow.up.arrow.down.square.fill"),
        .init(id: .f086, category: .contactsCrm, title: "Détecteur & Fusionneur Intelligent de Doublons", summary: "Identifie les contacts en double (email, téléphone ou nom similaire) et les fusionne proprement en unifiant leurs informations.", locationHint: "Onglet Contacts > Dédoublonnage", icon: "arrow.triangle.merge"),
        .init(id: .f087, category: .contactsCrm, title: "Anniversaires & Dates Clés avec Vœux 1-Clic", summary: "Enregistre anniversaires et dates importantes de vos contacts avec rappel visuel et génération immédiate d'un message de vœux.", locationHint: "Onglet Contacts > Dates Clés", icon: "gift.fill"),
        .init(id: .f088, category: .contactsCrm, title: "Graphe Visuel Interactif du Réseau par Domaine", summary: "Cartographie interactive de votre écosystème de correspondants regroupés par organisation/domaine et volume d'échanges.", locationHint: "Onglet Contacts > Graphe Réseau", icon: "point.3.connected.trianglepath.dotted"),
        .init(id: .f089, category: .contactsCrm, title: "Indicateur d'Heure Locale & Joignabilité Contact", summary: "Affiche le fuseau horaire, l'heure locale actuelle et le statut ouvré/nuit d'un correspondant avant de lui écrire ou de l'appeler.", locationHint: "Onglet Contacts & Fiche CRM 360°", icon: "clock.fill"),
        .init(id: .f090, category: .contactsCrm, title: "Mémos Vocaux & Journal Privé sur Fiche Contact", summary: "Attache des notes confidentielles horodatées et des mémos vocaux privés directement sur la fiche d'un interlocuteur.", locationHint: "Onglet Contacts > Fiche CRM 360°", icon: "mic.square.fill"),

        // --- LOT 10 : FONCTIONS AVANCÉES, POWER-TOOLS & ÉCOSYSTÈME (091..100) ---
        .init(id: .f091, category: .powerTools, title: "Palette de Commandes Universelle Rapide (⌘K)", summary: "Lanceur instantané permettant de chercher et déclencher n'importe quelle action, dossier, courrier, contact ou outil Beta en quelques lettres.", locationHint: "En-tête principal > Bouton ⌘K", icon: "command.square.fill"),
        .init(id: .f092, category: .powerTools, title: "Recherche Booléenne par Opérateurs Pro", summary: "Active dans la recherche les opérateurs avancés from:, to:, subject:, has:attachment, is:unread, is:starred, is:vip, domain:, before:, after:.", locationHint: "Boîte de réception > Barre de recherche", icon: "magnifyingglass.circle.fill"),
        .init(id: .f093, category: .powerTools, title: "Constructeur Visuel de Règles « Si → Alors »", summary: "Automatise le classement (Si expéditeur/domaine/mot-clé → Épingler, Favori, Dossier, Étiquette) avec test sur les courriers existants.", locationHint: "Boîte & Réglages > Automatisation Si-Alors", icon: "gearshape.2.fill"),
        .init(id: .f094, category: .powerTools, title: "Studio d'Export Souverain (.eml, PDF, JSON)", summary: "Exporte tout courrier au format standard RFC 5322 (.eml), en PDF mis en page prêt à imprimer ou en archive JSON vérifiable.", locationHint: "Lecteur de courrier > Exporter", icon: "externaldrive.fill.badge.checkmark"),
        .init(id: .f095, category: .powerTools, title: "Lecteur de Flux RSS / Atom de Veille Intégré", summary: "S'abonne à vos flux d'actualités et blogs RSS/Atom favoris et récupère leurs articles en direct pour les lire dans Viple Mail.", locationHint: "Onglet Dossiers & Barre Beta > Veille RSS", icon: "dot.radiowaves.up.forward"),
        .init(id: .f096, category: .powerTools, title: "Presse-Papiers Multi-Entrées & Coffre Snippets", summary: "Conserve jusqu'à 25 extraits réutilisables (réponses types, coordonnées, liens) insérables en 1 clic dans le Compositeur et le Chat.", locationHint: "Compositeur, Chat & Outils > Snippets", icon: "doc.on.clipboard.fill"),
        .init(id: .f097, category: .powerTools, title: "Console Réseau Live & Moniteur de Latence", summary: "Mesure en temps réel la latence API HTTPS, IMAP/SMTP Stalwart et WebSocket Visio avec graphique en millisecondes et journal technique.", locationHint: "Réglages & Outils > Console Réseau Live", icon: "waveform.path.ecg.rectangle.fill"),
        .init(id: .f098, category: .powerTools, title: "Raccourcis Gestuels & Secouer pour Annuler", summary: "Détecte la secousse de l'iPhone pour annuler la dernière mise à la corbeille / archivage et ajoute le retour rapide en haut de liste.", locationHint: "Boîte de réception & Gestes globaux", icon: "hand.draw.fill"),
        .init(id: .f099, category: .powerTools, title: "Gestionnaire Hors-Ligne & Déduplication Stockage", summary: "Inspecte le poids local des caches, repère les pièces jointes lourdes ou dupliquées et précharge vos courriers pour le mode Avion.", locationHint: "Dossiers & Réglages > Stockage Hors-Ligne", icon: "internaldrive.fill"),
        .init(id: .f100, category: .powerTools, title: "Briefing Matinal Exécutif « Viple Pulse »", summary: "Journal quotidien interactif compilant vos courriers VIP non lus, relances échues, tâches prioritaires et réunions Agenda du jour.", locationHint: "En-tête principal & Boîte > Viple Pulse", icon: "sun.max.trianglebadge.exclamationmark.fill")
    ]

    private static let byId: [VipleBetaFeatureID: VipleBetaFeatureSpec] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    public static func spec(for id: VipleBetaFeatureID) -> VipleBetaFeatureSpec {
        byId[id]!
    }

    public static func features(in category: VipleBetaCategory) -> [VipleBetaFeatureSpec] {
        all.filter { $0.category == category }
    }
}

// MARK: - 4. Modèles Persistants Partagés par les 100 Fonctions Beta

public struct BetaSnoozedMail: Codable, Identifiable, Equatable, Sendable {
    public let messageId: String
    public let subject: String
    public let senderName: String
    public let wakeAt: Date
    public var id: String { messageId }
}

public enum BetaKanbanColumn: String, CaseIterable, Codable, Identifiable, Sendable {
    case todo = "À traiter"
    case inProgress = "En cours"
    case waiting = "En attente"
    case done = "Terminé"
    public var id: String { rawValue }
    public var color: Color {
        switch self {
        case .todo: return Color(red: 0.02, green: 0.48, blue: 0.88)
        case .inProgress: return Color(red: 0.90, green: 0.52, blue: 0.08)
        case .waiting: return Color(red: 0.52, green: 0.30, blue: 0.92)
        case .done: return Color(red: 0.10, green: 0.68, blue: 0.42)
        }
    }
}

public struct BetaStickyNote: Codable, Identifiable, Equatable, Sendable {
    public let messageId: String
    public var text: String
    public var colorName: String // "yellow" | "blue" | "mint" | "coral"
    public var tags: [String]
    public var updatedAt: Date
    public var id: String { messageId }
}

public struct BetaFollowUpItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let messageId: String
    public let subject: String
    public let recipientOrSenderEmail: String
    public let recipientOrSenderName: String
    public var dueAt: Date
    public var completed: Bool
}

public struct BetaSmartDynamicView: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var domainFilter: String
    public var keywordFilter: String
    public var unreadOnly: Bool
    public var attachmentsOnly: Bool
    public var vipOnly: Bool
}

public struct BetaHighlightQuote: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let messageId: String
    public let messageSubject: String
    public let senderEmail: String
    public var excerpt: String
    public var colorHex: String
    public let createdAt: Date
}

public struct BetaMailTemplate: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var subjectTemplate: String
    public var bodyTemplate: String
}

public struct BetaSignatureProfile: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var label: String
    public var content: String
}

public struct BetaScheduledOutgoingMail: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var fromMailbox: String
    public var to: String
    public var cc: String
    public var bcc: String
    public var subject: String
    public var bodyText: String
    public var sendAt: Date
}

public enum BetaChromaticTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case vipleCobalt = "Cobalt Viple"
    case cenelisPine = "Émeraude Pin"
    case imperialAmber = "Ambre Impérial"
    case cosmicViolet = "Violet Cosmique"
    case crimsonRuby = "Rubis Souverain"
    case slateEInk = "Ardoise E-Ink"
    case cyberCyan = "Cyber Néon"
    case roseQuartz = "Or Rose"

    public var id: String { rawValue }

    public var primaryColor: Color {
        switch self {
        case .vipleCobalt: return Color(red: 0.00, green: 0.47, blue: 0.84)
        case .cenelisPine: return Color(red: 0.08, green: 0.52, blue: 0.42)
        case .imperialAmber: return Color(red: 0.86, green: 0.48, blue: 0.06)
        case .cosmicViolet: return Color(red: 0.48, green: 0.28, blue: 0.94)
        case .crimsonRuby: return Color(red: 0.82, green: 0.16, blue: 0.28)
        case .slateEInk: return Color(red: 0.26, green: 0.32, blue: 0.40)
        case .cyberCyan: return Color(red: 0.00, green: 0.72, blue: 0.84)
        case .roseQuartz: return Color(red: 0.84, green: 0.34, blue: 0.58)
        }
    }
}

public enum BetaListDensityMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case compact = "Ultra-Compact"
    case standard = "Standard"
    case magazine = "Magazine + PJ"
    public var id: String { rawValue }
}

public enum BetaMailSwipeTransitionStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case slide = "Glissement Fluide"
    case cube3D = "Rotation 3D"
    case editorialZoom = "Fondu Éditorial"
    public var id: String { rawValue }
}

public struct BetaEncryptedVaultRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let originalMessageId: String
    public let subjectHint: String
    public let senderEmail: String
    public let sealedAt: Date
    public let saltBase64: String
    public let combinedCipherBase64: String
    public let sha256Hex: String
}

public struct BetaAliasEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var serviceName: String
    public var aliasEmail: String
    public var isRevoked: Bool
    public let createdAt: Date
}

public struct BetaSecurityAuditEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let timestamp: Date
    public let category: String
    public let summary: String
    public let sha256Fingerprint: String
}

public struct BetaChatPollRecord: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let question: String
    public var options: [String]
    public var votesByOptionIndex: [Int: [String]]
}

public struct BetaScheduledChatItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let sessionId: String
    public let peerEmail: String
    public let text: String
    public let sendAt: Date
}

public struct BetaActionTaskItem: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var notes: String
    public var dueAt: Date?
    public var priority: String // "Haute" | "Normale" | "Basse"
    public var isDone: Bool
    public var sourceMessageId: String?
    public var subtasks: [String]
    public var completedSubtasks: Set<String>
}

public struct BetaMailingGroup: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var memberEmails: [String]
    public var colorHex: String
}

public struct BetaContactCrmNote: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let contactEmail: String
    public var text: String
    public var audioFileName: String?
    public let createdAt: Date
}

public struct BetaAutomationRule: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var matchField: String      // "sender" | "domain" | "subject"
    public var matchQuery: String
    public var actionPin: Bool
    public var actionStar: Bool
    public var actionMarkRead: Bool
    public var targetFolder: String?
    public var isEnabled: Bool
}

public struct BetaRssFeedSource: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var feedUrl: String
}

public struct BetaRssArticle: Identifiable, Equatable, Sendable {
    public let id: String
    public let feedTitle: String
    public let title: String
    public let link: String
    public let summary: String
    public let pubDate: String
}

public struct BetaClipboardSnippet: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var content: String
    public var isPinned: Bool
    public let createdAt: Date
}

public struct BetaUndoActionSnapshot: Equatable, Sendable {
    public let messageIds: [String]
    public let previousFolderByMessageId: [String: String]
    public let description: String
    public let timestamp: Date
}

// MARK: - 5. Moteur Central Observable « VipleBetaStore » (0 / 100 Activées par Défaut)

@MainActor
public final class VipleBetaStore: ObservableObject {
    public static let shared = VipleBetaStore()

    private let defaults = UserDefaults.standard
    private let enabledStorageKey = "viple.mail.beta.enabledFeatureRawIds.v1"
    private let stateBlobStorageKey = "viple.mail.beta.persistentStateBlob.v1"

    /// Par défaut strictement vide (`[]`) : les 100 fonctionnalités sont DÉSACTIVÉES tant que l'utilisateur ne les coche pas.
    @Published public private(set) var enabledIds: Set<VipleBetaFeatureID> = []

    /// Permet d'ouvrir directement l'espace interactif ou le configurateur de n'importe laquelle des 100 fonctions.
    @Published public var presentedFeatureWorkspace: VipleBetaFeatureID? = nil

    // --- États persistants des 100 fonctionnalités ---
    @Published public var snoozedMails: [String: BetaSnoozedMail] = [:]
    @Published public var kanbanAssignments: [String: BetaKanbanColumn] = [:]
    @Published public var approvedScreenerSenders: Set<String> = []
    @Published public var blockedScreenerSenders: Set<String> = []
    @Published public var followUpItems: [BetaFollowUpItem] = []
    @Published public var unsubscribedDomains: Set<String> = []
    @Published public var stickyNotesByMessage: [String: BetaStickyNote] = [:]
    @Published public var smartDynamicViews: [BetaSmartDynamicView] = []
    @Published public var activeSmartViewId: String? = nil
    @Published public var batchDeliveryHours: [Int] = [9, 13, 18]
    @Published public var batchBypassUntil: Date? = nil

    // Lecture (011..020)
    @Published public var bionicFontScale: Double = 1.08
    @Published public var bionicLineSpacing: Double = 7.0
    @Published public var bionicDyslexiaFriendly: Bool = false
    @Published public var bionicPaperTint: String = "sepia" // "clean" | "sepia" | "night"
    @Published public var highlightQuotes: [BetaHighlightQuote] = []
    @Published public var teleprompterSpeedPtsPerSec: Double = 28.0
    @Published public var pinnedReferenceMessage: VipleMailMessage? = nil

    // Rédaction (021..030)
    @Published public var undoSendDelaySeconds: Int = 8
    @Published public var scheduledOutgoingMails: [BetaScheduledOutgoingMail] = []
    @Published public var mailTemplates: [BetaMailTemplate] = []
    @Published public var signatureProfiles: [BetaSignatureProfile] = []
    @Published public var selectedSignatureProfileId: String? = nil
    @Published public var pollVotesByPollId: [String: Int] = [:]

    // Design & Motion (031..040)
    @Published public var selectedChromaticTheme: BetaChromaticTheme = .vipleCobalt
    @Published public var activeParticleBurstTrigger: Int = 0
    @Published public var listDensityMode: BetaListDensityMode = .standard
    @Published public var isRadialWheelExpanded: Bool = false
    @Published public var mailSwipeTransitionStyle: BetaMailSwipeTransitionStyle = .cube3D
    @Published public var oledPureBlackEnabled: Bool = true
    @Published public var amberNightFilterIntensity: Double = 0.22

    // Sécurité & MailRTE+ (041..050)
    @Published public var isBiometricAppUnlocked: Bool = false
    @Published public var encryptedVaultRecords: [BetaEncryptedVaultRecord] = []
    @Published public var ephemeralExpiryByMessageId: [String: Date] = [:]
    @Published public var blockedTrackersTotalCount: Int = 0
    @Published public var generatedAliases: [BetaAliasEntry] = []
    @Published public var securityAuditLog: [BetaSecurityAuditEntry] = []
    @Published public var isPublicStealthMaskActive: Bool = false

    // Chat (051..060)
    @Published public var chatReactionsByMessageId: [String: [String]] = [:]
    @Published public var chatReplyQuoteByMessageId: [String: String] = [:]
    @Published public var chatPinnedMessageIdsBySession: [String: [String]] = [:]
    @Published public var chatAutoDraftBySession: [String: String] = [:]
    @Published public var scheduledChatMessages: [BetaScheduledChatItem] = []
    @Published public var chatEphemeralSecondsBySession: [String: Int] = [:]
    @Published public var chatChecklistDoneKeys: Set<String> = []
    @Published public var chatPollsById: [String: BetaChatPollRecord] = [:]

    // Visio & Agenda (061..080)
    @Published public var activeVisioCameraFilter: String = "none" // "none" | "studio" | "warm" | "mono" | "blur"
    @Published public var visioLowBandwidthMode: Bool = false
    @Published public var visioVoiceClarityBoost: Bool = true
    @Published public var completedPomodoroCountToday: Int = 0
    @Published public var actionTasks: [BetaActionTaskItem] = []

    // Contacts CRM & Power-Tools (081..100)
    @Published public var mailingGroups: [BetaMailingGroup] = []
    @Published public var contactBirthdaysByEmail: [String: Date] = [:]
    @Published public var contactTimezonesByEmail: [String: String] = [:]
    @Published public var contactCrmNotes: [BetaContactCrmNote] = []
    @Published public var automationRules: [BetaAutomationRule] = []
    @Published public var rssFeeds: [BetaRssFeedSource] = []
    @Published public var rssArticles: [BetaRssArticle] = []
    @Published public var clipboardSnippets: [BetaClipboardSnippet] = []
    @Published public var lastUndoSnapshot: BetaUndoActionSnapshot? = nil
    @Published public var isShowingCommandPalette: Bool = false
    @Published public var isShowingMorningPulse: Bool = false

    private struct PersistentStateContainer: Codable {
        var snoozedMails: [String: BetaSnoozedMail] = [:]
        var kanbanAssignments: [String: BetaKanbanColumn] = [:]
        var approvedScreenerSenders: [String] = []
        var blockedScreenerSenders: [String] = []
        var followUpItems: [BetaFollowUpItem] = []
        var unsubscribedDomains: [String] = []
        var stickyNotesByMessage: [String: BetaStickyNote] = [:]
        var smartDynamicViews: [BetaSmartDynamicView] = []
        var batchDeliveryHours: [Int] = [9, 13, 18]
        var bionicFontScale: Double = 1.08
        var bionicLineSpacing: Double = 7.0
        var bionicDyslexiaFriendly: Bool = false
        var bionicPaperTint: String = "sepia"
        var highlightQuotes: [BetaHighlightQuote] = []
        var teleprompterSpeedPtsPerSec: Double = 28.0
        var undoSendDelaySeconds: Int = 8
        var scheduledOutgoingMails: [BetaScheduledOutgoingMail] = []
        var mailTemplates: [BetaMailTemplate] = []
        var signatureProfiles: [BetaSignatureProfile] = []
        var selectedSignatureProfileId: String? = nil
        var pollVotesByPollId: [String: Int] = [:]
        var selectedChromaticTheme: BetaChromaticTheme = .vipleCobalt
        var listDensityMode: BetaListDensityMode = .standard
        var mailSwipeTransitionStyle: BetaMailSwipeTransitionStyle = .cube3D
        var oledPureBlackEnabled: Bool = true
        var amberNightFilterIntensity: Double = 0.22
        var encryptedVaultRecords: [BetaEncryptedVaultRecord] = []
        var ephemeralExpiryByMessageId: [String: Date] = [:]
        var blockedTrackersTotalCount: Int = 0
        var generatedAliases: [BetaAliasEntry] = []
        var securityAuditLog: [BetaSecurityAuditEntry] = []
        var chatReactionsByMessageId: [String: [String]] = [:]
        var chatReplyQuoteByMessageId: [String: String] = [:]
        var chatPinnedMessageIdsBySession: [String: [String]] = [:]
        var chatAutoDraftBySession: [String: String] = [:]
        var scheduledChatMessages: [BetaScheduledChatItem] = []
        var chatEphemeralSecondsBySession: [String: Int] = [:]
        var chatChecklistDoneKeys: [String] = []
        var chatPollsById: [String: BetaChatPollRecord] = [:]
        var activeVisioCameraFilter: String = "none"
        var visioLowBandwidthMode: Bool = false
        var visioVoiceClarityBoost: Bool = true
        var completedPomodoroCountToday: Int = 0
        var actionTasks: [BetaActionTaskItem] = []
        var mailingGroups: [BetaMailingGroup] = []
        var contactBirthdaysByEmail: [String: Date] = [:]
        var contactTimezonesByEmail: [String: String] = [:]
        var contactCrmNotes: [BetaContactCrmNote] = []
        var automationRules: [BetaAutomationRule] = []
        var rssFeeds: [BetaRssFeedSource] = []
        var clipboardSnippets: [BetaClipboardSnippet] = []
    }

    private init() {
        if let rawArray = defaults.array(forKey: enabledStorageKey) as? [Int] {
            self.enabledIds = Set(rawArray.compactMap { VipleBetaFeatureID(rawValue: $0) })
        } else {
            self.enabledIds = [] // Strictement désactivé par défaut (0 / 100)
        }

        loadPersistentState()
        seedHelpfulDefaultsIfEmpty()
    }

    // MARK: - Activation / Désactivation (1 par 1, par Catégorie, ou Tout Activer / Tout Désactiver)

    public var enabledCount: Int {
        enabledIds.count
    }

    public var areAllEnabled: Bool {
        enabledIds.count == VipleBetaFeatureID.allCases.count
    }

    public func isEnabled(_ id: VipleBetaFeatureID) -> Bool {
        enabledIds.contains(id)
    }

    public func toggle(_ id: VipleBetaFeatureID) {
        if enabledIds.contains(id) {
            enabledIds.remove(id)
        } else {
            enabledIds.insert(id)
            if id == .f041 {
                isBiometricAppUnlocked = true // Ne bloque pas brutalement pendant qu'on coche la case
            }
        }
        persistEnabledFlags()
    }

    public func setEnabled(_ id: VipleBetaFeatureID, _ enabled: Bool) {
        if enabled {
            enabledIds.insert(id)
            if id == .f041 {
                isBiometricAppUnlocked = true
            }
        } else {
            enabledIds.remove(id)
        }
        persistEnabledFlags()
    }

    public func enableAll() {
        enabledIds = Set(VipleBetaFeatureID.allCases)
        isBiometricAppUnlocked = true
        persistEnabledFlags()
        recordAudit(category: "BetaLab", summary: "Activation globale des 100 Fonctions Beta")
    }

    public func disableAll() {
        enabledIds.removeAll()
        isPublicStealthMaskActive = false
        activeSmartViewId = nil
        persistEnabledFlags()
        recordAudit(category: "BetaLab", summary: "Désactivation globale des 100 Fonctions Beta")
    }

    public func setCategory(_ category: VipleBetaCategory, enabled: Bool) {
        let ids = VipleBetaFeatureCatalog.features(in: category).map(\.id)
        if enabled {
            for fid in ids {
                enabledIds.insert(fid)
                if fid == .f041 { isBiometricAppUnlocked = true }
            }
        } else {
            for fid in ids {
                enabledIds.remove(fid)
            }
        }
        persistEnabledFlags()
    }

    public func enabledCount(in category: VipleBetaCategory) -> Int {
        VipleBetaFeatureCatalog.features(in: category).filter { enabledIds.contains($0.id) }.count
    }

    private func persistEnabledFlags() {
        let sortedRaw = enabledIds.map(\.rawValue).sorted()
        defaults.set(sortedRaw, forKey: enabledStorageKey)
    }

    // MARK: - Persistance JSON Locale Complète

    public func saveState() {
        let container = PersistentStateContainer(
            snoozedMails: snoozedMails,
            kanbanAssignments: kanbanAssignments,
            approvedScreenerSenders: Array(approvedScreenerSenders),
            blockedScreenerSenders: Array(blockedScreenerSenders),
            followUpItems: followUpItems,
            unsubscribedDomains: Array(unsubscribedDomains),
            stickyNotesByMessage: stickyNotesByMessage,
            smartDynamicViews: smartDynamicViews,
            batchDeliveryHours: batchDeliveryHours,
            bionicFontScale: bionicFontScale,
            bionicLineSpacing: bionicLineSpacing,
            bionicDyslexiaFriendly: bionicDyslexiaFriendly,
            bionicPaperTint: bionicPaperTint,
            highlightQuotes: highlightQuotes,
            teleprompterSpeedPtsPerSec: teleprompterSpeedPtsPerSec,
            undoSendDelaySeconds: undoSendDelaySeconds,
            scheduledOutgoingMails: scheduledOutgoingMails,
            mailTemplates: mailTemplates,
            signatureProfiles: signatureProfiles,
            selectedSignatureProfileId: selectedSignatureProfileId,
            pollVotesByPollId: pollVotesByPollId,
            selectedChromaticTheme: selectedChromaticTheme,
            listDensityMode: listDensityMode,
            mailSwipeTransitionStyle: mailSwipeTransitionStyle,
            oledPureBlackEnabled: oledPureBlackEnabled,
            amberNightFilterIntensity: amberNightFilterIntensity,
            encryptedVaultRecords: encryptedVaultRecords,
            ephemeralExpiryByMessageId: ephemeralExpiryByMessageId,
            blockedTrackersTotalCount: blockedTrackersTotalCount,
            generatedAliases: generatedAliases,
            securityAuditLog: Array(securityAuditLog.prefix(150)),
            chatReactionsByMessageId: chatReactionsByMessageId,
            chatReplyQuoteByMessageId: chatReplyQuoteByMessageId,
            chatPinnedMessageIdsBySession: chatPinnedMessageIdsBySession,
            chatAutoDraftBySession: chatAutoDraftBySession,
            scheduledChatMessages: scheduledChatMessages,
            chatEphemeralSecondsBySession: chatEphemeralSecondsBySession,
            chatChecklistDoneKeys: Array(chatChecklistDoneKeys),
            chatPollsById: chatPollsById,
            activeVisioCameraFilter: activeVisioCameraFilter,
            visioLowBandwidthMode: visioLowBandwidthMode,
            visioVoiceClarityBoost: visioVoiceClarityBoost,
            completedPomodoroCountToday: completedPomodoroCountToday,
            actionTasks: actionTasks,
            mailingGroups: mailingGroups,
            contactBirthdaysByEmail: contactBirthdaysByEmail,
            contactTimezonesByEmail: contactTimezonesByEmail,
            contactCrmNotes: contactCrmNotes,
            automationRules: automationRules,
            rssFeeds: rssFeeds,
            clipboardSnippets: Array(clipboardSnippets.prefix(25))
        )
        if let encoded = try? JSONEncoder().encode(container) {
            defaults.set(encoded, forKey: stateBlobStorageKey)
        }
    }

    private func loadPersistentState() {
        guard let data = defaults.data(forKey: stateBlobStorageKey),
              let c = try? JSONDecoder().decode(PersistentStateContainer.self, from: data) else {
            return
        }
        snoozedMails = c.snoozedMails
        kanbanAssignments = c.kanbanAssignments
        approvedScreenerSenders = Set(c.approvedScreenerSenders)
        blockedScreenerSenders = Set(c.blockedScreenerSenders)
        followUpItems = c.followUpItems
        unsubscribedDomains = Set(c.unsubscribedDomains)
        stickyNotesByMessage = c.stickyNotesByMessage
        smartDynamicViews = c.smartDynamicViews
        batchDeliveryHours = c.batchDeliveryHours
        bionicFontScale = c.bionicFontScale
        bionicLineSpacing = c.bionicLineSpacing
        bionicDyslexiaFriendly = c.bionicDyslexiaFriendly
        bionicPaperTint = c.bionicPaperTint
        highlightQuotes = c.highlightQuotes
        teleprompterSpeedPtsPerSec = c.teleprompterSpeedPtsPerSec
        undoSendDelaySeconds = c.undoSendDelaySeconds
        scheduledOutgoingMails = c.scheduledOutgoingMails
        mailTemplates = c.mailTemplates
        signatureProfiles = c.signatureProfiles
        selectedSignatureProfileId = c.selectedSignatureProfileId
        pollVotesByPollId = c.pollVotesByPollId
        selectedChromaticTheme = c.selectedChromaticTheme
        listDensityMode = c.listDensityMode
        mailSwipeTransitionStyle = c.mailSwipeTransitionStyle
        oledPureBlackEnabled = c.oledPureBlackEnabled
        amberNightFilterIntensity = c.amberNightFilterIntensity
        encryptedVaultRecords = c.encryptedVaultRecords
        ephemeralExpiryByMessageId = c.ephemeralExpiryByMessageId
        blockedTrackersTotalCount = c.blockedTrackersTotalCount
        generatedAliases = c.generatedAliases
        securityAuditLog = c.securityAuditLog
        chatReactionsByMessageId = c.chatReactionsByMessageId
        chatReplyQuoteByMessageId = c.chatReplyQuoteByMessageId
        chatPinnedMessageIdsBySession = c.chatPinnedMessageIdsBySession
        chatAutoDraftBySession = c.chatAutoDraftBySession
        scheduledChatMessages = c.scheduledChatMessages
        chatEphemeralSecondsBySession = c.chatEphemeralSecondsBySession
        chatChecklistDoneKeys = Set(c.chatChecklistDoneKeys)
        chatPollsById = c.chatPollsById
        activeVisioCameraFilter = c.activeVisioCameraFilter
        visioLowBandwidthMode = c.visioLowBandwidthMode
        visioVoiceClarityBoost = c.visioVoiceClarityBoost
        completedPomodoroCountToday = c.completedPomodoroCountToday
        actionTasks = c.actionTasks
        mailingGroups = c.mailingGroups
        contactBirthdaysByEmail = c.contactBirthdaysByEmail
        contactTimezonesByEmail = c.contactTimezonesByEmail
        contactCrmNotes = c.contactCrmNotes
        automationRules = c.automationRules
        rssFeeds = c.rssFeeds
        clipboardSnippets = c.clipboardSnippets
    }

    private func seedHelpfulDefaultsIfEmpty() {
        if mailTemplates.isEmpty {
            mailTemplates = [
                BetaMailTemplate(
                    id: "tpl-pro-followup",
                    name: "Suivi de dossier professionnel",
                    subjectTemplate: "Point d'étape — {{entreprise}}",
                    bodyTemplate: "Bonjour {{prenom}},\n\nSuite à nos derniers échanges du {{date}}, je souhaitais faire un point rapide avec vous concernant l'avancement de notre dossier.\n\nRestant à votre entière disposition,\nBien cordialement,"
                ),
                BetaMailTemplate(
                    id: "tpl-rdv-visio",
                    name: "Proposition d'appel Viple Visio",
                    subjectTemplate: "Entretien Viple Visio — {{prenom}}",
                    bodyTemplate: "Bonjour {{prenom}},\n\nSeriez-vous disponible cette semaine pour un court point de 20 minutes sur Viple Visio ?\n\nÀ très vite,"
                ),
                BetaMailTemplate(
                    id: "tpl-ack",
                    name: "Accusé de bonne réception",
                    subjectTemplate: "Bonne réception de vos éléments",
                    bodyTemplate: "Bonjour {{prenom}},\n\nJe vous confirme la bonne réception de votre courrier et des documents associés. J'en prends connaissance et reviens vers vous rapidement.\n\nCordialement,"
                )
            ]
        }

        if signatureProfiles.isEmpty {
            signatureProfiles = [
                BetaSignatureProfile(id: "sig-exec", label: "Direction & Officielle", content: "Cordialement,\n— Envoyé depuis Viple Mail Souverain • Chiffré MailRTE"),
                BetaSignatureProfile(id: "sig-short", label: "Courte Mobile", content: "Bien à vous,\nEnvoyé depuis mon iPhone (Viple Mail)"),
                BetaSignatureProfile(id: "sig-en", label: "International (EN)", content: "Best regards,\n— Sent securely via Viple Mail iOS")
            ]
            selectedSignatureProfileId = "sig-exec"
        }

        if smartDynamicViews.isEmpty {
            smartDynamicViews = [
                BetaSmartDynamicView(id: "sv-docs-unread", name: "Pièces jointes à lire", domainFilter: "", keywordFilter: "", unreadOnly: true, attachmentsOnly: true, vipOnly: false),
                BetaSmartDynamicView(id: "sv-cenelis", name: "Écosystème Cenelis", domainFilter: "cenelis", keywordFilter: "", unreadOnly: false, attachmentsOnly: false, vipOnly: false),
                BetaSmartDynamicView(id: "sv-factures", name: "Factures & Commandes", domainFilter: "", keywordFilter: "facture", unreadOnly: false, attachmentsOnly: false, vipOnly: false)
            ]
        }

        if rssFeeds.isEmpty {
            rssFeeds = [
                BetaRssFeedSource(id: "rss-certfr", title: "CERT-FR Cybersécurité", feedUrl: "https://www.cert.ssi.gouv.fr/feed/"),
                BetaRssFeedSource(id: "rss-apple", title: "Apple Newsroom", feedUrl: "https://www.apple.com/newsroom/rss-feed.rss")
            ]
        }

        if clipboardSnippets.isEmpty {
            clipboardSnippets = [
                BetaClipboardSnippet(id: "snp-1", title: "Formule de politesse formelle", content: "Je vous prie d'agréer, Madame, Monsieur, l'expression de mes salutations distinguées.", isPinned: true, createdAt: Date()),
                BetaClipboardSnippet(id: "snp-2", title: "Disponibilité réunion", content: "Je suis disponible demain entre 10h00 et 12h00 ou jeudi à partir de 14h30 sur Viple Visio.", isPinned: true, createdAt: Date())
            ]
        }
    }

    // MARK: - Utilitaires Cryptographiques Souverains (#044 Coffre AES-256-GCM & #049 Audit SHA-256)

    public func recordAudit(category: String, summary: String, rawMaterial: String = "") {
        let seed = "\(Date().timeIntervalSince1970)|\(category)|\(summary)|\(rawMaterial)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let entry = BetaSecurityAuditEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            category: category,
            summary: summary,
            sha256Fingerprint: hex
        )
        securityAuditLog.insert(entry, at: 0)
        if securityAuditLog.count > 150 {
            securityAuditLog = Array(securityAuditLog.prefix(150))
        }
        saveState()
    }

    public func sealMessageInVault(_ message: VipleMailMessage, passphrase: String) throws {
        let cleanPass = passphrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanPass.count >= 4 else {
            throw NSError(domain: "VipleVault", code: 1, userInfo: [NSLocalizedDescriptionKey: "La phrase secrète doit contenir au moins 4 caractères."])
        }
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }

        let key = deriveVaultKey(passphrase: cleanPass, salt: salt)
        let payloadDict: [String: String] = [
            "id": message.id,
            "subject": message.subject,
            "from": "\(message.senderName) <\(message.senderEmail)>",
            "to": message.recipientEmail,
            "date": message.formattedFullDate,
            "body": message.plainBodyText
        ]
        let clearData = try JSONEncoder().encode(payloadDict)
        let sealedBox = try AES.GCM.seal(clearData, using: key)
        guard let combined = sealedBox.combined else {
            throw NSError(domain: "VipleVault", code: 2, userInfo: [NSLocalizedDescriptionKey: "Échec de scellement AES-256-GCM."])
        }

        let shaHex = SHA256.hash(data: clearData).map { String(format: "%02x", $0) }.joined()
        let rec = BetaEncryptedVaultRecord(
            id: UUID().uuidString,
            originalMessageId: message.id,
            subjectHint: String(message.subject.prefix(42)),
            senderEmail: message.senderEmail,
            sealedAt: Date(),
            saltBase64: salt.base64EncodedString(),
            combinedCipherBase64: combined.base64EncodedString(),
            sha256Hex: shaHex
        )
        encryptedVaultRecords.insert(rec, at: 0)
        recordAudit(category: "Coffre AES-256", summary: " Courrier scellé : \(rec.subjectHint)", rawMaterial: shaHex)
        saveState()
    }

    public func unsealVaultRecord(_ record: BetaEncryptedVaultRecord, passphrase: String) throws -> [String: String] {
        guard let salt = Data(base64Encoded: record.saltBase64),
              let combined = Data(base64Encoded: record.combinedCipherBase64) else {
            throw NSError(domain: "VipleVault", code: 3, userInfo: [NSLocalizedDescriptionKey: "Enveloppe chiffrée corrompue."])
        }
        let key = deriveVaultKey(passphrase: passphrase.trimmingCharacters(in: .whitespacesAndNewlines), salt: salt)
        let box = try AES.GCM.SealedBox(combined: combined)
        let clearData = try AES.GCM.open(box, using: key)
        let dict = try JSONDecoder().decode([String: String].self, from: clearData)
        recordAudit(category: "Coffre AES-256", summary: "Déchiffrement autorisé : \(record.subjectHint)", rawMaterial: record.sha256Hex)
        return dict
    }

    private func deriveVaultKey(passphrase: String, salt: Data) -> SymmetricKey {
        let inputKey = SymmetricKey(data: Data(passphrase.utf8))
        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data("VipleMail-Sovereign-Vault-v1".utf8),
            outputByteCount: 32
        )
    }

    public func triggerCelebrationParticles() {
        guard isEnabled(.f033) else { return }
        activeParticleBurstTrigger += 1
    }
}
