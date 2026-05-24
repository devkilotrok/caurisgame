-- =====================================================
-- MIGRATION: Ajout du champ beneficiaire_name
-- Date: 2025
-- Description: Ajoute le champ beneficiaire_name pour les retraits
-- =====================================================

-- Utiliser la base de données
USE cauris_db;

-- Ajouter la colonne beneficiaire_name à la table transactions
ALTER TABLE transactions 
ADD COLUMN beneficiaire_name VARCHAR(255) NULL 
COMMENT 'Nom du bénéficiaire pour les retraits'
AFTER fcfa_amount;

-- Créer un index sur beneficiaire_name pour améliorer les performances
CREATE INDEX idx_beneficiaire_name ON transactions(beneficiaire_name);

-- =====================================================
-- FIN DU FICHIER
-- =====================================================

