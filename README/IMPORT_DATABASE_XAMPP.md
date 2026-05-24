# 🗄️ Guide d'importation de la base de données dans XAMPP

## 📋 Fichier SQL à importer

**Fichier** : `database/IMPORT_DATABASE.sql`

## 🚀 Étapes d'importation

### Méthode 1 : Via phpMyAdmin (Recommandé)

1. **Ouvrir phpMyAdmin**
   - Aller sur `http://localhost/phpmyadmin`
   - Ou `http://127.0.0.1/phpmyadmin`

2. **Importer le fichier SQL**
   - Cliquer sur l'onglet **"Importer"**
   - Cliquer sur **"Choisir le fichier"**
   - Sélectionner `database/IMPORT_DATABASE.sql`
   - Cliquer sur **"Exécuter"**

3. **Vérifier l'importation**
   - Vérifier que la base `cauris_db` existe
   - Vérifier que la table `users` contient les 3 admins

### Méthode 2 : Via la ligne de commande

```bash
# Aller dans le dossier database
cd database

# Importer dans MySQL
mysql -u root -p < IMPORT_DATABASE.sql
```

Ou depuis n'importe où :

```bash
mysql -u root -p < /home/adolphe/cauris_app/database/IMPORT_DATABASE.sql
```

## ✅ Vérification

### Vérifier les comptes admin

```sql
USE cauris_db;

SELECT user_id, pseudo, email, is_admin, is_active 
FROM users 
WHERE is_admin = TRUE 
ORDER BY user_id;
```

### Résultat attendu

| user_id | pseudo        | email                    | is_admin | is_active |
|---------|---------------|--------------------------|----------|-----------|
| 1       | superAdmin    | superadmin@cauris.com    | 1        | 1         |
| 2       | managerAdmin  | manager@cauris.com        | 1        | 1         |
| 3       | admin         | admin@cauris.com          | 1        | 1         |

### Vérifier les tables

```sql
SHOW TABLES;
```

**Tables attendues** :
- users
- friendships
- friend_requests
- rooms
- room_players
- games
- announcements
- rounds
- tricks
- played_cards
- scores
- room_invitations
- user_settings
- **transactions** ⭐ (avec le champ beneficiaire_name)
- admin_logs

## 🔐 Connexion aux comptes admin

### Mots de passe

**Mot de passe par défaut pour tous** : `password`

⚠️ **IMPORTANT** : Changez les mots de passe après la création !

### Test de connexion

Vous pouvez tester dans l'application Flutter avec :
- **Email** : `superadmin@cauris.com`
- **Password** : `password`

## 📝 Notes sur les emails

### Système d'emails à implémenter

**Frontend** (déjà créé) :
- ✅ `lib/services/api/auth_api_service.dart` - Service API
- ✅ `lib/interfaces/auth/verify_email_page.dart` - Page de vérification
- ⏳ À connecter dans `signup_page.dart` et `forgot_password_page.dart`

**Backend** (à implémenter dans Laravel) :
1. Configuration SMTP dans `.env`
2. Création des Mailables
3. Implémentation des endpoints dans `AuthController`

### Fonctionnalités email

1. **Inscription** : Envoi d'un code de vérification (6 chiffres)
2. **Mot de passe oublié** : Envoi d'un code de réinitialisation (6 chiffres)
3. **Confirmation** : Email de confirmation après vérification

## ✅ Checklist complète

- [ ] Importer `IMPORT_DATABASE.sql` dans XAMPP
- [ ] Vérifier les comptes admin dans phpMyAdmin
- [ ] Changer les mots de passe des comptes admin
- [ ] Vérifier que toutes les tables sont créées
- [ ] Tester la connexion avec un compte admin
- [ ] Configurer le backend Laravel pour les emails (SMTP)
- [ ] Implémenter les endpoints d'envoi d'emails
- [ ] Tester l'envoi d'emails depuis l'application

## 🎯 Prochaines étapes

1. Importer la base de données dans XAMPP
2. Configurer l'envoi d'emails dans Laravel
3. Implémenter les méthodes dans Flutter
4. Tester le flux complet

## 📚 Documentation

Pour plus de détails :
- Voir `lib/interfaces/auth/GUIDE_IMPLEMENTATION_EMAIL.md`
- Voir `lib/interfaces/auth/RESUME_EMAIL_IMPLEMENTATION.md`

