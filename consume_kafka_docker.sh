#!/bin/bash

TOPIC="$1"

if [[ -z "$TOPIC" ]]; then
	echo "Usage: $0 <topic>"
	exit 1
fi

echo "[*] Consuming messages from topic: $TOPIC"
echo "-----------------------------------------"

docker exec -i dev-kafka-1 kafka-console-consumer \
   --bootstrap-server localhost:9092 \
   --topic "$TOPIC" \
   --from-beginning \
| while read -r line; do

    # Check if line is valid base64
    if echo "$line" | base64 -d >/dev/null 2>&1; then
	echo "Decoded:"
	echo "$line" | base64 -d
	echo
    else
	echo "Raw:"
	echo "$line"
	echo
    fi
done
