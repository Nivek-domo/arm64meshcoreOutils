# 📡 Meshcore Installation Scripts

Collection complète de scripts d'installation pour déployer une stack **Meshcore + Node-RED + PostgreSQL** sur ARM64 (Raspberry Pi, Orange Pi, etc.).

> Deux versions disponibles : **EMQX** (avancé) ou **Mosquitto** (simple)

---

## 🎯 Choix rapide

### Je veux une solution **simple et légère** ✅ → Mosquitto
- Installation rapide (~10 min)
- Configuration fichier simple
- Consommation CPU/RAM minimale
- **👉 Lire [README_MOSQUITTO.md](README_MOSQUITTO.md)**

### Je veux une solution **avancée avec dashboard** → EMQX
- Dashboard web complet (port 18083)
- ACL et topics rewrite avancé
- Gestion API complète
- **👉 Lire [TUTORIEL_COMPLET.md](rpi3-trixie-installer/TUTORIEL_COMPLET.md)**

---

## ⚡ Installation Mosquitto (5 min)

```bash
git clone https://github.com/[USERNAME]/scriptserveur.git
cd scriptserveur
sudo ./install-meshcore-nodered-mosquitto.sh
```

✅ Prêt ! Accédez à **http://localhost:1880** (Node-RED)

---

## 📦 Fichiers disponibles

| Script | Stack | Utilisateurs |
|--------|-------|--------------|
| `install-meshcore-nodered-mosquitto.sh` | Mosquitto + Node-RED + PostgreSQL + meshcore-decoder | **Recommandé** |
| `install-meshcore-nodered-v3.sh` | EMQX + Node-RED + PostgreSQL + meshcore-decoder | Avancé |
| `install-meshcore-nodered-v2.sh` | Ancien (référence historique) | Historique |
| `install-meshcore-nodered.sh` | Ancien (référence historique) | Historique |

---

## 🌐 Accès post-installation

| Service | URL | Identifiants |
|---------|-----|--------------|
| **Node-RED** | `http://192.168.X.X:1880` | Aucun |
| **Mosquitto MQTT** | `mqtt://192.168.X.X:1883` | `meshuser` / `meshpass123` |
| **PostgreSQL** | `192.168.X.X:5432` | `vpnuser` / `motdepassefort` |

---

## 🚀 Marche à suivre pour vos copains

### Prérequis
- ✅ Raspberry Pi 3B+/4 ou Orange Pi Zero 2W (ARM64)
- ✅ Debian 12 Bookworm ou Debian 13 Trixie
- ✅ Accès SSH ou écran
- ✅ Connexion réseau

### Étapes

1. **Se connecter en SSH**
   ```bash
   ssh pi@<IP_DE_VOTRE_RASPBERRY>
   # ou
   ssh orangepi@<IP_OPI>
   ```

2. **Télécharger le script**
   ```bash
   cd /home/pi  # ou /home/orangepi
   git clone https://github.com/[USERNAME]/scriptserveur.git
   cd scriptserveur
   ```

3. **Lancer l'installation**
   ```bash
   # Avec paramètres par défaut
   sudo ./install-meshcore-nodered-mosquitto.sh
   
   # Ou personnaliser
   sudo env MOSQUITTO_USER="custom" MOSQUITTO_PASSWORD="pass123" \
     bash ./install-meshcore-nodered-mosquitto.sh
   ```

4. **Attendre ~15-20 minutes** ☕
   - Installation des dépendances
   - Compilation de meshcore-decoder
   - Démarrage des services

5. **Vérifier l'installation**
   ```bash
   # Voir l'état des services
   systemctl status mosquitto nodered postgresql
   
   # Test rapide
   curl http://localhost:1880
   mosquitto_sub -h localhost -u meshuser -P meshpass123 -t msh/#
   ```

6. **Accédez à Node-RED**
   - Browser → `http://192.168.X.X:1880`
   - Importer vos flows depuis l'UI

---

## 🔧 Paramétrage courant

### Changer les identifiants MQTT
```bash
# Ajouter/modifier un utilisateur
sudo mosquitto_passwd -b /etc/mosquitto/passwd <user> <password>

# Redémarrer
sudo systemctl restart mosquitto
```

### Ajouter une ACL personnalisée
Éditer `/etc/mosquitto/acl.conf` :
```
user mon_utilisateur
  topic read recette/donnees/#
  topic write commande/action/#
```

Puis redémarrer :
```bash
sudo systemctl restart mosquitto
```

### Vérifier PostgreSQL
```bash
PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d postgres \
  -c "SELECT COUNT(*) FROM meshcore_nodes;"
```

---

## 🐛 Problèmes courants

| Symptôme | Cause | Solution |
|----------|-------|----------|
| Node-RED ne démarre pas | Port 1880 occupé | `sudo lsof -i :1880` → kill le processus |
| Mosquitto refuse la connexion | User/pass erroné | Vérifier avec `mosquitto_passwd -b` |
| PostgreSQL `permission denied` | Bug déjà corrigé dans le script | Relancer le script ou faire les GRANT manuellement |
| Lent à installer | Normal sur RPi | Attendre ~20 min + 5 min de compil meshcore-decoder |

---

## 📚 Documentation complète

- **Node-RED** : https://nodered.org/docs/
- **Mosquitto** : https://mosquitto.org/man/mosquitto-8.html
- **PostgreSQL** : https://www.postgresql.org/docs/
- **meshcore-decoder** : https://github.com/michaelhart/meshcore-decoder

---

## 🆘 Support

En cas de problème :

1. **Lire les logs** :
   ```bash
   journalctl -u nodered -n 100 --no-pager
   journalctl -u mosquitto -n 100 --no-pager
   ```

2. **Partager les erreurs** sur GitHub Issues avec :
   - Output de `systemctl status <service>`
   - Dernières lignes de journalctl
   - Version de Debian/ARM (`cat /etc/os-release`)

3. **Reset complet** (si tout est cassé) :
   ```bash
   # Arrêter les services
   sudo systemctl stop nodered mosquitto postgresql
   
   # Réinitialiser
   sudo rm -rf /home/pi/.node-red
   sudo /etc/init.d/postgresql restart
   
   # Relancer le script
   sudo ./install-meshcore-nodered-mosquitto.sh
   ```

---

## 📝 Versions

- **Mosquitto v1.0** : Version légère recommandée (Avril 2026)
- **EMQX v3** : Version avancée (Avril 2026)
- **Plus anciennes** : Voir branches Git (v1, v2)

---

**Repository créé :** Avril 2026  
**Mainteneur :** @Nivek
