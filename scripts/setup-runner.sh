#!/usr/bin/env bash
# Sets up an Ubuntu 24.04 VM as a GitHub Actions self-hosted runner.
# Does NOT register the runner — registration token must be added manually.
set -euo pipefail

RUNNER_USER="runner"
RUNNER_HOME="/opt/actions-runner"
SSH_KEY_PATH="/home/${RUNNER_USER}/.ssh/id_ed25519"

# ── System packages ──────────────────────────────────────────────────────────
echo "==> Installing packages..."
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl git jq openssh-client sudo tar

# ── Docker ───────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo "==> Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# ── Runner OS user ───────────────────────────────────────────────────────────
if ! id "${RUNNER_USER}" &>/dev/null; then
    useradd -m -s /bin/bash "${RUNNER_USER}"
fi
usermod -aG docker "${RUNNER_USER}"

# ── SSH key for connecting to the target node ─────────────────────────────────
echo "==> Preparing SSH key..."
install -d -m 700 -o "${RUNNER_USER}" -g "${RUNNER_USER}" "/home/${RUNNER_USER}/.ssh"
if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    sudo -u "${RUNNER_USER}" \
        ssh-keygen -t ed25519 -N "" -f "${SSH_KEY_PATH}" -C "github-runner@$(hostname)"
    echo "==> New SSH key generated."
fi
echo
echo ">>> Runner public key — add this to the target node's authorized_keys:"
echo "    (paste into /home/operator/.ssh/authorized_keys on the target VM)"
echo
cat "${SSH_KEY_PATH}.pub"
echo

# ── Download GitHub Actions runner ───────────────────────────────────────────
echo "==> Downloading GitHub Actions runner..."
RUNNER_VERSION=$(curl -fsSL https://api.github.com/repos/actions/runner/releases/latest \
    | jq -r '.tag_name' | sed 's/^v//')
RUNNER_ARCH="x64"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"

mkdir -p "${RUNNER_HOME}"
curl -fsSL "${RUNNER_URL}" | tar -xz -C "${RUNNER_HOME}"
chown -R "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_HOME}"
echo "==> Runner v${RUNNER_VERSION} installed to ${RUNNER_HOME}"

# ── Instructions for manual steps ────────────────────────────────────────────
cat <<EOF

════════════════════════════════════════════════════════════════════════════════
 MANUAL STEPS REQUIRED
════════════════════════════════════════════════════════════════════════════════

1. Add the runner public key (printed above) to the target VM:
     echo '<public-key>' >> /home/operator/.ssh/authorized_keys

2. Obtain a registration token from GitHub:
     https://github.com/<owner>/<repo>/settings/actions/runners/new

3. Register the runner (replace placeholders):
     sudo -u ${RUNNER_USER} ${RUNNER_HOME}/config.sh \\
         --url https://github.com/<owner>/<repo> \\
         --token <TOKEN> \\
         --name $(hostname) \\
         --labels self-hosted,target-deployer \\
         --unattended

4. Install and start as a systemd service:
     cd ${RUNNER_HOME}
     sudo ./svc.sh install ${RUNNER_USER}
     sudo ./svc.sh start
     sudo ./svc.sh status

5. After completing your lab work, stop and deregister the runner to prevent
   unauthorized use of this self-hosted runner on a public repository:
     cd ${RUNNER_HOME}
     sudo ./svc.sh stop
     sudo ./svc.sh uninstall
     sudo -u ${RUNNER_USER} ./config.sh remove --token <TOKEN>

════════════════════════════════════════════════════════════════════════════════
EOF
