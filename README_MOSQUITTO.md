# Installation Meshcore + Node-RED + PostgreSQL - Version Mosquitto

Script d'installation automatisé pour déployer une stack complète sur Raspberry Pi, Orange Pi ou autre ARM64.

> **Choix entre deux versions :**
> - **v3 (EMQX)** : Broker MQTT avancé, dashboard web (18083), ACL complexe
> - **Mosquitto** : Broker MQTT léger et simple, configuration fichier

---

## 🚀 Démarrage rapide (Version Mosquitto)

### Prérequis
- ARM64 : Raspberry Pi 3B+/4, Orange Pi Zero 2W, ou équivalent
- Debian 12 (Bookworm), Debian 13 (Trixie), ou Ubuntu 22.04 LTS
- Accès root/sudo
- Connexion Internet

### Installation en 1 commande

```bash
# Cloner le repo
git clone https://github.com/[USERNAME]/scriptserveur.git
cd scriptserveur

# Rendre le script exécutable
chmod +x install-meshcore-nodered-mosquitto.sh

# Lancer l'installation (avec paramètres par défaut)
sudo ./install-meshcore-nodered-mosquitto.sh
```

**Avec paramètres personnalisés :**

```bash
sudo env \
  MOSQUITTO_USER="mon_user" \
  MOSQUITTO_PASSWORD="mon_password" \
  DB_NAME="postgres" \
  DB_USER="vpnuser" \
  DB_PASSWORD="motdepassefort" \
  bash ./install-meshcore-nodered-mosquitto.sh
```

---

## 📋 Paramètres de configuration

| Variable | Défaut | Description |
|----------|--------|-------------|
| `MOSQUITTO_USER` | `meshuser` | Utilisateur MQTT |
| `MOSQUITTO_PASSWORD` | `meshpass123` | Mot de passe MQTT |
| `DB_NAME` | `postgres` | Nom de la base de données PostgreSQL |
| `DB_USER` | `vpnuser` | Utilisateur PostgreSQL |
| `DB_PASSWORD` | `motdepassefort` | Mot de passe PostgreSQL |
| `NODERED_STRICT_CLONE` | `1` | 1 = clone strict, 0 = fusion fichiers |

---

## 📦 Composants installés

| Composant | Version | Description |
|-----------|---------|-------------|
| **Node.js** | 20.x | Runtime JavaScript |
| **PostgreSQL** | 17 | Base de données relationnelle |
| **Mosquitto** | latest | Broker MQTT léger |
| **Node-RED** | latest | Plateforme IoT/automation |
| **meshcore-decoder** | v0.3.0+ | Décodeur MeshCore |

### Palettes Node-RED incluses
- `@flowfuse/node-red-dashboard` : Dashboard UI
- `node-red-contrib-postgresql` : Connecteur PostgreSQL
- `node-red-contrib-moment` : Manipulation dates/heures
- `node-red-contrib-web-worldmap` : Carte mondiale interactive

---

## 🌐 Accès après installation

| Service | URL/Port | Identifiants |
|---------|----------|--------------|
| **Node-RED** | `http://localhost:1880` | Aucun (par défaut) |
| **Mosquitto MQTT** | `mqtt://localhost:1883` | `meshuser` / `meshpass123` |
| **PostgreSQL** | `localhost:5432` | `vpnuser` / `motdepassefort` |

---

## 🔧 Configuration Mosquitto

### Utilisateurs MQTT

La liste des utilisateurs est gérée dans `/etc/mosquitto/passwd` :

```bash
# Voir les utilisateurs
cat /etc/mosquitto/passwd

# Ajouter un utilisateur
sudo mosquitto_passwd /etc/mosquitto/passwd nouveau_user

# Changer le mot de passe
sudo mosquitto_passwd -b /etc/mosquitto/passwd mon_user mon_password

# Supprimer un utilisateur
sudo mosquitto_passwd -D /etc/mosquitto/passwd mon_user
```

Ensuite, redémarrer Mosquitto :
```bash
sudo systemctl restart mosquitto
```

### ACL (Access Control List)

Fichier : `/etc/mosquitto/acl.conf`

Format standard :
```
user mon_user
  topic read recette/donnees/#
  topic write commande/action/#

user autre_user
  topic readwrite msh/#
```

Redémarrer après modification :
```bash
sudo systemctl restart mosquitto
```

---

## 📊 Vérification des services

```bash
# Vérifier l'état
systemctl status mosquitto nodered postgresql

# Voir les logs
journalctl -u mosquitto -n 50
journalctl -u nodered -n 50
journalctl -u postgresql -n 50

# Test MQTT
mosquitto_sub -h localhost -u meshuser -P "meshpass123" -t "msh/#"
```

---

## 🐛 Troubleshooting

### Mosquitto ne démarre pas
```bash
# Vérifier les erreurs
sudo mosquitto -c /etc/mosquitto/mosquitto.conf

# Vérifier le port
ss -lntp | grep 1883
```

### Node-RED erreurs "permission denied" sur les tables PostgreSQL
Solution déjà appliquée par le script (GRANT sur tables + dépendances).

Vérifier manuellement :
```bash
PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d postgres \
  -c "SELECT count(*) FROM meshcore_nodes;"
```

### PostgreSQL bloquée en boucle locale (127.0.0.1 seulement)
Vérifié lors de l'installation - `listen_addresses = '*'` activé automatiquement.

Vérifier :
```bash
ss -lntp | grep 5432
sudo grep 'listen_addresses' /etc/postgresql/*/main/postgresql.conf
```

---

## 🚀 Déploiement sur une autre machine

Pour cloner cette installation sur une nouvelle machine :

1. **Sur la machine de référence, extraire la config Node-RED :**
   ```bash
   # Copier le bundle (depuis /home/pi/.node-red)
   tar czf nodered_backup.tar.gz -C /home/pi .node-red/
   ```

2. **Mettre à jour le bundle du repo :**
   ```bash
   # Mettre à jour le script avec la dernière config
   cp nodered_backup.tar.gz /chemin/vers/repo/rpi3-trixie-installer/nodered/reference-opi66/
   ```

3. **Sur la nouvelle machine :**
   ```bash
   sudo env NODERED_STRICT_CLONE=1 bash ./install-meshcore-nodered-mosquitto.sh
   ```

---

## 📚 Documentation complète

Voir le fichier `TUTORIEL_COMPLET.md` pour :
- Architecture détaillée
- Configuration avancée Mosquitto
- Intégration custom Meshcore
- Migration d'une instance EMQX

---

## 🆘 Support

- **Issues** : Poster sur GitHub
- **Logs utiles pour debug :**
  ```bash
  journalctl -u nodered --since "1 hour ago" | tail -100
  journalctl -u mosquitto --since "1 hour ago" | tail -100
  ```

---

## 📄 Licence

Voir `LICENSE`

---

**Dernière mise à jour :** Avril 2026
