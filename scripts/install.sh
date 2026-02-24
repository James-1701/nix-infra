#!/usr/bin/env bash
#
# install.sh - Automated NixOS Deployment Script
#
# Usage: ./scripts/install.sh <hostname> <target_ip>
# Example: ./scripts/install.sh "my-server" "192.168.1.50"

# If anything fails, exit immediately
set -euo pipefail

# Gets the need directories
FLAKE_URI="."
SOPS_CONFIG=".sops.yaml"
TARGET_KEY_DIR="nix/persist/etc/ssh"

# Helper functions for logging and error handling
log() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
error() {
  echo -e "\033[1;31m[ERROR]\033[0m $*"
  exit 1
}

# Check for required arguments
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <hostname> <target_ip>"
  exit 1
fi

# Sets the hostname and target IP from the command line arguments
HOST="$1"
TARGET_IP="$2"

# Check for required tools
command -v nix >/dev/null || error "Nix is not installed."
command -v sops >/dev/null || error "'sops' not found. Run 'nix develop' first."
command -v ssh-to-age >/dev/null || error "'ssh-to-age' not found. Run 'nix develop' first."

# Creates temporary directories to house the SSH keys
log "Generating SSH host keys for $HOST..."
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
KEY_DIR="$TEMP_DIR/$TARGET_KEY_DIR"
mkdir -p "$KEY_DIR"

# Creates the SSH keys
ssh-keygen -t ed25519 \
  -f "$KEY_DIR/ssh_host_ed25519_key" \
  -N "" \
  -C "root@$HOST" \
  -q

# Turns the SSH public key into an Age public key
PUBLIC_KEY_PATH="$KEY_DIR/ssh_host_ed25519_key.pub"
AGE_KEY=$(ssh-to-age -i "$PUBLIC_KEY_PATH")
log "Derived Age public key: $AGE_KEY"

log "Updating $SOPS_CONFIG..."

# Check for duplicate hostname anchor
if grep -q "&host-$HOST " "$SOPS_CONFIG" 2>/dev/null; then
  error "Hostname '$HOST' already exists in $SOPS_CONFIG. Please choose a different hostname or remove the existing entry."
fi

# Check for duplicate age key
if grep -q "$AGE_KEY" "$SOPS_CONFIG" 2>/dev/null; then
  error "Age key '$AGE_KEY' already exists in $SOPS_CONFIG. This host may already be configured."
fi

log "Adding key for $HOST to $SOPS_CONFIG..."

# Makes a backup of the original SOPS config before modifying it
cp "$SOPS_CONFIG" "${SOPS_CONFIG}.bak"

# Inserts the new host's age key as an anchor into the creation_rules section.
awk -v host="$HOST" -v key="$AGE_KEY" '
  /^creation_rules:/ && !inserted {
    print "  # Location: /etc/ssh/ssh_host_ed25519_key.pub on '\''" host "'\''"
    print "  - &host-" host " " key
    print ""
    inserted=1
  }
  {print}
' "${SOPS_CONFIG}.bak" >"$SOPS_CONFIG"

# Appends the new host age key to the list of allowed key references.
awk -v host="$HOST" '
  /^          - \*host-/ {
    print
    last_line = $0
    next
  }
  /^[^ ]/ && last_line ~ /\*host-/ && !inserted {
    print "          - *host-" host
    inserted=1
  }
  {print}
  END {
    if (!inserted && last_line ~ /\*host-/) {
      print "          - *host-" host
    }
  }
' "$SOPS_CONFIG" >"${SOPS_CONFIG}.tmp"

# Moves the new SOPS config into place and removes the backup
mv "${SOPS_CONFIG}.tmp" "$SOPS_CONFIG"
rm "${SOPS_CONFIG}.bak"

# Re-encrypts all secrets with the new keys
log "Re-encrypting secrets with new keys..."
shopt -s nullglob
files=(secrets/*)
if [ ${#files[@]} -eq 0 ]; then
  log "No secrets found in secrets/ directory. Skipping re-encryption."
else
  sops updatekeys "${files[@]}" -y
fi

# Installs NixOS to the target machine using nixos-anywhere
log "Deploying NixOS to $HOST ($TARGET_IP)..."
nix run github:nix-community/nixos-anywhere -- \
  --flake "${FLAKE_URI}#${HOST}" \
  --extra-files "$TEMP_DIR" \
  "root@${TARGET_IP}"

log "Deployment completed successfully"
