#!/bin/bash

source libs/db_lib.sh
db_exec "UPDATE job_execution_report SET execution_log='Updated message' WHERE id=1;"
