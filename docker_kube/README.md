# LabNow Container Kit (Kubernetes Air-gap Installation)

This project provides one-click installation assets for deploying Kubernetes (`k3s` / `k0s`) in air-gapped (offline) environments.

All binaries, offline image bundles, and setup scripts are packaged into lightweight Docker images. Users can pull these images on a connected machine, transfer them to the offline host, and extract the assets using a volume mount to complete the installation without internet access.

## Workflow

1. **Build (Online)**: The Dockerfile downloads Kubernetes binaries, `kubectl`, `helm`, and the air-gap image bundle, packaging them into a runner image.
2. **Deploy (Offline)**: 
   - Export/pull the built image on the target host.
   - Run the container with a volume mount to copy installation assets to the host filesystem.
   - Run the provided scripts to install the cluster.

---

## Image Components

The tools and files included in each container image:

| Component Role | `k3s-ctk` Image | `k0s-ctk` Image | Description |
| :--- | :--- | :--- | :--- |
| **Kubernetes Engine** | `k3s` | `k0s` | The core Kubernetes distribution binary. |
| **Air-gap Image Bundle** | `k3s-airgap-images-*.tar.zst` | `k0s-airgap-bundle-*.tar` | System container images bundle for offline deployment. |
| **Kubernetes CLI** | `kubectl` | `kubectl` | Command-line tool for control plane operations. |
| **Package Manager** | `helm` | `helm` | Tool for managing Kubernetes pre-packaged charts. |
| **CRI Adapter** | (embedded in k3s) | `cri-dockerd` | Adapter to use Docker as the container runtime. |
| **Official Installer** | `script-get-k3s-io.sh` | (embedded in k0s) | Official installation script. |
| **Setup Helper Script** | `script-setup-k3s.sh` | `script-setup-k0s.sh` | Scripts containing functions for configuration and setup. |

---

## Air-Gap Installation

### Option A: Install K3s (with Docker Runtime)

#### 1. Extract installation assets
Run the image to copy all assets to `/opt/k3s` on the host:
```bash
docker run --rm -it -v /opt/k3s:/tmp quay.io/labnow/k3s-ctk:latest
```

#### 2. Load K3s air-gap images
Import the K3s system images into your Docker daemon:
```bash
cd /opt/k3s
zstd -cd ./k3s-airgap-images-${ARCH:-amd64}.tar.zst | docker load
sudo rm -f /opt/k3s/k3s-*.tar.zst

# (Optional) Link binaries to PATH
sudo ln -sf /opt/k3s/k* /opt/k3s/helm /usr/local/bin/
```

#### 3. Run the offline installer
```bash
INSTALL_K3S_SKIP_DOWNLOAD=true \
INSTALL_K3S_BIN_DIR=/opt/k3s \
./script-get-k3s-io.sh --docker --data-dir /data/storage/data-k3s
```

#### 4. (Optional) Manually start k3s without systemd
For environment like Github Codespace, you might want to start k3s without systemd:
```bash
sudo k3s server \
  --docker \
  --container-runtime-endpoint unix:///var/run/docker.sock
```

#### 5. Access the k3s cluster with kubectl

Copy the k3s default kube config file `/etc/rancher/k3s/k3s.yaml` for current user and use kubectl.

```bash
mkdir -pv ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config

kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl get services -A
```

---

### Option B: Install K0s

#### 1. Extract installation assets
Run the image to copy all assets to `/opt/k0s` on the host:
```bash
docker run --rm -it -v /opt/k0s:/tmp quay.io/labnow/k0s-ctk:latest
```

#### 2. Copy binaries and setup the air-gap bundle
K0s loads offline images from `/var/lib/k0s/images/` by default.
```bash
cd /opt/k0s

# Load the docker images in the air-gap bundle
sudo mkdir -p /var/lib/k0s/images/
sudo cat   ./k0s-airgap-bundle-* | docker load
sudo rm -f ./k0s-airgap-bundle-*

# (Optional) Link binaries to PATH
sudo ln -sf /opt/k0s/k* /opt/k0s/helm /usr/local/bin/
```

#### 3. Install and start K0s service
```bash
# (Optional) Setup cri-dockerd for k0s to use docker daemon instead of containerd as runtime
source ./script-setup-k0s.sh && create_cri_dockerd_unit_files

# Install as a single-node controller + worker
sudo k0s install controller --single --enable-worker

# Start the service
sudo k0s start
```

#### 4. (Optional) Manually start k0s without systemd
```bash
sudo /opt/k0s/cri-dockerd \
  --docker-endpoint=unix:///var/run/docker.sock \
  --container-runtime-endpoint=unix:///run/cri-dockerd.sock

sudo k0s controller --single --enable-worker \
  --cri-socket=remote:unix:///run/cri-dockerd.sock -v
```

#### 5. Verify installation
```bash
sudo k0s status

mkdir -pv ~/.kube
sudo k0s kubeconfig admin > ~/.kube/config
sudo chown "$(id -u):$(id -g)" ~/.kube/config
chmod 600 ~/.kube/config

kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
kubectl get services -A
```
