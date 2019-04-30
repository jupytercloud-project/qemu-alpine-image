# qemu-alpine-image

## Build

### CI with the Docker build-container (no qemu acceleration)

```bash
# cd /tmp
# DKR=https://github.com/jupytercloud-project/build-container/releases/download/0.0.1/jupytercloud-project_build-container_latest.dkr
# curl --location ${DKR} | docker load
# git clone https://github.com/jupytercloud-project/qemu-alpine-image.git
# docker run --name build_container --detach --interactive --rm --volume /tmp/qemu-image-alpine:/src jupytercloud-project/build-container:latest /bin/bash
# docker exec build_container /bin/bash /src/tools/hashicorp/packer/images/qemu-alpine-image/build.bash
# docker stop $(docker ps -aqf "name=build_container")
```
### DEV (qemu acceleration: kvm, hvf)

```bash
# cd /tmp
# git clone https://github.com/jupytercloud-project/qemu-alpine-image.git
# cd qemu-alpine-image
# docker-compose up
```
