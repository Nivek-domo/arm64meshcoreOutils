#!/bin/bash
################################################################################
# Installation complète : Node-RED + PostgreSQL + meshcore-decoder + Meshtastic
# Pour ARM64 (Raspberry Pi, Orange Pi, etc.)
# Testé sur : Debian 12 Bookworm, Ubuntu 22.04, Debian 13 Trixie
#
# Usage: sudo ./install-meshcore-nodered.sh
#    ou: ./install-meshcore-nodered.sh (will prompt for sudo password)
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

NODERED_USER="${NODERED_USER:-pi}"
DB_NAME="vpndb"
DB_USER="vpnuser"
DB_PASSWORD="${DB_PASSWORD:-motdepassefort}"
DB_PORT=5432

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# FONCTIONS
# ============================================================================

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

log_info "=== Installation Meshcore + Node-RED + PostgreSQL pour ARM64 ==="
log_info "NODERED_USER=${NODERED_USER}, DB_NAME=${DB_NAME}"

# ============================================================================
# 1. MISE À JOUR SYSTÈME
# ============================================================================

log_info "=== Étape 1 : Mise à jour système ==="
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git build-essential python3

# ============================================================================
# 2. INSTALLATION NODE.JS (via NodeSource)
# ============================================================================

log_info "=== Étape 2 : Installation Node.js ==="
if ! command -v node &> /dev/null; then
    log_info "Téléchargement et configuration NodeSource..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    log_warn "Node.js déjà installé : $(node --version)"
fi

log_info "Versions installées:"
node --version
npm --version

# ============================================================================
# 3. INSTALLATION POSTGRESQL
# ============================================================================

log_info "=== Étape 3 : Installation PostgreSQL ==="
if ! command -v psql &> /dev/null; then
    log_info "Installation de PostgreSQL..."
    apt-get install -y postgresql postgresql-contrib
else
    log_warn "PostgreSQL déjà installé"
fi

systemctl enable postgresql
systemctl start postgresql
sleep 3

log_info "Configuration PostgreSQL..."

# Créer l'utilisateur et la base de données
sudo -u postgres bash << 'PGSQL_SETUP'
# Check if user exists, if not create it
if ! psql -U postgres -tc "SELECT 1 FROM pg_user WHERE usename = 'vpnuser'" | grep -q 1; then
    psql -U postgres -c "CREATE USER vpnuser WITH PASSWORD 'motdepassefort';"
fi

# Check if database exists, if not create it
if ! psql -U postgres -lqt | cut -d \| -f 1 | grep -w vpndb ; then
    psql -U postgres -c "CREATE DATABASE vpndb OWNER vpnuser;"
fi

# Grant privileges
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE vpndb TO vpnuser;"
PGSQL_SETUP

