# 🔧 Exemples d'Implémentation Backend - Remplacement Joueurs par Bots

Ce document contient des exemples de code backend pour implémenter les endpoints requis pour la synchronisation des remplacements de joueurs par des bots.

---

## 📋 Table des Matières

1. [Structure Base de Données](#structure-base-de-données)
2. [Exemple PHP (Laravel/Lumen)](#exemple-php-laravellumen)
3. [Exemple Node.js (Express)](#exemple-nodejs-express)
4. [Exemple Python (Flask/FastAPI)](#exemple-python-flaskfastapi)
5. [WebSocket Events](#websocket-events)

---

## 🗄️ Structure Base de Données

### Table `player_replacements`

Ajouter cette table pour suivre les remplacements :

```sql
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
    INDEX idx_disconnected_at (disconnected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Table `room_players` - Modifications

Ajouter une colonne pour marquer les bots remplaçants :

```sql
ALTER TABLE room_players 
ADD COLUMN is_replacement_bot BOOLEAN DEFAULT FALSE,
ADD COLUMN replaced_player_name VARCHAR(50) NULL,
ADD COLUMN is_excluded BOOLEAN DEFAULT FALSE;
```

---

## 🔴 Exemple PHP (Laravel/Lumen)

### Controller: `RoomController.php`

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Services\WebSocketService;

class RoomController extends Controller
{
    protected $wsService;

    public function __construct(WebSocketService $wsService)
    {
        $this->wsService = $wsService;
    }

    /**
     * POST /api/rooms/replace-player
     * Remplace un joueur par un bot
     */
    public function replacePlayerWithBot(Request $request)
    {
        $request->validate([
            'room_id' => 'required|integer',
            'player_name' => 'required|string',
            'bot_name' => 'required|string',
            'is_permanent' => 'required|boolean',
        ]);

        try {
            DB::beginTransaction();

            $roomId = $request->room_id;
            $playerName = $request->player_name;
            $botName = $request->bot_name;
            $isPermanent = $request->is_permanent;

            // 1. Récupérer le joueur à remplacer
            $player = DB::table('room_players')
                ->where('room_id', $roomId)
                ->where('pseudo', $playerName)
                ->first();

            if (!$player) {
                return response()->json([
                    'success' => false,
                    'message' => 'Joueur non trouvé',
                ], 404);
            }

            // 2. Créer ou récupérer le bot remplaçant
            $bot = DB::table('room_players')
                ->where('room_id', $roomId)
                ->where('pseudo', $botName)
                ->first();

            if (!$bot) {
                // Créer le bot dans room_players
                $botId = DB::table('room_players')->insertGetId([
                    'room_id' => $roomId,
                    'pseudo' => $botName,
                    'is_bot' => true,
                    'is_replacement_bot' => true,
                    'replaced_player_name' => $playerName,
                    'position' => $player->position,
                    'created_at' => now(),
                ]);
            } else {
                // Mettre à jour le bot existant
                DB::table('room_players')
                    ->where('id', $bot->id)
                    ->update([
                        'is_replacement_bot' => true,
                        'replaced_player_name' => $playerName,
                    ]);
            }

            // 3. Enregistrer le remplacement
            DB::table('player_replacements')->insert([
                'room_id' => $roomId,
                'player_name' => $playerName,
                'bot_name' => $botName,
                'is_permanent' => $isPermanent,
                'disconnected_at' => now(),
            ]);

            // 4. Transférer les statistiques du joueur au bot
            // - Scores globaux (rester au même index)
            // - Plis gagnés dans le round actuel
            // - Annonces
            // (Ces transferts sont gérés dans la logique métier)

            // 5. Marquer le joueur comme exclu si permanent
            if ($isPermanent) {
                DB::table('room_players')
                    ->where('room_id', $roomId)
                    ->where('pseudo', $playerName)
                    ->update(['is_excluded' => true]);
            }

            DB::commit();

            // 6. Émettre l'événement WebSocket à tous les clients
            $this->wsService->broadcastToRoom($roomId, [
                'event' => 'player_replaced',
                'data' => [
                    'room_id' => $roomId,
                    'player_name' => $playerName,
                    'bot_name' => $botName,
                    'is_permanent' => $isPermanent,
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Joueur remplacé par bot',
                'data' => [
                    'room_id' => $roomId,
                    'player_replaced' => $playerName,
                    'bot_name' => $botName,
                    'is_permanent' => $isPermanent,
                ],
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Erreur remplacement joueur: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors du remplacement',
            ], 500);
        }
    }

    /**
     * POST /api/rooms/restore-player
     * Restaure un joueur qui s'est reconnecté
     */
    public function restorePlayer(Request $request)
    {
        $request->validate([
            'room_id' => 'required|integer',
            'player_name' => 'required|string',
            'bot_name' => 'required|string',
        ]);

        try {
            DB::beginTransaction();

            $roomId = $request->room_id;
            $playerName = $request->player_name;
            $botName = $request->bot_name;

            // 1. Vérifier que le remplacement existe et n'est pas permanent
            $replacement = DB::table('player_replacements')
                ->where('room_id', $roomId)
                ->where('player_name', $playerName)
                ->where('bot_name', $botName)
                ->whereNull('restored_at')
                ->where('is_permanent', false)
                ->first();

            if (!$replacement) {
                return response()->json([
                    'success' => false,
                    'message' => 'Remplacement non trouvé ou déjà permanent',
                ], 404);
            }

            // 2. Retirer le bot
            DB::table('room_players')
                ->where('room_id', $roomId)
                ->where('pseudo', $botName)
                ->delete();

            // 3. Restaurer le joueur
            DB::table('room_players')
                ->where('room_id', $roomId)
                ->where('pseudo', $playerName)
                ->update([
                    'is_excluded' => false,
                ]);

            // 4. Marquer le remplacement comme restauré
            DB::table('player_replacements')
                ->where('replacement_id', $replacement->replacement_id)
                ->update(['restored_at' => now()]);

            DB::commit();

            // 5. Émettre l'événement WebSocket
            $this->wsService->broadcastToRoom($roomId, [
                'event' => 'player_restored',
                'data' => [
                    'room_id' => $roomId,
                    'player_name' => $playerName,
                    'bot_name' => $botName,
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Joueur restauré',
                'data' => [
                    'room_id' => $roomId,
                    'player_restored' => $playerName,
                    'bot_removed' => $botName,
                ],
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Erreur restauration joueur: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la restauration',
            ], 500);
        }
    }

    /**
     * POST /api/rooms/player-disconnected
     * Notifie une déconnexion de joueur
     */
    public function notifyPlayerDisconnection(Request $request)
    {
        $request->validate([
            'room_id' => 'required|integer',
            'player_name' => 'required|string',
        ]);

        try {
            $roomId = $request->room_id;
            $playerName = $request->player_name;

            // Enregistrer la déconnexion avec timestamp
            $disconnectionId = DB::table('player_disconnections')->insertGetId([
                'room_id' => $roomId,
                'player_name' => $playerName,
                'disconnected_at' => now(),
            ]);

            // Lancer un timer de 15 secondes (job queue ou cron)
            // Si pas de reconnexion après 15s, rendre permanent
            dispatch(new MakeReplacementPermanentJob($roomId, $playerName))
                ->delay(now()->addSeconds(15));

            // Émettre l'événement WebSocket
            $this->wsService->broadcastToRoom($roomId, [
                'event' => 'player_disconnected',
                'data' => [
                    'room_id' => $roomId,
                    'player_name' => $playerName,
                    'timestamp' => now()->toIso8601String(),
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Déconnexion notifiée',
            ]);

        } catch (\Exception $e) {
            Log::error('Erreur notification déconnexion: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la notification',
            ], 500);
        }
    }

    /**
     * POST /api/rooms/player-reconnected
     * Notifie une reconnexion de joueur
     */
    public function notifyPlayerReconnection(Request $request)
    {
        $request->validate([
            'room_id' => 'required|integer',
            'player_name' => 'required|string',
        ]);

        try {
            $roomId = $request->room_id;
            $playerName = $request->player_name;

            // Vérifier la dernière déconnexion
            $lastDisconnection = DB::table('player_disconnections')
                ->where('room_id', $roomId)
                ->where('player_name', $playerName)
                ->whereNull('reconnected_at')
                ->orderBy('disconnected_at', 'desc')
                ->first();

            $canRestore = false;
            if ($lastDisconnection) {
                $secondsSinceDisconnection = now()->diffInSeconds($lastDisconnection->disconnected_at);
                $canRestore = $secondsSinceDisconnection < 15;

                // Marquer comme reconnecté
                DB::table('player_disconnections')
                    ->where('id', $lastDisconnection->id)
                    ->update(['reconnected_at' => now()]);
            }

            // Émettre l'événement WebSocket
            $this->wsService->broadcastToRoom($roomId, [
                'event' => 'player_reconnected',
                'data' => [
                    'room_id' => $roomId,
                    'player_name' => $playerName,
                    'can_restore' => $canRestore,
                ],
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Reconnexion notifiée',
                'can_restore' => $canRestore,
            ]);

        } catch (\Exception $e) {
            Log::error('Erreur notification reconnexion: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la notification',
            ], 500);
        }
    }

    /**
     * POST /api/rooms/check-exclusion
     * Vérifie si un joueur est exclu
     */
    public function checkPlayerExclusion(Request $request)
    {
        $request->validate([
            'room_id' => 'required|integer',
            'player_name' => 'required|string',
        ]);

        try {
            $roomId = $request->room_id;
            $playerName = $request->player_name;

            // Vérifier dans room_players
            $player = DB::table('room_players')
                ->where('room_id', $roomId)
                ->where('pseudo', $playerName)
                ->first();

            $isExcluded = false;
            $reason = 'not_excluded';

            if ($player) {
                $isExcluded = $player->is_excluded ?? false;
                
                if ($isExcluded) {
                    // Vérifier le type d'exclusion
                    $replacement = DB::table('player_replacements')
                        ->where('room_id', $roomId)
                        ->where('player_name', $playerName)
                        ->where('is_permanent', true)
                        ->whereNull('restored_at')
                        ->first();

                    if ($replacement) {
                        $reason = 'disconnected_too_long';
                    } else {
                        $reason = 'manual_leave';
                    }
                }
            } else {
                // Joueur n'existe plus dans la room = exclu
                $isExcluded = true;
                $reason = 'not_found';
            }

            return response()->json([
                'success' => true,
                'is_excluded' => $isExcluded,
                'reason' => $reason,
            ]);

        } catch (\Exception $e) {
            Log::error('Erreur vérification exclusion: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Erreur lors de la vérification',
            ], 500);
        }
    }
}
```

### Job: `MakeReplacementPermanentJob.php`

```php
<?php

namespace App\Jobs;

use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\DB;
use App\Services\WebSocketService;

class MakeReplacementPermanentJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected $roomId;
    protected $playerName;

    public function __construct($roomId, $playerName)
    {
        $this->roomId = $roomId;
        $this->playerName = $playerName;
    }

    public function handle(WebSocketService $wsService)
    {
        // Vérifier si le joueur s'est reconnecté entre-temps
        $replacement = DB::table('player_replacements')
            ->where('room_id', $this->roomId)
            ->where('player_name', $this->playerName)
            ->whereNull('restored_at')
            ->where('is_permanent', false)
            ->first();

        if ($replacement) {
            // Rendre permanent
            DB::table('player_replacements')
                ->where('replacement_id', $replacement->replacement_id)
                ->update(['is_permanent' => true]);

            DB::table('room_players')
                ->where('room_id', $this->roomId)
                ->where('pseudo', $this->playerName)
                ->update(['is_excluded' => true]);

            // Notifier via WebSocket
            $wsService->broadcastToRoom($this->roomId, [
                'event' => 'player_replaced',
                'data' => [
                    'room_id' => $this->roomId,
                    'player_name' => $this->playerName,
                    'bot_name' => $replacement->bot_name,
                    'is_permanent' => true,
                ],
            ]);
        }
    }
}
```

### Routes: `routes/api.php`

```php
Route::prefix('rooms')->group(function () {
    Route::post('/replace-player', [RoomController::class, 'replacePlayerWithBot']);
    Route::post('/restore-player', [RoomController::class, 'restorePlayer']);
    Route::post('/player-disconnected', [RoomController::class, 'notifyPlayerDisconnection']);
    Route::post('/player-reconnected', [RoomController::class, 'notifyPlayerReconnection']);
    Route::post('/check-exclusion', [RoomController::class, 'checkPlayerExclusion']);
});
```

---

## 🔴 Exemple Node.js (Express)

### Controller: `roomController.js`

```javascript
const db = require('../config/database');
const WebSocketService = require('../services/websocketService');

class RoomController {
    /**
     * POST /api/rooms/replace-player
     */
    async replacePlayerWithBot(req, res) {
        try {
            const { room_id, player_name, bot_name, is_permanent } = req.body;

            await db.beginTransaction();

            // 1. Récupérer le joueur
            const [player] = await db.query(
                'SELECT * FROM room_players WHERE room_id = ? AND pseudo = ?',
                [room_id, player_name]
            );

            if (!player.length) {
                await db.rollback();
                return res.status(404).json({
                    success: false,
                    message: 'Joueur non trouvé',
                });
            }

            // 2. Créer/mettre à jour le bot
            const [botExists] = await db.query(
                'SELECT * FROM room_players WHERE room_id = ? AND pseudo = ?',
                [room_id, bot_name]
            );

            if (!botExists.length) {
                await db.query(
                    `INSERT INTO room_players (room_id, pseudo, is_bot, is_replacement_bot, replaced_player_name, position)
                     VALUES (?, ?, 1, 1, ?, ?)`,
                    [room_id, bot_name, player_name, player[0].position]
                );
            } else {
                await db.query(
                    `UPDATE room_players 
                     SET is_replacement_bot = 1, replaced_player_name = ?
                     WHERE room_id = ? AND pseudo = ?`,
                    [player_name, room_id, bot_name]
                );
            }

            // 3. Enregistrer le remplacement
            await db.query(
                `INSERT INTO player_replacements (room_id, player_name, bot_name, is_permanent, disconnected_at)
                 VALUES (?, ?, ?, ?, NOW())`,
                [room_id, player_name, bot_name, is_permanent ? 1 : 0]
            );

            // 4. Marquer comme exclu si permanent
            if (is_permanent) {
                await db.query(
                    'UPDATE room_players SET is_excluded = 1 WHERE room_id = ? AND pseudo = ?',
                    [room_id, player_name]
                );
            }

            await db.commit();

            // 5. Émettre WebSocket
            WebSocketService.broadcastToRoom(room_id, {
                event: 'player_replaced',
                data: {
                    room_id,
                    player_name,
                    bot_name,
                    is_permanent,
                },
            });

            res.json({
                success: true,
                message: 'Joueur remplacé par bot',
                data: {
                    room_id,
                    player_replaced: player_name,
                    bot_name,
                    is_permanent,
                },
            });

        } catch (error) {
            await db.rollback();
            console.error('Erreur remplacement:', error);
            res.status(500).json({
                success: false,
                message: 'Erreur lors du remplacement',
            });
        }
    }

    /**
     * POST /api/rooms/restore-player
     */
    async restorePlayer(req, res) {
        try {
            const { room_id, player_name, bot_name } = req.body;

            await db.beginTransaction();

            // Vérifier le remplacement
            const [replacement] = await db.query(
                `SELECT * FROM player_replacements 
                 WHERE room_id = ? AND player_name = ? AND bot_name = ? 
                 AND restored_at IS NULL AND is_permanent = 0`,
                [room_id, player_name, bot_name]
            );

            if (!replacement.length) {
                await db.rollback();
                return res.status(404).json({
                    success: false,
                    message: 'Remplacement non trouvé',
                });
            }

            // Retirer le bot
            await db.query(
                'DELETE FROM room_players WHERE room_id = ? AND pseudo = ?',
                [room_id, bot_name]
            );

            // Restaurer le joueur
            await db.query(
                'UPDATE room_players SET is_excluded = 0 WHERE room_id = ? AND pseudo = ?',
                [room_id, player_name]
            );

            // Marquer comme restauré
            await db.query(
                'UPDATE player_replacements SET restored_at = NOW() WHERE replacement_id = ?',
                [replacement[0].replacement_id]
            );

            await db.commit();

            // Émettre WebSocket
            WebSocketService.broadcastToRoom(room_id, {
                event: 'player_restored',
                data: {
                    room_id,
                    player_name,
                    bot_name,
                },
            });

            res.json({
                success: true,
                message: 'Joueur restauré',
                data: {
                    room_id,
                    player_restored: player_name,
                    bot_removed: bot_name,
                },
            });

        } catch (error) {
            await db.rollback();
            console.error('Erreur restauration:', error);
            res.status(500).json({
                success: false,
                message: 'Erreur lors de la restauration',
            });
        }
    }

    /**
     * POST /api/rooms/player-disconnected
     */
    async notifyPlayerDisconnection(req, res) {
        try {
            const { room_id, player_name } = req.body;

            // Enregistrer la déconnexion
            await db.query(
                `INSERT INTO player_disconnections (room_id, player_name, disconnected_at)
                 VALUES (?, ?, NOW())`,
                [room_id, player_name]
            );

            // Lancer timer de 15 secondes
            setTimeout(async () => {
                // Vérifier si reconnexion
                const [reconnected] = await db.query(
                    `SELECT * FROM player_disconnections 
                     WHERE room_id = ? AND player_name = ? 
                     AND reconnected_at IS NOT NULL
                     AND disconnected_at > DATE_SUB(NOW(), INTERVAL 15 SECOND)`,
                    [room_id, player_name]
                );

                if (!reconnected.length) {
                    // Rendre permanent
                    await this.makeReplacementPermanent(room_id, player_name);
                }
            }, 15000);

            // Émettre WebSocket
            WebSocketService.broadcastToRoom(room_id, {
                event: 'player_disconnected',
                data: {
                    room_id,
                    player_name,
                    timestamp: new Date().toISOString(),
                },
            });

            res.json({
                success: true,
                message: 'Déconnexion notifiée',
            });

        } catch (error) {
            console.error('Erreur notification déconnexion:', error);
            res.status(500).json({
                success: false,
                message: 'Erreur lors de la notification',
            });
        }
    }

    /**
     * POST /api/rooms/player-reconnected
     */
    async notifyPlayerReconnection(req, res) {
        try {
            const { room_id, player_name } = req.body;

            // Vérifier la dernière déconnexion
            const [lastDisconnection] = await db.query(
                `SELECT * FROM player_disconnections 
                 WHERE room_id = ? AND player_name = ? AND reconnected_at IS NULL
                 ORDER BY disconnected_at DESC LIMIT 1`,
                [room_id, player_name]
            );

            let canRestore = false;
            if (lastDisconnection.length) {
                const disconnectedAt = new Date(lastDisconnection[0].disconnected_at);
                const secondsSince = (Date.now() - disconnectedAt.getTime()) / 1000;
                canRestore = secondsSince < 15;

                // Marquer comme reconnecté
                await db.query(
                    'UPDATE player_disconnections SET reconnected_at = NOW() WHERE id = ?',
                    [lastDisconnection[0].id]
                );
            }

            // Émettre WebSocket
            WebSocketService.broadcastToRoom(room_id, {
                event: 'player_reconnected',
                data: {
                    room_id,
                    player_name,
                    can_restore: canRestore,
                },
            });

            res.json({
                success: true,
                message: 'Reconnexion notifiée',
                can_restore: canRestore,
            });

        } catch (error) {
            console.error('Erreur notification reconnexion:', error);
            res.status(500).json({
                success: false,
                message: 'Erreur lors de la notification',
            });
        }
    }

    /**
     * POST /api/rooms/check-exclusion
     */
    async checkPlayerExclusion(req, res) {
        try {
            const { room_id, player_name } = req.body;

            const [player] = await db.query(
                'SELECT * FROM room_players WHERE room_id = ? AND pseudo = ?',
                [room_id, player_name]
            );

            let isExcluded = false;
            let reason = 'not_excluded';

            if (player.length) {
                isExcluded = player[0].is_excluded === 1;

                if (isExcluded) {
                    const [replacement] = await db.query(
                        `SELECT * FROM player_replacements 
                         WHERE room_id = ? AND player_name = ? 
                         AND is_permanent = 1 AND restored_at IS NULL`,
                        [room_id, player_name]
                    );

                    reason = replacement.length ? 'disconnected_too_long' : 'manual_leave';
                }
            } else {
                isExcluded = true;
                reason = 'not_found';
            }

            res.json({
                success: true,
                is_excluded: isExcluded,
                reason,
            });

        } catch (error) {
            console.error('Erreur vérification exclusion:', error);
            res.status(500).json({
                success: false,
                message: 'Erreur lors de la vérification',
            });
        }
    }
}

module.exports = new RoomController();
```

---

## 🔴 Exemple Python (Flask/FastAPI)

### FastAPI: `room_controller.py`

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from datetime import datetime, timedelta
from database import db
from services.websocket_service import WebSocketService

router = APIRouter()

class ReplacePlayerRequest(BaseModel):
    room_id: int
    player_name: str
    bot_name: str
    is_permanent: bool

class RestorePlayerRequest(BaseModel):
    room_id: int
    player_name: str
    bot_name: str

class PlayerDisconnectionRequest(BaseModel):
    room_id: int
    player_name: str

@router.post("/rooms/replace-player")
async def replace_player_with_bot(request: ReplacePlayerRequest):
    try:
        async with db.transaction():
            # 1. Récupérer le joueur
            player = await db.fetchrow(
                "SELECT * FROM room_players WHERE room_id = $1 AND pseudo = $2",
                request.room_id, request.player_name
            )
            
            if not player:
                raise HTTPException(status_code=404, detail="Joueur non trouvé")
            
            # 2. Créer/mettre à jour le bot
            bot = await db.fetchrow(
                "SELECT * FROM room_players WHERE room_id = $1 AND pseudo = $2",
                request.room_id, request.bot_name
            )
            
            if not bot:
                await db.execute(
                    """INSERT INTO room_players 
                       (room_id, pseudo, is_bot, is_replacement_bot, replaced_player_name, position)
                       VALUES ($1, $2, true, true, $3, $4)""",
                    request.room_id, request.bot_name, request.player_name, player['position']
                )
            else:
                await db.execute(
                    """UPDATE room_players 
                       SET is_replacement_bot = true, replaced_player_name = $1
                       WHERE room_id = $2 AND pseudo = $3""",
                    request.player_name, request.room_id, request.bot_name
                )
            
            # 3. Enregistrer le remplacement
            await db.execute(
                """INSERT INTO player_replacements 
                   (room_id, player_name, bot_name, is_permanent, disconnected_at)
                   VALUES ($1, $2, $3, $4, NOW())""",
                request.room_id, request.player_name, request.bot_name, request.is_permanent
            )
            
            # 4. Marquer comme exclu si permanent
            if request.is_permanent:
                await db.execute(
                    "UPDATE room_players SET is_excluded = true WHERE room_id = $1 AND pseudo = $2",
                    request.room_id, request.player_name
                )
            
            # 5. Émettre WebSocket
            await WebSocketService.broadcast_to_room(request.room_id, {
                "event": "player_replaced",
                "data": {
                    "room_id": request.room_id,
                    "player_name": request.player_name,
                    "bot_name": request.bot_name,
                    "is_permanent": request.is_permanent,
                }
            })
            
            return {
                "success": True,
                "message": "Joueur remplacé par bot",
                "data": {
                    "room_id": request.room_id,
                    "player_replaced": request.player_name,
                    "bot_name": request.bot_name,
                    "is_permanent": request.is_permanent,
                }
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/rooms/restore-player")
async def restore_player(request: RestorePlayerRequest):
    # Implémentation similaire...
    pass

@router.post("/rooms/player-disconnected")
async def notify_player_disconnection(request: PlayerDisconnectionRequest):
    # Implémentation similaire...
    pass

@router.post("/rooms/player-reconnected")
async def notify_player_reconnection(request: PlayerDisconnectionRequest):
    # Implémentation similaire...
    pass

@router.post("/rooms/check-exclusion")
async def check_player_exclusion(request: PlayerDisconnectionRequest):
    # Implémentation similaire...
    pass
```

---

## 🔔 WebSocket Events Implementation

### Exemple PHP (Ratchet/Socket.io)

```php
use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;

class GameWebSocketHandler implements MessageComponentInterface
{
    protected $clients;
    protected $rooms;

    public function onMessage(ConnectionInterface $from, $msg)
    {
        $data = json_decode($msg, true);
        $event = $data['event'] ?? '';
        
        switch ($event) {
            case 'join_room':
                $this->joinRoom($from, $data['data']);
                break;
                
            case 'player_disconnected':
                $this->handlePlayerDisconnection($from, $data['data']);
                break;
                
            // ... autres événements
        }
    }

    protected function broadcastPlayerReplaced($roomId, $playerName, $botName, $isPermanent)
    {
        $message = json_encode([
            'event' => 'player_replaced',
            'data' => [
                'room_id' => $roomId,
                'player_name' => $playerName,
                'bot_name' => $botName,
                'is_permanent' => $isPermanent,
            ],
        ]);

        foreach ($this->rooms[$roomId] ?? [] as $client) {
            $client->send($message);
        }
    }
}
```

---

## 📝 Table `player_disconnections` (SQL)

```sql
CREATE TABLE IF NOT EXISTS player_disconnections (
    id INT PRIMARY KEY AUTO_INCREMENT,
    room_id INT NOT NULL,
    player_name VARCHAR(50) NOT NULL,
    disconnected_at TIMESTAMP NOT NULL,
    reconnected_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (room_id) REFERENCES rooms(room_id) ON DELETE CASCADE,
    INDEX idx_room_player (room_id, player_name),
    INDEX idx_disconnected_at (disconnected_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

---

## ✅ Checklist d'Implémentation Backend

- [ ] Créer la table `player_replacements`
- [ ] Créer la table `player_disconnections`
- [ ] Ajouter les colonnes à `room_players` (`is_replacement_bot`, `replaced_player_name`, `is_excluded`)
- [ ] Implémenter `POST /api/rooms/replace-player`
- [ ] Implémenter `POST /api/rooms/restore-player`
- [ ] Implémenter `POST /api/rooms/player-disconnected`
- [ ] Implémenter `POST /api/rooms/player-reconnected`
- [ ] Implémenter `POST /api/rooms/check-exclusion`
- [ ] Configurer les événements WebSocket (`player_replaced`, `player_restored`, `player_disconnected`, `player_reconnected`)
- [ ] Implémenter le job/timer pour rendre permanent après 15 secondes
- [ ] Tester tous les scénarios (déconnexion < 15s, > 15s, départ manuel)

---

## 📞 Support

Pour toute question sur l'intégration frontend, voir `lib/interfaces/game/game_room_page.dart`.

