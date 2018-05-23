FROM alpine:latest

RUN apk add --no-cache tzdata borgbackup bash lftp \
    && chmod 0600 /var/spool/cron/crontabs/root \
    && sed -i 's/\/root:\/bin\/ash/\/root:\/bin\/bash/g' /etc/passwd \
    && touch /var/log/backup.log \
    && ln -sf /dev/stdout /var/log/backup.log

COPY entrypoint.sh /usr/local/bin/

COPY cronjob /var/spool/cron/crontabs/root

ENTRYPOINT ["entrypoint.sh"]
