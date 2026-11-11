# Pasta do telefone

Esta pasta faz parte do ZENBOOT. Ela nao e um segundo projeto.

Aqui se monta, no computador, o `boot.img` Android do ASUS Zenfone 2 ZE551ML. O bootloader de PC continua na raiz do repositorio: `boot.asm`, `stage2.asm` e `build.sh`.

O arquivo gerado ainda nao foi carregado no telefone. Nao o grave em particao, firmware ou bootloader.

## O que entra na imagem

- Kernel: um `bzImage` externo, informado em `--kernel`. Este repositorio nao inclui o kernel GPL.
- Ramdisk: o diretorio `initramfs/`. O `/init` abre um shell pelo BusyBox, se `/bin/busybox` existir. Sem esse binario, o script registra a ausencia e espera.
- Segundo estagio e assinatura: opcionais. Relatos publicos dizem que o bootloader de Android 6 deste aparelho exige uma assinatura no final do `boot.img`. Isso ainda nao foi verificado neste aparelho.

Os enderecos de carga e o page size 2048 sao os padroes do mkbootimg do AOSP. Eles devem ser alinhados a um `boot.img` original antes de qualquer teste no hardware.

## Exemplo

```bash
sh telefone/pack-bootimg.sh \
  --kernel /caminho/bzImage \
  --initramfs-dir telefone/initramfs \
  --output /tmp/zenboot-telefone-boot.img
sh telefone/scripts/check-bootimg.sh
```

O teste estatico usa um kernel ficticio. Ele nao prova que o aparelho inicia. O plano completo esta em `ROADMAP.md`, na raiz do repositorio.
