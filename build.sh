#!/bin/sh
set -eu
cd "$(dirname "$0")"

nasm -f bin boot.asm -o boot.bin
nasm -f bin stage2.asm -o stage2.bin

boot_size=$(wc -c < boot.bin | tr -d ' ')
stage2_size=$(wc -c < stage2.bin | tr -d ' ')

if [ "$boot_size" -ne 512 ]; then
  echo "Erro: boot.bin deve ter 512 bytes (tem $boot_size)" >&2
  exit 1
fi
if [ "$stage2_size" -gt 8704 ]; then
  echo "Erro: stage2.bin excede 17 setores (tem $stage2_size bytes)" >&2
  exit 1
fi

dd if=/dev/zero of=zenboot-v02.img bs=1024 count=1440 >/dev/null 2>&1
dd if=boot.bin of=zenboot-v02.img conv=notrunc >/dev/null 2>&1
dd if=stage2.bin of=zenboot-v02.img bs=512 seek=1 conv=notrunc >/dev/null 2>&1

echo "Imagem criada: zenboot-v02.img"
echo "Stage1: $boot_size bytes; Stage2: $stage2_size bytes"
echo 'Para executar no Mac: qemu-system-i386 -drive file=zenboot-v02.img,format=raw,if=floppy -display cocoa,zoom-to-fit=on'
