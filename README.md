# Viple Mail pour iOS (`viplemail.iOS`)

Application native iOS (Swift 6 / SwiftUI, cible iOS 18.0+) de messagerie officielle **`@viplemail.fr`**, connectée en temps réel au **SSO Viple Live ID** (`identity-v2.viple.digital`) et à la base de données SQL Server de **Viple Live** (`mail.live.viplenetwork.com/api/mobile/v1/mail`).

## Fonctionnalités Clés (Zéro Donnée de Démo)
- **Authentification SSO Viple Live ID & Cross-App SSO** :
  - Détection automatique en 1 toucher d'une session Viple Live ID déjà active sur l'iPhone (via l'App Group partagé `group.store.livria.shared` et l'API `/sso/discover`).
  - Connexion avec n'importe quel compte `@viplemail.fr` / Viple Live ID.
  - Création directe d'une nouvelle boîte `@viplemail.fr` (provisionnée sur `VipleID` et `VipleLive` avec quota de 5 Go).
  - Connexion **Sign in with Apple** avec onboarding `@viplemail.fr` ou liaison d'un compte Viple existant.
- **Boîte de Réception Prioritaire (Focused Inbox) & Recherche Avancée** :
  - Séparation intelligente **Prioritaire / Autres**, section **Messages Épinglés 📌**, et filtres rapides (*Non lus*, *Favoris ⭐*, *Contacts VIP 👑*, *Pièces jointes 📎*, *Priorité Haute ❗*).
  - Gestes de balayage (Swipe gauche / droite) personnalisables et mode de sélection multiple en masse.
- **Lecture par Fil de Conversation & Réponse Rapide** :
  - Regroupement par fil de discussion (`ThreadId`), barre de réponse rapide en bas d'écran, téléchargement de pièces jointes hébergées sur **Viple Live SkyDrive**.
- **Compositeur Complet & Brouillons** :
  - Auto-complétion des destinataires depuis le carnet d'adresses Viple Live (`dbo.WL_Contacts`), champs `Cc` / `Cci`, sélecteur de priorité, modèles rapides, envoi de photos (`PhotosPicker`) et de fichiers (`fileImporter`), sauvegarde dans les **Brouillons**.
- **Dossiers Personnalisés, Carnet d'Adresses VIP & Répondeur Automatique** :
  - Création/suppression de dossiers personnalisés, gestion des Contacts VIP, signature personnalisée et répondeur automatique d'absence.
