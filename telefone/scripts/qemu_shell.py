#!/usr/bin/env python3
"""Carrega o kernel extraido do boot.img e confirma o shell do BusyBox."""

import os
import pty
import select
import subprocess
import sys
import time


def fail(message, log):
    tail = log.decode("utf-8", "replace")[-4000:]
    sys.stderr.write(tail)
    if tail and not tail.endswith("\n"):
        sys.stderr.write("\n")
    raise SystemExit(message)


def main(argv):
    if len(argv) != 3:
        raise SystemExit("uso: qemu_shell.py KERNEL INITRD")
    kernel, initrd = argv[1], argv[2]
    qemu = os.environ.get("QEMU", "qemu-system-i386")
    master, slave = pty.openpty()
    command = [
        qemu,
        "-cpu", "max",
        "-m", "256",
        "-kernel", kernel,
        "-initrd", initrd,
        "-append", "console=ttyS0 rdinit=/init panic=1",
        "-display", "none",
        "-monitor", "none",
        "-serial", "stdio",
        "-no-reboot",
    ]
    process = subprocess.Popen(
        command,
        stdin=slave,
        stdout=slave,
        stderr=slave,
        close_fds=True,
    )
    os.close(slave)
    deadline = time.monotonic() + 120
    log = b""
    userspace_at = None
    sent = False
    try:
        while time.monotonic() < deadline:
            if process.poll() is not None:
                ready, _, _ = select.select([master], [], [], 0)
                if not ready:
                    break
            ready, _, _ = select.select([master], [], [], 0.5)
            if ready:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                log += chunk
            if userspace_at is None and b"ZENBOOT: userspace" in log:
                userspace_at = time.monotonic()
            if not sent and userspace_at is not None:
                waited = time.monotonic() - userspace_at
                if prompt_ready(log) or waited > 8:
                    os.write(master, b"/bin/busybox echo ZENBOOT_BUSYBOX_OK\n")
                    sent = True
            if marker_output(log):
                try:
                    os.write(master, b"/bin/busybox poweroff -f\n")
                except OSError:
                    pass
                time.sleep(1)
                break
        else:
            fail("tempo esgotado esperando o BusyBox", log)
    finally:
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
        os.close(master)
    text = log.decode("utf-8", "replace")
    if "Linux version" not in text:
        fail("o kernel nao anunciou Linux version", log)
    if not marker_output(log):
        fail("o shell do BusyBox nao executou o comando", log)
    for line in text.splitlines():
        if "Linux version" in line or line.strip() == "ZENBOOT_BUSYBOX_OK" or line.startswith("ZENBOOT:"):
            print(line)
    print("PASS: kernel carregou e o BusyBox abriu o shell")
    return 0


def marker_output(log):
    return any(line.strip() == b"ZENBOOT_BUSYBOX_OK" for line in log.splitlines())


def prompt_ready(log):
    return log.rstrip().endswith(b"#") or b"\n# " in log or b"~ #" in log


if __name__ == "__main__":
    sys.exit(main(sys.argv))
