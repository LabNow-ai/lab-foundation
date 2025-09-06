# DockerKit

In this docker image (DockerKit), the following tools are included:

- [docker-compose](https://github.com/docker/compose): tool for running multi-container applications on Docker.

- [image-syncer](https://github.com/AliyunContainerService/image-syncer): along with some Python scripts used to sync docker images between docker registries.

## Image Syncer

With the help of [image-sync](https://github.com/AliyunContainerService/image-syncer), you can easily have your docker images copied from one registry to another, or run in batch mode.

### Sync one image

Below is an example of command for sync one image:

```shell
docker run --rm \
  -e DOCKER_REGISTRY_PASSWORD='' \
  -e DOCKER_REGISTRY_USERNAME='' \
  -e DOCKER_MIRROR_REGISTRY_USERNAME='' \
  -e DOCKER_MIRROR_REGISTRY_PASSWORD='' \
  labnow/docker-kit python /opt/utils/image-syncer/run_sync.py library/ubuntu --source-registry='quay.io' --target-registry='docker.io'  
```

Fill the environment variables above, and more details can be found in code: `./work/image-syncer/run_sync.py`.

### Sync images in batch

To sync images in batch, two config files (or combine them in one as `--config`) are needed.

The `auth.yaml` file should look like:

```yaml
docker.io:
  username: ""
  password: ""
  insecure: true
registry.cn-hangzhou.aliyuncs.com:
  username: ""
  password: ""
  insecure: true
```

The `images.yaml` file should look like:

```yaml
quay.io/labnow/docker-kit:
  - docker.io/labnow/docker-kit
  - registry.cn-hangzhou.aliyuncs.com/labnow/docker-kit
```
