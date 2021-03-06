#!/bin/bash

borg_passphrase=${BORG_PASSPHRASE}
borg_target=${BORG_TARGET}
borg_sources=${BORG_SOURCES}

synchronisation_method=${SYNCHRONISATION_METHOD,,}
lftp_target=${LFTP_TARGET}
ssh_host=${SSH_HOST}
repository_name=${REPOSITORY_NAME}

notification_method=${NOTIFICATION_METHOD,,}
slack_alert_identifier=${SLACK_ALERT_IDENTIFIER}
slack_alert_link=${SLACK_ALERT_LINK}
slack_webhook_url=${SLACK_WEBHOOK_URL}

cron_delay=${CRON_DELAY}
keep_within=${KEEP_WITHIN}

function log {

  [[ -z $2 ]] && type="info" || type="$2"

  echo "time=\"$(date '+%m/%d/%Y %H:%M:%S')\" level=$type msg=\"$1\""

}

function notify {

  if [[ ${notification_method} = "slack" ]]; then

    if [[ -n ${slack_webhook_url} ]]; then

      if [[ -n ${slack_alert_identifier} ]]; then

        title="["${slack_alert_identifier}"] - Backup failed"

      else

        title="Backup failed"

      fi

      if [[ -z ${slack_alert_link} ]]; then

        attachments='[{"fallback": "'$1'", "title": "'${title}'", "text": "'$1'", "color": "danger",}]'

      else

        attachments='[{"fallback": "'$1'", "title": "'${title}'", "title_link": "'${slack_alert_link}'", "text": "'$1'", "color": "danger",}]'

      fi

      payload='{"channel": "backup", "username": "Borgbackup", "attachments": '${attachments}'}'

      curl -X POST --data-urlencode "payload=$payload" ${slack_webhook_url} &> /dev/null

    fi

  fi

}

function check_requirements {

  error=0

  if [[ -z ${borg_passphrase} ]]; then

    log "You need to specify BORG_PASSPHRASE" error
    error=1

  fi

  if [[ -z ${borg_target} ]]; then

    log "You need to specify BORG_TARGET" error
    error=1

  fi

  if [[ -z ${borg_sources} ]]; then

    log "You need to specify BORG_SOURCES" error
    error=1

  fi

  if [[ -z ${cron_delay} ]]; then

    log "You need to specify CRON_DELAY" error
    error=1

  fi

  if [[ -n ${synchronisation_method} ]]; then

    if [[ ${synchronisation_method} = "ssh" ]]; then

      log "Synchronisation is setup to ssh"

      if [[ -z ${ssh_host} ]]; then

        log "You need to specify SSH_HOST" error
	      error=1

      fi

    fi

    if [[ ${synchronisation_method} = "lftp" ]]; then

      log "Synchronisation is setup to lftp"

      if [[ -z ${lftp_target} ]]; then

        log "You need to specify LFTP_TARGET" error
        error=1

      fi

    fi

    if [[ ${synchronisation_method} = "local" ]]; then

      log "Synchronisation is setup to local. Backup(s) will be local only"

    fi

  else

    log "You need to specify SYNCHRONISATION_METHOD" error
    error=1

  fi

  if [[ -z ${repository_name} ]]; then

    repository_name="backup"
    log "You don't specify REPOSITORY_NAME. Repository name will be 'backup'" warning

  fi

  if [[ -n ${notification_method} ]]; then

    if [[ ${notification_method} = "slack" ]]; then

      log "Notification is setup to slack"

      if [[ -z ${slack_alert_identifier} ]]; then

        log "You don't specify SLACK_ALERT_IDENTIFIER. Alert will be less expressive" warning

      fi

      if [[ -z ${slack_alert_link} ]]; then

        log "You don't specify SLACK_ALERT_LINK. Alert will be less expressive" warning

      fi

      if [[ -z ${slack_webhook_url} ]]; then

        log "You need to specify SLACK_WEBHOOK_URL" error
        error=1

      fi

    fi

    if [[ ${notification_method} = "log" ]]; then

      log "Notification is setup to log. Error(s) will be only logged here"

    fi

  else

    log "You need to specify NOTIFICATION_METHOD" error
    error=1

  fi

  if [[ -z ${keep_within} ]]; then

    log "You don't specify KEEP_WITHIN. Backup(s) will never be pruned" warning

  fi

  if [[ ${error} = 1 ]]; then

    exit

  fi

}

