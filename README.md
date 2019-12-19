NGINX with SSL Stream Support
------
This repository contains the necessary files to build and run an Nginx proxy with support
for TLS/SSL and streaming (TCP).  It pre-supposes that it will be placed in front of Redis
by naming its environment variables `REDIS_*`, although in truth there is nothing
Redis-specific built into this docker image and so it could be used as a proxy for any
kind of TCP backend service.

#### Running a container
In order to correctly run a container from this image, you will need to set environment
variables, open ports, and map volumes in the `docker run` command, as described in the
sections below.

##### Environment Variables

Name | Required | Purpose | Default
---|:---:|---|---
PROXY_PORT | no | The port on which the nginx server listens | 6379
REDIS_HOST | yes | The hostname or IP Address to which nginx should forward incoming streams | N/A
REDIS_PORT | no | The port on which the redis server listens | 6379

##### Ports
When you run the docker image, you should remember to open the PROXY_PORT port so that
other services can reach your proxy.  Assuming that PROXY_PORT was not set, the default
will be 6379 and so you would open that port with this argument to 
`docker run`: `-p "6379:6379"`

##### Volumes
The nginx server is configured to perform mutual certificate authentication on incoming
connections.  In order to provide a cert chain as well as verify presented client certs,
Nginx must have access to a number of certs and keys.  The `nginx.conf` file looks for the
following set of items in the locations described in the table below.

File Path | Expectation
---|---
/root/ca/certs/nginx-chain.pem | A chain of certificates starting with the nginx proxy's certificate and going through its issuers back to its root authority certificate.
/root/ca/private/nginx.key | The private key for the nginx proxy.
/root/ca/certs/ca.pem | The root certificate authority's certificate

Note that each of these files resides in `/root/ca`, which is a `VOLUME` defined in the
Dockerfile.  Certificates are provided to Nginx by mounting a directory that contains the
`certs` and `private` directories with their associated certs and keys.  For example, if
you have directory called `$HOME/ca`, you can mount it using the following argument in the
`docker run` command: `-v $HOME/ca:/root/ca`

#### Linking to a Redis container
If this nginx proxy should be for a redis server running in another docker container, you
will want to link your nginx container to your redis container by passing the following
argument to the `docker run` command: `--link <redis_container_name>:redis`.  If your
Redis container happens to be named `redis` then your argument can simply be: 
`--link redis`.  When you do this, the DNS name `redis` will resolve to the IP address of
the redis container and so you need to set your `REDIS_HOST` environment variable to
`redis`.

#### Example `docker run` commands

###### Nginx proxy for redis server at my.redis.com and ca folder in your current working directory
`docker run -e "REDIS_HOST=my.redis.com" -v $(pwd)/ca:/root/ca --name nginx -d -p "6379:6379" rentlytics/nginx-streaming:1.12.2`

###### Nginx proxy for redis server in docker container listening on 6379 and certs in a container named redis-ca
`docker run -e "REDIS_HOST=redis" -e "PROXY_PORT=6378" --volumes-from redis-ca --name nginx --link redis -p "6378:6378" -d rentlytics/nginx-streaming:1.12.2`

###### docker-compose
This repo also contains a docker-compose example that starts a CA container, a redis
container, and an nginx container listening on port 6378.  Start it with the standard
command: `docker-compose up`

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

#### Certificate Concerns

##### Getting the correct CN on the nginx proxy certificate
When you connect to an SSL/TLS service, the hostname or IP Address that you use must
match what's on the server's certificate.  In order to generate the correct certificate
for the nginx server, build its docker image and pass the `NGINX_URL` build argument:
`docker build --build-arg NGINX_URL=redis.staging.rentlytics.com:6379 -t rentlytics/redis-ca:latest .`
(the default is `localhost:6379`).  

##### Protecting the CA private key
Obviously, the private keys in `/root/ca/private` must be protected.  The private key to
the certificate authority is further protected with a password that you can set with a
`ROOT_KEY_PASS` build argument: `docker build --build-arg ROOT_KEY_PASS=some_very_secure_password -t rentlytics/redis-ca:latest .`
(the default is `development`).

