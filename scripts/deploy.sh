#!/usr/bin/env bash
# Deploys a new image version to the target node via SSH.
# Designed to run on the self-hosted GitHub Actions runner.
#
# Required environment variables (set via GitHub Actions secrets/vars):
#   TARGET_HOST  — IP or hostname of the target VM
#   TARGET_USER  — SSH user on the target (operator)
#   APP_IMAGE    — Full image reference, e.g. ghcr.io/owner/repo:v1.2.3
#
# Optional:
#   SSH_KEY_PATH — Path to the private key (default: ~/.ssh/id_ed25519)
set -euo pipefail

: "${TARGET_HOST:?TARGET_HOST is not set}"
: "${TARGET_USER:?TARGET_USER is not set}"
: "${APP_IMAGE:?APP_IMAGE is not set}"
SSH_KEY_PATH="${SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"

WEBAPP_DIR="/opt/mywebapp"
SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o BatchMode=yes)

echo "==> Deploying ${APP_IMAGE} → ${TARGET_USER}@${TARGET_HOST}:${WEBAPP_DIR}"

# ── Update APP_IMAGE in .env on the target ────────────────────────────────────
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" \
    APP_IMAGE="${APP_IMAGE}" WEBAPP_DIR="${WEBAPP_DIR}" bash <<'REMOTE'
set -euo pipefail
ENV_FILE="${WEBAPP_DIR}/.env"

if grep -q '^APP_IMAGE=' "${ENV_FILE}" 2>/dev/null; then
    sed -i "s|^APP_IMAGE=.*|APP_IMAGE=${APP_IMAGE}|" "${ENV_FILE}"
else
    echo "APP_IMAGE=${APP_IMAGE}" >> "${ENV_FILE}"
fi
echo "==> .env updated: APP_IMAGE=${APP_IMAGE}"
REMOTE

# ── Pull image & restart the service ─────────────────────────────────────────
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" \
    APP_IMAGE="${APP_IMAGE}" bash <<'REMOTE'
set -euo pipefail

echo "==> Pulling image ${APP_IMAGE}..."
docker pull "${APP_IMAGE}"

echo "==> Restarting mywebapp-container.service..."
sudo systemctl restart mywebapp-container.service

echo "==> Waiting for service to become active..."
for i in $(seq 1 30); do
    STATUS=$(systemctl is-active mywebapp-container.service 2>/dev/null || echo "inactive")
    if [[ "${STATUS}" == "active" ]]; then
        echo "==> Service is active after ${i}s."
        break
    fi
    printf "    [%2d/30] status: %s\n" "${i}" "${STATUS}"
    sleep 2
done

if [[ "${STATUS}" != "active" ]]; then
    echo "ERROR: mywebapp-container.service did not become active." >&2
    sudo systemctl status mywebapp-container.service --no-pager --lines=30 || true
    exit 1
fi
REMOTE

echo "==> Deploy complete."
