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

DEFAULT_NODERED_USER="pi"
if id orangepi &>/dev/null; then
    DEFAULT_NODERED_USER="orangepi"
elif id pi &>/dev/null; then
    DEFAULT_NODERED_USER="pi"
elif [ -n "${SUDO_USER:-}" ] && id "${SUDO_USER}" &>/dev/null; then
    DEFAULT_NODERED_USER="${SUDO_USER}"
fi

NODERED_USER="${NODERED_USER:-$DEFAULT_NODERED_USER}"
DB_NAME="vpndb"
DB_USER="vpnuser"
DB_PASSWORD="${DB_PASSWORD:-motdepassefort}"
DB_PORT=5432
INSTALL_EMQX="${INSTALL_EMQX:-yes}"
EMQX_ARM64_VERSION="${EMQX_ARM64_VERSION:-5.3.2}"
EMQX_AMD64_VERSION="${EMQX_AMD64_VERSION:-5.3.2}"
CONFIGURE_EMQX_POSTINSTALL="${CONFIGURE_EMQX_POSTINSTALL:-yes}"
EMQX_DASHBOARD_USER="${EMQX_DASHBOARD_USER:-admin}"
EMQX_DASHBOARD_PASSWORD="${EMQX_DASHBOARD_PASSWORD:-public123}"
EMQX_SECONDARY_USER="${EMQX_SECONDARY_USER:-noderedovh}"
EMQX_SECONDARY_PASSWORD="${EMQX_SECONDARY_PASSWORD:-noderedovh123}"

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

install_emqx() {
    local architecture
    local debian_version
    local emqx_tmp
    local emqx_extract_dir
    local emqx_existing_dir

    if [ "${INSTALL_EMQX}" != "yes" ]; then
        log_warn "Installation EMQX désactivée (INSTALL_EMQX=${INSTALL_EMQX})"
        return 0
    fi

    architecture="$(dpkg --print-architecture)"
    debian_version="$(. /etc/os-release && echo "${VERSION_ID:-}")"
    emqx_existing_dir="no"

    if [ -x /usr/local/emqx/bin/emqx_ctl ] || [ -d /usr/local/emqx ]; then
        emqx_existing_dir="yes"
    fi

    log_info "=== Étape 7 : Installation EMQX ==="
    apt-get install -y curl wget tar unzip

    if systemctl list-unit-files | grep -q '^emqx.service' || [ "${emqx_existing_dir}" = "yes" ]; then
        log_warn "EMQX deja installe, aucune modification ne sera appliquee"
        return 0
    fi

    case "${architecture}" in
        arm64)
            log_info "Installation EMQX OSS ARM64 ${EMQX_ARM64_VERSION}"
            emqx_tmp="/tmp/emqx-${EMQX_ARM64_VERSION}-debian12-arm64.tar.gz"
            emqx_extract_dir="/tmp/emqx-extract-${EMQX_ARM64_VERSION}"
            wget -O "${emqx_tmp}" "https://www.emqx.com/en/downloads/broker/v${EMQX_ARM64_VERSION}/emqx-${EMQX_ARM64_VERSION}-debian12-arm64.tar.gz"
            rm -rf /usr/local/emqx "${emqx_extract_dir}"
            mkdir -p "${emqx_extract_dir}" /usr/local/emqx
            tar -xzf "${emqx_tmp}" -C "${emqx_extract_dir}"
            cp -a "${emqx_extract_dir}"/. /usr/local/emqx/

            cat > /etc/systemd/system/emqx.service << 'EOF'
[Unit]
Description=EMQX MQTT Broker
After=network.target

