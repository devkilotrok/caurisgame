# 🔧 Installation du démarrage automatique - Explications

## 📍 Où se fait l'installation ?

### Script d'installation
- **Emplacement** : `/home/adolphe/cauris_app/install_autostart.sh`
- **Exécution** : Depuis le répertoire `cauris_app`

### Service systemd installé
- **Emplacement** : `/etc/systemd/system/cauris-websocket.service`
- **Cible** : Le service pointe vers `/opt/lampp/htdocs/backendCauris/websocket-server`

## 🔄 Processus d'installation

1. **Vous exécutez** : `sudo ./install_autostart.sh` depuis `cauris_app`
2. **Le script** :
   - Trouve automatiquement le fichier `cauris-websocket.service` dans `cauris_app`
   - Copie ce fichier vers `/etc/systemd/system/`
   - Active le service pour le démarrage automatique
   - Démarre le service immédiatement

3. **Résultat** :
   - Le service est installé dans le système (pas dans cauris_app)
   - Socket.io démarre automatiquement au démarrage du PC
   - Les logs sont dans `~/websocket.log`

## 📂 Structure des fichiers

```
/home/adolphe/cauris_app/
  ├── install_autostart.sh          # Script d'installation (à exécuter)
  └── cauris-websocket.service      # Fichier de configuration (source)

/etc/systemd/system/
  └── cauris-websocket.service      # Service installé (copie)

/opt/lampp/htdocs/backendCauris/websocket-server/
  └── server.js                     # Script exécuté par le service
```

## ✅ Avantages

- Le script peut être exécuté depuis n'importe où (il trouve automatiquement son répertoire)
- Le service est installé dans le système (persistant)
- Le service pointe vers le bon répertoire du backend
- Les logs sont centralisés dans `~/websocket.log`

## 🚀 Utilisation

```bash
cd /home/adolphe/cauris_app
sudo ./install_autostart.sh
```

Le script fonctionne même si vous l'exécutez depuis un autre répertoire, car il détecte automatiquement son emplacement.

