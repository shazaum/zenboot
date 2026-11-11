#!/usr/bin/env python3
"""Empacota e confere um boot.img Android legado.

O cabecalho segue o formato usado pelo mkbootimg da epoca do Android 5/6.
Os enderecos padrao sao os do AOSP, nao os medidos num boot.img do Z00A.
"""

import argparse
import gzip
import hashlib
import os
import stat
import struct
import sys

BOOT_MAGIC = b"ANDROID!"
HEADER_SIZE = 1632
PAGE_CHOICES = (2048, 4096, 8192, 16384)


def refuse_output(path):
    real = os.path.realpath(path)
    if real == "/dev" or real.startswith("/dev/"):
        raise SystemExit("recusa: nao escrevo em dispositivo")
    if os.path.lexists(path):
        mode = os.lstat(path).st_mode
        if stat.S_ISBLK(mode) or stat.S_ISCHR(mode):
            raise SystemExit("recusa: destino e um dispositivo")


def pad(data, align):
    extra = (-len(data)) % align
    if extra:
        return data + (b"\0" * extra)
    return data


def cpio_newc_entry(name, data, mode):
    name_b = name.encode("ascii") + b"\0"
    header = (
        "070701"
        f"{0:08X}{mode:08X}{0:08X}{0:08X}{1:08X}{0:08X}"
        f"{len(data):08X}{0:08X}{0:08X}{0:08X}{0:08X}"
        f"{len(name_b):08X}{0:08X}"
    ).encode("ascii")
    if len(header) != 110:
        raise RuntimeError("cabecalho cpio com tamanho inesperado")
    blob = pad(header + name_b, 4)
    blob += pad(data, 4)
    return blob


def directory_to_ramdisk(root):
    entries = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        filenames.sort()
        rel = os.path.relpath(dirpath, root)
        if rel != ".":
            entries.append((rel.replace(os.sep, "/"), b"", 0o040755))
        for filename in filenames:
            full = os.path.join(dirpath, filename)
            rel_file = filename if rel == "." else rel.replace(os.sep, "/") + "/" + filename
            with open(full, "rb") as handle:
                payload = handle.read()
            mode = 0o100755 if filename == "init" or os.access(full, os.X_OK) else 0o100644
            entries.append((rel_file, payload, mode))
    if not any(name == "init" for name, _, _ in entries):
        raise SystemExit("initramfs sem arquivo init")
    archive = b"".join(cpio_newc_entry(name, data, mode) for name, data, mode in entries)
    archive += cpio_newc_entry("TRAILER!!!", b"", 0)
    return gzip.compress(archive, mtime=0)


def content_id(kernel, ramdisk, second):
    digest = hashlib.sha1()
    for blob in (kernel, ramdisk, second):
        digest.update(blob)
        digest.update(struct.pack("<I", len(blob)))
    return digest.digest() + (b"\0" * 12)


def build_image(kernel, ramdisk, second, cmdline, pagesize, base, offsets, name, signature):
    kernel_addr = base + offsets["kernel"]
    ramdisk_addr = base + offsets["ramdisk"]
    second_addr = base + offsets["second"]
    tags_addr = base + offsets["tags"]
    ident = content_id(kernel, ramdisk, second)
    header = struct.pack(
        "<8s10I16s512s32s1024s",
        BOOT_MAGIC,
        len(kernel),
        kernel_addr,
        len(ramdisk),
        ramdisk_addr,
        len(second),
        second_addr,
        tags_addr,
        pagesize,
        0,
        0,
        name.encode("ascii")[:16].ljust(16, b"\0"),
        cmdline.encode("ascii")[:511].ljust(512, b"\0"),
        ident,
        b"\0" * 1024,
    )
    if len(header) != HEADER_SIZE:
        raise RuntimeError("cabecalho Android com tamanho inesperado")
    image = pad(header, pagesize)
    image += pad(kernel, pagesize)
    image += pad(ramdisk, pagesize)
    if second:
        image += pad(second, pagesize)
    image += signature
    return image


def cpio_names(payload):
    offset = 0
    names = []
    while offset + 110 <= len(payload):
        if payload[offset:offset + 6] != b"070701":
            break
        def field(index):
            start = offset + 6 + (index * 8)
            return int(payload[start:start + 8], 16)
        namesize = field(11)
        filesize = field(6)
        name_at = offset + 110
        name = payload[name_at:name_at + namesize].split(b"\0", 1)[0].decode("ascii", "replace")
        names.append(name)
        cursor = (name_at + namesize + 3) & ~3
        cursor = (cursor + filesize + 3) & ~3
        offset = cursor
        if name == "TRAILER!!!":
            break
    return names


