#!/bin/bash
################################################################################
# Installation complète : EMQX + Node-RED + PostgreSQL + meshcore-decoder + Meshtastic
# Pour ARM64 (Raspberry Pi, Orange Pi, etc.)
# Testé sur : Debian 12 Bookworm, Ubuntu 22.04, Debian 13 Trixie
#
# Usage: sudo ./install-meshcore-nodered.sh
#    ou: ./install-meshcore-nodered.sh (will prompt for sudo password)
################################################################################

# ============================================================================
# CONFIGURATION
# ============================================================================

if id orangepi &>/dev/null; then
    DEFAULT_NODERED_USER="orangepi"
elif id pi &>/dev/null; then
    DEFAULT_NODERED_USER="pi"
else
    DEFAULT_NODERED_USER="${SUDO_USER:-$(whoami)}"
fi

NODERED_USER="${NODERED_USER:-${DEFAULT_NODERED_USER}}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-vpnuser}"
DB_PASSWORD="${DB_PASSWORD:-motdepassefort}"
DB_PORT=5432
EMQX_VERSION="${EMQX_VERSION:-5.3.2}"
EMQX_ACL_FILE="${EMQX_ACL_FILE:-/etc/emqx/acl.conf}"
EMQX_DASHBOARD_USER="${EMQX_DASHBOARD_USER:-admin}"
EMQX_DASHBOARD_PASSWORD="${EMQX_DASHBOARD_PASSWORD:-gaulix2026}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NODERED_STRICT_CLONE="${NODERED_STRICT_CLONE:-1}"

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

find_emqx_package_url() {
    local arch="$1"
    local -a candidates

    if [ -n "${EMQX_PACKAGE_URL:-}" ]; then
        echo "${EMQX_PACKAGE_URL}"
        return 0
    fi

    case "$arch" in
        amd64)
            candidates=(
                "https://www.emqx.com/en/downloads/broker/v${EMQX_VERSION}/emqx-${EMQX_VERSION}-debian12-amd64.deb"
            )
            ;;
        arm64)
            candidates=(
                "https://www.emqx.com/en/downloads/broker/v${EMQX_VERSION}/emqx-${EMQX_VERSION}-debian12-arm64.deb"
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-arm64.zip"
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-arm64.tar.gz"
            )
            ;;
        armhf|armv7l)
            candidates=(
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-armv7.zip"
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-arm.zip"
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-armv7.tar.gz"
                "https://www.emqx.io/downloads/broker/${EMQX_VERSION}/emqx-${EMQX_VERSION}-arm.tar.gz"
            )
            ;;
        *)
            return 1
            ;;
    esac

    for url in "${candidates[@]}"; do
        if wget --spider -q "$url"; then
            echo "$url"
            return 0
        fi
    done

    return 1
}

install_emqx_archive() {
    local archive_path="$1"
    local extract_dir="/tmp/emqx_extract"

    rm -rf "$extract_dir" /usr/local/emqx
    mkdir -p "$extract_dir"

    if [[ "$archive_path" == *.zip ]]; then
        unzip -q "$archive_path" -d "$extract_dir"
    else
        tar -xzf "$archive_path" -C "$extract_dir"
    fi

    if [ -d "$extract_dir/emqx" ]; then
        mv "$extract_dir/emqx" /usr/local/emqx
    else
        local first_dir
        first_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)
        if [ -z "$first_dir" ]; then
            log_error "Archive EMQX invalide: impossible de trouver le dossier extrait"
            return 1
        fi
        mv "$first_dir" /usr/local/emqx
    fi

    ln -sf /usr/local/emqx/bin/emqx /usr/local/bin/emqx
    ln -sf /usr/local/emqx/bin/emqx_ctl /usr/local/bin/emqx_ctl
}

configure_emqx_acl() {
    mkdir -p "$(dirname "${EMQX_ACL_FILE}")"
    cat > "${EMQX_ACL_FILE}" << 'EMQX_ACL'
%% 1) Clients "!" peuvent s'abonner uniquement sur msh/# (apres rewrite)
{allow, {clientid, {re, "^!.+"}}, subscribe, ["msh/#"]}.