[Service]
Type=forking
User=root
WorkingDirectory=/usr/local/emqx
ExecStart=/usr/local/emqx/bin/emqx start
ExecStop=/usr/local/emqx/bin/emqx stop
ExecReload=/usr/local/emqx/bin/emqx restart
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

            systemctl daemon-reload
            systemctl enable emqx
            systemctl restart emqx
            ;;
        amd64)
            if [ "${debian_version}" = "12" ]; then
                log_info "Installation EMQX OSS Debian 12 amd64 ${EMQX_AMD64_VERSION}"
                emqx_tmp="/tmp/emqx-${EMQX_AMD64_VERSION}-debian12-amd64.deb"
                wget -O "${emqx_tmp}" "https://www.emqx.com/en/downloads/broker/v${EMQX_AMD64_VERSION}/emqx-${EMQX_AMD64_VERSION}-debian12-amd64.deb"
                apt-get install -y "${emqx_tmp}"
                systemctl enable emqx
                systemctl restart emqx
            else
                log_warn "EMQX amd64 automatisé prévu pour Debian 12. Système détecté: Debian ${debian_version:-inconnu}"
            fi
            ;;
        *)
            log_warn "Architecture non prise en charge pour EMQX automatique: ${architecture}"
            ;;
    esac
}

configure_emqx_postinstall() {
    if [ "${CONFIGURE_EMQX_POSTINSTALL}" != "yes" ]; then
        log_warn "Configuration EMQX post-install desactivee (CONFIGURE_EMQX_POSTINSTALL=${CONFIGURE_EMQX_POSTINSTALL})"
        return 0
    fi

    if ! command -v python3 >/dev/null 2>&1; then
        log_warn "python3 indisponible, configuration EMQX ignoree"
        return 0
    fi

    if ! systemctl is-active --quiet emqx; then
        log_warn "EMQX inactif, configuration post-install ignoree"
        return 0
    fi

    log_info "=== Etape 8 : Configuration EMQX (ACL + Topic Rewrite) ==="

    export EMQX_DASHBOARD_USER
    export EMQX_DASHBOARD_PASSWORD
    export EMQX_SECONDARY_USER
    export EMQX_SECONDARY_PASSWORD

    python3 << 'PY'
import json
import os
import urllib.request

base = "http://127.0.0.1:18083"
dashboard_user = os.environ.get("EMQX_DASHBOARD_USER", "admin")
dashboard_password = os.environ.get("EMQX_DASHBOARD_PASSWORD", "public123")
secondary_user = os.environ.get("EMQX_SECONDARY_USER", "noderedovh")
secondary_password = os.environ.get("EMQX_SECONDARY_PASSWORD", "noderedovh123")

if len(dashboard_password) < 8:
    raise SystemExit("EMQX_DASHBOARD_PASSWORD doit contenir au moins 8 caracteres")
if len(secondary_password) < 8:
    raise SystemExit("EMQX_SECONDARY_PASSWORD doit contenir au moins 8 caracteres")

def req(path, method="GET", payload=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    with urllib.request.urlopen(request, timeout=15) as response:
        body = response.read().decode(errors="ignore")
        return response.status, body

# Login dashboard
status, body = req("/api/v5/login", method="POST", payload={"username": dashboard_user, "password": dashboard_password})
if status != 200:
    raise SystemExit(f"Login EMQX impossible avec {dashboard_user}: HTTP {status} {body}")

token = json.loads(body)["token"]

# ACL source file
acl_rules = (
    "%% 1) Clients ! : abonnement autorise uniquement sur msh/#\n"
    "{allow, {clientid, {re, \"^!.+\"}}, subscribe, [\"msh/#\"]}.\n\n"
    "%% 2) Clients ! : interdits d'abonnement sur le reste\n"
    "{deny,  {clientid, {re, \"^!.+\"}}, subscribe, [\"#\"]}.\n\n"
    "%% 3) NodeRedOVH et tous les autres\n"
    "{allow, all}.\n"
)

status, _ = req(
    "/api/v5/authorization/sources/file",
    method="PUT",
    payload={"type": "file", "enable": True, "rules": acl_rules},
    token=token,
)
if status not in (200, 204):
    raise SystemExit(f"Mise a jour ACL echouee: HTTP {status}")

# Topic rewrite rules
rewrite_payload = [
    {
        "action": "publish",
        "source_topic": "msh/#",
        "re": "^msh/(.*)$",
        "dest_topic": "Traitement/msh/$1",
    },
    {
        "action": "publish",
        "source_topic": "Filtre/msh/#",
        "re": "^Filtre/msh/(.*)$",
        "dest_topic": "msh/$1",
    },
]

status, _ = req(
    "/api/v5/mqtt/topic_rewrite",
    method="PUT",
    payload=rewrite_payload,
    token=token,
)
if status not in (200, 204):
    raise SystemExit(f"Mise a jour Topic Rewrite echouee: HTTP {status}")

# Ensure secondary dashboard user exists
status, _ = req(
    "/api/v5/users",
    method="POST",
    payload={
        "username": secondary_user,
        "password": secondary_password,
        "description": "Node-RED admin",
        "role": "administrator",
    },
    token=token,
)
if status not in (200, 201, 204, 409):
    raise SystemExit(f"Creation utilisateur secondaire echouee: HTTP {status}")

print("EMQX_CONFIG_OK")
PY
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

log_info "=== Installation Meshcore + Node-RED + PostgreSQL + EMQX ==="
log_info "NODERED_USER=${NODERED_USER}, DB_NAME=${DB_NAME}"

# ============================================================================
# 1. MISE À JOUR SYSTÈME
# ============================================================================

log_info "=== Étape 1 : Mise à jour système ==="
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git build-essential python3 unzip

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
    node-red-contrib-postgresql \
    node-red-dashboard \
    node-red-contrib-moment

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
# 7. INSTALLATION EMQX
# ============================================================================

install_emqx

# ============================================================================
# 8. CONFIGURATION EMQX POST-INSTALL
# ============================================================================

configure_emqx_postinstall

# ============================================================================
# 9. VÉRIFICATION FINALE
# ============================================================================

log_info "=== Etape 9 : Verification finale ==="
log_info "Vérification des services..."

for service in nodered postgresql; do
    if systemctl is-active --quiet $service; then
        log_info "✓ Service $service est actif"
    else
        log_error "✗ Service $service n'est pas actif"
    fi
done

if systemctl list-unit-files | grep -q '^emqx.service'; then
    if systemctl is-active --quiet emqx; then
        log_info "✓ Service emqx est actif"
    else
        log_error "✗ Service emqx n'est pas actif"
    fi
fi

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
log_info "2. Base de données PostgreSQL: PGPASSWORD='${DB_PASSWORD}' psql -h localhost -U ${DB_USER} -d ${DB_NAME}"
log_info "3. Dashboard EMQX: http://localhost:18083 (${EMQX_DASHBOARD_USER}/${EMQX_DASHBOARD_PASSWORD})"
log_info "4. Vérifier les logs: journalctl -u nodered -f"
log_info ""
log_info "Pour configurer Node-RED:"
log_info "- Accédez à http://localhost:1880"
log_info "- Installez les nodes si nécessaire (Manage Palette)"
log_info "- Importez vos flows depuis votre Orange Pi (si migration)"
log_info ""
log_info "Commandes utiles:"
log_info "- Redémarrer Node-RED: systemctl restart nodered"
log_info "- Redémarrer EMQX: systemctl restart emqx"
log_info "- Statut EMQX: /usr/local/emqx/bin/emqx_ctl status ou systemctl status emqx"
log_info "- Logs Node-RED: journalctl -u nodered -n 100"
log_info "- Test PostgreSQL: PGPASSWORD='${DB_PASSWORD}' psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c 'SELECT version();'"
log_info ""
log_info "Documentation complète disponible dans TUTORIEL_COMPLET.md"
log_info "════════════════════════════════════════════════════════════════════"

exit 0
