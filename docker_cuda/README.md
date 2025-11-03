# Install `nvidia-container-toolkit` (nvidia-ctk) offline

[![Docker Pulls](https://img.shields.io/docker/pulls/labnow/nvidia-ctk.svg)](https://hub.docker.com/r/labnow/nvidia-ctk)
[![Docker Starts](https://img.shields.io/docker/stars/labnow/nvidia-ctk.svg)](https://hub.docker.com/r/labnow/nvidia-ctk)

This document and docker image helps you to install `nvidia-ctk` (NVIDIA Container Toolkit) offline, which is especially usefull when your machine is in a restricted / air-gapped network.

## Step 1. Install container engine

Ensure you have installed your container engine (e.g. docker-ce) properly.

## Step 2. Install NVIDIA driver

You can skip this step if you have already installed NVIDIA driver,
otherwise please install the driver for your device and machine fistly following the guidence below or refert to [NVIDIA documentation](https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html) for detailed instructions.

Before you install the driver, please change the following configurations and restart your machine.

```bash
sudo tee /etc/modprobe.d/blacklist-nouveau.conf <<< \
"blacklist nouveau
options nouveau modeset=0
"

sudo update-initramfs -u && sudo reboot
```

After the proper configuration above, download the proper installation (`.run`) file from [NVIDIA driver download page](https://www.nvidia.com/Download/index.aspx) and install NVIDIA driver (run file) for your hardware.
Download the `.run` file, and `chmod +x *.run` to make it executbale, and then run the file `./NVIDIA-*.run`.

After that, you should be able to inspect your device status by using `nvidia-smi` command.

## Step 3. Install the `nvidia-ctk` Component

Originally, the component requires Internet connection or a mirror for the package manger, as specified in [nvidia-ctk documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html).

This docker image helps you to get the installation package into a container image and you can export the files to your local file system.

Please follow the instructions below to export install packages to your local file system and install them using your OS package manager (below is an example for Ubuntu).

```bash
# a folder to store tmp files -- do not change it as it will be used in the file: /etc/apt/sources.list.d/nvidia-container-toolkit.list
LOCAL_REPO="/tmp/nvidia.github.io"
mkdir -pv ${LOCAL_REPO} && cd ${LOCAL_REPO} && docker run --rm -it -v $(pwd):/tmp labnow/nvidia-ctk

cat $LOCAL_REPO/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

# for ubuntu, get the raw apt source list file and replace the URLs with file system based files
cat $LOCAL_REPO/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] file:///tmp/#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update && sudo apt-get install nvidia-container-toolkit
```

After the installation, configure NVIDIA Container Toolkit with command `sudo nvidia-ctk runtime configure --runtime=docker` or refer to the [documentation](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#configuration).
