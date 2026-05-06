#!/usr/bin/env bash
# Prepares an Ubuntu 24.04 target node for Docker-based deployment.
# Usage: sudo ./setup-target.sh [runner-public-key]
#   runner-public-key — optional; SSH public key of the runner VM.
#                       If omitted, add the key to /home/operator/.ssh/authorized_keys manually.
set -euo pipefail

DEPLOY_USER="operator"
WEBAPP_DIR="/opt/mywebapp"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER_PUBKEY="${1:-}"

# ── System packages ──────────────────────────────────────────────────────────
echo "==> Installing packages..."
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git nginx openssl sudo

# ── Docker ───────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "==> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi
systemctl enable docker
systemctl start docker

# ── Users ────────────────────────────────────────────────────────────────────
echo "==> Configuring users..."

if ! id "student" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo student
    echo "student ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/student
fi

if ! id "teacher" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo teacher
    usermod --password "$(openssl passwd -6 12345678)" teacher
    chage -d 0 teacher
fi

if ! id "app" &>/dev/null; then
    useradd -r -s /bin/false app
fi

if ! id "${DEPLOY_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${DEPLOY_USER}"
    usermod --password "$(openssl passwd -6 12345678)" "${DEPLOY_USER}"
fi

# operator gets access to Docker and restricted sudo for service management
usermod -aG docker "${DEPLOY_USER}"
cat > "/etc/sudoers.d/${DEPLOY_USER}" <<EOF
${DEPLOY_USER} ALL=(ALL) NOPASSWD: \\
    /bin/systemctl start mywebapp-container.service, \\
    /bin/systemctl stop mywebapp-container.service, \\
    /bin/systemctl restart mywebapp-container.service, \\
    /bin/systemctl status mywebapp-container.service, \\
    /bin/systemctl reload nginx, \\
    /usr/sbin/nginx -t
EOF

echo "12" > /home/student/gradebook
chown student:student /home/student/gradebook

# ── SSH access for runner ─────────────────────────────────────────────────────
echo "==> Configuring SSH access for runner..."
DEPLOY_HOME="$(getent passwd "${DEPLOY_USER}" | cut -d: -f6)"
install -d -m 700 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${DEPLOY_HOME}/.ssh"
touch "${DEPLOY_HOME}/.ssh/authorized_keys"
chmod 600 "${DEPLOY_HOME}/.ssh/authorized_keys"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${DEPLOY_HOME}/.ssh/authorized_keys"

if [[ -n "${RUNNER_PUBKEY}" ]]; then
    echo "${RUNNER_PUBKEY}" >> "${DEPLOY_HOME}/.ssh/authorized_keys"
    echo "==> Runner public key added to ${DEPLOY_HOME}/.ssh/authorized_keys"
else
    echo "INFO: Add the runner's public key manually:"
    echo "      echo '<public-key>' >> ${DEPLOY_HOME}/.ssh/authorized_keys"
fi

# ── Webapp directory ──────────────────────────────────────────────────────────
echo "==> Creating ${WEBAPP_DIR}..."
install -d -m 755 -o "${DEPLOY_USER}" -g "${DEPLOY_USER}" "${WEBAPP_DIR}"

# Production docker-compose (no build:, image from .env)
cp "${REPO_ROOT}/docker-compose.prod.yml" "${WEBAPP_DIR}/docker-compose.yml"
chown "${DEPLOY_USER}:${DEPLOY_USER}" "${WEBAPP_DIR}/docker-compose.yml"

# .env template — passwords MUST be changed before the first deploy
if [[ ! -f "${WEBAPP_DIR}/.env" ]]; then
    cat > "${WEBAPP_DIR}/.env" <<'EOF'
APP_IMAGE=ghcr.io/OWNER/REPO:latest
DB_USER=user
DB_NAME=mywebapp_db
DB_PASSWORD=CHANGE_ME
DB_ROOT_PASSWORD=CHANGE_ME_ROOT
EOF
    chown "${DEPLOY_USER}:${DEPLOY_USER}" "${WEBAPP_DIR}/.env"
    chmod 640 "${WEBAPP_DIR}/.env"
    echo "WARN: Edit ${WEBAPP_DIR}/.env and set real passwords before first deploy."
fi

# ── nginx ─────────────────────────────────────────────────────────────────────
echo "==> Configuring nginx..."
cp "${REPO_ROOT}/configs/nginx.conf" /etc/nginx/sites-available/mywebapp
ln -sf /etc/nginx/sites-available/mywebapp /etc/nginx/sites-enabled/mywebapp
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl enable --now nginx
systemctl reload nginx

# ── systemd unit ──────────────────────────────────────────────────────────────
echo "==> Installing mywebapp-container.service..."
cp "${REPO_ROOT}/configs/mywebapp-container.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable mywebapp-container.service

# ── Disable ubuntu user ───────────────────────────────────────────────────────
# Only lock after confirming operator SSH access works.
# Run manually: sudo usermod -L -e 1 ubuntu
echo "INFO: ubuntu user NOT locked automatically."
echo "      Verify operator SSH access works, then run:"
echo "      sudo usermod -L -e 1 ubuntu"

cat <<EOF

==> Target node setup complete.
    Next steps:
      1. Edit ${WEBAPP_DIR}/.env — set real DB_PASSWORD and DB_ROOT_PASSWORD.
      2. Add the runner's SSH public key to ${DEPLOY_HOME}/.ssh/authorized_keys
         (if not passed as an argument to this script).
      3. Run the deployment pipeline to start the application.
EOF
