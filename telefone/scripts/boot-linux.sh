#!/bin/sh
# Monta o boot.img com kernel e BusyBox e abre o shell no QEMU.
# Nao grava em disco, particao ou aparelho.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
cache="$root/.cache/telefone"
kernel_url="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86/netboot-3.24.4/vmlinuz-lts"
kernel_sha="f444697de43f55c32c2779172e02b015e1029ee5c6387a3ea0f2279bccf0d34c"
busybox_url="https://dl-cdn.alpinelinux.org/alpine/v3.24/main/x86/busybox-static-1.37.0-r31.apk"
busybox_sha="26d45cc895b3fa99ba7500d0860c3934a363e74e464eeb5fc623f08147c33cfd"

fetch() {
    url=$1
    dest=$2
    expect=$3
    if [ -f "$dest" ]; then
        got=$(shasum -a 256 "$dest" | awk '{print $1}')
        if [ "$got" = "$expect" ]; then
            return
        fi
        rm -f "$dest"
    fi
    curl -fL --retry 2 --max-time 180 -o "$dest.partial" "$url"
    mv "$dest.partial" "$dest"
    got=$(shasum -a 256 "$dest" | awk '{print $1}')
    if [ "$got" != "$expect" ]; then
        echo "hash inesperado em $dest" >&2
        exit 1
    fi
}

mkdir -p "$cache"
fetch "$kernel_url" "$cache/vmlinuz-lts" "$kernel_sha"
fetch "$busybox_url" "$cache/busybox-static.apk" "$busybox_sha"

rm -rf "$cache/apk" "$cache/initramfs" "$cache/unpacked"
mkdir -p "$cache/apk" "$cache/initramfs/bin" "$cache/unpacked"
tar -xzf "$cache/busybox-static.apk" -C "$cache/apk"
if [ ! -f "$cache/apk/bin/busybox.static" ]; then
    echo "o pacote nao trouxe bin/busybox.static" >&2
    exit 1
fi
cp "$cache/apk/bin/busybox.static" "$cache/initramfs/bin/busybox"
chmod 755 "$cache/initramfs/bin/busybox"
cp "$root/telefone/initramfs/init" "$cache/initramfs/init"
chmod 755 "$cache/initramfs/init"

sh "$root/telefone/pack-bootimg.sh" \
    --kernel "$cache/vmlinuz-lts" \
    --initramfs-dir "$cache/initramfs" \
    --cmdline "console=ttyS0 rdinit=/init" \
    --output "$cache/boot.img"
python3 "$root/telefone/pack_bootimg.py" --check "$cache/boot.img"
python3 "$root/telefone/pack_bootimg.py" --unpack "$cache/boot.img" --unpack-dir "$cache/unpacked"

kernel_got=$(shasum -a 256 "$cache/unpacked/kernel" | awk '{print $1}')
if [ "$kernel_got" != "$kernel_sha" ]; then
    echo "o kernel extraido do boot.img nao confere" >&2
    exit 1
fi

python3 "$root/telefone/scripts/qemu_shell.py" \
    "$cache/unpacked/kernel" \
    "$cache/unpacked/ramdisk.cpio.gz"
