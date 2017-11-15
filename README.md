NGINX with SSL Stream Support
------
This repository contains the necessary files to build and run an Nginx proxy with support for TLS/SSL and streaming (TCP).  It pre-supposes that it will be placed in front of Redis by naming its environment variables `REDIS_*`, although in truth there is nothing Redis-specific built into this docker image and so it could be used as a proxy for any kind of TCP backend service.
#### Running a container
In order to correctly run a container from this image, you will need to set environment variables, open ports, and map volumes in the `docker run` command, as described in the sections below.
##### Environment Variables

Name | Required | Purpose | Default
---|:---:|---|---
PROXY_PORT | no | The port on which the nginx server listens | 6379
REDIS_HOST | yes | The hostname or IP Address to which nginx should forward incoming streams | N/A
REDIS_PORT | no | The port on which the redis server listens | 6379

##### Ports
When you run the docker image, you should remember to open the PROXY_PORT port so that other services can reach your proxy.  Assuming that PROXY_PORT was not set, the default will be 6379 and so you would open that port with this argument to `docker run`: `-p "6379:6379"`
##### Volumes
The nginx server is configured to perform mutual certificate authentication on incoming connections.  In order to provide a cert chain as well as verify presented client certs, Nginx must have access to a number of certs and keys.  The `nginx.conf` file looks for the following set of items in the locations described in the table below.

File Path | Expectation
---|---
/root/ca/certs/nginx-chain.pem | A chain of certificates starting with the nginx proxy's certificate and going through its issuers back to its root authority certificate.
/root/ca/private/nginx.key | The private key for the nginx proxy.
/root/ca/certs/ca.pem | The root certificate authority's certificate

Note that each of these files resides in `/root/ca`, which is a `VOLUME` defined in the Dockerfile.  Certificates are provided to Nginx by mounting a directory that contains the `certs` and `private` directories with their associated certs and keys.  For example, if you have directory called `$HOME/ca`, you can mount it using the following argument in the `docker run` command: `-v $HOME/ca:/root/ca`

#### Linking to a Redis container
If this nginx proxy should be for a redis server running in another docker container, you will want to link your nginx container to your redis container by passing the following argument to the `docker run` command: `--link <redis_container_name>:redis`.  If your Redis container happens to be named `redis` then your argument can simply be: `--link redis`.  When you do this, the DNS name `redis` will resolve to the IP address of the redis container and so you need to set your `REDIS_HOST` environment variable to `redis`.
#### Example `docker run` commands
###### Nginx proxy for redis server at my.redis.com and ca folder in your current working directory
`docker run -e "REDIS_HOST=my.redis.com" -v $(pwd)/ca:/root/ca --name nginx -d -p "6379:6379" rentlytics/nginx-streaming:1.12.2`
###### Nginx proxy for redis server in docker container listening on 6379 and certs in a container named redis-ca
`docker run -e "REDIS_HOST=redis" -e "PROXY_PORT=6378" --volumes-from redis-ca --name nginx --link redis -p "6378:6378" -d rentlytics/nginx-streaming:1.12.2`
###### docker-compose
This repo also contains a docker-compose example that starts a CA container, a redis container, and an nginx container listening on port 6378.  Start it with the standard command: `docker-compose up`

#### Testing the connection
If you are running via `docker-compose`, it's possible to test the secure connection to redis because the `redis-ca` generates client certificates too.  Copy them to your local host machine with `docker cp nginxredis_redis-ca_1:/root/ca/certs/client.pem .` and `docker cp nginxredis_redis-ca_1:/root/ca/certs/ca.pem .` and `docker cp nginxredis_redis-ca_1:/root/ca/private/client.key .`.  Then you can use the certs and openssl to create a secure client: `openssl s_client -connect localhost:6379 -cert client.pem -key client.key -CAfile ca.pem`.  Once the secure channel is open, you can interact with your redis server.  Try a few commands:
```
set foo 100
incr foo
append foo xxx
get foo
get /
del foo
get /
quit
```