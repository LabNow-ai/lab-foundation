# Lab Foundation — LabNow Container Image Stack

[![License](https://img.shields.io/badge/License-BSD%203--Clause-green.svg)](https://opensource.org/licenses/BSD-3-Clause)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/LabNow-ai/lab-foundation/build-docker.yml?branch=main)](https://github.com/LabNow-ai/lab-foundation/actions/workflows/build-docker.yml)
[![Recent Code Update](https://img.shields.io/github/last-commit/LabNow-ai/lab-foundation.svg)](https://github.com/LabNow-ai/lab-foundation/commits)
[![Visit Images on Quay.io](https://img.shields.io/badge/Quay.io-Images-green)](https://quay.io/organization/labnow)
[![Visit Images on DockerHub](https://img.shields.io/badge/DockerHub-Images-green)](https://hub.docker.com/u/LabNow)

If Lab Foundation is useful to you, please consider giving the project a star:
[![GitHub Stars](https://img.shields.io/github/stars/LabNow-ai/lab-foundation.svg?label=Stars)](https://github.com/LabNow-ai/lab-foundation/stargazers)

**Documentation & community**

- [Docs & tutorials](https://doc.labnow.ai)
| [使用指引](https://labnow-ai.feishu.cn/wiki/wikcn0sBhMtb1KNRSUTettxWstc)
| [Ask DeepWiki](https://deepwiki.com/LabNow-ai/lab-foundation)

- [Discord community](https://discord.gg/kHUzgQxgbJ)
| [Open an issue](https://github.com/LabNow-ai/lab-foundation/issues)
| [Contribute on GitHub](https://github.com/LabNow-ai/lab-foundation)



---

## Reusable container environments for Agent Runtime, Sandbox, and Environment as a Service (EaaS)

Lab Foundation is the container image foundation behind [LabNow](https://LabNow.ai). It packages operating-system dependencies, language runtimes, and workload tools into reusable images that platforms can launch as agent execution environments or offer as on-demand environments.

Use these images as building blocks: select a lightweight runtime, compose a purpose-built toolchain, and provide it to an agent or user when needed. This makes it easier to standardize environment templates and avoid rebuilding the same dependencies for every session.

## Built for agent environments

- **Runtime building blocks** — start from a base image with common system utilities and a Python runtime, or use a richer image with more tools preinstalled.
- **Repeatable environment templates** — build images from shared layers and package profiles so agent sessions can start from consistent environments.
- **Fit the workload** — choose focused language and toolchain images, broader stacks, GPU variants, or PostgreSQL images with additional extensions.
- **EaaS-ready substrate** — use the published images as templates for an environment service that provisions environments on demand.

> **Scope:** This repository builds and publishes container images. Agent orchestration, per-session lifecycle, authentication, and sandbox security policies (such as filesystem, network, and resource limits) are responsibilities of the runtime or platform that launches these images.

## Image catalog

The following image names are built by this repository's workflows. On the `main` branch, the default image namespace is `quay.io/labnow`; images are also published or mirrored through the registries linked above.

Image availability and tags may vary by registry. Browse the current images on [Quay.io](https://quay.io/organization/labnow) or [DockerHub](https://hub.docker.com/u/LabNow).

| Environment building block | Images | Intended role |
| --- | --- | --- |
| Foundation and language runtimes | `atom`, `base`, `python-3.7`, `python-3.13`, `python-3.14`, `r-base`, `r-std`, `node`, `bun`, `jdk`, `go`, `rust`, `julia` | Minimal starting points for a custom agent runtime or environment template |
| Focused execution environments | `py-data`, `py-std`, `py-chem`, `py-jdk` | Ready-made Python environments with different tool and dependency profiles |
| Broad toolchain environments | `core`, `data-science-stack`, `full-stack` | Multi-language environments for agents or users that need a wider set of installed tools |
| Accelerated execution environments | `torch`, `tf2`, `paddle-3.0`, `py-nlp`, `py-cv`, `core-cuda` | GPU/framework-oriented variants (see the [GPU workflow](.github/workflows/build-docker-gpu.yml)) |
| Database images | `postgres-16`, `postgres-17`, `postgres-18`, `*-ext` | PostgreSQL base images and variants with additional extensions |
| Container and Kubernetes utilities | `docker-kit`, `k3s-ctk`, `k0s-ctk` | Docker/image-sync utilities and asset bundles for installing k3s or k0s in air-gapped environments |

The `k3s-ctk` and `k0s-ctk` images package the distribution binaries, offline image bundles, Kubernetes tools, and setup scripts. Run an image with a mounted destination to export these assets to a host; the image does not itself run a Kubernetes cluster. See [`docker_kube/README.md`](docker_kube/README.md) for the offline installation steps.

## Quick start

Start a container from the base runtime image and mount a workspace into it:

```bash
docker run --rm -it \
  -v "$PWD":/workspace \
  -w /workspace \
  quay.io/labnow/base:latest \
  bash
```

An agent runtime or environment service can use the same pattern to launch a selected image with its own workspace, resource limits, and lifecycle policy. Replace `base` with another image from the catalog to provide a different toolchain. For GPU images, configure the NVIDIA Container Toolkit on the host and pass `--gpus all`:

```bash
docker run --rm -it --gpus all quay.io/labnow/torch:latest bash
```

## Repository layout and builds

Image definitions are grouped by their purpose:

| Directory | Contents |
| --- | --- |
| `docker_atom/` | OS-level foundation and shared system setup |
| `docker_base/` | Base runtime images, including the configurable Python runtime |
| `docker_core/` | Profile-driven language and workload environments |
| `docker_cuda/` | NVIDIA CUDA base and container toolkit images |
| `docker_db_postgres/` | PostgreSQL images with optional extensions |
| `docker_docker_kit/` | Docker utility and image synchronization tooling |
| `docker_kube/` | k3s/k0s air-gap installation asset images and setup scripts |

The GitHub Actions workflows in `.github/workflows/` build and publish these groups: [`build-docker.yml`](.github/workflows/build-docker.yml) covers the standard runtime and workload images, while [`build-docker-gpu.yml`](.github/workflows/build-docker-gpu.yml), [`build-docker-db.yml`](.github/workflows/build-docker-db.yml), and [`build-docker-kube.yml`](.github/workflows/build-docker-kube.yml) cover GPU, PostgreSQL, and Kubernetes/container utility images respectively. The Kubernetes workflow builds `k3s-ctk` and `k0s-ctk` with a configurable Kubernetes version and synchronizes its published images.

To build a custom Python environment with database packages on top of the published `base` image:

```bash
docker build \
  -f docker_core/core.Dockerfile \
  --build-arg BASE_NAMESPACE=quay.io/labnow \
  --build-arg ARG_PROFILE_PYTHON=base,database \
  -t lab-foundation:custom \
  docker_core/
```

Available profiles and package lists are defined in `docker_core/work/`. See each module's Dockerfiles and README for module-specific details.
