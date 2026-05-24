# 🚀 Guide de démarrage du backend Cauris

## 📋 Scripts disponibles

### 1. Démarrage complet (`start_all.sh`)
Démarre tous les services en une seule commande :
- Laravel (port 8000)
- WebSocket Socket.io (port 3000)
- ngrok (tunnels)

```bash
cd /home/adolphe/cauris_app
./start_all.sh
```

### 2. Arrêt complet (`stop_all.sh`)
Arrête tous les services :

```bash
./stop_all.sh
```

### 3. Démarrage automatique de Socket.io

Pour que Socket.io démarre automatiquement au démarrage du PC :

```bash
sudo ./install_autostart.sh
```

Cela installe un service systemd qui démarre Socket.io automatiquement.

## 🔧 Services individuels

### Laravel
```bash
cd /opt/lampp/htdocs/backendCauris
php artisan serve
```

### WebSocket Socket.io
```bash
./start_websocket.sh
```

### ngrok
```bash
./start_ngrok_all.sh
```

## 📊 Vérification des services

### Vérifier que tout fonctionne
```bash
# Laravel
curl http://localhost:8000/api

# WebSocket
curl http://localhost:3000/health

# ngrok
curl http://localhost:4040/api/tunnels
```

### Vérifier le service systemd (si installé)
```bash
sudo systemctl status cauris-websocket
```

## 📋 Logs

- Laravel: `tail -f ~/laravel.log`
- WebSocket: `tail -f ~/websocket.log`
- ngrok: `tail -f ~/ngrok_all.log`
- Service systemd: `sudo journalctl -u cauris-websocket -f`

## 🛑 Arrêt des services

### Arrêt manuel
```bash
./stop_all.sh
```

### Arrêt individuel
```bash
# Laravel
pkill -f "php artisan serve"

# WebSocket
pkill -f "node.*server.js"

# ngrok
pkill ngrok

# Service systemd
sudo systemctl stop cauris-websocket
```

## ⚙️ Configuration du démarrage automatique

### Socket.io (recommandé)
Le service systemd démarre automatiquement Socket.io au démarrage du PC.

### Laravel et ngrok
Pour démarrer automatiquement Laravel et ngrok, vous pouvez :
1. Ajouter `start_all.sh` à votre `.bashrc` ou `.profile`
2. Créer un service systemd pour Laravel
3. Utiliser un gestionnaire de processus comme `supervisord`

## 🔍 Dépannage

### Le serveur ne démarre pas
1. Vérifier les logs : `tail -f ~/websocket.log`
2. Vérifier que le port n'est pas utilisé : `netstat -tlnp | grep :3000`
3. Vérifier les permissions : `ls -la /opt/lampp/htdocs/backendCauris/websocket-server`

### Le service systemd ne démarre pas
1. Vérifier les logs : `sudo journalctl -u cauris-websocket`
2. Vérifier le chemin de node : `which node`
3. Vérifier les permissions du fichier de service

