#!/bin/bash
set -euo pipefail

USERNAME=$(whoami)
UID=$(id -u)
GID=$(id -g)
TAG="localhost/nvim-podman:$(whoami)"

echo "Building for user: $USERNAME (UID=$UID, GID=$GID)"
echo "Tagging as: $TAG"

podman build \
  --build-arg USERNAME="$USERNAME" \
  --build-arg USER_ID="$UID" \
  --build-arg GROUP_ID="$GID" \
  -t "$TAG" \
  -f Dockerfile.user .

echo "Built $TAG for $USERNAME!"
