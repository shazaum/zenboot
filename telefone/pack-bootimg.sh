#!/bin/sh
# Empacota um boot.img Android. Nao grava em disco, particao ou aparelho.
set -eu
cd "$(dirname "$0")/.."
exec python3 z00a/pack_bootimg.py "$@"