function init {

  log "Starting ..."

  # Check if backup folder exist
  if [[ ! -d ${borg_target} ]]; then

    mkdir -p ${borg_target}

  fi

  # Parse env var to get all sources
  IFS=', ' read -r -a borg_sources <<< ${borg_sources}

  # Loop over list of sources
  for element in "${borg_sources[@]}"
  do

    # Extract directory name from path
    basename=$(basename ${element})

    # Create backup repository path
    repository_path="${borg_target}/${basename}"

    if [[ ${synchronisation_method} = "local" ]] || [[ ${synchronisation_method} = "lftp" ]]; then

      # Check if the repository exists
      if [[ ! -d ${repository_path} ]]; then

        mkdir -p ${repository_path}

        log "Init borg repository for $element"
        BORG_PASSPHRASE=${borg_passphrase} borg init --encryption=repokey-blake2 ${repository_path} &> /dev/null

        if [[ $? -ne 0 ]]; then

          message="An error occurred when we try to initialize $element"
          log "$message" error
          notify "$message"

        fi

      fi

    fi

    if [[ ${synchronisation_method} = "ssh" ]]; then

      if ! ssh ${ssh_host} "ls ${repository_path}/${repository_name} > /dev/null 2>&1"; then

        ssh ${ssh_host} "mkdir ${repository_path}/${repository_name}" 

	log "Init borg repository for $element"
        BORG_PASSPHRASE=${borg_passphrase} borg init --encryption=repokey-blake2 ${ssh_host}:${repository_path}/${repository_name} &> /dev/null

	if [[ $? -ne 0 ]]; then

          message="An error occurred when we try to initialize $element"
          log "$message" error
          notify "$message"

        fi

      fi

    fi

  done

  backup

  log "Setup cron tasks"
  echo "${cron_delay} entrypoint.sh backup" > /var/spool/cron/crontabs/root

  log "Start cron daemon"
  crond -L /dev/null -f

}

function backup {

  # Parse env var to get all sources
  IFS=', ' read -r -a borg_sources <<< ${borg_sources}

  # Loop over list of sources
  for element in "${borg_sources[@]}"
  do

    # Extract directory name from path
    basename=$(basename ${element})

    # Create backup repository path
    repository_path="${borg_target}/${basename}"

    if [[ ${synchronisation_method} = "local" ]] || [[ ${synchronisation_method} = "lftp" ]]; then

      log "Backup "${element}
      BORG_PASSPHRASE=${borg_passphrase} borg create ${repository_path}::$(date '+%d-%m-%Y_%H:%M:%S') ${element}

      if [[ $? -ne 0 ]]; then

        message="An error occurred when we try to backup ${element}"
        log "$message" error
        notify "$message"

      fi

    fi

    if [[ ${synchronisation_method} = "ssh" ]]; then
      
      log "Backup "${element}
      BORG_PASSPHRASE=${borg_passphrase} borg create ${ssh_host}:${repository_path}/${repository_name}::$(date '+%d-%m-%Y_%H:%M:%S') ${element}

      if [[ $? -ne 0 ]]; then

        message="An error occurred when we try to backup ${element}"
        log "$message" error
        notify "$message"

      fi

    fi

  done

  # Sync backup folder with LFTP
  if [[ ${synchronisation_method} = "lftp" ]]; then

    log "Synchronize backups with ${lftp_target}"
    lftp ftp://auto:@${lftp_target} -e "mirror -e -R ${borg_target} / ; quit" &> /dev/null

    if [[ $? -ne 0 ]]; then

      message="An error occurred when we try to synchronise ${borg_target} with ${lftp_target}"
      log "$message" error
      notify "$message"

    fi

  fi

  # Prune old backups
  if [[ -n ${keep_within} ]]; then

    for element in "${borg_sources[@]}"
    do

      # Extract directory name from path
      basename=$(basename ${element})

      # Create backup repository path
      repository_path="${borg_target}/${basename}"

      if [[ ${synchronisation_method} = "local" ]] || [[ ${synchronisation_method} = "lftp" ]]; then

        log "Prune ${element}"
        borg prune --keep-within ${keep_within} ${repository_path}

    	if [[ $? -ne 0 ]]; then

      	  message="An error occurred when we try to prune ${element}"
      	  log "$message" error
      	  notify "$message"

    	fi
	
      fi

      if [[ ${synchronisation_method} = "ssh" ]]; then

        log "Prune ${element}"
        borg prune --keep-within ${keep_within} ${ssh_host}:${repository_path}/${repository_name}

    	if [[ $? -ne 0 ]]; then

      	  message="An error occurred when we try to prune ${element}"
      	  log "$message" error
      	  notify "$message"

    	fi

      fi

    done

  fi

}

if [[ -z $1 ]]; then

  check_requirements
  init

else

  backup

fi
