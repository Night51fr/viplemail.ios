# Viple Mail pour iOS (`viplemail.iOS`)

Application native iOS (Swift 6 / SwiftUI, cible iOS 18.0+) de messagerie officielle **`@viplemail.fr`** & **`@cenelis.com`**, connectée en temps réel aux serveurs officiels **Viple Mail (`mail.viplemail.fr`)** propulsés par **Stalwart Mail Server**, au **SSO Viple Live ID** (`identity-v2.viple.digital`) et à **Cenelis Connect** (`sso.prod.cenelis.com`).

## Serveurs Officiels de Production (`viplemail.fr` & `cenelis.com`)
- **Passerelle API Mobile principale** : `https://mail.viplemail.fr/api/mobile/v1/mail` (repli : `https://viplemail.fr/api/mobile/v1/mail`)
- **Webmail officiel** : `https://mail.viplemail.fr`
- **Serveur Entrant IMAP / IMAPS** : `imap.viplemail.fr` — Port `993` (`SSL/TLS`) / `143` (`STARTTLS`)
- **Serveur Sortant SMTP / Submission** : `smtp.viplemail.fr` — Port `587` (`STARTTLS`) / `465` (`SSL/TLS`)
- **Enregistrements MX** : `10 mail.viplemail.fr` (`viplemail.fr` & `cenelis.com`)
- **Fournisseurs SSO** : `https://identity-v2.viple.digital`, `https://sso.prod.cenelis.com`, `https://api.viple.digital`
- **Autodiscover / Profil Apple Mail** : `https://autodiscover.viplemail.fr` & `https://mail.viplemail.fr/api/v1/apple-profile.mobileconfig`

## Fonctionnalités Clés (Zéro Donnée de Démo)
- **Authentification SSO Viple Live ID, Cenelis Connect & Bascule Multi-Boîtes** :
  - Détection inter-applications stricte (`group.store.livria.shared` et `/sso/discover`).
  - Connexion avec tout compte `@viplemail.fr`, `@cenelis.com`, Viple Live ID ou Cenelis Connect + jeton signé `Bearer`.
  - Bascule instantanée en 1 toucher entre `@viplemail.fr` et `@cenelis.com` depuis l'en-tête, le compositeur (`De :`) et les Réglages (`/api/mobile/v1/mail/switch-mailbox`).
  - Création directe d'une nouvelle boîte `@viplemail.fr` provisionnée instantanément sur Stalwart Mail Server (`imap.viplemail.fr` / `smtp.viplemail.fr`, quota 5 Go).
  - Connexion **Sign in with Apple** avec onboarding `@viplemail.fr` ou liaison d'un compte existant.
- **Boîte de Réception Prioritaire (Focused Inbox) & Recherche Avancée** :
  - Séparation intelligente **Prioritaire / Autres**, section **Messages Épinglés**, et filtres rapides (*Non lus*, *Favoris*, *Contacts VIP*, *Pièces jointes*, *Priorité Haute*).
  - Gestes de balayage (Swipe gauche / droite) personnalisables et sélection multiple en masse.
- **Lecture Riche HTML & Texte par Fil de Conversation** :
  - Regroupement par fil de discussion (`ThreadId`), rendu HTML natif (`WKWebView` compatible Swift 6 `@MainActor`) ou texte sélectionnable, téléchargement direct des pièces jointes MIME signées, barre de réponse rapide.
- **Compositeur Complet, Brouillons & Administration IMAP/SMTP** :
  - Auto-complétion des contacts (`dbo.WL_Contacts`), champs `Cc` / `Cci`, priorité, pièces jointes (`PhotosPicker` & `fileImporter`), sauvegarde dans `Drafts`, définition du mot de passe IMAP/SMTP tiers et téléchargement du profil `.mobileconfig` iPhone/Mac.
