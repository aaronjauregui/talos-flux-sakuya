#!/usr/bin/env bash
# Render Talos machine configs from secrets + patches. Outputs are gitignored.
set -euo pipefail
cd "$(dirname "$0")"
talosctl gen config sakuya https://sakuya.kinoko.house:6443 \
  --with-secrets secrets.yaml \
  --additional-sans sakuya.kinoko.house,192.168.1.26 \
  --config-patch @patches/install.yaml \
  --config-patch @patches/hostname.yaml \
  --config-patch @patches/storage.yaml \
  --config-patch-control-plane @patches/single-node.yaml \
  --with-docs=false --with-examples=false --force -o .
talosctl validate --mode metal --strict -c controlplane.yaml
