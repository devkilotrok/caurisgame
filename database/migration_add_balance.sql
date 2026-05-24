-- =====================================================
-- MIGRATION : Ajout du système de solde (cauris_balance et company_balance)
-- =====================================================

USE cauris_db;

-- Ajouter la colonne cauris_balance pour les joueurs
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS cauris_balance INT DEFAULT 0 COMMENT 'Solde en Cauris du joueur' AFTER theme_preference;

-- Ajouter la colonne company_balance pour l'entreprise
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS company_balance INT DEFAULT 0 COMMENT 'Solde de l\'entreprise' AFTER cauris_balance;

-- Créer un INDEX pour optimiser les requêtes de solde
CREATE INDEX IF NOT EXISTS idx_cauris_balance ON users(cauris_balance);
CREATE INDEX IF NOT EXISTS idx_company_balance ON users(company_balance);

-- Initialiser le solde de l'entreprise (un seul admin avec company_balance > 0)
-- Trouver le premier admin et lui donner le solde initial de l'entreprise
UPDATE users 
SET company_balance = 1000000 
WHERE is_admin = TRUE 
LIMIT 1;

SELECT '✅ Migration de solde effectuée avec succès !' AS result;

