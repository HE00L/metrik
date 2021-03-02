FROM mongo:4.4.3-bionic

# set locale
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get update \
    && apt-get install -y --no-install-recommends tzdata curl ca-certificates fontconfig locales \
    && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen en_US.UTF-8

# # import public keys
RUN apt-get install -y --no-install-recommends software-properties-common wget apt-transport-https gnupg \
    && wget --no-check-certificate -qO - https://adoptopenjdk.jfrog.io/adoptopenjdk/api/gpg/key/public | apt-key add - \
    && wget --no-check-certificate -qO - https://nginx.org/keys/nginx_signing.key | apt-key add - \
    && add-apt-repository --yes https://adoptopenjdk.jfrog.io/adoptopenjdk/deb/ \
    && echo "deb https://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list \
    && echo "deb-src https://nginx.org/packages/mainline/ubuntu/ bionic nginx" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends supervisor adoptopenjdk-11-hotspot-jre nginx \
    && rm -rf /var/lib/apt/lists/*

# Create artifacts storaging
RUN mkdir -p /app/logs

# Suporvisord config
RUN mkdir -p /etc/supervisor/conf.d/
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# MongoDB Config
# Note. Do not put the mongo init scripts to /docker-entrypoint-initdb.d for automated initialization.
# Currently it causes error when initializing replica set in mongo entrypoint execution.
# Use supervisord instead.
COPY config/mongo-create-user.js /app/mongo/mongo-init-replica-set.js
COPY config/mongo-create-user.js /app/mongo/mongo-create-user.js
RUN openssl rand -base64 756 > /app/mongo/keyfile
RUN chown 999 /app/mongo/keyfile && chmod 400 /app/mongo/keyfile

ENV MONGO_INITDB_DATABASE 4-Key-Metrics
ENV MONGO_INITDB_ROOT_USERNAME admin
ENV MONGO_INITDB_ROOT_PASSWORD root

# Copy BACKEND artifact
ENV APP_ENV local

COPY artifacts/run.sh /app/4km-service.sh
COPY artifacts/build/libs/sea-4-key-metrics-service-*.jar /app/sea-4-key-metrics-service.jar

# FRONTEND and Nginx
COPY artifacts/dist /usr/share/nginx/html
COPY artifacts/nginx.conf /etc/nginx/

RUN chmod +x /app/*.sh

EXPOSE 80 9000 27017

ENTRYPOINT ["supervisord"]
