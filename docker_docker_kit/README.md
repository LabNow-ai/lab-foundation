# DockerKit

In this docker image (DockerKit), the following tools are included:

- [docker-compose](https://github.com/docker/compose): tool for running multi-container applications on Docker.

- [image-syncer](https://github.com/AliyunContainerService/image-syncer): used to sync docker images between docker registries.

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
  labnow/docker-kit sh /opt/utils/script-sync-image.sh library/ubuntu --source-registry='quay.io' --target-registry='docker.io'
```

Fill the environment variables above, and more details can be found in `./work/script-sync-image.sh`.
For workflow-based syncs, `IMG_NAMESPACE_SRC` selects the source namespace and `IMG_NAMESPACE_DST` optionally selects a different destination namespace; when omitted, the destination namespace matches the source.

For different destination namespaces per registry, set `DOCKER_MIRROR_TARGETS` to comma-separated `registry=namespace-template` entries:

```shell
DOCKER_MIRROR_TARGETS='docker.io=%s,registry.cn-hangzhou.aliyuncs.com=%s-oss'
```

The single `%s` placeholder is replaced with `IMG_NAMESPACE`. In GitHub Actions, the main branch uses the repository owner namespace (for example, `labnow`), while all non-main branches use the fixed `0dev` suffix (for example, `labnow0dev`). The workflow syncs `quay.io/<namespace>/<image>` to each configured target namespace. `DOCKER_MIRROR_TARGETS` takes precedence over the legacy `DOCKER_MIRROR_REGISTRY`; without it, legacy behavior is unchanged. Each destination registry must have matching credentials in the auth file.

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
