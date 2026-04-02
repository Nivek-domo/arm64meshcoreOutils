#!/bin/bash
################################################################################
# Vérification de l'installation : Node-RED, PostgreSQL, et Python
# Ce script vérifie que tous les services nécessaires sont actifs et fonctionnent correctement.
################################################################################

# Fonction pour vérifier l'état d'un service
check_service() {
    if systemctl is-active --quiet "$1"; then
        echo "✓ Service $1 est actif"
    else
        echo "✗ Service $1 n'est pas actif"
    fi
}

# Vérification des services Node-RED et PostgreSQL
echo "=== Vérification des services ==="
check_service nodered
check_service postgresql

# Vérification de l'installation de Python
if command -v python3 &> /dev/null; then
    echo "✓ Python est installé : $(python3 --version)"
else
    echo "✗ Python n'est pas installé"
fi

# Vérification des dépendances Python
if [ -f "../python/requirements.txt" ]; then
    echo "✓ Fichier requirements.txt trouvé"
else
    echo "✗ Fichier requirements.txt manquant"
fi

# Vérification de l'installation de pip
if command -v pip3 &> /dev/null; then
    echo "✓ pip est installé : $(pip3 --version)"
else
    echo "✗ pip n'est pas installé"
fi

# Résumé final
echo "=== Vérification terminée ==="