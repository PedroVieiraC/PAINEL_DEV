# Painel Dev

Painel de desktop em PowerShell (WinForms) com abas para tarefas do dia a dia num PC Windows:
manter acordado, monitorar sistema, limpeza, rede, dev e otimização — tudo num só lugar, sem abrir
telas de configuração diferentes a cada vez.

## Como usar

Clique duas vezes em **`PainelDev.bat`** (ele pede elevação sozinho — o painel roda como
administrador; nenhum módulo se auto-eleva).

## Abas
- **Manter Acordado** — desliga suspensão/hibernação/apagar tela temporariamente, com botão para
  restaurar o original.
- **Sistema** — monitor de RAM/CPU/disco, troca de plano de energia, atalhos de manutenção.
- **Limpeza**, **Rede**, **Dev** — atalhos e utilitários do dia a dia.
- **Otimização** — atalho para rodar o projeto [`OTIMIZAR_WINDOWS`](../OTIMIZAR_WINDOWS), se ele
  estiver clonado na pasta ao lado desta.
- **Windows Defender** — liga/desliga o Defender via **defender-control** (ver abaixo).

## Aba Windows Defender: usa o `defender-control`, de qtKite

Essa aba chama o [**defender-control**](https://github.com/pgkt04/defender-control), projeto de
código aberto (MIT License) de **qtKite** que desliga/liga o Windows Defender de forma mais
completa que as configurações padrão. Todo o crédito dessa parte é dele — o Painel Dev só dá um
botão para chamá-lo.

Os `.exe` do defender-control **não estão neste repositório** (o Windows Defender e os
navegadores costumam bloquear o download/execução deles automaticamente — é esperado, o próprio
projeto avisa isso: é uma detecção por categoria, qualquer "desligador de Defender" cai nela, não é
evidência de que o código seja malicioso).

Para habilitar a aba:
1. Baixe a release do defender-control em
   [github.com/pgkt04/defender-control/releases](https://github.com/pgkt04/defender-control/releases).
2. Antes de extrair: no Windows Security, desligue **Proteção contra Adulteração** e a
   **Proteção em tempo real** (temporariamente) — senão o Defender coloca os `.exe` em quarentena
   ao extrair.
3. Extraia o conteúdo dentro da pasta `defender-control\` deste projeto, de forma que
   `defender-control\disable-defender.exe` e `defender-control\enable-defender.exe` existam.
4. Reative a Proteção em tempo real. A aba detecta os `.exe` automaticamente na próxima abertura
   do painel.

Sem esses arquivos, a aba só mostra os botões desativados — o resto do painel funciona normal.

## Para adicionar uma funcionalidade nova

Crie `modulos\<nome>.ps1` com uma função `Add-Aba<Nome>([Windows.Forms.TabControl]$tabs)` e
acrescente, em `painel.ps1`, as duas linhas de dot-source + chamada (siga o padrão das abas
existentes). Nenhum módulo deve se auto-elevar.
