#!/bin/bash

# Load Kafka producer/consumer functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bin/kafka_producer.sh"

TOPIC=$1

if [[ -z "$TOPIC" ]]; then
	echo "Usage: $0 <topic>"
	exit 1
fi

echo "[*] Consuming messages from topic: $TOPIC"
echo "-----------------------------------------"

# Read all messages from beginning
kcat -C -b "$KAFKA_BOOTSTRAP_SERVERS" -t "$TOPIC" -o beginning -r 2000 -D "" -f '%s\n' \
| while read -r line; do

    # Skip non-JSON lines
    echo "$line" | jq empty >/dev/null 2>&1 || continue

    payload=$(echo "$line" | jq -r '.payload // empty')

    if [[ -n "$payload" ]]; then
	echo "----- Decoded Payload -----"
	echo "$payload" | base64 -d
	echo
    fi
done