##### Future work
It may be wiser to move all of the CA and certificate creation to a docker entrypoint so
that the CA and certificates will be built at runtime instead of at image creation time.
This is because anyone who can get a copy of the image will also be able to get the
private keys.  What I would do is keep the redis-ca docker image for docker-compose usage,
but I would update `setup-instance.sh` to run all the commands (from the redis-ca
dockerfile) to create a CA in $HOME/ca on the docker host and then mount that into the
nginx docker container - instead of creating a volume and using the redis-ca docker
container to create the CA and certificates.

### Setting up an EC2 instance to be an nginx-redis proxy
These steps apply whether you're setting up a new environment or just updating the
certificates for an existing environment. 

You will need:
1. An EC2 instance running ubuntu that has `setup-instance.sh` (from this repository) on
   it.
1. A Route 53 "A Record" that points the to the EC2 instance with the name you intend to 
   have in the `${REDIS_URL}` below.
1. The following pieces of information. You don't need to set them as environment
   variables, and it won't do you much good if you did because we're running 
   commands across multiple machines, but all the commands below will use 
   shell-style `${VARNAME}` references as if you do have these set:
  
    AWS_ECR_ID
    : The ID of your AWS ECR. Obtain by runing `aws ecr get-login` and
      look at the hostname at the end 
      (ex: `123456789012.dkr.ecr.us-east-1.amazonaws.com`)

    ENV_NAME
    : The name of the environment you're creating a server for (ex: `production`) 

    HOST_IP
    : The ip address of the EC2 instance. You can find it in your aws console under
       EC2 > Instances. 
      
    HOST_NAME
    : The DNS name for the Route 53 A Record. You can find this in your aws console
      under Route 53. (ex. `redis.production.mycompany.com`)

    REDIS_URL
    : The host and port for inbound redis connections. This should be something like 
      `${HOST_NAME}:6379` (ex. `redis.production.mycompany.com:6379`)

    REDIS_HOST
    : The primary endpoint of an AWS redis instance. This can be found in the aws console
      under Elasticache Dashboard > Redis. 
      (ex. `redis-staging.121lpg.ag.0001.use1.cache.amazonaws.com`)
      
    ROOT_KEY_PASS
    : A secure password for your certificate authority's key. Keep this secret and safe.
      
Then:
1. on your local machine, log in to your AWS ECR: 
   `$(aws ecr get-login --no-include-email)`
1. Build the redis-ca container: 
   `docker build --build-arg NGINX_URL=${REDIS_URL} --build-arg ROOT_KEY_PASS=${ROOT_KEY_PASS} -f ./redis-ca.Dockerfile -t redis-ca:${ENV_NAME} .`
1. Tag it for AWS ECR: 
   `docker tag redis-ca:${ENV_NAME} ${AWS_ECR_ID}/redis-ca:${ENV_NAME}`
1. push it to the registry: 
   `docker push ${AWS_ECR_ID}/redis-ca:${ENV_NAME}`
1. ssh into your host instance: `ssh ubuntu@${HOST_IP}`
1. if you're updating an existing nginx server, there will be name collisions with the old
   containers and images, so run the following commands first:
   1. stop running docker containers: 
      `sudo docker stop -t=0 $(docker ps -aq)`
   1. delete all docker containers:
      `sudo docker container rm $(docker container ls -aq)`
   1. delete all docker images:
      `sudo docker image rm $(docker image ls -aq)`
1. run `setup-instance.sh ${ENV_NAME} ${REDIS_HOST} ${AWS_ECR_ID}`
1. exit from the instance
1. download the client cert materials: `scp ubuntu@{HOST_IP}:./client-cert.zip .`
1. unzip the file and copy the contents of each file into the specified environment
   variables in heroku:

   filename | variable
   ---|---
   ca.pem | `REDIS_TRUST_CERT`
   client.pem | `REDIS_CLIENT_CERT`
   client.key | `REDIS_CLIENT_KEY`

