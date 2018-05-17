#!/bin/bash

BORG_PASSPHRASE="pockost"
BORG_TARGET="/backup"
BORG_SOURCES=""

# Parse env var to get all sources
IFS=', ' read -r -a borg_sources <<< $BORG_SOURCES

# Loop over list of sources
for element in "${borg_sources[@]}"
do

  # Extract directory name from path
  basename=$(basename $element)

  # Check if the repositoy exists
  if [ ! -d "/backup/$basename" ]; then

    BORG_PASSPHRASE=$BORG_PASSPHRASE borg init --encryption=repokey-blake2 /backup/$basename
    echo "create"

  fi

  BORG_PASSPHRASE=$BORG_PASSPHRASE borg create /backup/$basename::$(date '+%d-%m-%Y_%H:%M:%S') $element

done

crond -L /dev/null -f
