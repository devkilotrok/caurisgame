# 📊 Liste des Tables dans cauris_schema.sql

## ✅ Tables principales (14 tables)

1. **users** (Utilisateurs)
   - Gestion des utilisateurs
   - Avatars, thèmes, admin

2. **friendships** (Relations d'amitié)
   - Gestion des amitiés
   - Statut: pending, accepted, blocked

3. **friend_requests** (Demandes d'amitié)
   - Demandes d'ajout d'amis
   - Statut: pending, accepted, rejected, cancelled

4. **rooms** (Salles de jeu)
   - Salles de jeu
   - Codes, créateurs, mise minimum

5. **room_players** (Participants des salles)
   - Joueurs dans les salles
   - Positions, statut

6. **games** (Parties de jeu)
   - Partie en cours
   - Gagnants, scores finaux

7. **announcements** (Annonces des joueurs)
   - Annonces (0-13)
   - Par round et joueur

8. **rounds** (Rounds de jeu)
   - Rounds
   - Résultats JSON

9. **tricks** (Plis)
   - Plis
   - Joueur meneur, gagnant

10. **played_cards** (Cartes jouées)
    - Cartes jouées
    - Code, valeur, couleur

11. **scores** (Scores)
    - Scores
    - Annonces, plis gagnés

12. **room_invitations** (Invitations à rejoindre une salle)
    - Invitations de salle
    - Messages optionnels

13. **user_settings** (Paramètres utilisateur)
    - Paramètres
    - Langue, notifications

14. **transactions** (Transactions de la caisse) ⭐ NOUVEAU
    - Dépôts et retraits
    - **beneficiaire_name** - Nom du bénéficiaire
    - phone_number - Numéro de téléphone
    - image_path - Preuve de paiement
    - status - en_attente, valide, rejete

15. **admin_logs** (Logs d'administration)
    - Logs admin
    - Actions, détails JSON

## 📋 Résumé

- **Total** : 15 tables
- **Nouvelle table** : transactions (ajoutée récemment)
- **Support JSON** : games, rounds, tricks
- **Relations** : Contraintes de clés étrangères

## 🎯 Utilisation

```sql
-- Voir toutes les tables
SHOW TABLES;

-- Voir la structure d'une table
DESCRIBE transactions;

-- Voir les données d'une table
SELECT * FROM transactions WHERE type = 'retrait';

-- Nouvelle transaction avec nom du bénéficiaire
INSERT INTO transactions (user_id, type, cauris_amount, fcfa_amount, beneficiaire_name, phone_number, status)
VALUES (1, 'retrait', 50, 5000, 'John DOE', '+22901234567', 'en_attente');
```

