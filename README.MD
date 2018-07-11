# docker-ubuntu-arm
A docker container for building an ubuntu-arm image

## Building the Docker Image
Build the docker image by executing
`docker build -t docker-ubuntu-arm .`

## Tagging the resulting docker image
Tag the docker image by executing
`docker tag docker-ubuntu-arm pseudodesign/docker-ubuntu-arm:xenial-rel-0.0.6`

## Push the resulting docker image
Push the docker image by executing
`docker push pseudodesign/docker-ubuntu-arm:xenial-rel-0.0.6`

## Bring up docker image shell
`docker run -u appuser -it --privileged docker-ubuntu-arm /bin/bash`
