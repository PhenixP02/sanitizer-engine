#!/bin/bash

source libs/db_lib.sh
db_exec "SELECT * FROM job_execution_report;"
