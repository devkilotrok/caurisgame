# Modifications de la Table Transactions

## 📋 Résumé

Ajout de la table `transactions` dans le schéma SQL pour gérer les dépôts et retraits de Cauris.

## ✨ Nouvelle Table : transactions

### Structure

```sql
CREATE TABLE IF NOT EXISTS transactions (
    transaction_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    type ENUM('depot', 'retrait') NOT NULL,
    cauris_amount INT NOT NULL,
    fcfa_amount INT NOT NULL,
    beneficiaire_name VARCHAR(255) NULL COMMENT 'Nom du bénéficiaire pour les retraits',
    phone_number VARCHAR(20) NULL COMMENT 'Numéro de téléphone pour les retraits',
    image_path VARCHAR(500) NULL COMMENT 'Chemin de la preuve de paiement pour les dépôts',
    status ENUM('en_attente', 'valide', 'rejete') DEFAULT 'en_attente',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    validated_at TIMESTAMP NULL,
    validated_by INT NULL,
    notes TEXT NULL,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (validated_by) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_user_id (user_id),
    INDEX idx_type (type),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Colonnes

| Colonne | Type | Description |
|---------|------|-------------|
| `transaction_id` | INT | ID unique de la transaction |
| `user_id` | INT | ID de l'utilisateur (FK vers users) |
| `type` | ENUM | Type de transaction ('depot' ou 'retrait') |
| `cauris_amount` | INT | Montant en Cauris |
| `fcfa_amount` | INT | Montant équivalent en FCFA |
| `beneficiaire_name` | VARCHAR(255) | **Nom du bénéficiaire (pour les retraits)** |
| `phone_number` | VARCHAR(20) | Numéro de téléphone (pour les retraits) |
| `image_path` | VARCHAR(500) | Chemin de la preuve de paiement (pour les dépôts) |
| `status` | ENUM | Statut ('en_attente', 'valide', 'rejete') |
| `created_at` | TIMESTAMP | Date de création |
| `validated_at` | TIMESTAMP | Date de validation |
| `validated_by` | INT | ID de l'admin qui a validé |
| `notes` | TEXT | Notes administratives |

## 🎯 Champ bénéficiaire_name

### Caractéristiques

- **Type** : VARCHAR(255)
- **Nullable** : OUI (NULL autorisé)
- **Commentaire** : 'Nom du bénéficiaire pour les retraits'
- **Index** : Créé pour améliorer les performances

### Utilisation

Ce champ est utilisé uniquement pour les transactions de type 'retrait' :

```sql
-- Exemple d'insertion
INSERT INTO transactions (user_id, type, cauris_amount, fcfa_amount, beneficiaire_name, phone_number, status)
VALUES (1, 'retrait', 50, 5000, 'John DOE', '+22901234567', 'en_attente');
```

### Requête de sélection

```sql
-- Sélectionner les retraits avec le nom du bénéficiaire
SELECT 
    transaction_id,
    user_id,
    cauris_amount,
    fcfa_amount,
    beneficiaire_name,
    phone_number,
    status,
    created_at
FROM transactions
WHERE type = 'retrait'
ORDER BY created_at DESC;
```

## 🔄 Migration

### Pour les nouvelles installations

La table est déjà incluse dans `cauris_schema.sql`.

### Pour les bases existantes

Utilisez le fichier de migration :

```bash
mysql -u root -p cauris_db < database/migration_add_beneficiaire.sql
```

Ou via MySQL :

```sql
SOURCE /path/to/database/migration_add_beneficiaire.sql;
```

## 📊 Exemples d'utilisation

### Créer une transaction de retrait

```sql
INSERT INTO transactions (
    user_id, 
    type, 
    cauris_amount, 
    fcfa_amount, 
    beneficiaire_name, 
    phone_number, 
    status
) VALUES (
    1,
    'retrait',
    50,
    5000,
    'John DOE',
    '+22901234567',
    'en_attente'
);
```

### Créer une transaction de dépôt

```sql
INSERT INTO transactions (
    user_id, 
    type, 
    cauris_amount, 
    fcfa_amount, 
    image_path, 
    status
) VALUES (
    1,
    'depot',
    100,
    10000,
    '/storage/proof/payment_123.jpg',
    'en_attente'
);
```

### Valider une transaction

```sql
UPDATE transactions
SET 
    status = 'valide',
    validated_at = NOW(),
    validated_by = 1,
    notes = 'Transaction validée par l''admin'
WHERE transaction_id = 1;
```

### Réjeter une transaction

```sql
UPDATE transactions
SET 
    status = 'rejete',
    validated_at = NOW(),
    validated_by = 1,
    notes = 'Montant invalide'
WHERE transaction_id = 2;
```

## 🔍 Vues utiles

### Vue : Transactions en attente

```sql
CREATE OR REPLACE VIEW pending_transactions AS
SELECT 
    t.transaction_id,
    u.pseudo,
    t.type,
    t.cauris_amount,
    t.fcfa_amount,
    t.beneficiaire_name,
    t.phone_number,
    t.status,
    t.created_at
FROM transactions t
JOIN users u ON t.user_id = u.user_id
WHERE t.status = 'en_attente'
ORDER BY t.created_at DESC;
```

### Vue : Historique utilisateur

```sql
CREATE OR REPLACE VIEW user_transaction_history AS
SELECT 
    t.transaction_id,
    t.type,
    t.cauris_amount,
    t.fcfa_amount,
    t.beneficiaire_name,
    t.status,
    t.created_at,
    t.validated_at
FROM transactions t
WHERE t.user_id = ?  -- Paramètre à fournir
ORDER BY t.created_at DESC;
```

## ✅ Avantages

1. **Traçabilité** : Toutes les transactions sont enregistrées
2. **Audit** : Suivi des validations par les admins
3. **Sécurité** : Informations complètes sur les retraits
4. **Flexibilité** : Support des dépôts et retraits
5. **Performance** : Index optimisés pour les requêtes

## 🔒 Sécurité

- Contraintes de clés étrangères
- Types ENUM pour limiter les valeurs
- Index pour améliorer les performances
- Support des transactions (COMMIT/ROLLBACK)

## 📝 Notes

- Les transactions de type 'retrait' doivent avoir un `beneficiaire_name`
- Les transactions de type 'depot' doivent avoir un `image_path`
- Le statut par défaut est 'en_attente'
- Les admins peuvent ajouter des notes pour expliquer leurs décisions

