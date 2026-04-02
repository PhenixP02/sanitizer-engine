#!/bin/bash

# Source sanitization library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/libs/san_lib.sh"
source "$SCRIPT_DIR/libs/kafka_lib.sh"
source "$SCRIPT_DIR/libs/db_lib.sh"
source "$SCRIPT_DIR/libs/file_lib.sh"

# Configuration
QUARANTINE_DIR="./quarantine"
OUTPUT_DIR="./sanitized_output"
mkdir -p "$QUARANTINE_DIR" "$OUTPUT_DIR"

# --- Main Logic ---

# FETCH LATEST PENDING JOB (ADDED BY PHENIX 4/1/26)
read REQ_ID FILE_NAME TYPE <<< "$(job_request_get_latest_pending)"

if [ -z "$REQ_ID" ]; then
   echo "[!] No pending jobs found."
   insert_execution_report NULL "NO_JOBS" "No pending jobs found."   # Send execution status report to job_execution_report 
   exit 0
fi

echo "[+] Loaded job_request ID=$REQ_ID"
insert_execution_report "$REQ_ID" "STARTED" "Loaded job_request ID=$REQ_ID"   # Send execution status report to job_execution_report 
echo "[+] File: $FILE_NAME"
echo "[+] Type: $TYPE"

if verify_log "$FILE_NAME" "$TYPE"; then
    SANITIZED_FILE="$OUTPUT_DIR/$(basename "$FILE_NAME")"

    case "$TYPE" in
        PCAP|PCAPNG|CAP)
            sanitize_pcap "$FILE_NAME"
            send_file_to_topic "$SANITIZED_FILE" "networklog_in"

	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            insert_execution_report "$REQ_ID" "SUCCESS" "Sanitization complete and sent to Kafka"   # Send execution status report to job_execution_report 
            ;;
        JSON)
            sanitize_json "$FILE_NAME"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
	    
	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            insert_execution_report "$REQ_ID" "SUCCESS" "Sanitization complete and sent to Kafka"   # Send execution status report to job_execution_report 
            ;;
        CSV|LOG|EVTX)
            sanitize_text "$FILE_NAME"
            send_file_to_topic "$SANITIZED_FILE" "systemlog_in"
	    
	    #ADDED BY PHENIX: Update DB status after success
	    job_request_update_status "$REQ_ID" "SUCCESS"
            insert_execution_report "$REQ_ID" "SUCCESS" "Sanitization complete and sent to Kafka"   # Send execution status report to job_execution_report 
            ;;
        *)
            echo "[!] Unknown LogType: $TYPE"
            insert_execution_report "$REQ_ID" "FAILED_UNKNOWN_TYPE" "Unknown log type: $TYPE"   # Send execution status report to job_execution_report 
	    # ADDED BY PHENIX: Mark DB record as failed
	    job_request_update_status "$REQ_ID" "FAILED"
            return 1
            ;;
    esac
else
    echo "[!] Verification FAILED. Quarantining $FILE_NAME"
    insert_execution_report "$REQ_ID" "FAILED_VERIFICATION" "Verification failed for file: $FILE_NAME"   # Send execution status report to job_execution_report 
    mv "$FILE_NAME" "$QUARANTINE_DIR/"
    # ADDED BY PHENIX: Mark DB record as failed
    job_request_update_status "$REQ_ID" "FAILED"
    exit 1
fi
