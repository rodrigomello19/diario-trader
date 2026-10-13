# Central de Controle (SPCentral)

Programa do Windows que segura o seu plano de trading. Os limites são cadastrados antes do pregão. Quando um deles é atingido, a central **trava todos os Scalper Pro (MT5) e as filhas NinjaTrader 8**, fecha as plataformas e só libera no reset diário ou com a **senha mestra**, que deve ficar com outra pessoa.

## O que ela controla

Todos os limites são contados **pela conta mãe**. Uma operação copiada para 3 filhas conta como 1, e os pontos são os do painel do Scalper Pro da mãe.

| Limite | Exemplo | O que acontece |
|---|---|---|
| Máximo de operações no dia | 3 | Ao fechar a 3ª operação: trava. As plataformas fecham. |
| Meta de pontos | 1.200 | Ao atingir (realizado + flutuante): **sem novas entradas**. A operação aberta **continua até fechar** (SL/TP/trailing/manual), e depois as plataformas fecham. |
| Limite de perda | 1.500 (= −1.500) | Ao atingir (realizado + flutuante): **ZERA tudo** (mãe e filhas) e fecha as plataformas. |
| Horário limite | 10:30 | A partir desse horário: sem novas entradas. A operação aberta termina e depois as plataformas fecham. Também dá para marcar "zerar no horário limite". |
| Horário de início (opcional) | 09:00 | Antes desse horário as entradas ficam bloqueadas. As plataformas não são fechadas. |
| Divergência de sinal | 20 s | Uma filha posicionada com a mãe zerada há mais de 20 s (perda de sinal do copiador) tem **só aquela filha** zerada. |

Enquanto estiver travada, a central **fecha de novo** qualquer MT5, NinjaTrader ou TradingView que for aberto (processos `terminal64`, `NinjaTrader`, `TradingView` e janelas com "TradingView" no título, como abas do navegador). As listas podem ser editadas.

A trava dura até o **reset diário** (ex.: 06:00 do dia seguinte). A **senha mestra** destrava antes. Ao destravar, a contagem recomeça do zero.

## Proteção contra alterações

- **Janela de edição:** as configurações só podem ser alteradas sem senha dentro da janela definida. Com "bloqueada a partir de 09:00" e "liberada a partir de 22:00", dá para mexer à noite e até as 9h. Fora disso, e sempre que a central estiver travada, alterar exige a senha mestra.
- **Fechar a central** (menu do ícone ou aba Senha mestra) exige a senha. O "X" da janela só esconde a central, que continua no ícone do escudo perto do relógio.
- **Central fechada à força** (Gerenciador de Tarefas): os Scalper Pro e as filhas NT8 **bloqueiam novas entradas** em até 10 s ("central offline").
- **Arquivos editados ou apagados:** se a configuração ou o estado forem alterados à mão ou apagados, a central bloqueia tudo até a senha mestra.
- **Inicialização:** a central se registra para abrir junto com o Windows.

> **Limite honesto:** isto é uma barreira contra o impulso, não um cofre. Quem tiver acesso de administrador e conhecimento técnico consegue contornar, por exemplo apagando a marca `SP_Central_Ativa.txt` com a central fechada, recompilando o EA ou mudando o relógio do PC. A proteção funciona porque desfazê-la exige tempo e intenção, o que costuma bastar para o momento de impulso.

## Instalação

1. Crie uma pasta fixa, por exemplo `C:\SPCentral`, e copie `SPCentral.cs` e `compilar.bat` para ela.
2. Dê dois cliques em **`compilar.bat`**. Ele usa o compilador C# que já vem no Windows e gera o `SPCentral.exe`. Se aparecer erro, envie as mensagens para correção.
3. Abra o **`SPCentral.exe`**. Na primeira vez ele pede a **senha mestra**: **peça para a outra pessoa digitar** (mínimo de 6 caracteres).
4. Na aba **Configuração**, preencha:
   - **Conta mãe:** o login MT5 da mãe (ex.: `510087363`). Se ficar vazio, a central usa o Scalper Pro em modo Mãe que estiver rodando.
   - **Contas filhas:** separe por vírgula. MT5 pelo login (ex.: `1514567645`); NT8 como `NT-<conta>` (ex.: `NT-APEX2209540000056`). Os IDs aparecem na lista de contas do Painel.
   - Limites, horários, reset e janela de edição. Depois clique em **Salvar configuração**.
5. Atualize os EAs e a estratégia:
   - **Scalper Pro v5.87** em todos os terminais MT5 (mãe e filhas);
   - **SPCopyFilhaNT v1.2** no NinjaTrader 8.

   A partir daí todos obedecem à central automaticamente. Não há parâmetro para desligar.

## Painel

- **Estado**, com a cor correspondente: LIBERADA (verde), AGUARDANDO HORÁRIO (laranja) ou TRAVADA (vermelho, com o motivo e o horário até quando).
- **Contadores:** operações x/máximo e pontos (realizado, flutuante e total), comparados com a meta e o limite de perda.
- **Contas:** todas as contas que o Scalper Pro e a filha NT8 estão reportando, com papel (mãe ou filha), online, posições e flutuante.
- **Eventos:** histórico das ações. Também fica gravado em `%LOCALAPPDATA%\SPCentral\log_AAAAMMDD.txt`.

No MT5, a barra de status do Scalper Pro mostra `CENTRAL: BLOQUEADO (motivo)` ou `CENTRAL: ZERANDO (motivo)`. Na filha NT8, o motivo aparece no log.

## Como os EAs obedecem

| Comando da central | Scalper Pro (MT5) | Filha NT8 |
|---|---|---|
| LIVRE | Normal | Normal |
| BLOQ | Recusa entradas (botões, teclas, linhas J/L), cancela pendentes e não abre cópias. Posições abertas seguem com SL/TP/trailing e fecham junto com a mãe. | Não abre cópias. Fecha junto com a mãe. |
| ZERAR | Fecha todas as posições do símbolo, a cada 1 s até zerar | Fecha a posição do contrato e cancela o SL/TP |

Arquivos trocados em `%APPDATA%\MetaQuotes\Terminal\Common\Files`:

| Arquivo | Quem grava | Conteúdo |
|---|---|---|
| `SP_Central_Ativa.txt` | central | Marca: os EAs passam a obedecer |
| `SP_Central_Cmd.txt` | central (a cada 0,5 s) | `CMD|1|tick|LIVRE/BLOQ/ZERAR|motivo|ate` e linhas `Z|<conta>` |
| `SP_Central_St_<conta>_<símbolo>.txt` | cada EA ou estratégia (1 s) | Posições e flutuante |
| `SP_Central_Tr_<conta>.txt` | Scalper Pro | Uma linha por operação encerrada, com os pontos |

## Desinstalar

Feche a central com a senha mestra e apague:
- a pasta do `.exe`;
- `%LOCALAPPDATA%\SPCentral`;
- o arquivo `SP_Central_Ativa.txt` em `Common\Files`;
- o valor `SPCentral` em `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`.