%% 2) Clients "!" interdits sur tout le reste
{deny,  {clientid, {re, "^!.+"}}, subscribe, ["#"]}.

%% 3) NodeRedOVH et tous les autres
{allow, all}.
EMQX_ACL
}

detect_emqx_conf_dir() {
    if [ -d "/etc/emqx" ]; then
        echo "/etc/emqx"
        return 0
    fi

    if [ -d "/usr/local/emqx/etc" ]; then
        echo "/usr/local/emqx/etc"
        return 0
    fi

    return 1
}

configure_emqx_authorization_file() {
    local conf_dir
    conf_dir="$(detect_emqx_conf_dir || true)"

    if [ -z "$conf_dir" ]; then
        log_warn "Impossible de trouver le dossier de configuration EMQX"
        return 1
    fi

    mkdir -p "${conf_dir}/conf.d"
    cat > "${conf_dir}/conf.d/99-authorization-file.conf" << EMQX_AUTHZ
authorization {
  no_match = deny
  deny_action = ignore
  cache {
    enable = true
  }
  sources = [
    {
      type = file
      enable = true
      path = "${EMQX_ACL_FILE}"
    }
  ]
}
EMQX_AUTHZ

    log_info "Authorization source 'file' configurée dans ${conf_dir}/conf.d/99-authorization-file.conf"
}

configure_emqx_topic_rewrite_file() {
        local conf_dir
        conf_dir="$(detect_emqx_conf_dir || true)"

        if [ -z "$conf_dir" ]; then
                log_warn "Impossible de trouver le dossier de configuration EMQX pour Topic Rewrite"
                return 1
        fi

        cat > "${conf_dir}/conf.d/99-topic-rewrite.conf" << 'EMQX_REWRITE'
    rewrite = [
      {
        action = publish
        source_topic = "msh/#"
        re = "^msh/(.*)$"
        dest_topic = "Traitement/msh/$1"
      },
      {
        action = publish
        source_topic = "Filtre/msh/#"
        re = "^Filtre/msh/(.*)$"
        dest_topic = "msh/$1"
      }
    ]
EMQX_REWRITE

        log_info "Topic Rewrite configuré dans ${conf_dir}/conf.d/99-topic-rewrite.conf"
}

emqx_api_try_post() {
    local endpoint="$1"
    local payload="$2"
    local code

    code=$(curl -sS -o /tmp/emqx_api_resp.json -w "%{http_code}" \
        -u "${EMQX_DASHBOARD_USER}:${EMQX_DASHBOARD_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X POST "http://127.0.0.1:18083${endpoint}" \
        -d "$payload" || true)

    case "$code" in
        200|201|204|409)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

emqx_api_try_put() {
    local endpoint="$1"
    local payload="$2"
    local code

    code=$(curl -sS -o /tmp/emqx_api_resp.json -w "%{http_code}" \
        -u "${EMQX_DASHBOARD_USER}:${EMQX_DASHBOARD_PASSWORD}" \
        -H "Content-Type: application/json" \
        -X PUT "http://127.0.0.1:18083${endpoint}" \
        -d "$payload" || true)

    case "$code" in
        200|201|204|409)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wait_for_emqx_dashboard() {
    local retries=30
    local i

    for ((i=1; i<=retries; i++)); do
        if curl -sS -o /dev/null -u "${EMQX_DASHBOARD_USER}:${EMQX_DASHBOARD_PASSWORD}" "http://127.0.0.1:18083/api/v5/status"; then
            return 0
        fi
        sleep 2
    done

    return 1
}

set_emqx_admin_password() {
    if command -v emqx_ctl &> /dev/null; then
        emqx_ctl admins passwd "${EMQX_DASHBOARD_USER}" "${EMQX_DASHBOARD_PASSWORD}" || true
    fi

    if command -v emqx &> /dev/null; then
        emqx ctl admins passwd "${EMQX_DASHBOARD_USER}" "${EMQX_DASHBOARD_PASSWORD}" || true
    fi
}

