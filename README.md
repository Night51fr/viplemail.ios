# Viple Mail pour iOS (`viplemail.iOS`)

Application native iOS (Swift 6 / SwiftUI, cible iOS 18.0+) de messagerie officielle **`@viplemail.fr`**, connectée en temps réel aux serveurs officiels **Viple Mail (`viplemail.fr`)** propulsés par **Stalwart Mail Server** et au **SSO Viple Live ID** (`identity-v2.viple.digital`).

## Serveurs Officiels de Production (`viplemail.fr`)
- **Passerelle API Mobile & Webmail** : `https://mail.viplemail.fr/api/mobile/v1/mail` (repli : `https://viplemail.fr/api/mobile/v1/mail`)
- **Serveur Entrant IMAP / IMAPS** : `imap.viplemail.fr` — Port `993` (`SSL/TLS`) / `143` (`STARTTLS`)
- **Serveur Sortant SMTP / Submission** : `smtp.viplemail.fr` — Port `587` (`STARTTLS`) / `465` (`SSL/TLS`)
- **Enregistrement MX** : `10 mail.viplemail.fr`
- **Autodiscover / Profil Apple Mail** : `https://autodiscover.viplemail.fr` & `https://mail.viplemail.fr/api/v1/apple-profile.mobileconfig`

## Fonctionnalités Clés (Zéro Donnée de Démo)
- **Authentification SSO Viple Live ID & Cross-App SSO** :
  - Détection inter-applications stricte (concordance simultanée `deviceId` + IP via `group.store.livria.shared` et `/sso/discover`).
  - Connexion avec n'importe quel compte `@viplemail.fr` / Viple Live ID + jeton signé `Bearer`.
  - Création directe d'une nouvelle boîte `@viplemail.fr` provisionnée instantanément sur Stalwart Mail Server (`imap.viplemail.fr` / `smtp.viplemail.fr`, quota 5 Go).
  - Connexion **Sign in with Apple** avec onboarding `@viplemail.fr` ou liaison d'un compte Viple existant.
- **Boîte de Réception Prioritaire (Focused Inbox) & Recherche Avancée** :
  - Séparation intelligente **Prioritaire / Autres**, section **Messages Épinglés**, et filtres rapides (*Non lus*, *Favoris*, *Contacts VIP*, *Pièces jointes*, *Priorité Haute*).
  - Gestes de balayage (Swipe gauche / droite) personnalisables et sélection multiple en masse.
- **Lecture Riche HTML & Texte par Fil de Conversation** :
  - Regroupement par fil de discussion (`ThreadId`), rendu HTML natif (`WKWebView`) ou texte sélectionnable, téléchargement direct des pièces jointes MIME signées, barre de réponse rapide.
- **Compositeur Complet, Brouillons & Administration IMAP/SMTP** :
  - Auto-complétion des contacts (`dbo.WL_Contacts`), champs `Cc` / `Cci`, priorité, pièces jointes (`PhotosPicker` & `fileImporter`), sauvegarde dans `Drafts`, définition du mot de passe IMAP/SMTP tiers et téléchargement du profil `.mobileconfig` iPhone/Mac.
