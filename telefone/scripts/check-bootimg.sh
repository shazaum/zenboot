#!/bin/sh
# Confere a estrutura do boot.img. Nao inicia QEMU, fastboot, ADB nem disco fisico.
set -eu
root=$(cd "$(dirname "$0")/../.." && pwd)
work=$(mktemp -d "$root/.tmp-telefone.XXXXXX")
trap 'rm -rf "$work"' EXIT

printf 'fixture-kernel' > "$work/kernel.bin"
printf 'SIGTEST' > "$work/sig.bin"
out="$work/boot.img"

sh "$root/telefone/pack-bootimg.sh" \
  --kernel "$work/kernel.bin" \
  --initramfs-dir "$root/telefone/initramfs" \
  --cmdline "zenboot.init=/init" \
  --signature "$work/sig.bin" \
  --output "$out"

python3 "$root/telefone/pack_bootimg.py" --check "$out"

python3 - "$out" << 'PY'
import pathlib, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
if not data.startswith(b"ANDROID!"):
    raise SystemExit("magic ausente")
if not data.endswith(b"SIGTEST"):
    raise SystemExit("assinatura opcional nao ficou no final")
print("PASS: magic ANDROID! e assinatura no final")
PY

set +e
sh "$root/telefone/pack-bootimg.sh" \
  --kernel "$work/kernel.bin" \
  --initramfs-dir "$root/telefone/initramfs" \
  --output /dev/null
status=$?
set -e
if [ "$status" -eq 0 ]; then
    echo "FAIL: o empacotador aceitou /dev/null" >&2
    exit 1
fi

echo "PASS: boot.img estrutural, init presente, escrita em /dev recusada"
