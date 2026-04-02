#!/bin/bash
################################################################################
# Script d'installation de Python et des dépendances pour le projet
# Pour ARM64 (Raspberry Pi 3 avec Trixie)
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

# ============================================================================
# MAIN
# ============================================================================

set -e  # Exit on error

ensure_sudo "$@"

log_info "=== Installation de Python et des dépendances ==="

# Installer Python et pip
if ! command -v python3 &> /dev/null; then
    log_info "Installation de Python..."
    apt-get update
    apt-get install -y python3 python3-pip
else
    log_warn "Python déjà installé : $(python3 --version)"
fi

# Installer les dépendances Python
if [ -f "python/requirements.txt" ]; then
    log_info "Installation des dépendances Python à partir de requirements.txt..."
    pip3 install -r python/requirements.txt
else
    log_error "Fichier requirements.txt non trouvé."
    exit 1
fi

log_info "Python et les dépendances installés avec succès"