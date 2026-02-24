#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CLIENT_KEY="$SCRIPT_DIR/client_key"
# ssh uses -p (lowercase), scp uses -P (uppercase) for port
SSH_OPTS="-i $CLIENT_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

PASS=0
FAIL=0

pass() { echo "[PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "[FAIL] $1"; FAIL=$((FAIL + 1)); }

echo "=== Building and starting containers ==="
docker compose -f "$SCRIPT_DIR/docker-compose.test.yaml" up -d --build

echo "Waiting for sshd to be ready..."
for i in $(seq 1 30); do
    if ssh $SSH_OPTS -p 2222 host1@localhost "exit" 2>/dev/null; then
        echo "  Ready after ${i}s"
        break
    fi
    sleep 1
done

echo ""
echo "=== Test 1: Log file ==="
LOG=$(docker exec ssh_jumpbox cat /var/log/jumpbox.log 2>/dev/null || echo "")
if [ -n "$LOG" ]; then
    pass "Log file has content"
    echo "  Last entry: $(echo "$LOG" | tail -1)"
else
    fail "Log file is empty or missing"
fi

echo ""
echo "=== Test 2: Interactive SSH ==="
RESULT=$(ssh $SSH_OPTS -p 2222 host1@localhost "echo SSH_OK" 2>/dev/null || echo "")
if [[ "$RESULT" == "SSH_OK" ]]; then
    pass "Interactive SSH reached target"
else
    fail "Interactive SSH failed (got: '$RESULT')"
fi

echo ""
echo "=== Test 3: SCP upload ==="
echo "scp_test_content" > /tmp/scp_test.txt
# scp uses -P (uppercase) for port
if scp $SSH_OPTS -P 2222 /tmp/scp_test.txt host1@localhost:/tmp/scp_test.txt 2>/dev/null; then
    REMOTE=$(ssh $SSH_OPTS -p 2222 host1@localhost "cat /tmp/scp_test.txt" 2>/dev/null || echo "")
    if [[ "$REMOTE" == "scp_test_content" ]]; then
        pass "SCP upload succeeded"
    else
        fail "SCP upload: file not found on target (got: '$REMOTE')"
    fi
else
    fail "SCP upload command failed"
fi

echo ""
echo "=== Test 4: SFTP ==="
# Use batch mode (-b -) to avoid hanging; timeout after 10s
SFTP_OUT=$(echo -e "ls /tmp\nexit" | timeout 10 sftp $SSH_OPTS -P 2222 -b - host1@localhost 2>/dev/null || echo "")
if echo "$SFTP_OUT" | grep -q "scp_test.txt"; then
    pass "SFTP session worked and listed /tmp/scp_test.txt"
else
    fail "SFTP failed or couldn't list files (got: '$SFTP_OUT')"
fi

echo ""
echo "=== Test 5: Port forwarding (-L) ==="
ssh $SSH_OPTS -p 2222 -L 9022:target:22 host1@localhost -N -f -o ExitOnForwardFailure=yes 2>/dev/null
sleep 1
# Connect through the forwarded port using the jumpbox-to-target key (not the client key)
FWD_RESULT=$(ssh -i "$ROOT_DIR/keys/id_rsa" -p 9022 \
    -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
    user1@localhost "echo PORT_FWD_OK" 2>/dev/null || echo "")
pkill -f "ssh.*9022:target:22" 2>/dev/null || true
if [[ "$FWD_RESULT" == "PORT_FWD_OK" ]]; then
    pass "Port forwarding (-L) worked"
else
    fail "Port forwarding failed (got: '$FWD_RESULT')"
fi

echo ""
echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

echo "=== Jumpbox log ==="
docker exec ssh_jumpbox cat /var/log/jumpbox.log 2>/dev/null || echo "(empty)"

echo ""
echo "=== Cleanup ==="
docker compose -f "$SCRIPT_DIR/docker-compose.test.yaml" down

if [ $FAIL -gt 0 ]; then
    exit 1
fi
