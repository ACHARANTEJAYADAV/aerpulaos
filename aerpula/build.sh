#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out
docker run --rm --privileged \
  -e HOST_UID="$(id -u)" -e HOST_GID="$(id -g)" \
  -v "$PWD":/work alpine:latest sh /work/profile/inside-build.sh
ls -lh out/
