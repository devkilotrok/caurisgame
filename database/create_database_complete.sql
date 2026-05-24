-- =====================================================
-- SCRIPT DE CRÉATION COMPLÈTE DE LA BASE DE DONNÉES CAURIS
-- Version: 1.0
-- Date: 2025
-- Description: Base complète avec comptes admin
-- =====================================================

-- Création de la base de données
DROP DATABASE IF EXISTS cauris_db;
CREATE DATABASE cauris_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE cauris_db;

-- =====================================================
-- TABLES (voir cauris_schema.sql pour la structure complète)
-- =====================================================

-- Copier toutes les tables depuis cauris_schema.sql
SOURCE database/cauris_schema.sql;

-- =====================================================
-- COMPTES ADMINISTRATEURS
-- =====================================================

-- Password hash pour 'admin123' avec bcrypt
-- Vous pouvez changer ces mots de passe après la création

INSERT INTO users (pseudo, email, password_hash, avatar, is_admin, is_active, created_at) VALUES
-- Super Admin
('superAdmin', 'superadmin@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👑', TRUE, TRUE, NOW()),

-- Manager Admin
('managerAdmin', 'manager@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🔧', TRUE, TRUE, NOW()),

-- Admin
('admin', 'admin@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🛡️', TRUE, TRUE, NOW());

-- =====================================================
-- COMPTES UTILISATEURS DE TEST
-- =====================================================

INSERT INTO users (pseudo, email, password_hash, avatar, is_admin, is_active, created_at) VALUES
('Lewis', 'lewis@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👤', FALSE, TRUE, NOW()),
('Bil', 'bil@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW()),
('Jonh', 'jonh@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW()),
('Alice', 'alice@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👤', FALSE, TRUE, NOW()),
('Bob', 'bob@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW());

-- =====================================================
-- PARAMÈTRES PAR DÉFAUT
-- =====================================================

INSERT INTO user_settings (user_id, language, theme_mode, created_at) VALUES
(1, 'fr', 'dark', NOW()),
(2, 'fr', 'dark', NOW()),
(3, 'fr', 'dark', NOW()),
(4, 'fr', 'light', NOW()),
(5, 'fr', 'light', NOW()),
(6, 'en', 'light', NOW()),
(7, 'fr', 'light', NOW()),
(8, 'en', 'light', NOW());

-- =====================================================
-- AFFICHAGE DES RÉSULTATS
-- =====================================================

SELECT 'Base de données cauris_db créée avec succès !' AS message;

SELECT 
    user_id,
    pseudo,
    email,
    CASE WHEN is_admin = 1 THEN 'Admin' ELSE 'User' END as role,
    CASE WHEN is_active = 1 THEN 'Actif' ELSE 'Inactif' END as status
FROM users 
ORDER BY user_id;

SELECT 'Total utilisateurs: ' AS info, COUNT(*) as count FROM users;
SELECT 'Total admins: ' AS info, COUNT(*) as count FROM users WHERE is_admin = 1;

-- =====================================================
-- FIN DU SCRIPT
-- =====================================================

