# Roadmap

Um projeto, dois alvos. Itens marcados ja estao no repositorio. Itens abertos ainda nao foram feitos.

## PC no QEMU

- [x] Setor de boot de 512 bytes e segundo estagio.
- [x] Modo protegido de 32 bits, VGA e teclado PS/2.
- [x] Comandos `help`, `info` e `clear`.
- [x] Fabricante da CPU no comando `info`.
- [x] Build no Mac e teste manual no QEMU.
- [x] Comando `cpu` com familia, modelo, stepping, x86-64 e recursos. Esta na branch `feat/cpu-info`, commit `15b512b`. Ainda nao entrou em `main`.
- [ ] Integrar `feat/cpu-info` em `main`, quando for pedido.
- [ ] Comando `version`.
- [ ] Mapa de memoria pela BIOS, no modo real.
- [ ] Revisao do buffer do teclado e da apresentacao do terminal.

## Telefone ZE551ML

A pasta `telefone/` prepara a imagem. O boot de PC da raiz nao e o carregador do aparelho.

- [x] Auditoria da cadeia IFWI, Droidboot e `boot.img`.
- [x] Empacotador, `/init` e teste estrutural no computador. Commit `09cad9b` na branch `feat/z00a-bootimg`. Sem kernel real e sem o telefone.
- [ ] Receita reproduzivel do `bzImage` a partir do fonte GPL do ZE551ML.
- [ ] Linha de comando, segundo estagio e assinatura copiados de um `boot.img` original.
- [ ] Leitura do aparelho, somente com autorizacao explicita e sem gravacao.
- [ ] Primeiro boot no hardware, somente depois de autorizacao explicita.
- [ ] Disco persistente e escolha da distribuicao, depois que o shell iniciar.

Gravar firmware, bootloader ou particoes nao faz parte deste plano.
