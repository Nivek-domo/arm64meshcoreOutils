# 📡 Meshcore Installation Scripts

Installation automatisée complète : **Mosquitto MQTT + Node-RED + PostgreSQL + meshcore-decoder** pour ARM64 (Raspberry Pi, Orange Pi, etc.).

---

## ⚡ Installation rapide (20 min)

```bash
git clone https://github.com/Nivek-domo/arm64meshcoreOutils.git
cd arm64meshcoreOutils
sudo ./install-meshcore-nodered-mosquitto.sh
```

✅ C'est tout ! Accédez à **http://localhost:1880** (Node-RED) après l'installation

---

## 📦 Composants installés

| Composant | Description |
|-----------|-------------|
| **Node.js 20.x** | Runtime JavaScript |
| **PostgreSQL 17** | Base de données relationnelle |
| **Mosquitto** | Broker MQTT léger |
| **Node-RED** | Plateforme IoT/automation |
| **meshcore-decoder** | Décodeur MeshCore |
| **node-red-contrib-web-worldmap** | Carte mondiale interactive |
| **node-red-contrib-postgresql** | Connecteur BD |
| **@flowfuse/node-red-dashboard** | Dashboard UI |

---

## 🌐 Accès après installation

| Service | Adresse | Identifiants |
|---------|---------|--------------|
| **Node-RED** | `http://192.168.X.X:1880` | Aucun |
| **Mosquitto MQTT** | `mqtt://192.168.X.X:1883` | user: `meshuser` / pass: `meshpass123` |
| **PostgreSQL** | `192.168.X.X:5432` | user: `vpnuser` / pass: `motdepassefort` |

---

## 🚀 Marche à suivre

### Prérequis
- ✅ Raspberry Pi 3B+/4 ou Orange Pi Zero 2W (ARM64)
- ✅ Debian 12/13 ou Ubuntu 22.04 LTS
- ✅ Accès SSH/écran + connexion réseau

### Installation

1. **Se connecter à la machine**
   ```bash
   ssh pi@<IP_RASPBERRY>
   # ou
   ssh orangepi@<IP_OPI>
   ```

2. **Cloner et installer**
   ```bash
   git clone https://github.com/Nivek-domo/arm64meshcoreOutils.git
   cd arm64meshcoreOutils
   sudo ./install-meshcore-nodered-mosquitto.sh
   ```

3. **Attendre 20-25 minutes** ☕
   - Installation des dépendances
   - Compilation de meshcore-decoder
   - Création de la base de données

4. **Vérifier que c'est bon**
   ```bash
   systemctl status mosquitto nodered postgresql
   ```

5. **Accéder à Node-RED**
   - Ouvrir dans le navigateur : **http://192.168.X.X:1880**
   - C'est prêt ! 🎉

---

## 🔧 Personnalisation

### Changer les identifiants MQTT
```bash
sudo mosquitto_passwd -b /etc/mosquitto/passwd mon_user mon_password
sudo systemctl restart mosquitto
```

### Ajouter une ACL personnalisée
Éditer `/etc/mosquitto/acl.conf` puis redémarrer :
```bash
sudo systemctl restart mosquitto
```

### Vérifier PostgreSQL
```bash
PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d postgres -c "SELECT 1;"
```

---

## 🐛 Dépannage rapide

```bash
# Node-RED ne répond pas ?
sudo systemctl restart nodered
journalctl -u nodered -n 50 --no-pager

# Mosquitto bloqué ?
sudo systemctl restart mosquitto

# Test rapid MQTT
mosquitto_sub -h localhost -u meshuser -P meshpass123 -t msh/#
```

---

## 📚 Documentation

- [Mosquitto guide](README_MOSQUITTO.md)
- [Node-RED docs](https://nodered.org/docs/)
- [PostgreSQL docs](https://www.postgresql.org/docs/)
- [meshcore-decoder](https://github.com/michaelhart/meshcore-decoder)

---

**Créé :** Avril 2026 | **Auteur :** Nivek-domo
