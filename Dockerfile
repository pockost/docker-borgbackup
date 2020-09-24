FROM alpine:3.9

RUN apk upgrade --no-cache \
    && apk add --no-cache \
       alpine-sdk \
       tzdata \
       bash \
       lftp \
       curl \
       python3-dev \
       openssl-dev \
       lz4-dev \
       acl-dev \
       linux-headers \
       openssh-client \
    && chmod 0600 /var/spool/cron/crontabs/root \
    && sed -i 's/\/root:\/bin\/ash/\/root:\/bin\/bash/g' /etc/passwd \
    && touch /var/log/backup.log \
    && ln -sf /dev/stdout /var/log/backup.log \
    && pip3 install --upgrade pip \
    && pip3 install --upgrade borgbackup

COPY entrypoint.sh /usr/local/bin/

RUN chmod o+x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["entrypoint.sh"]