def unpack_image(path, dest):
    with open(path, "rb") as handle:
        blob = handle.read()
    if len(blob) < HEADER_SIZE or blob[:8] != BOOT_MAGIC:
        raise SystemExit("imagem sem magic ANDROID!")
    fields = struct.unpack("<8s10I", blob[:8 + 40])
    kernel_size = fields[1]
    ramdisk_size = fields[3]
    pagesize = fields[8]
    if pagesize not in PAGE_CHOICES:
        raise SystemExit("page size invalido na imagem")
    kernel_at = pagesize
    ramdisk_at = pagesize + pad_len(kernel_size, pagesize)
    kernel = blob[kernel_at:kernel_at + kernel_size]
    ramdisk = blob[ramdisk_at:ramdisk_at + ramdisk_size]
    if len(kernel) != kernel_size or len(ramdisk) != ramdisk_size:
        raise SystemExit("imagem truncada")
    os.makedirs(dest, exist_ok=True)
    kernel_path = os.path.join(dest, "kernel")
    ramdisk_path = os.path.join(dest, "ramdisk.cpio.gz")
    refuse_output(kernel_path)
    refuse_output(ramdisk_path)
    with open(kernel_path, "wb") as handle:
        handle.write(kernel)
    with open(ramdisk_path, "wb") as handle:
        handle.write(ramdisk)
    print(f"kernel: {len(kernel)} bytes em {kernel_path}")
    print(f"ramdisk: {len(ramdisk)} bytes em {ramdisk_path}")


def inspect_image(path):
    with open(path, "rb") as handle:
        header = handle.read(HEADER_SIZE)
    if len(header) < HEADER_SIZE or header[:8] != BOOT_MAGIC:
        raise SystemExit("imagem sem magic ANDROID!")
    fields = struct.unpack("<8s10I", header[:8 + 40])
    kernel_size = fields[1]
    ramdisk_size = fields[3]
    second_size = fields[5]
    pagesize = fields[8]
    if pagesize not in PAGE_CHOICES:
        raise SystemExit("page size invalido na imagem")
    with open(path, "rb") as handle:
        blob = handle.read()
    ramdisk_at = pagesize + pad_len(kernel_size, pagesize)
    ramdisk = blob[ramdisk_at:ramdisk_at + ramdisk_size]
    try:
        archive = gzip.decompress(ramdisk)
    except OSError as exc:
        raise SystemExit(f"ramdisk nao e gzip: {exc}") from exc
    names = cpio_names(archive)
    if "init" not in names:
        raise SystemExit("ramdisk sem /init")
    print(
        f"PASS: ANDROID!, page {pagesize}, kernel {kernel_size} bytes, "
        f"ramdisk {ramdisk_size} bytes, second {second_size} bytes, init presente"
    )


def pad_len(size, pagesize):
    return (size + pagesize - 1) & ~(pagesize - 1)


def read_file(path):
    with open(path, "rb") as handle:
        return handle.read()


def parse_args(argv):
    parser = argparse.ArgumentParser(description="Empacota um boot.img Android legado")
    parser.add_argument("--check", metavar="BOOTIMG", help="confere uma imagem ja gerada")
    parser.add_argument("--unpack", metavar="BOOTIMG", help="extrai kernel e ramdisk da imagem")
    parser.add_argument("--unpack-dir", help="diretorio de saida do --unpack")
    parser.add_argument("--kernel", help="bzImage ou arquivo usado como kernel")
    parser.add_argument("--ramdisk", help="ramdisk cpio.gz pronto")
    parser.add_argument("--initramfs-dir", help="diretorio com init e demais arquivos")
    parser.add_argument("--second", help="segundo estagio opcional")
    parser.add_argument("--signature", help="bytes acrescentados ao final, sem entrar no cabecalho")
    parser.add_argument("--cmdline", default="", help="linha de comando do kernel")
    parser.add_argument("--pagesize", type=lambda value: int(value, 0), default=2048)
    parser.add_argument("--base", type=lambda value: int(value, 0), default=0x10000000)
    parser.add_argument("--kernel-offset", type=lambda value: int(value, 0), default=0x00008000)
    parser.add_argument("--ramdisk-offset", type=lambda value: int(value, 0), default=0x01000000)
    parser.add_argument("--second-offset", type=lambda value: int(value, 0), default=0x00F00000)
    parser.add_argument("--tags-offset", type=lambda value: int(value, 0), default=0x00000100)
    parser.add_argument("--name", default="zenboot")
    parser.add_argument("--output", help="caminho do boot.img")
    return parser.parse_args(argv)


def main(argv):
    args = parse_args(argv)
    if args.unpack:
        if not args.unpack_dir:
            raise SystemExit("informe --unpack-dir")
        unpack_image(args.unpack, args.unpack_dir)
        return 0
    if args.check:
        inspect_image(args.check)
        return 0
    if not args.kernel or not args.output:
        raise SystemExit("informe --kernel e --output")
    if bool(args.ramdisk) == bool(args.initramfs_dir):
        raise SystemExit("informe somente um entre --ramdisk e --initramfs-dir")
    if args.pagesize not in PAGE_CHOICES:
        raise SystemExit("page size deve ser 2048, 4096, 8192 ou 16384")
    refuse_output(args.output)
    kernel = read_file(args.kernel)
    ramdisk = read_file(args.ramdisk) if args.ramdisk else directory_to_ramdisk(args.initramfs_dir)
    second = read_file(args.second) if args.second else b""
    signature = read_file(args.signature) if args.signature else b""
    image = build_image(
        kernel,
        ramdisk,
        second,
        args.cmdline,
        args.pagesize,
        args.base,
        {
            "kernel": args.kernel_offset,
            "ramdisk": args.ramdisk_offset,
            "second": args.second_offset,
            "tags": args.tags_offset,
        },
        args.name,
        signature,
    )
    parent = os.path.dirname(os.path.abspath(args.output))
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(args.output, "wb") as handle:
        handle.write(image)
    print(f"boot.img: {len(image)} bytes em {args.output}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
