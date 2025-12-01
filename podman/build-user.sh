#!/usr/bin/env bash
set -euo pipefail

USERNAME="$(whoami)"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
TAG="localhost/nvim-podman:${USERNAME}"

echo "Building for user: ${USERNAME} (UID=${HOST_UID}, GID=${HOST_GID})"
echo "Tagging as: ${TAG}"

podman build \
  --build-arg USER_NAME="${USERNAME}" \
  --build-arg USER_ID="${HOST_UID}" \
  --build-arg USER_GID="${HOST_GID}" \
  -t "${TAG}" \
  -f Dockerfile.user .

echo "Built ${TAG} for ${USERNAME}!"
