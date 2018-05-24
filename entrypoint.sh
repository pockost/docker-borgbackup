#!/bin/bash

function log {

  [[ -z $2 ]] && type="info" || type="$2"

  echo "time=\"$(date '+%m/%d/%Y %H:%M:%S')\" level=$type msg=\"$1\""

}

function check_requirements {

  if [ -z "$BORG_PASSPHRASE" ]; then
    log "You need to specify BORG_PASSPHRASE" error
    exit
  fi

  if [ -z "$BORG_TARGET" ]; then
    log "You need to specify BORG_TARGET" error
    exit
  fi

  if [ -z "$BORG_SOURCES" ]; then
    log "You need to specify BORG_SOURCES" error
    exit
  fi

  if [ -z "$LFTP_TARGET" ]; then
    log "You need to specify LFTP_TARGET" error
    exit
  fi

  if [ -z "$CRON_DELAY" ]; then
    log "You need to specify CRON_DELAY" error
    exit
  fi

}

function init {

  log "Starting ..."

  # Parse env var to get all sources
  IFS=', ' read -r -a borg_sources <<< $BORG_SOURCES

  # Loop over list of sources
  for element in "${borg_sources[@]}"
  do

    # Extract directory name from path
    basename=$(basename $element)

    # Check if backup folder exist
    if [ ! -d "/backup" ]; then

      mkdir /backup

    fi

    # Check if the repository exists
    if [ ! -d "/backup/$basename" ]; then

      mkdir /backup/$basename

      log "Init borg repository for $element"
      BORG_PASSPHRASE=$BORG_PASSPHRASE borg init --encryption=repokey-blake2 /backup/$basename &> /dev/null

      log "Create first backup for $element"
      BORG_PASSPHRASE=$BORG_PASSPHRASE borg create /backup/$basename::$(date '+%d-%m-%Y_%H:%M:%S') $element

    fi

  done

  log "Setup cron tasks"
  echo "$CRON_DELAY entrypoint.sh backup" > /var/spool/cron/crontabs/root

  log "Start cron daemon"
  crond -L /dev/null -f

}

function backup {

  # Parse env var to get all sources
  IFS=', ' read -r -a borg_sources <<< $BORG_SOURCES

  # Loop over list of sources
  for element in "${borg_sources[@]}"
  do

    # Extract directory name from path
    basename=$(basename $element)

    log "Backup $element"
    BORG_PASSPHRASE=$BORG_PASSPHRASE borg create /backup/$basename::$(date '+%d-%m-%Y_%H:%M:%S') $element

  done

  # Sync backup folder with LFTP
  if [ $(lftp ftp://auto:@$LFTP_TARGET -e "mirror -e -R $BORG_TARGET / ; quit" &> /dev/null) ]; then
    log "Synchronize backups with $LFTP_TARGET"
  else
    log "Impossible to synchronize backups with $LFTP_TARGET" error
  fi

}

check_requirements

if [ -z $1 ]; then
  init
else
  backup
fi
