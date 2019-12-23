FROM ubuntu:xenial
LABEL maintainer='Rentlytics Engineers <engineers@rentlytics.com>'

WORKDIR /root
ARG NGINX_VERSION=1.12.2

RUN echo 'deb-src http://archive.ubuntu.com/ubuntu/ xenial main restricted' >> /etc/apt/sources.list
RUN echo 'deb-src http://archive.ubuntu.com/ubuntu/ xenial-updates main restricted' >> /etc/apt/sources.list
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y libpcre3 libpcre3-dev zlib1g zlib1g-dev libssl1.0.0 libssl-dev unzip wget dpkg-dev automake

RUN mkdir ca && \
    mkdir nginx && \
    chown _apt:root nginx && \
    chmod 774 nginx

WORKDIR /root/nginx
USER root
RUN apt-get source pcre3 zlib1g

RUN wget https://github.com/nginx/nginx/archive/release-${NGINX_VERSION}.zip
RUN unzip release-${NGINX_VERSION}.zip
WORKDIR /root/nginx/nginx-release-${NGINX_VERSION}

RUN auto/configure \
    --with-http_ssl_module \
    --with-stream_ssl_module \
    --with-stream \
    --with-pcre=$(find /root/nginx -type d -iname pcre3-*) \
    --with-zlib=$(find /root/nginx -type d -iname zlib-1*)
RUN make && make install

COPY docker-entrypoint.sh /root/
COPY nginx.conf /usr/local/nginx/conf/
COPY nginx.logrotate.conf /root/
RUN mv /root/nginx.logrotate.conf /etc/logrotate.d/nginx
RUN chmod +x /root/docker-entrypoint.sh

ENTRYPOINT [ "/root/docker-entrypoint.sh" ]
CMD [ "/usr/local/nginx/sbin/nginx", "-g", "daemon off;", "-c", "/usr/local/nginx/conf/nginx.conf" ]
