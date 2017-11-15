#!/usr/bin/env bash
set -e

if [ -z "$PROXY_PORT" ]; then
    export PROXY_PORT=6379
fi

if [ -z "$REDIS_HOST" ]; then
    echo "Environment variable REDIS_HOST is not set"
    exit 1
fi

if [ -z "$REDIS_PORT" ]; then
    export REDIS_PORT=6379
elif [[ "$REDIS_PORT" =~ "tcp://" ]]; then
   export REDIS_PORT=6379
fi

sed -i'' "s/%{PROXY_PORT}/${PROXY_PORT}/" /usr/local/nginx/conf/nginx.conf
sed -i'' "s/%{REDIS_HOST}/${REDIS_HOST}/" /usr/local/nginx/conf/nginx.conf
sed -i'' "s/%{REDIS_PORT}/${REDIS_PORT}/" /usr/local/nginx/conf/nginx.conf

exec "$@"