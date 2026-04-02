#!/bin/bash
################################################################################
# Script de configuration de Node-RED pour Raspberry Pi 3 sous Trixie ARM64
# Ce script installe Node-RED, ses dépendances et restaure une config clone.
################################################################################

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier et obtenir les privilèges sudo si nécessaire
ensure_sudo() {
    if [[ $EUID -ne 0 ]]; then
        log_warn "Ce script nécessite des privilèges root. Demande de mot de passe..."
        exec sudo "$0" "$@"
    fi
}

set -e  # Exit on error

ensure_sudo "$@"

if id orangepi &>/dev/null; then
    NODERED_USER="orangepi"
elif id pi &>/dev/null; then
    NODERED_USER="pi"
else
    NODERED_USER="${SUDO_USER:-$(whoami)}"
fi

NODERED_HOME="/home/${NODERED_USER}"
NODERED_DIR="${NODERED_HOME}/.node-red"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../nodered/reference-opi66"
NODERED_STRICT_CLONE="${NODERED_STRICT_CLONE:-1}"

log_info "=== Installation de Node-RED ==="

# Installer Node-RED globalement
if ! command -v node &> /dev/null; then
    log_error "Node.js n'est pas installé. Veuillez installer Node.js avant de continuer."
    exit 1
fi

log_info "Installation de Node-RED..."
npm install -g --unsafe-perm node-red

log_info "Installation des nodes Node-RED nécessaires..."
npm install -g \
    node-red-contrib-postgresql \
    node-red-dashboard

log_info "Configuration de Node-RED comme service systemd..."
cat << EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED
After=network.target

[Service]
ExecStart=/usr/bin/env node-red
User=${NODERED_USER}
Group=${NODERED_USER}
WorkingDirectory=${NODERED_HOME}
Restart=always
Environment=NODE_OPTIONS=--max-old-space-size=256

[Install]
WantedBy=multi-user.target
EOF

log_info "Préparation du dossier Node-RED pour ${NODERED_USER}..."
mkdir -p "${NODERED_DIR}"
chown -R "${NODERED_USER}:${NODERED_USER}" "${NODERED_DIR}"

if [ -d "${TEMPLATE_DIR}" ]; then
    log_info "Restauration du clone Node-RED depuis ${TEMPLATE_DIR}..."
    ts="$(date +%Y%m%d%H%M%S)"

    if [ "${NODERED_STRICT_CLONE}" = "1" ]; then
        if [ -n "$(find "${NODERED_DIR}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            backup_dir="${NODERED_HOME}/.node-red-backup-${ts}"
            mv "${NODERED_DIR}" "${backup_dir}"
            log_info "Mode strict clone actif: sauvegarde complète dans ${backup_dir}"
        fi
        mkdir -p "${NODERED_DIR}"
        cp -a "${TEMPLATE_DIR}/." "${NODERED_DIR}/"
    else
        if [ -f "${NODERED_DIR}/flows.json" ] || [ -f "${NODERED_DIR}/settings.js" ]; then
            backup_dir="${NODERED_DIR}/backup-before-clone-${ts}"
            mkdir -p "${backup_dir}"
            cp -a "${NODERED_DIR}/flows.json" "${backup_dir}/" 2>/dev/null || true
            cp -a "${NODERED_DIR}/settings.js" "${backup_dir}/" 2>/dev/null || true
            cp -a "${NODERED_DIR}/package.json" "${backup_dir}/" 2>/dev/null || true
            cp -a "${NODERED_DIR}/package-lock.json" "${backup_dir}/" 2>/dev/null || true
            log_info "Backup local créé: ${backup_dir}"
        fi

        for cfg in \
            flows.json \
            .flows.json.backup \
            settings.js \
            package.json \
            package-lock.json \
            environment \
            .npmrc \
            .config.nodes.json \
            .config.nodes.json.backup \
            .config.runtime.json \
            .config.runtime.json.backup \
            .config.users.json \
            .config.users.json.backup
        do
            if [ -f "${TEMPLATE_DIR}/${cfg}" ]; then
                cp -a "${TEMPLATE_DIR}/${cfg}" "${NODERED_DIR}/${cfg}"
            fi
        done

        if [ -d "${TEMPLATE_DIR}/lib" ]; then
            rm -rf "${NODERED_DIR}/lib"
            cp -a "${TEMPLATE_DIR}/lib" "${NODERED_DIR}/lib"
        fi
    fi

    chown -R "${NODERED_USER}:${NODERED_USER}" "${NODERED_DIR}"

    if [ -f "${NODERED_DIR}/package-lock.json" ]; then
        log_info "Installation des palettes exactement comme la référence..."
        sudo -u "${NODERED_USER}" bash -lc "cd '${NODERED_DIR}' && npm ci --omit=dev"
    elif [ -f "${NODERED_DIR}/package.json" ]; then
        log_info "Installation des palettes depuis package.json..."
        sudo -u "${NODERED_USER}" bash -lc "cd '${NODERED_DIR}' && npm install --omit=dev"
    fi
else
    log_warn "Template clone Node-RED introuvable: ${TEMPLATE_DIR}"
    log_warn "Le service démarre sans restauration des flows/config de référence."
fi

# Recharger les fichiers de configuration systemd
systemctl daemon-reload
systemctl enable nodered
systemctl restart nodered

log_info "Node-RED installé et configuré avec succès."
log_info "Utilisateur Node-RED: ${NODERED_USER}"
log_info "Mode strict clone: ${NODERED_STRICT_CLONE} (1=oui, 0=non)"
log_info "Vous pouvez accéder à l'interface web de Node-RED à l'adresse http://localhost:1880"