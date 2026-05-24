-- =====================================================
-- CRÉATION DE LA BASE DE DONNÉES CAURIS
-- Avec comptes SuperAdmin, ManagerAdmin et Admin
-- Date: 2025
-- =====================================================

-- Supprimer la base si elle existe
DROP DATABASE IF EXISTS cauris_db;

-- Créer la base de données
CREATE DATABASE cauris_db 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE cauris_db;

-- Importer le schéma complet
SOURCE cauris_schema.sql;

-- =====================================================
-- INSERTION DES COMPTES ADMINISTRATEURS
-- =====================================================

-- Note: Les hash de mot de passe sont générés avec bcrypt
-- Vous pouvez changer les mots de passe après la création

INSERT INTO users (pseudo, email, password_hash, avatar, is_admin, is_active, created_at) VALUES
-- SuperAdmin (Pouvoirs complets)
('superAdmin', 'superadmin@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👑', TRUE, TRUE, NOW()),

-- ManagerAdmin (Gestion des utilisateurs et transactions)
('managerAdmin', 'manager@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🔧', TRUE, TRUE, NOW()),

-- Admin (Validation des transactions et modération)
('admin', 'admin@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🛡️', TRUE, TRUE, NOW()),

-- Utilisateurs de test
('Lewis', 'lewis@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👤', FALSE, TRUE, NOW()),
('Bil', 'bil@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW()),
('Jonh', 'jonh@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW()),
('Alice', 'alice@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '👤', FALSE, TRUE, NOW()),
('Bob', 'bob@cauris.com', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', '🤖', FALSE, TRUE, NOW());

-- Paramètres par défaut pour tous les utilisateurs
INSERT INTO user_settings (user_id, language, theme_mode, notifications_enabled, sound_enabled, created_at) VALUES
(1, 'fr', 'dark', TRUE, TRUE, NOW()),
(2, 'fr', 'dark', TRUE, TRUE, NOW()),
(3, 'fr', 'dark', TRUE, TRUE, NOW()),
(4, 'fr', 'light', TRUE, TRUE, NOW()),
(5, 'fr', 'light', TRUE, TRUE, NOW()),
(6, 'en', 'light', TRUE, TRUE, NOW()),
(7, 'fr', 'light', TRUE, TRUE, NOW()),
(8, 'en', 'light', TRUE, TRUE, NOW());

-- Amitiés de test
INSERT INTO friendships (user_id, friend_id, status) VALUES
(4, 5, 'accepted'),
(4, 6, 'accepted'),
(5, 6, 'accepted'),
(7, 8, 'accepted');

-- =====================================================
-- RÉSULTATS
-- =====================================================

SELECT '✅ Base de données créée avec succès !' AS message;
SELECT 'Total utilisateurs: ' AS info, COUNT(*) as count FROM users;
SELECT 'Total admins: ' AS info, COUNT(*) as count FROM users WHERE is_admin = 1;

SELECT user_id, pseudo, email, 
       CASE WHEN is_admin = 1 THEN 'Admin' ELSE 'User' END as role,
       CASE WHEN is_active = 1 THEN 'Actif' ELSE 'Inactif' END as status
FROM users 
ORDER BY user_id;
