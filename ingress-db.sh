#!/bin/bash

# Source sanitization library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/bin/san_lib.sh"
source "$SCRIPT_DIR/bin/kafka_lib.sh"
source "$SCRIPT_DIR/bin/db_lib.sh"
source "$SCRIPT_DIR/bin/file_lib.sh"

# Configuration
QUARANTINE_DIR="./quarantine"
OUTPUT_DIR="./sanitized_output"
mkdir -p "$QUARANTINE_DIR" "$OUTPUT_DIR"

# --- Main Logic ---

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <file_path> <LogType>"
    echo "Example: $0 network.pcap PCAP"
    exit 1
fi

FILE_PATH=$1
TYPE=$2

# ADDED BY PHENIX: Insert Initial DB record BEFORE verification/sanitization
REQ_ID=$(job_request_insert "$FILE_PATH" "$TYPE" "PENDING" "$TYPE" "FILE_INGEST" "NORMAL" "$(basename "$FILE_PATH")" 1 NULL) 

echo "[+] Created DB job_request with ID: $REQ_ID"

if verify_log "$FILE_PATH" "$TYPE"; then
    SANITIZED_FILE="$OUTPUT_DIR/$(basename "$FILE_PATH")"

    case "$TYPE" in
        PCAP|PCAPNG|CAP)
            sanitize_pcap "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "networklog_in"

	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            ;;
        JSON)
            sanitize_json "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
	    
	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            ;;
        CSV|LOG|EVTX)
            sanitize_text "$FILE_PATH"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
	    
	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            ;;
        *)
            echo "[!] Unknown LogType: $TYPE"

	    # ADDED BY PHENIX: Mark DB record as failed
	    job_request_update_status "$REQ_ID" "FAILED"
            return 1
            ;;
    esac
else
    echo "[!] Verification FAILED. Quarantining $FILE_PATH"
    mv "$FILE_PATH" "$QUARANTINE_DIR/"

    # ADDED BY PHENIX: Mark DB record as failed
    job_request_update_status "$REQ_ID" "FAILED"
    exit 1
fi
