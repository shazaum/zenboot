# Z00A — imagem de boot Android

Esta pasta prepara, no computador, um `boot.img` no formato Android usado pelo Droidboot do ASUS Zenfone 2 ZE551ML. Ela nao substitui `boot.asm` nem a imagem de disquete do QEMU.

O arquivo gerado ainda nao foi carregado no telefone. Nao o grave em particao, firmware ou bootloader.

## O que entra na imagem

- Kernel: um `bzImage` externo, informado em `--kernel`. Este repositorio nao inclui o kernel GPL.
- Ramdisk: o diretorio `initramfs/`. O `/init` abre um shell pelo BusyBox, se `/bin/busybox` existir. Sem esse binario, o script registra a ausencia e espera.
- Segundo estagio e assinatura: opcionais. Relatos publicos dizem que o bootloader de Android 6 do Z00A exige uma assinatura no final do `boot.img`. Isso ainda nao foi verificado neste aparelho.

Os enderecos de carga e o page size 2048 sao os padroes do mkbootimg do AOSP. Eles devem ser alinhados a um `boot.img` original antes de qualquer teste no hardware.

## Exemplo

```bash
sh z00a/pack-bootimg.sh \
  --kernel /caminho/bzImage \
  --initramfs-dir z00a/initramfs \
  --output /tmp/zenboot-z00a-boot.img
sh z00a/scripts/check-bootimg.sh
```

O teste estatico usa um kernel ficticio. Ele nao prova que o aparelho inicia.
