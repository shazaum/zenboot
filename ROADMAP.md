# Roadmap

Um projeto, dois alvos. Itens marcados ja estao no repositorio. Itens abertos ainda nao foram feitos.

## PC no QEMU

- [x] Setor de boot de 512 bytes e segundo estagio.
- [x] Modo protegido de 32 bits, VGA e teclado PS/2.
- [x] Comandos `help`, `info` e `clear`.
- [x] Fabricante da CPU no comando `info`.
- [x] Build no Mac e teste manual no QEMU.
- [x] Comando `cpu` com familia, modelo, stepping, x86-64 e recursos, na branch `feat/cpu-info`.
- [ ] Integrar o comando `cpu` na linha principal.
- [ ] Comando `version`.
- [ ] Mapa de memoria pela BIOS, no modo real.
- [ ] Revisao do buffer do teclado e da apresentacao do terminal.

## Telefone ZE551ML

A pasta `telefone/` prepara a imagem. O boot de PC da raiz nao e o carregador do aparelho.

- [x] Auditoria da cadeia IFWI, Droidboot e `boot.img`.
- [x] Empacotador, `/init` e teste estrutural no computador.
- [x] Kernel Linux i686 e shell BusyBox no QEMU, a partir do `boot.img` montado no computador. O kernel e o da Alpine, nao o do ZE551ML. Nada foi gravado no aparelho.
- [ ] Kernel do ZE551ML compilado a partir do fonte GPL.
- [ ] Linha de comando, segundo estagio e assinatura de um `boot.img` original.
- [ ] Leitura do estado do aparelho, sem gravar.
- [ ] Primeiro boot no aparelho, com o medidor de bateria estavel.
- [ ] Disco persistente e escolha da distribuicao, depois que o shell iniciar no aparelho.

Gravar firmware, bootloader ou particoes nao faz parte deste plano.
