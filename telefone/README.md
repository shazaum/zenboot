# Pasta do telefone

Esta pasta faz parte do ZENBOOT. Ela nao e um segundo projeto.

Aqui se monta, no computador, o `boot.img` Android do ASUS Zenfone 2 ZE551ML. O bootloader de PC continua na raiz do repositorio: `boot.asm`, `stage2.asm` e `build.sh`.

O arquivo gerado ainda nao foi carregado no telefone. Nao o grave em particao, firmware ou bootloader.

## O que entra na imagem

- Kernel: um `bzImage` externo, informado em `--kernel`. Este repositorio nao inclui o kernel GPL. O teste no QEMU usa o kernel i686 da Alpine, que nao e o kernel do ZE551ML.
- Ramdisk: o diretorio `initramfs/`. O `/init` abre um shell pelo BusyBox. O binario estatico i686 entra na montagem e nao fica no Git.
- Segundo estagio e assinatura: opcionais. Relatos publicos dizem que o bootloader de Android 6 deste aparelho exige uma assinatura no final do `boot.img`. Isso ainda nao foi verificado neste aparelho.

Os enderecos de carga e o page size 2048 sao os padroes do mkbootimg do AOSP. Eles devem ser alinhados a um `boot.img` original antes de qualquer teste no hardware.

## Exemplo

```bash
sh telefone/pack-bootimg.sh \
  --kernel /caminho/bzImage \
  --initramfs-dir telefone/initramfs \
  --output /tmp/zenboot-telefone-boot.img
sh telefone/scripts/check-bootimg.sh
sh telefone/scripts/boot-linux.sh
```

`check-bootimg.sh` usa um kernel ficticio e so confere a estrutura. `boot-linux.sh` monta um `boot.img` com kernel e BusyBox, extrai esses dois arquivos da imagem e os entrega ao QEMU. O shell que abre e o do emulador. O plano completo esta em `ROADMAP.md`, na raiz do repositorio.
