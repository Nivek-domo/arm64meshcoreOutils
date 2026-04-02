#!/bin/bash
# QUICK START - Meshcore Mosquitto Installation
# ============================================
# Copier/coller ces commandes sur ta RPi/OPi pour l'installation rapide

# 1️⃣  Télécharger le script
cd /home/pi  # ou /home/orangepi pour Orange Pi
git clone https://github.com/[USERNAME]/scriptserveur.git
cd scriptserveur

# 2️⃣  Lancer l'installation (version default)
sudo ./install-meshcore-nodered-mosquitto.sh

# ☕ Attendre ~20-25 minutes pendant que tout s'installe...

# 3️⃣  C'est bon ! Vérifier que ça tourne
systemctl status mosquitto nodered postgresql

# 4️⃣  Accéder à Node-RED
# Ouvrir dans le navigateur : http://192.168.X.X:1880
# (remplacer 192.168.X.X par l'IP de ta RPi, ex: 192.168.100.122)

# ============================================
# ✅ C'EST FAIT ! Vous avez maintenant :
# ============================================
# 
# • 🌍 Node-RED : http://192.168.X.X:1880
# • 📡 Mosquitto MQTT : mqtt://192.168.X.X:1883
#        User: meshuser / Pass: meshpass123
# • 🗄️  PostgreSQL : 192.168.X.X:5432
#        User: vpnuser / Pass: motdepassefort
#
# ============================================
# 📝 OPTIONS : Personnaliser les identifiants
# ============================================
# 
# Si vous voulez changer le user/password MQTT :
# 
# sudo env MOSQUITTO_USER="mon_user" MOSQUITTO_PASSWORD="mon_pass" \
#   bash ./install-meshcore-nodered-mosquitto.sh
#
# ============================================
# 🆘 DÉPANNAGE RAPIDE
# ============================================
#
# Node-RED ne répond pas ?
#   sudo systemctl restart nodered
#   journalctl -u nodered -n 30
#
# Mosquitto ne répond pas ?
#   sudo systemctl status mosquitto
#   sudo mosquitto -c /etc/mosquitto/mosquitto.conf
#
# PostgreSQL erreur de permission ?
#   PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d postgres -c "SELECT 1;"
#
# ============================================
# 🔗 DOCS COMPLÈTES
# ============================================
#
# Voir README_MOSQUITTO.md pour des explications détaillées
# Voir rpi3-trixie-installer/TUTORIEL_COMPLET.md pour config avancée
#
# ============================================
