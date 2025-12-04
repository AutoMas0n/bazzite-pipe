#!/usr/bin/env bash
set -euo pipefail

# Script: capture-external-traffic.sh
# Purpose: Capture ALL external network traffic during game launch
# Usage: Run this, then launch the game

readonly CAPTURE_FILE="/tmp/ersc-capture-$(date +%Y%m%d-%H%M%S).pcap"
readonly LOG_FILE="${CAPTURE_FILE}.log"

echo "External Traffic Capture"
echo "========================"
echo "Capture file: ${CAPTURE_FILE}"
echo ""
echo "This will capture ALL external network traffic"
echo "Filtering out local/LAN traffic"
echo ""
echo "Instructions:"
echo "1. This script will start capturing in 3 seconds"
echo "2. Launch the game in Lutris"
echo "3. Wait for the update check to fail/complete"
echo "4. Press Ctrl+C to stop capture"
echo ""
echo "Starting in 3 seconds..."
sleep 3

# Build tcpdump filter to exclude local traffic
FILTER="not ("
FILTER="${FILTER} dst net 127.0.0.0/8 or"      # localhost
FILTER="${FILTER} dst net 10.0.0.0/8 or"       # private
FILTER="${FILTER} dst net 172.16.0.0/12 or"    # private
FILTER="${FILTER} dst net 192.168.0.0/16 or"   # private
FILTER="${FILTER} dst net 169.254.0.0/16"      # link-local
FILTER="${FILTER} )"

echo "Starting capture..."
echo "Filter: External traffic only"
echo ""

# Start capture
sudo tcpdump -i any -n -s 0 -w "${CAPTURE_FILE}" "${FILTER}" &
TCPDUMP_PID=$!

echo "Capturing... (PID: ${TCPDUMP_PID})"
echo "Launch the game NOW"
echo ""

# Trap to stop capture
trap "echo ''; echo 'Stopping capture...'; sudo kill ${TCPDUMP_PID} 2>/dev/null || true; sleep 2" EXIT

# Wait for user to stop
wait ${TCPDUMP_PID} 2>/dev/null || true

echo ""
echo "Analyzing capture..."
echo ""

# Analyze the capture
if [ -f "${CAPTURE_FILE}" ]; then
    # Extract unique destination IPs and ports
    echo "External connections found:"
    echo "============================"
    
    sudo tcpdump -r "${CAPTURE_FILE}" -n 2>/dev/null | \
        awk '{print $3, $5}' | \
        grep -v "^$" | \
        sort -u | \
        tee "${LOG_FILE}"
    
    echo ""
    echo "Detailed analysis:"
    echo "=================="
    
    # Try to identify HTTP/HTTPS traffic
    if command -v tshark &> /dev/null; then
        echo ""
        echo "HTTP/HTTPS hosts:"
        sudo tshark -r "${CAPTURE_FILE}" -Y 'http.request or tls.handshake.type == 1' \
            -T fields -e ip.dst -e tcp.dstport -e http.host -e tls.handshake.extensions_server_name \
            2>/dev/null | sort -u || echo "None found"
    fi
    
    echo ""
    echo "Files saved:"
    echo "  Capture: ${CAPTURE_FILE}"
    echo "  Log: ${LOG_FILE}"
    echo ""
    echo "To block an IP:port, use:"
    echo "  sudo ~/GitHub/bazzite-pipe/scripts/gaming/block-ersc-updates.sh firewall <ip:port>"
else
    echo "Error: Capture file not created"
fi
