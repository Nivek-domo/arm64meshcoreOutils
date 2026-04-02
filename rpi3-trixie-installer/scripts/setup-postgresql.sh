#!/bin/bash
################################################################################
# Script d'installation et de configuration de PostgreSQL pour Raspberry Pi 3
# Ce script installe PostgreSQL, crée les utilisateurs et les bases de données
# nécessaires, et applique les configurations spécifiques.
################################################################################

# Fonction pour afficher les messages d'information
log_info() {
    echo "[INFO] $1"
}

# Fonction pour afficher les messages d'erreur
log_error() {
    echo "[ERROR] $1" >&2
}

# Mise à jour des paquets et installation de PostgreSQL
log_info "Mise à jour des paquets..."
apt-get update
apt-get upgrade -y

log_info "Installation de PostgreSQL..."
apt-get install -y postgresql postgresql-contrib

# Configuration de PostgreSQL
log_info "Configuration de PostgreSQL..."

# Créer un utilisateur et une base de données
sudo -u postgres psql <<EOF
DO
\$do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vpnuser') THEN
        CREATE ROLE vpnuser WITH LOGIN PASSWORD 'motdepassefort';
    END IF;
END
\$do$;

DO
\$do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'vpndb') THEN
        CREATE DATABASE vpndb OWNER vpnuser;
    END IF;
END
\$do$;

GRANT ALL PRIVILEGES ON DATABASE vpndb TO vpnuser;
EOF

log_info "PostgreSQL configuré avec succès"

# Redémarrer le service PostgreSQL
log_info "Redémarrage du service PostgreSQL..."
systemctl restart postgresql

log_info "Installation et configuration de PostgreSQL terminées avec succès"