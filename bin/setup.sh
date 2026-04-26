#!/usr/bin/env bash
# Copyright 2026 Dave LeBlanc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Install all development dependencies for simmerplan-infra on Arch Linux.
# Run once after cloning the repo: bash bin/setup.sh

set -euo pipefail

# ── Guards ────────────────────────────────────────────────────────────────────

if [[ ! -f /etc/arch-release ]]; then
  echo "error: this script targets Arch Linux (/etc/arch-release not found)" >&2
  exit 1
fi

if [[ $EUID -eq 0 ]]; then
  echo "error: do not run this script as root — it will sudo when needed" >&2
  exit 1
fi

# ── Keyring ───────────────────────────────────────────────────────────────────
# Refresh keyring before anything else so newer maintainer keys are trusted.
echo "==> Updating archlinux-keyring..."
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman-key --populate archlinux

# ── Pre-flight: texinfo ───────────────────────────────────────────────────────
# pacman hooks for info pages run install-info (from texinfo) during any
# upgrade. If texinfo is absent or /usr/share/info/dir doesn't exist the hook
# fails with "error: command failed to execute correctly". Ensure both are
# present before the main upgrade triggers those hooks.

echo "==> Ensuring texinfo hook dependencies are in place..."
sudo pacman -S --needed --noconfirm texinfo
sudo mkdir -p /usr/share/info
[[ -f /usr/share/info/dir ]] || sudo install-info --dir-file=/usr/share/info/dir /dev/null 2>/dev/null || true

# ── Official repo packages ────────────────────────────────────────────────────

PACMAN_PACKAGES=(
  curl
  git
  jq
  unzip
  terraform   # >= 1.0, from extra repo
  ansible     # >= 2.x, from extra repo
  python-boto3
  python-botocore
)

# -Syu (full upgrade) is required — Arch does not support partial upgrades.
# Without it, syncing the DB then installing can conflict with package splits
# (e.g. gcc-libs → libgcc + libstdc++) that need the old package removed first.
echo "==> Upgrading system and installing packages..."
sudo pacman -Syu --needed --noconfirm "${PACMAN_PACKAGES[@]}"

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────

if command -v aws &>/dev/null; then
  echo "==> AWS CLI already installed: $(aws --version 2>&1)"
else
  echo "==> Installing AWS CLI v2..."
  AWSTMP=$(mktemp -d)
  trap 'rm -rf "$AWSTMP"' EXIT
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
    -o "$AWSTMP/awscliv2.zip"
  unzip -q "$AWSTMP/awscliv2.zip" -d "$AWSTMP"
  sudo "$AWSTMP/aws/install"
  echo "==> AWS CLI installed: $(aws --version 2>&1)"
fi

# ── tfsec ─────────────────────────────────────────────────────────────────────

if command -v tfsec &>/dev/null; then
  echo "==> tfsec already installed: $(tfsec --version 2>&1)"
else
  echo "==> Installing tfsec..."
  TFSEC_VERSION=$(
    curl -fsSL https://api.github.com/repos/aquasecurity/tfsec/releases/latest \
      | jq -r '.tag_name'
  )
  sudo curl -fsSL \
    "https://github.com/aquasecurity/tfsec/releases/download/${TFSEC_VERSION}/tfsec-linux-amd64" \
    -o /usr/local/bin/tfsec
  sudo chmod +x /usr/local/bin/tfsec
  echo "==> tfsec installed: $(tfsec --version 2>&1)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "==> All dependencies installed."
echo ""
echo "Next steps:"
echo "  1. Configure the management account AWS profile:"
echo "       aws configure --profile simmerplan-management"
echo "     (credentials for the AWS Organizations management account)"
echo ""
echo "  2. Copy and populate tfvars for each account workspace:"
echo "       cp terraform/bootstrap/terraform.tfvars.example terraform/bootstrap/terraform.tfvars"
echo "       cp terraform/accounts/management/terraform.tfvars.example terraform/accounts/management/terraform.tfvars"
echo "       cp terraform/accounts/sandbox/terraform.tfvars.example    terraform/accounts/sandbox/terraform.tfvars"
echo "       cp terraform/accounts/prod/terraform.tfvars.example       terraform/accounts/prod/terraform.tfvars"
echo "     Fill in the real AWS account IDs for management, sandbox, and prod."
echo ""
echo "  3. Run bootstrap (once, against the management account):"
echo "       cd terraform/bootstrap && terraform init && terraform apply"
echo ""
echo "  4. Initialise a workspace (sandbox example):"
echo "       cd terraform/accounts/sandbox && terraform init \\"
echo "         -backend-config=\"bucket=<state-bucket>\" \\"
echo "         -backend-config=\"dynamodb_table=<lock-table>\" \\"
echo "         -backend-config=\"region=ca-central-1\""
