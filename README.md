# BorgBackup Docker Image

## What is BorgBackup ?

BorgBackup (short: Borg) is a deduplicating backup program. Optionally, it supports compression and authenticated encryption.

The main goal of Borg is to provide an efficient and secure way to backup data. The data deduplication technique used makes Borg suitable for daily backups since only changes are stored. The authenticated encryption technique makes it suitable for backups to not fully trusted targets.

For more information about and related questions about BorgBackup, please visit [borgbackup.readthedocs.io](http://borgbackup.readthedocs.io)

## How to use this image

Please refer to the [BorgBackup documentation](http://borgbackup.readthedocs.io) for a comprehensive overview and a detailed description of the BorgBackup system.

### Quick start

If you simply want to make a backup of your data every day at 5:00am and copy it into a safe place via LFTP, you can run the following command:

```
$ docker run --name borgbackup -e BORG_PASSPHRASE="passphrase" -e BORG_TARGET="/backup" -e BORG_SOURCES="/var/www/html" -e LFTP_TARGET="dedibackup-dc3.online.net" -e CRON_DELAY="0 5 * * *" pockost/borgbackup
```

### Settings

When you use the borgbackup image you can adjust the configuration of your backups by passing one or more environment variables.

#### `BORG_PASSPHRASE`

Required*: This variable specifies the passphrase that will be used by borg to encrypt all backups.

#### `BORG_TARGET`

Required*: This variable specifies the destination of the backups before the mirroring via LFTP.

#### `BORG_SOURCES`

Required*: This variable specifies the folders that will be backup and and encrypt by borg.

#### `LFTP_TARGET`

Optional*: This variable specifies the safe place where your `BORG_TARGET` folder will be mirrored. If not set no mirroring will be done.

#### `CRON_DELAY`

Required*: This variable specifies the recursion of your backups. Based on UNIX cron format.

Every day at 6:00am : `0 6 * * *`

Every monday at 5:30am : `30 5 * * 1`

#### `SLACK_WEBHOOK_URL`

Optional: This variable specifies the slack webhook url that will be call if an error occured.

#### `SLACK_ALERT_IDENTIFIER`

Optional: This variable is used to customize the alert notifications send into the Slack channel.

#### `SLACK_ALERT_LINK`

Optional: This variable is used to add a link to the alert notifications title send into the Slack channel.
