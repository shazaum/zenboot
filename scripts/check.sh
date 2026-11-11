#!/bin/sh
# Testes de integridade do layout da imagem QEMU/BIOS - não executa VM nem toca discos físicos.
set -eu
cd "$(dirname "$0")/.."

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
size() { wc -c < "$1" | tr -d '[:space:]'; }

[ -f boot.bin ] || fail 'boot.bin ausente; execute ./build.sh'
[ -f stage2.bin ] || fail 'stage2.bin ausente; execute ./build.sh'
[ -f zenboot-v02.img ] || fail 'zenboot-v02.img ausente; execute ./build.sh'

[ "$(size boot.bin)" -eq 512 ] || fail 'stage 1 não tem 512 bytes'
[ "$(size stage2.bin)" -le 8704 ] || fail 'stage 2 excede 17 setores'
[ "$(size stage2.bin)" -gt 0 ] || fail 'stage 2 vazio'
[ "$(size zenboot-v02.img)" -eq 1474560 ] || fail 'imagem não tem 1,44 MiB'

signature=$(od -An -tx1 -j 510 -N 2 boot.bin | tr -d '[:space:]')
[ "$signature" = 55aa ] || fail "assinatura BIOS inválida: $signature"

dd if=zenboot-v02.img bs=512 count=1 2>/dev/null | cmp - boot.bin >/dev/null || fail 'LBA 0 difere de boot.bin'
stage2_size=$(size stage2.bin)
dd if=zenboot-v02.img bs=1 skip=512 count="$stage2_size" 2>/dev/null | cmp - stage2.bin >/dev/null || fail 'stage 2 difere da imagem a partir de LBA 1'

printf 'PASS: stage 1 512 bytes, assinatura 55aa, stage 2 %s bytes, imagem 1474560 bytes, conteúdo consistente.\n' "$stage2_size"
printf 'NOTA: teste estático; boot interativo no QEMU deve ser validado separadamente.\n'
