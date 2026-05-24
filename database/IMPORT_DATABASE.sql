-- =====================================================
-- IMPORTER CETTE BASE DE DONNÉES DANS XAMPP
-- Avec comptes SuperAdmin, ManagerAdmin et Admin
-- =====================================================

DROP DATABASE IF EXISTS cauris_db;
CREATE DATABASE cauris_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cauris_db;

-- =====================================================
-- TABLE: users (Utilisateurs)
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    pseudo VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    avatar VARCHAR(255) DEFAULT 'default_avatar.png',
    theme_preference VARCHAR(20) DEFAULT 'light',
    cauris_balance INT DEFAULT 0 COMMENT 'Solde en Cauris du joueur',
    company_balance INT DEFAULT 0 COMMENT 'Solde de l\'entreprise',
    is_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_pseudo (pseudo),
    INDEX idx_email (email),
    INDEX idx_is_admin (is_admin),
    INDEX idx_is_active (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: friendships (Relations d'amitié)
-- =====================================================
CREATE TABLE IF NOT EXISTS friendships (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'blocked') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (friend_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_friendship (user_id, friend_id),
    INDEX idx_user_id (user_id),
    INDEX idx_friend_id (friend_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: friend_requests (Demandes d'amitié)
-- =====================================================
CREATE TABLE IF NOT EXISTS friend_requests (
    request_id INT PRIMARY KEY AUTO_INCREMENT,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'rejected', 'cancelled') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_sender (sender_id),
    INDEX idx_receiver (receiver_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: rooms (Salles de jeu)
-- =====================================================
CREATE TABLE IF NOT EXISTS rooms (
    room_id INT PRIMARY KEY AUTO_INCREMENT,
    room_name VARCHAR(100) NOT NULL,
    room_code VARCHAR(6) UNIQUE NOT NULL,
    creator_id INT NOT NULL,
    minimum_bet INT DEFAULT 50,
    status ENUM('waiting', 'playing', 'finished', 'cancelled') DEFAULT 'waiting',
    max_players INT DEFAULT 4,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    started_at TIMESTAMP NULL,
    finished_at TIMESTAMP NULL,
    FOREIGN KEY (creator_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_room_code (room_code),
    INDEX idx_creator (creator_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: room_players (Participants des salles)
-- =====================================================
CREATE TABLE IF NOT EXISTS room_players (
    player_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    user_id INT NOT NULL,
    position INT NOT NULL CHECK (position BETWEEN 1 AND 4),
    is_creator BOOLEAN DEFAULT FALSE,
    status ENUM('waiting', 'ready', 'playing', 'left') DEFAULT 'waiting',
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    UNIQUE KEY unique_room_position (room_id, position),
    INDEX idx_room_id (room_id),
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: games (Parties de jeu)
-- =====================================================
CREATE TABLE IF NOT EXISTS games (
    game_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    deck_id VARCHAR(100) NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP NULL,
    winner_id INT NULL,
    final_scores JSON,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (winner_id) REFERENCES users(user_id) ON DELETE SET NULL,
    INDEX idx_room_id (room_id),
    INDEX idx_winner (winner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: announcements (Annonces des joueurs)
-- =====================================================
CREATE TABLE IF NOT EXISTS announcements (
    announcement_id INT PRIMARY KEY AUTO_INCREMENT,
    game_id INT NOT NULL,
    round_number INT NOT NULL,
    player_id INT NOT NULL,
    user_id INT NOT NULL,
    announcement_value INT NOT NULL CHECK (announcement_value BETWEEN 0 AND 13),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES room_players(player_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_game_round (game_id, round_number),
    INDEX idx_player_id (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: rounds (Rounds de jeu)
-- =====================================================
CREATE TABLE IF NOT EXISTS rounds (
    round_id INT PRIMARY KEY AUTO_INCREMENT,
    game_id INT NOT NULL,
    round_number INT NOT NULL,
    announcements JSON,
    results JSON,
    trick_winner_id INT NULL,
    status ENUM('in_progress', 'completed', 'cancelled') DEFAULT 'in_progress',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP NULL,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (trick_winner_id) REFERENCES room_players(player_id) ON DELETE SET NULL,
    INDEX idx_game_id (game_id),
    INDEX idx_round_number (round_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: tricks (Plis)
-- =====================================================
CREATE TABLE IF NOT EXISTS tricks (
    trick_id INT PRIMARY KEY AUTO_INCREMENT,
    round_id INT NOT NULL,
    trick_number INT NOT NULL,
    lead_player_id INT NOT NULL,
    winner_player_id INT NULL,
    cards_played JSON,
    status ENUM('in_progress', 'completed') DEFAULT 'in_progress',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP NULL,
    FOREIGN KEY (round_id) REFERENCES rounds(round_id) ON DELETE CASCADE,
    FOREIGN KEY (lead_player_id) REFERENCES room_players(player_id) ON DELETE CASCADE,
    FOREIGN KEY (winner_player_id) REFERENCES room_players(player_id) ON DELETE SET NULL,
    INDEX idx_round_trick (round_id, trick_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: played_cards (Cartes jouées)
-- =====================================================
CREATE TABLE IF NOT EXISTS played_cards (
    card_id INT PRIMARY KEY AUTO_INCREMENT,
    trick_id INT NOT NULL,
    player_id INT NOT NULL,
    card_code VARCHAR(3) NOT NULL,
    card_value VARCHAR(10) NOT NULL,
    card_suit VARCHAR(10) NOT NULL,
    played_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (trick_id) REFERENCES tricks(trick_id) ON DELETE CASCADE,
    FOREIGN KEY (player_id) REFERENCES room_players(player_id) ON DELETE CASCADE,
    INDEX idx_trick_id (trick_id),
    INDEX idx_player_id (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: scores (Scores)
-- =====================================================
CREATE TABLE IF NOT EXISTS scores (
    score_id INT PRIMARY KEY AUTO_INCREMENT,
    game_id INT NOT NULL,
    round_id INT NULL,
    player_id INT NOT NULL,
    user_id INT NOT NULL,
    announcement INT DEFAULT 0,
    tricks_won INT DEFAULT 0,
    round_score INT DEFAULT 0,
    cumulative_score INT DEFAULT 0,
    FOREIGN KEY (game_id) REFERENCES games(game_id) ON DELETE CASCADE,
    FOREIGN KEY (round_id) REFERENCES rounds(round_id) ON DELETE SET NULL,
    FOREIGN KEY (player_id) REFERENCES room_players(player_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_game_id (game_id),
    INDEX idx_player_id (player_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: room_invitations (Invitations à rejoindre une salle)
-- =====================================================
CREATE TABLE IF NOT EXISTS room_invitations (
    invitation_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    sender_id INT NOT NULL,
    receiver_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'rejected', 'cancelled') DEFAULT 'pending',
    message VARCHAR(255) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    FOREIGN KEY (sender_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (receiver_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_receiver (receiver_id),
    INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: user_settings (Paramètres utilisateur)
-- =====================================================
CREATE TABLE IF NOT EXISTS user_settings (
    setting_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL UNIQUE,
    language VARCHAR(10) DEFAULT 'fr',
    notifications_enabled BOOLEAN DEFAULT TRUE,
    sound_enabled BOOLEAN DEFAULT TRUE,
    vibration_enabled BOOLEAN DEFAULT TRUE,
    theme_mode VARCHAR(20) DEFAULT 'light',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: transactions (Transactions de la caisse)
-- =====================================================
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

-- =====================================================
-- TABLE: admin_logs (Logs d'administration)
-- =====================================================
CREATE TABLE IF NOT EXISTS admin_logs (
    log_id INT PRIMARY KEY AUTO_INCREMENT,
    admin_user_id INT NOT NULL,
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(50) NULL,
    target_id INT NULL,
    details JSON NULL,
    ip_address VARCHAR(45) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (admin_user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    INDEX idx_admin_user (admin_user_id),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: email_verification_codes (Codes de vérification d'email)
-- =====================================================
CREATE TABLE IF NOT EXISTS email_verification_codes (
    code_id INT PRIMARY KEY AUTO_INCREMENT,
    email VARCHAR(100) NOT NULL,
    code VARCHAR(6) NOT NULL COMMENT 'Code à 6 chiffres',
    type ENUM('verification', 'reset') NOT NULL COMMENT 'Type de code',
    expires_at TIMESTAMP NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP NULL,
    updated_at TIMESTAMP NULL,
    INDEX idx_email (email),
    INDEX idx_email_type (email, type),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- INSERTION DES COMPTES ADMINISTRATEURS
-- =====================================================

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
-- VUES
-- =====================================================

CREATE OR REPLACE VIEW player_stats AS
SELECT 
    u.user_id,
    u.pseudo,
    u.email,
    COUNT(DISTINCT g.game_id) as total_games,
    COUNT(DISTINCT CASE WHEN g.winner_id = u.user_id THEN g.game_id END) as games_won,
    COUNT(DISTINCT CASE WHEN g.winner_id != u.user_id AND g.finished_at IS NOT NULL THEN g.game_id END) as games_lost,
    AVG(s.cumulative_score) as avg_score,
    MAX(s.cumulative_score) as best_score,
    u.is_admin,
    u.is_active,
    u.last_login,
    u.created_at
FROM users u
LEFT JOIN scores s ON u.user_id = s.user_id
LEFT JOIN games g ON s.game_id = g.game_id
GROUP BY u.user_id, u.pseudo, u.email, u.is_admin, u.is_active, u.last_login, u.created_at;

CREATE OR REPLACE VIEW room_stats AS
SELECT 
    r.room_id,
    r.room_name,
    r.room_code,
    r.creator_id,
    u.pseudo as creator_pseudo,
    r.minimum_bet,
    r.status,
    COUNT(rp.player_id) as current_players,
    r.max_players,
    COUNT(DISTINCT g.game_id) as total_games,
    r.created_at,
    r.started_at,
    r.finished_at
FROM rooms r
LEFT JOIN room_players rp ON r.room_id = rp.room_id
LEFT JOIN users u ON r.creator_id = u.user_id
LEFT JOIN games g ON r.room_id = g.room_id
GROUP BY r.room_id;

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

