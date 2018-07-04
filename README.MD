# docker-ubuntu-arm
A docker container for building an ubuntu-arm image

## Building the Docker Image
Build the docker image by executing
`docker build -t docker-ubuntu-arm .`

## Bring up docker image shell
`docker run -u appuser -it --privileged docker-ubuntu-arm /bin/bash`