# Now create tables - connect as the new user
PGPASSWORD='motdepassefort' psql -h localhost -U vpnuser -d vpndb << 'SQL_TABLES'
-- Tables Meshtastic
CREATE TABLE IF NOT EXISTS public.meshcore_nodes (
    public_key TEXT PRIMARY KEY,
    device_name TEXT,
    device_role TEXT,
    signature TEXT,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    ts TIMESTAMPTZ,
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.node_info (
    from_id BIGINT PRIMARY KEY,
    node_id TEXT,
    long_name TEXT,
    short_name TEXT,
    macaddr TEXT,
    hw_model TEXT,
    hw_model_num INTEGER,
    role TEXT,
    role_num INTEGER,
    public_key TEXT,
    is_unmessagable BOOLEAN,
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mqtt_packets (
    id BIGSERIAL PRIMARY KEY,
    data JSONB NOT NULL,
    channel_id TEXT,
    gateway_id TEXT,
    received_at TIMESTAMPTZ DEFAULT now(),
    CONSTRAINT check_data_not_null CHECK (data IS NOT NULL)
);

-- Index pour performances
CREATE INDEX IF NOT EXISTS idx_meshcore_nodes_updated ON meshcore_nodes (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_node_info_node_id ON node_info (node_id);
CREATE INDEX IF NOT EXISTS idx_mqtt_packets_received_at ON mqtt_packets (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_mqtt_packets_channel_id ON mqtt_packets (channel_id);
CREATE INDEX IF NOT EXISTS idx_mqtt_packets_data_gin ON mqtt_packets USING gin(data);
SQL_TABLES

log_info "PostgreSQL configuré avec succès"

# ============================================================================
# 4. INSTALLATION NODE-RED
# ============================================================================

log_info "=== Étape 4 : Installation Node-RED ==="

# Créer utilisateur si nécessaire
if ! id "${NODERED_USER}" &>/dev/null; then
    log_info "Création de l'utilisateur ${NODERED_USER}..."
    useradd -m -s /bin/bash ${NODERED_USER}
fi

# Installer Node-RED globalement
npm install -g --unsafe-perm node-red

log_info "Installation des nodes Node-RED nécessaires..."
# Utiliser npm -g pour une installation globale accessible
npm install -g \
    node-red-contrib-postgresql@^4.7.2 \
    node-red-dashboard@^2.36.2

log_info "Setup Node-RED comme service systemd..."
# Uninstall previous version if exists
curl -fsSL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/uninstall.sh | bash -s -- --skip-stop &>/dev/null || true
sleep 2
# Install current version
curl -fsSL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/install.sh | bash -s -- --node20

systemctl daemon-reload
systemctl enable nodered
systemctl start nodered

log_warn "Attente du démarrage de Node-RED (15s)..."
sleep 15

# ============================================================================
# 5. INSTALLATION MESHCORE-DECODER
# ============================================================================

log_info "=== Étape 5 : Installation meshcore-decoder ==="

log_info "Installation de meshcore-decoder depuis le fork Nivek-domo..."
npm install -g 'github:Nivek-domo/meshcore-decoder#feature/grouptext-2byte-hash-auto'

log_info "Test meshcore-decoder..."
meshcore-decoder --version

log_info "meshcore-decoder installé avec succès"

# ============================================================================
# 6. CONFIGURATION NODE-RED CRYPTO
# ============================================================================

log_info "=== Étape 6 : Configuration Node-RED crypto ==="
SETTINGS_FILE="/home/${NODERED_USER}/.node-red/settings.js"

# Attendre que Node-RED crée sa config
if [ ! -f "${SETTINGS_FILE}" ]; then
    log_warn "Attente de création du répertoire Node-RED (15s)..."
    sleep 15
fi

if [ -f "${SETTINGS_FILE}" ]; then
    # Vérifier si crypto est déjà configuré
    if ! grep -q "crypto:" "${SETTINGS_FILE}"; then
        log_info "Ajout de crypto au contexte global..."
        # Insert crypto configuration into functionGlobalContext
        sed -i '/functionGlobalContext.*{/a\        crypto: require('\''crypto'\''),' "${SETTINGS_FILE}"
    else
        log_warn "crypto déjà configuré"
    fi
    
    systemctl restart nodered
    sleep 5
else
    log_warn "Fichier settings.js non trouvé à ${SETTINGS_FILE}"
fi

# ============================================================================
# 7. VÉRIFICATION FINALE
# ============================================================================

log_info "=== Étape 7 : Vérification finale ==="
log_info "Vérification des services..."

for service in nodered postgresql; do
    if systemctl is-active --quiet $service; then
        log_info "✓ Service $service est actif"
    else
        log_error "✗ Service $service n'est pas actif"
    fi
done

log_info "Vérification de meshcore-decoder..."
if command -v meshcore-decoder &> /dev/null; then
    log_info "✓ meshcore-decoder disponible"
    meshcore-decoder --version
else
    log_error "✗ meshcore-decoder non disponible"
fi

# ============================================================================
# RÉSUMÉ FINAL
# ============================================================================

log_info ""
log_info "════════════════════════════════════════════════════════════════════"
log_info "✓ Installation terminée avec succès!"
log_info "════════════════════════════════════════════════════════════════════"
log_info ""
log_info "Prochaines étapes:"
log_info "1. Node-RED web interface (attendre quelques secondes): http://localhost:1880"
log_info "2. Base de données PostgreSQL: psql -h localhost -U ${DB_USER} -d ${DB_NAME}"
log_info "3. Vérifier les logs: journalctl -u nodered -f"
log_info ""
log_info "Pour configurer Node-RED:"
log_info "- Accédez à http://localhost:1880"
log_info "- Installez les nodes si nécessaire (Manage Palette)"
log_info "- Importez vos flows depuis votre Orange Pi (si migration)"
log_info ""
log_info "Commandes utiles:"
log_info "- Redémarrer Node-RED: systemctl restart nodered"
log_info "- Logs Node-RED: journalctl -u nodered -n 100"
log_info "- Test PostgreSQL: PGPASSWORD='${DB_PASSWORD}' psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c 'SELECT version();'"
log_info ""
log_info "Documentation complète disponible dans TUTORIEL_COMPLET.md"
log_info "════════════════════════════════════════════════════════════════════"

exit 0
