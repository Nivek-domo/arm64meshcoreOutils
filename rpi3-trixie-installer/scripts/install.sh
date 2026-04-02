#!/bin/bash
################################################################################
# Script principal d'installation pour Raspberry Pi 3 avec Trixie ARM64
# Ce script gère l'exécution des autres scripts de configuration.
################################################################################

# Fonction pour afficher les messages d'information
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

# Vérifier les privilèges sudo
if [[ $EUID -ne 0 ]]; then
    echo "Ce script nécessite des privilèges root. Veuillez exécuter avec sudo."
    exit 1
fi

log_info "=== Démarrage de l'installation ==="

# Exécuter les scripts de configuration
for script in setup-nodered.sh setup-postgresql.sh setup-python.sh; do
    if [ -f "./scripts/$script" ]; then
        log_info "Exécution de $script..."
        bash "./scripts/$script"
    else
        echo "Erreur : $script non trouvé."
        exit 1
    fi
done

log_info "=== Vérification de l'installation ==="
bash "./scripts/verify-installation.sh"

log_info "Installation terminée avec succès!"