configure_emqx_topic_rewrite_api() {
    local ok=0
    local payload

    payload='{"rules":[{"action":"publish","source_topic":"msh/#","re":"^msh/(.*)$","dest_topic":"Traitement/msh/$1"},{"action":"publish","source_topic":"Filtre/msh/#","re":"^Filtre/msh/(.*)$","dest_topic":"msh/$1"}]}'

    if emqx_api_try_put "/api/v5/mqtt/topic_rewrite" "$payload"; then
        log_info "Règles Topic Rewrite appliquées via API (PUT /api/v5/mqtt/topic_rewrite)."
        return 0
    fi

    if emqx_api_try_put "/api/v5/topic_rewrite" "$payload"; then
        log_info "Règles Topic Rewrite appliquées via API (PUT /api/v5/topic_rewrite)."
        return 0
    fi

    # Compatibilite entre builds EMQX: on tente plusieurs endpoints/payloads.
    if emqx_api_try_post "/api/v5/mqtt/topic_rewrite" '{"action":"publish","source_topic":"msh/#","re":"^msh/(.*)$","dest_topic":"Traitement/msh/$1"}'; then
        ok=1
    fi
    if emqx_api_try_post "/api/v5/mqtt/topic_rewrite" '{"action":"publish","source_topic":"Filtre/msh/#","re":"^Filtre/msh/(.*)$","dest_topic":"msh/$1"}'; then
        ok=1
    fi

    if emqx_api_try_post "/api/v5/topic_rewrite" '{"action":"publish","source_topic":"msh/#","re":"^msh/(.*)$","dest_topic":"Traitement/msh/$1"}'; then
        ok=1
    fi
    if emqx_api_try_post "/api/v5/topic_rewrite" '{"action":"publish","source_topic":"Filtre/msh/#","re":"^Filtre/msh/(.*)$","dest_topic":"msh/$1"}'; then
        ok=1
    fi

    if [ "$ok" -eq 1 ]; then
        log_info "Tentative Topic Rewrite API envoyée (vérifiez les règles dans le Dashboard EMQX)."
        return 0
    fi

    log_warn "Injection Topic Rewrite via API non confirmée automatiquement (EMQX peut exiger api_key/api_secret)."
    return 1
}

setup_nodered_systemd_service() {
    local nodered_bin
    nodered_bin="$(command -v node-red || true)"

    if [ -z "$nodered_bin" ]; then
        log_error "Binaire node-red introuvable apres installation npm"
        return 1
    fi

    mkdir -p "/home/${NODERED_USER}/.node-red"
    chown -R "${NODERED_USER}:${NODERED_USER}" "/home/${NODERED_USER}/.node-red"

    cat > /etc/systemd/system/nodered.service << NODERED_UNIT
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=${NODERED_USER}
Group=${NODERED_USER}
WorkingDirectory=/home/${NODERED_USER}/.node-red
Environment="NODE_OPTIONS=--max_old_space_size=256"
ExecStart=${nodered_bin}
Restart=on-failure
RestartSec=5
KillSignal=SIGINT
SyslogIdentifier=Node-RED

[Install]
WantedBy=multi-user.target
NODERED_UNIT

    systemctl daemon-reload
    systemctl enable nodered
    systemctl restart nodered
}

