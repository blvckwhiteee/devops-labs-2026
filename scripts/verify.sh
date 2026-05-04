#!/usr/bin/env bash
# Post-deployment verification. Runs on the self-hosted runner.
# Checks service availability, nginx configuration, and container health.
#
# Required environment variables:
#   TARGET_HOST  — IP or hostname of the target VM
#   TARGET_USER  — SSH user on the target (operator)
#
# Optional:
#   SSH_KEY_PATH — Path to the private key (default: ~/.ssh/id_ed25519)
set -euo pipefail

: "${TARGET_HOST:?TARGET_HOST is not set}"
: "${TARGET_USER:?TARGET_USER is not set}"
SSH_KEY_PATH="${SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"

WEBAPP_DIR="/opt/mywebapp"
BASE_URL="http://${TARGET_HOST}"
SSH_OPTS=(-i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no -o BatchMode=yes)
ERRORS=0

# ── Helpers ───────────────────────────────────────────────────────────────────
pass() { printf "[PASS] %s\n" "$*"; }
fail() { printf "[FAIL] %s\n" "$*" >&2; ERRORS=$((ERRORS + 1)); }

check_http() {
    local desc="$1" url="$2" expected_code="$3"
    local actual_code
    actual_code=$(curl -fsS -o /dev/null -w "%{http_code}" \
        --max-time 10 --retry 3 --retry-delay 2 "${url}" 2>/dev/null || echo "000")
    if [[ "${actual_code}" == "${expected_code}" ]]; then
        pass "${desc}: HTTP ${actual_code}"
    else
        fail "${desc}: expected HTTP ${expected_code}, got ${actual_code} (${url})"
    fi
}

# ── HTTP checks (from runner → nginx on target) ────────────────────────────────
echo "==> HTTP checks via nginx (${BASE_URL})..."

check_http "GET /"             "${BASE_URL}/"             "200"
check_http "GET /notes/"       "${BASE_URL}/notes/"       "200"
# nginx must block /health endpoints (see nginx.conf: location /health { return 404; })
check_http "/health/alive blocked by nginx" "${BASE_URL}/health/alive" "404"
check_http "/health/ready blocked by nginx" "${BASE_URL}/health/ready" "404"

# ── Remote checks via SSH (on target) ─────────────────────────────────────────
echo "==> Remote checks on ${TARGET_HOST}..."

# Remote script exits with the number of failed checks as its exit code.
# stdout/stderr flow through normally so all [PASS]/[FAIL] lines appear in the runner log.
REMOTE_ERRORS=0
ssh "${SSH_OPTS[@]}" "${TARGET_USER}@${TARGET_HOST}" \
    WEBAPP_DIR="${WEBAPP_DIR}" bash <<'REMOTE' || REMOTE_ERRORS=$?
set -euo pipefail
ERRORS=0
pass() { printf "[PASS] %s\n" "$*"; }
fail() { printf "[FAIL] %s\n" "$*" >&2; ERRORS=$((ERRORS + 1)); }

# systemd service is active
STATUS=$(systemctl is-active mywebapp-container.service 2>/dev/null || echo "inactive")
if [[ "${STATUS}" == "active" ]]; then
    pass "mywebapp-container.service is active"
else
    fail "mywebapp-container.service status: ${STATUS}"
    sudo systemctl status mywebapp-container.service --no-pager --lines=20 || true
fi

# web container is running
if docker compose -f "${WEBAPP_DIR}/docker-compose.yml" ps web 2>/dev/null \
        | grep -qi "running"; then
    pass "web container is running"
else
    fail "web container is not running"
    docker compose -f "${WEBAPP_DIR}/docker-compose.yml" ps || true
fi

# db container is running
if docker compose -f "${WEBAPP_DIR}/docker-compose.yml" ps db 2>/dev/null \
        | grep -qi "running"; then
    pass "db container is running"
else
    fail "db container is not running"
fi

# app health endpoint responds directly (bypasses nginx, proves the app itself is healthy)
if curl -fsS --max-time 5 http://127.0.0.1:3000/health/alive 2>/dev/null | grep -q "OK"; then
    pass "app /health/alive responds on :3000 (direct)"
else
    fail "app not responding on 127.0.0.1:3000"
fi

# nginx configuration is valid
if sudo nginx -t 2>/dev/null; then
    pass "nginx -t passed"
else
    fail "nginx config test failed"
fi

exit "${ERRORS}"
REMOTE

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((ERRORS + REMOTE_ERRORS))
echo
if [[ "${TOTAL}" -eq 0 ]]; then
    echo "==> All checks passed."
else
    printf "==> FAILED: %d check(s) did not pass.\n" "${TOTAL}" >&2
    exit 1
fi
