#!/bin/bash

source libs/db_lib.sh
db_exec "INSERT INTO job_execution_report (
	start_time,
	end_time,
	execution_node,
	execution_log,
	status,
	job_request_id,
	user_id
) VALUES (
	NOW(),
	NULL,
	'localhost',
	'Test execution log entry',
	'SUCCESS',
	1,
	1
);"