restore_nodered_reference_bundle() {
    local template_dir=""
    local nodered_home="/home/${NODERED_USER}"
    local nodered_dir="${nodered_home}/.node-red"
    local candidate
    local ts

    for candidate in \
        "${NODERED_TEMPLATE_DIR:-}" \
        "${SCRIPT_DIR}/rpi3-trixie-installer/nodered/reference-opi66" \
        "${SCRIPT_DIR}/nodered/reference-opi66"
    do
        if [ -n "$candidate" ] && [ -d "$candidate" ]; then
            template_dir="$candidate"
            break
        fi
    done

    if [ -z "$template_dir" ]; then
        log_warn "Bundle Node-RED de référence introuvable."
        log_warn "Chemins testés: NODERED_TEMPLATE_DIR, ${SCRIPT_DIR}/rpi3-trixie-installer/nodered/reference-opi66, ${SCRIPT_DIR}/nodered/reference-opi66"
        return 0
    fi

    log_info "Restauration Node-RED depuis ${template_dir}"
    mkdir -p "${nodered_dir}"

    ts="$(date +%Y%m%d%H%M%S)"
    if [ "${NODERED_STRICT_CLONE}" = "1" ]; then
        if [ -n "$(find "${nodered_dir}" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
            mv "${nodered_dir}" "${nodered_home}/.node-red-backup-${ts}"
            log_info "Mode strict clone actif: sauvegarde complète dans ${nodered_home}/.node-red-backup-${ts}"
        fi
        mkdir -p "${nodered_dir}"
        cp -a "${template_dir}/." "${nodered_dir}/"
    else
        if [ -f "${nodered_dir}/flows.json" ] || [ -f "${nodered_dir}/settings.js" ]; then
            mkdir -p "${nodered_dir}/backup-before-clone-${ts}"
            cp -a "${nodered_dir}/flows.json" "${nodered_dir}/backup-before-clone-${ts}/" 2>/dev/null || true
            cp -a "${nodered_dir}/settings.js" "${nodered_dir}/backup-before-clone-${ts}/" 2>/dev/null || true
            cp -a "${nodered_dir}/package.json" "${nodered_dir}/backup-before-clone-${ts}/" 2>/dev/null || true
            cp -a "${nodered_dir}/package-lock.json" "${nodered_dir}/backup-before-clone-${ts}/" 2>/dev/null || true
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
            if [ -f "${template_dir}/${cfg}" ]; then
                cp -a "${template_dir}/${cfg}" "${nodered_dir}/${cfg}"
            fi
        done

        if [ -d "${template_dir}/lib" ]; then
            rm -rf "${nodered_dir}/lib"
            cp -a "${template_dir}/lib" "${nodered_dir}/lib"
        fi
    fi

    chown -R "${NODERED_USER}:${NODERED_USER}" "${nodered_dir}"

    if [ -f "${nodered_dir}/package-lock.json" ]; then
        sudo -u "${NODERED_USER}" bash -lc "cd '${nodered_dir}' && npm ci --omit=dev"
    elif [ -f "${nodered_dir}/package.json" ]; then
        sudo -u "${NODERED_USER}" bash -lc "cd '${nodered_dir}' && npm install --omit=dev"
    fi
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

log_info "=== Installation EMQX + Meshcore + Node-RED + PostgreSQL ==="
log_info "NODERED_USER=${NODERED_USER}, DB_NAME=${DB_NAME}"
log_info "NODERED_STRICT_CLONE=${NODERED_STRICT_CLONE} (1=clone strict, 0=fusion)"

# ============================================================================
# 1. MISE À JOUR SYSTÈME
# ============================================================================

log_info "=== Étape 1 : Mise à jour système ==="
apt-get update
apt-get upgrade -y
apt-get install -y curl wget tar unzip git build-essential python3

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

log_info "Configuration réseau PostgreSQL (listen_addresses + pg_hba)..."
PG_CONF=$(find /etc/postgresql -name postgresql.conf 2>/dev/null | head -1)
PG_HBA=$(find /etc/postgresql -name pg_hba.conf 2>/dev/null | head -1)
if [ -n "${PG_CONF}" ]; then
    sed -i "s/^#\?listen_addresses.*/listen_addresses = '*'/" "${PG_CONF}"
fi
if [ -n "${PG_HBA}" ] && ! grep -q '192.168.0.0/16' "${PG_HBA}"; then
    echo "host    all             all             192.168.0.0/16          scram-sha-256" >> "${PG_HBA}"
fi
systemctl restart postgresql
sleep 3

log_info "Configuration PostgreSQL..."

DB_PASSWORD_SQL=${DB_PASSWORD//\'/\'\'}

# Créer l'utilisateur et la base de données
sudo -u postgres bash << PGSQL_SETUP
# Check if user exists, if not create it
if ! psql -U postgres -tc "SELECT 1 FROM pg_user WHERE usename = '${DB_USER}'" | grep -q 1; then
    psql -U postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD_SQL}';"
fi

# Check if database exists, if not create it
if ! psql -U postgres -lqt | cut -d \| -f 1 | grep -w ${DB_NAME} ; then
    psql -U postgres -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
fi

# Grant privileges
psql -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};"
psql -U postgres -d "${DB_NAME}" -c "GRANT USAGE, CREATE ON SCHEMA public TO ${DB_USER};"
PGSQL_SETUP

# Grant DML on existing tables and sequences (must run after tables are created)
GRANT_TABLES_DONE=0

# Now create tables - connect as the new user
PGPASSWORD="${DB_PASSWORD}" psql -v ON_ERROR_STOP=1 -h localhost -U "${DB_USER}" -d "${DB_NAME}" << 'SQL_TABLES'
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

# GRANT DML sur les tables maintenant créées
sudo -u postgres psql -d "${DB_NAME}" << GRANT_SQL
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO ${DB_USER};
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO ${DB_USER};
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO ${DB_USER};
GRANT_SQL

log_info "PostgreSQL configuré avec succès"

# ============================================================================
# 4. INSTALLATION EMQX OSS
# ============================================================================

log_info "=== Étape 4 : Installation EMQX OSS ${EMQX_VERSION} ==="
EMQX_ARCH="$(dpkg --print-architecture)"
EMQX_URL="$(find_emqx_package_url "${EMQX_ARCH}" || true)"

if [ -z "${EMQX_URL}" ]; then
    log_error "Aucun package EMQX trouvé automatiquement pour l'architecture ${EMQX_ARCH}."
    log_error "Définissez EMQX_PACKAGE_URL puis relancez, ex:"
    log_error "EMQX_PACKAGE_URL='https://.../emqx-${EMQX_VERSION}-<arch>.deb' sudo ./install-meshcore-nodered-v3.sh"
    exit 1
fi

log_info "Téléchargement EMQX: ${EMQX_URL}"
EMQX_PACKAGE_FILE="/tmp/${EMQX_URL##*/}"
wget -q --show-progress -O "${EMQX_PACKAGE_FILE}" "${EMQX_URL}"

if [[ "${EMQX_PACKAGE_FILE}" == *.deb ]]; then
    apt-get install -y "${EMQX_PACKAGE_FILE}"
    systemctl daemon-reload
    systemctl enable emqx
    systemctl restart emqx
else
    install_emqx_archive "${EMQX_PACKAGE_FILE}"
    /usr/local/emqx/bin/emqx start
fi

if command -v emqx_ctl &> /dev/null; then
    emqx_ctl status || true
fi

if command -v emqx &> /dev/null; then
    emqx ctl plugins install emqx_management || true
    emqx ctl plugins start emqx_management || true
fi

set_emqx_admin_password

configure_emqx_acl
log_info "ACL EMQX créée dans ${EMQX_ACL_FILE}"
configure_emqx_authorization_file || true
configure_emqx_topic_rewrite_file || true

if systemctl list-unit-files | grep -q '^emqx\.service'; then
    systemctl restart emqx
fi

if command -v emqx_ctl &> /dev/null; then
    emqx_ctl status || true
fi

if ! wait_for_emqx_dashboard; then
    log_warn "Dashboard EMQX indisponible après attente, l'injection API peut échouer."
fi

configure_emqx_topic_rewrite_api || true

if command -v emqx_ctl &> /dev/null; then
    emqx_ctl plugins reload emqx_management || true
fi

log_warn "Dashboard EMQX: http://<IP>:18083 (${EMQX_DASHBOARD_USER}/${EMQX_DASHBOARD_PASSWORD})"
log_warn "Authorization file configurée: ${EMQX_ACL_FILE}"
log_warn "Topic Rewrite attendu: msh/# -> Traitement/msh/\$1 et Filtre/msh/# -> msh/\$1"

# ============================================================================
# 5. INSTALLATION NODE-RED
# ============================================================================

log_info "=== Étape 5 : Installation Node-RED ==="

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
    node-red-dashboard

log_info "Setup Node-RED comme service systemd..."
setup_nodered_systemd_service
restore_nodered_reference_bundle
systemctl restart nodered

log_warn "Attente du démarrage de Node-RED (15s)..."
sleep 15

# ============================================================================
# 6. INSTALLATION MESHCORE-DECODER
# ============================================================================

log_info "=== Étape 6 : Installation meshcore-decoder ==="
DECODER_DIR="/opt/meshcore-decoder"

if [ ! -d "${DECODER_DIR}/.git" ]; then
    log_info "Clonage du dépôt meshcore-decoder..."
    rm -rf /opt/meshcore-decoder 2>/dev/null || true
    cd /opt
    git clone https://github.com/michaelhart/meshcore-decoder.git
else
    log_info "Mise à jour du dépôt meshcore-decoder..."
    cd ${DECODER_DIR}
    git pull origin main || true
fi

cd ${DECODER_DIR}

log_info "Installation des dépendances..."
npm install

log_info "Installation de @noble/ed25519@2.0.0 (compatible Node 20)..."
npm install '@noble/ed25519@2.0.0'

log_info "Compilation du projet..."
npm run build

# Créer lien symlink global
rm -f /usr/local/bin/meshcore-decoder 2>/dev/null || true
ln -s ${DECODER_DIR}/dist/cli.js /usr/local/bin/meshcore-decoder
chmod +x ${DECODER_DIR}/dist/cli.js
chmod +x /usr/local/bin/meshcore-decoder

log_info "Test meshcore-decoder..."
meshcore-decoder --version

log_info "meshcore-decoder installé avec succès"

# ============================================================================
# 7. CONFIGURATION NODE-RED CRYPTO
# ============================================================================

log_info "=== Étape 7 : Configuration Node-RED crypto ==="
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
# 8. VÉRIFICATION FINALE
# ============================================================================

log_info "=== Étape 8 : Vérification finale ==="
log_info "Vérification des services..."

for service in emqx nodered postgresql; do
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
log_info "1. Dashboard EMQX: http://localhost:18083 (${EMQX_DASHBOARD_USER}/${EMQX_DASHBOARD_PASSWORD})"
log_info "2. Node-RED web interface (attendre quelques secondes): http://localhost:1880"
log_info "3. Base de données PostgreSQL: PGPASSWORD='${DB_PASSWORD}' psql -h localhost -U ${DB_USER} -d ${DB_NAME}"
log_info "4. Vérifier les logs: journalctl -u emqx -f && journalctl -u nodered -f"
log_info ""
log_info "Pour configurer Node-RED:"
log_info "- Accédez à http://localhost:1880"
log_info "- Installez les nodes si nécessaire (Manage Palette)"
log_info "- Importez vos flows depuis votre Orange Pi (si migration)"
log_info ""
log_info "Commandes utiles:"
log_info "- Statut EMQX: emqx_ctl status"
log_info "- Redémarrer EMQX: systemctl restart emqx"
log_info "- Redémarrer Node-RED: systemctl restart nodered"
log_info "- Logs Node-RED: journalctl -u nodered -n 100"
log_info "- Logs EMQX: journalctl -u emqx -n 100"
log_info "- Test PostgreSQL: PGPASSWORD='${DB_PASSWORD}' psql -h localhost -U ${DB_USER} -d ${DB_NAME} -c 'SELECT version();'"
log_info ""
log_info "Documentation complète disponible dans TUTORIEL_COMPLET.md"
log_info "════════════════════════════════════════════════════════════════════"

exit 0
