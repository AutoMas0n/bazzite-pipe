#!/usr/bin/env bash
set -euo pipefail

# Test script to verify SSH ownership fix
# This simulates the quick-setup scenario where scripts run with sudo

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_USER="${SUDO_USER:-${USER}}"

echo "Testing SSH ownership fix..."
echo "Test user: ${TEST_USER}"
echo ""

# Source the ssh-setup script functions
export BAZZITE_PIPE_COMMON_DIR="${SCRIPT_DIR}/../scripts/common"
source "${SCRIPT_DIR}/../scripts/remote-access/ssh-setup.sh"

# Create a test SSH key
TEST_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyForOwnershipTesting test@example.com"

echo "Step 1: Testing add_authorized_key function..."
add_authorized_key "${TEST_KEY}" "${TEST_USER}"

echo ""
echo "Step 2: Checking ownership..."
TEST_HOME=$(eval echo "~${TEST_USER}")
SSH_DIR="${TEST_HOME}/.ssh"
AUTH_KEYS="${SSH_DIR}/authorized_keys"

# Check .ssh directory ownership
SSH_DIR_OWNER=$(stat -c '%U' "${SSH_DIR}")
if [[ "${SSH_DIR_OWNER}" == "${TEST_USER}" ]]; then
    echo "✅ .ssh directory owned by ${TEST_USER}"
else
    echo "❌ .ssh directory owned by ${SSH_DIR_OWNER} (expected ${TEST_USER})"
    exit 1
fi

# Check authorized_keys ownership
AUTH_KEYS_OWNER=$(stat -c '%U' "${AUTH_KEYS}")
if [[ "${AUTH_KEYS_OWNER}" == "${TEST_USER}" ]]; then
    echo "✅ authorized_keys owned by ${TEST_USER}"
else
    echo "❌ authorized_keys owned by ${AUTH_KEYS_OWNER} (expected ${TEST_USER})"
    exit 1
fi

# Check permissions
SSH_DIR_PERMS=$(stat -c '%a' "${SSH_DIR}")
if [[ "${SSH_DIR_PERMS}" == "700" ]]; then
    echo "✅ .ssh directory has correct permissions (700)"
else
    echo "❌ .ssh directory has permissions ${SSH_DIR_PERMS} (expected 700)"
    exit 1
fi

AUTH_KEYS_PERMS=$(stat -c '%a' "${AUTH_KEYS}")
if [[ "${AUTH_KEYS_PERMS}" == "600" ]]; then
    echo "✅ authorized_keys has correct permissions (600)"
else
    echo "❌ authorized_keys has permissions ${AUTH_KEYS_PERMS} (expected 600)"
    exit 1
fi

echo ""
echo "✅ All ownership and permission checks passed!"
echo ""
echo "Cleanup: Removing test key..."
sed -i '/test@example.com/d' "${AUTH_KEYS}"
echo "✅ Test complete!"
