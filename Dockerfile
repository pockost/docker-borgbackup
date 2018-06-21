FROM alpine:latest

RUN apk add --no-cache tzdata borgbackup bash lftp curl \
    && chmod 0600 /var/spool/cron/crontabs/root \
    && sed -i 's/\/root:\/bin\/ash/\/root:\/bin\/bash/g' /etc/passwd \
    && touch /var/log/backup.log \
    && ln -sf /dev/stdout /var/log/backup.log

COPY entrypoint.sh /usr/local/bin/

RUN chmod o+x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
