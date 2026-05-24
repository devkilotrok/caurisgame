# 📧 Configuration : Table email_verification_codes

## ✅ Table créée dans le script SQL

La table `email_verification_codes` est maintenant incluse dans le script `IMPORT_DATABASE.sql` et sera automatiquement créée lors de l'import.

## 📋 Structure de la table

```sql
CREATE TABLE email_verification_codes (
    code_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL,                    -- Code à 6 chiffres
    type ENUM('verification', 'reset') NOT NULL, -- Type de code
    expires_at TIMESTAMP NOT NULL,               -- Expiration
    used BOOLEAN DEFAULT FALSE,                  -- Utilisé ou non
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    INDEX idx_email (email),
    INDEX idx_email_type (email, type),
    INDEX idx_expires_at (expires_at)
);
```

## 🎯 Utilisation

Cette table stocke les codes envoyés par email pour :
- **Type 'verification'** : Codes d'inscription (expire après 24h)
- **Type 'reset'** : Codes de réinitialisation (expire après 1h)

## ✅ Prochaines étapes

### 1. Importer la base de données
```bash
mysql -u root < database/IMPORT_DATABASE.sql
```

OU via phpMyAdmin :
1. Ouvrir phpMyAdmin (http://localhost/phpmyadmin)
2. Cliquer sur "Importer"
3. Sélectionner `database/IMPORT_DATABASE.sql`
4. Cliquer sur "Exécuter"

### 2. Vérifier que la table existe
```sql
USE cauris_db;
SHOW TABLES LIKE 'email_verification_codes';
DESCRIBE email_verification_codes;
```

### 3. Exécuter les migrations Laravel (optionnel)
```bash
cd /opt/lampp/htdocs/backendCauris
php artisan migrate
```

## 📝 Notes

- La table est créée automatiquement via le script SQL
- Aucune donnée initiale à insérer (la table est vide au départ)
- Les codes seront ajoutés dynamiquement lors des inscriptions et réinitialisations
- Les codes expirés seront automatiquement ignorés par le système

## 🔍 Vérification

Pour vérifier que tout fonctionne, après l'import :

```sql
USE cauris_db;

-- Voir la structure de la table
DESCRIBE email_verification_codes;

-- Compter les tables (devrait afficher 14 tables)
SHOW TABLES;

-- Vérifier les index
SHOW INDEX FROM email_verification_codes;
```

**Résultat attendu** :
- 1 table `email_verification_codes`
- 3 index (email, email+type, expires_at)
- 0 lignes au départ

## ✅ Checklist

- [x] Table ajoutée dans `IMPORT_DATABASE.sql`
- [ ] Importer la base de données dans XAMPP
- [ ] Vérifier que la table existe
- [ ] Tester l'envoi d'emails via l'API
- [ ] Vérifier que les codes sont enregistrés dans la table

