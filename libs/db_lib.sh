#!/bin/bash

# MySQL connection defaults (override via env vars)
: "${DB_HOST:=127.0.0.1}"
: "${DB_PORT:=3306}"
: "${DB_NAME:=sanitizer_db}"
: "${DB_USER:=user}"
: "${DB_PASSWORD:=password}"

# If true, run mysql inside docker compose service "db"
: "${DB_USE_DOCKER_COMPOSE:=false}"
: "${DB_SERVICE_NAME:=db}"

_db_mysql_cmd() {
  if [[ "$DB_USE_DOCKER_COMPOSE" == "true" ]]; then
    echo "docker compose exec -T $DB_SERVICE_NAME mysql -u$DB_USER -p$DB_PASSWORD $DB_NAME"
  else
    echo "mysql -h$DB_HOST -P$DB_PORT -u$DB_USER -p$DB_PASSWORD $DB_NAME"
  fi
}

db_exec() {
  local sql="$1"
  local cmd
  cmd="$(_db_mysql_cmd)"
  eval "$cmd -N -e \"${sql//\"/\\\"}\""
}

sql_escape() {
  # basic single-quote escaping for SQL string literals
  printf "%s" "$1" | sed "s/'/''/g"
}

# READ -----------------------------------------------------------------------

# ADDED BY PHENIX 4/1/26
job_request_get_latest_pending() {
  mysql -h 127.0.0.1 -u user -ppassword -D sanitizer_db -N -e "
  	SELECT id, file_name, file_type
	FROM job_request
	WHERE status='PENDING'
	ORDER BY id DESC
	LIMIT 1;
	"
}

job_request_read_all() {
  local limit="${1:-100}"
  db_exec "SELECT id, file_name, file_type, request_type, priority, status, score, user_id
           FROM job_request
           ORDER BY id DESC
           LIMIT $limit;"
}

job_request_read_by_id() {
  local id="$1"
  [[ -z "$id" ]] && { echo "[!] id is required"; return 1; }

  db_exec "SELECT id, file_name, file_type, request_type, priority, status, score, user_id, file_content_content_type
           FROM job_request
           WHERE id = $id;"
}

# Optional: export blob content to a file
job_request_export_blob() {
  local id="$1"
  local out_file="$2"
  [[ -z "$id" || -z "$out_file" ]] && { echo "[!] usage: job_request_export_blob <id> <out_file>"; return 1; }

  local b64
  b64="$(db_exec "SELECT TO_BASE64(file_content) FROM job_request WHERE id = $id;")"
  b64="$(printf "%s" "$b64" | tr -d '\r\n\t ')"
  [[ -z "$b64" ]] && { echo "[!] no record/blob found for id=$id"; return 1; }

  if base64 --help 2>/dev/null | grep -q -- '--decode'; then
    printf "%s" "$b64" | base64 --decode > "$out_file"
  else
    printf "%s" "$b64" | base64 -D > "$out_file"
  fi

  echo "[+] exported blob to $out_file"
}

# INSERT ---------------------------------------------------------------------

# ADDED BY PHENIX 4/1/26
insert_execution_report() {
  local job_request_id="$1"
  local status="$2"
  local log_message="$3"
  local user_id="${4:-1}"   # default user_id = 1
  local node
  node="$(hostname)"

  # Escape single quotes in log_message
  log_message="${log_message//\'/\'\'}"

  db_exec "
  	INSERT INTO job_execution_report (
	   start_time,
	   execution_node,
	   execution_log,
	   status,
	   job_request_id,
	   user_id
	) VALUES (
	   NOW(6),
	   'localhost.localdomain',
	   '$LOG',
	   '$STATUS',
	   $REQ_ID,
	   1
	)
	ON DUPLICATE KEY UPDATE
	   end_time = NOW(6),
	   execution_log = VALUES(execution_log),
	   status = VALUES(status);
   "
}


job_request_insert() {
  # usage:
  # job_request_insert <file_path> <content_type> <status> <file_type> <request_type> <priority> <file_name> <user_id> [score]
  local file_path="$1"
  local content_type="$2"
  local status="$3"
  local file_type="$4"
  local request_type="$5"
  local priority="$6"
  local file_name="$7"
  local user_id="$8"
  local score="${9:-NULL}"

  [[ ! -f "$file_path" ]] && { echo "[!] file not found: $file_path"; return 1; }

  # Escape metadata
  content_type="$(sql_escape "$content_type")"
  status="$(sql_escape "$status")"
  file_type="$(sql_escape "$file_type")"
  request_type="$(sql_escape "$request_type")"
  priority="$(sql_escape "$priority")"
  file_name="$(sql_escape "$file_name")"

  # Build SQL without embedding file content
    local sql="
        INSERT INTO job_request
	  (file_content, file_content_content_type, score, status, file_type, request_type, priority, file_name, user_id)
	VALUES
	  (FROM_BASE64(@filedata), '$content_type', $score, '$status', '$file_type', '$request_type', '$priority', '$file_name', $user_id);
	SELECT LAST_INSERT_ID();
       "

  # Run SQL and stream file content safely
    base64 "$file_path" | tr -d '\r\n' | {
      local cmd="$(_db_mysql_cmd)"
      $cmd --silent --raw <<EOF
SET @filedata='$(cat)';
$sql
EOF
	  }


 
 #ADDED BY PHENIX: Fetch ID of row we just added
 local new_id
 new_id=$(db_exec "SELECT LAST_INSERT_ID();" 2>/dev/null | tail -n 1)

}


# UPDATE ---------------------------------------------------------------------

job_request_update_status() {
  local id="$1"
  local status="$2"
  [[ -z "$id" || -z "$status" ]] && { echo "[!] usage: job_request_update_status <id> <status>"; return 1; }

  status="$(sql_escape "$status")"
  db_exec "UPDATE job_request SET status='$status' WHERE id=$id;" >/dev/null 2>&1
  echo "[+] updated status for id=$id"
}

job_request_update_score() {
  local id="$1"
  local score="$2"
  [[ -z "$id" || -z "$score" ]] && { echo "[!] usage: job_request_update_score <id> <score>"; return 1; }

  db_exec "UPDATE job_request SET score=$score WHERE id=$id;" >/dev/null 2>&1
  echo "[+] updated score for id=$id"
}

job_request_update_priority() {
  local id="$1"
  local priority="$2"
  [[ -z "$id" || -z "$priority" ]] && { echo "[!] usage: job_request_update_priority <id> <priority>"; return 1; }

  priority="$(sql_escape "$priority")"
  db_exec "UPDATE job_request SET priority='$priority' WHERE id=$id;" >/dev/null 2>&1
  echo "[+] updated priority for id=$id"
}
