#!/bin/bash

function log {

  [[ -z $2 ]] && type="info" || type="$2"

  echo "time=\"$(date '+%m/%d/%Y %H:%M:%S')\" level=$type msg=\"$1\""

}

function alert {

  if [ -n "$SLACK_WEBHOOK_URL" ]; then

    if [ -n "$SLACK_ALERT_IDENTIFIER" ]; then

      title="[$SLACK_ALERT_IDENTIFIER] - Backup failed"

    else

      title="Backup failed"

    fi

    if [ -z "$SLACK_ALERT_LINK" ]; then

      attachments='[{"fallback": "The attachement isnt supported.", "title": "'$title'", "text": "'$1'", "color": "danger",}]'

    else

      attachments='[{"fallback": "The attachement isnt supported.", "title": "'$title'", "title_link": "'$SLACK_ALERT_LINK'", "text": "'$1'", "color": "danger",}]'

    fi

    payload='{"channel": "backup", "username": "Borgbackup", "attachments": '$attachments'}'

    curl -X POST --data-urlencode "payload=$payload" $SLACK_WEBHOOK_URL &> /dev/null

  fi

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

  # Check if backup folder exist
    if [ ! -d "$BORG_TARGET" ]; then

      mkdir -p $BORG_TARGET

    fi

  # Parse env var to get all sources
  IFS=', ' read -r -a borg_sources <<< $BORG_SOURCES

  # Loop over list of sources
  for element in "${borg_sources[@]}"
  do

    # Extract directory name from path
    basename=$(basename $element)

    # Create backup repository path
    repository_path="$BORG_TARGET/$basename"

    # Check if the repository exists
    if [ ! -d "$repository_path" ]; then

      mkdir -p $repository_path

      if BORG_PASSPHRASE=$BORG_PASSPHRASE borg init --encryption=repokey-blake2 $repository_path &> /dev/null; then

        log "Init borg repository for $element"

      else

        message="An error occured when we try to initialize $element"
        log "$message" error
        alert "$message"

      fi

    fi

  done

  backup

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

    # Create backup repository path
    repository_path="$BORG_TARGET/$basename"

    if BORG_PASSPHRASE=$BORG_PASSPHRASE borg create $repository_path::$(date '+%d-%m-%Y_%H:%M:%S') $element; then

      log "Backup $element"

    else

      message="An error occured when we try to backup $element"
      log "$message" error
      alert "$message"

    fi

  done

  # Sync backup folder with LFTP
  if lftp ftp://auto:@$LFTP_TARGET -e "mirror -e -R $BORG_TARGET / ; quit" &> /dev/null; then

    log "Synchronize backups with $LFTP_TARGET"

  else

    message="An error occured when we try to synchronise $BORG_TARGET with $LFTP_TARGET"
    log "$message" error
    alert "$message"
    
  fi

}

check_requirements

if [ -z $1 ]; then
  init
else
  backup
fi
