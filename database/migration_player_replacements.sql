-- =====================================================
-- MIGRATION: Gestion des Remplacements de Joueurs par Bots
-- Date: 2025
-- Description: Ajout des tables et colonnes nécessaires pour gérer
--              les remplacements temporaires et définitifs de joueurs
-- =====================================================

USE cauris_db;

-- =====================================================
-- TABLE: player_replacements
-- Suit les remplacements de joueurs par des bots
-- =====================================================
CREATE TABLE IF NOT EXISTS player_replacements (
    replacement_id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    player_name VARCHAR(50) NOT NULL,
    bot_name VARCHAR(50) NOT NULL,
    is_permanent BOOLEAN DEFAULT FALSE,
    disconnected_at TIMESTAMP NOT NULL,
    restored_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    INDEX idx_room_player (room_id, player_name),
    INDEX idx_disconnected_at (disconnected_at),
    INDEX idx_restored_at (restored_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- TABLE: player_disconnections
-- Suit les déconnexions pour calculer les 15 secondes
-- =====================================================
CREATE TABLE IF NOT EXISTS player_disconnections (
    id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    player_name VARCHAR(50) NOT NULL,
    disconnected_at TIMESTAMP NOT NULL,
    reconnected_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    INDEX idx_room_player (room_id, player_name),
    INDEX idx_disconnected_at (disconnected_at),
    INDEX idx_reconnected_at (reconnected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================
-- MODIFICATIONS TABLE: room_players
-- Ajout des colonnes pour gérer les bots remplaçants
-- =====================================================
ALTER TABLE room_players 
ADD COLUMN IF NOT EXISTS is_replacement_bot BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS replaced_player_name VARCHAR(50) NULL,
ADD COLUMN IF NOT EXISTS is_excluded BOOLEAN DEFAULT FALSE;

-- Ajout d'index pour optimiser les requêtes
CREATE INDEX IF NOT EXISTS idx_is_replacement_bot ON room_players(is_replacement_bot);
CREATE INDEX IF NOT EXISTS idx_is_excluded ON room_players(is_excluded);
CREATE INDEX IF NOT EXISTS idx_replaced_player_name ON room_players(replaced_player_name);

-- =====================================================
-- VÉRIFICATIONS
-- =====================================================
SELECT 'Migration terminée avec succès' AS status;

