#!/bin/bash
# KanokOffice Linux build environment: a plain ubuntu:24.04 container (GCC 13; LibreOffice 26.8 needs GCC 13+
# or Clang 18+), run as root. Installs the tools and LibreOffice's build dependencies from Ubuntu's archive
# and adds the unprivileged user the build runs as (configure refuses to run as root).
# usage: 00-build-env.sh   (env: BUILD_USER, default b)
set -eu
U=${BUILD_USER:-b}
export DEBIAN_FRONTEND=noninteractive
sed -i 's/^Types: deb$/Types: deb deb-src/' /etc/apt/sources.list.d/ubuntu.sources
apt-get update -qq
apt-get install -y -qq build-essential git wget curl xz-utils ccache nasm zip unzip python3 python3-dev \
  fakeroot dpkg-dev time
apt-get build-dep -y -qq libreoffice
id "$U" >/dev/null 2>&1 || useradd -m "$U"
