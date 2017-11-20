FROM ubuntu:xenial
LABEL maintainer='Rentlytics Engineers <engineers@rentlytics.com>'

ARG ROOT_KEY_PASS=development
ARG NGINX_URL=localhost:6379

RUN apt update && apt upgrade -y
RUN apt install -y openssl

RUN mkdir /root/ca
WORKDIR /root/ca

RUN mkdir certs private crl newcerts && \
    chmod 700 private && \
    touch index.txt && \
    echo 1000 > serial

RUN openssl genrsa \
    -aes256 \
    -passout pass:${ROOT_KEY_PASS} \
    -out private/ca.key \
    4096
RUN chmod 400 private/ca.key

COPY openssl.cnf /root/ca/

RUN openssl req -config openssl.cnf \
    -key private/ca.key \
    -passin pass:${ROOT_KEY_PASS} \
    -new -x509 -sha256 \
    -days 7300 \
    -extensions v3_ca \
    -subj "/CN=redis-ca/O=Rentlytics, Inc/OU=engineers/L=San Francisco/ST=California/C=US" \
    -batch \
    -out certs/ca.pem && \
    chmod 444 certs/ca.pem && \
    openssl x509 -noout -text -in certs/ca.pem

RUN openssl genrsa \
    -out private/nginx.key \
    2048 && chmod 400 private/nginx.key

RUN openssl req -config openssl.cnf \
    -key private/nginx.key \
    -new -sha256 \
    -subj "/CN=${NGINX_URL}/O=Rentlytics, Inc/OU=engineers/L=San Francisco/ST=California/C=US" \
    -out newcerts/nginx.csr

RUN openssl ca -config openssl.cnf \
    -extensions server_cert \
    -days 750 \
    -notext \
    -md sha256 \
    -key ${ROOT_KEY_PASS} \
    -in newcerts/nginx.csr \
    -batch \
    -out certs/nginx.pem && \
    chmod 444 certs/nginx.pem && \
    openssl x509 -noout -text -in certs/nginx.pem && \
    openssl verify -CAfile certs/ca.pem certs/nginx.pem

RUN cat certs/nginx.pem >> certs/nginx-chain.pem && \
    cat certs/ca.pem >> certs/nginx-chain.pem

RUN openssl genrsa -out private/client.key 2048 && \
    chmod 400 private/client.key

RUN openssl req -config openssl.cnf \
    -key private/client.key \
    -new -sha256 \
    -subj "/CN=client/O=Rentlytics, Inc/OU=engineers/L=San Francisco/ST=California/C=US" \
    -out newcerts/client.csr

RUN openssl ca -config openssl.cnf \
    -extensions usr_cert \
    -days 750 \
    -notext -batch \
    -md sha256 \
    -key development \
    -in newcerts/client.csr \
    -out certs/client.pem && \
    chmod 444 certs/client.pem

VOLUME ["/root/ca"]
CMD [ "/usr/bin/tail", "-f", "/dev/null" ]