#!/usr/bin/env bash
set -e

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT
CONTINUE=1

ctrl_c () {
    echo "** Trapped CTRL-C"
    CONTINUE=0
}

while [ $CONTINUE -eq 1 ]; do
    sleep 1
done