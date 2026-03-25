#!/bin/bash

send_file_to_topic() {
	    local file_path="$1"
	    local topic="$2"

	    if [[ ! -f "$file_path" ]]; then
                echo "[!] File not found: $file_path"
		return 1 
	    fi
	
	    #USING KCAT TO PUBLISH RAW FILE CONTENTS. MESSAGE OVER 1MB IN BINARY (TOO LARGE FOR DEFAULT KAFKA CONFIGS), CONVERTED TO ASCII USING BASE64
	    base64 "$file_path" | kcat -b localhost:9092 -t "$topic" -P 

	    echo "[+] Sent file to topic: $topic ($file_path)"
}
