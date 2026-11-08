# Revisão de performance do Scalper Pro v6.05

Data: 08/11/2026. Foco: copiador (mãe → filhas MT5 e NT8) e execução de entradas e saídas.

Revisão só de leitura: o código não foi alterado. Os números de linha são da v6.05 (9.343 linhas).

## Resumo

O caminho principal da cópia está bem montado:

- a mãe publica logo depois de cada ordem e no início de cada tick e de cada transação;
- a filha lê a mãe no timer e também nos ticks;
- não há nenhum `Sleep`.

Hoje, o que mais atrasa a cópia são:

1. **Chamadas que esperam o gráfico, a cada tick, com posição aberta.** Elas existem na mãe e nas filhas no modo LOCAL, e atrasam justamente o **sinal de saída**. É o item mais importante.
2. **500 ms de espera quando a corretora recusa** uma abertura ou um fechamento da cópia, inclusive por variação de preço (requote). Uma recusa vira meio segundo de atraso.
3. **Trabalho de tela no fechamento** (`OnTradeTransaction`), feito antes de a filha voltar a ler a mãe.

O resto é ganho pequeno ou só limpeza.

## Como o tempo de uma cópia se divide hoje

| Etapa | Tempo típico | Dá para reduzir? |
|---|---|---|
| Mãe: ida e volta à corretora (`trade.Buy` síncrono) | 30–150 ms | Só publicando **antes** da confirmação. Muda o funcionamento: a filha entraria mesmo se a mãe fosse recusada. **Não recomendado.** |
| Mãe grava o arquivo | < 0,2 ms | Não precisa |
| Filha percebe o arquivo novo | 0–31 ms (timer de 20 ms arredondado pelo Windows para ~16 ms; também lê a cada tick, no máximo a cada 5 ms) | Sim: intervalo de 10 ms (item 6) |
| Filha: trabalho que estiver rodando no momento (tick, parciais, tela) | 0 a vários ms | **Sim: itens 1 e 3** |
| Filha: ida e volta à corretora | 30–150 ms | Não |
| Filha: recusa por preço → nova tentativa | **+500 ms** | **Sim: item 2** |

## A. Oportunidades de performance, em ordem de impacto

| # | Onde | O que acontece | Efeito | Proposta |
|---|---|---|---|---|
| 1 | `SetParcialLabel` (L8108), chamada por `ProcessarParciaisPosicao` / `AtualizarStatusParcialUI` a cada tick; `AtualizarLinhasParciais` (L8876); `AtualizarArrasteSLNoGrafico` (L1003) | Com posição aberta e parciais ligadas, cada tick faz cerca de **13 chamadas síncronas ao gráfico**: `ObjectFind`, `ObjectGetString`, `ObjectGetInteger`, `ObjectGetDouble` e `ChartGetInteger`. Cada uma espera o gráfico terminar o que estiver na fila, como redesenho e indicadores (ex.: bolhas). Também envia 5 ou mais `ObjectSet*` iguais por tick (cor, estilo, dica), o que força redesenho. | De microssegundos a **vários ms por tick**, conforme o gráfico. Afeta a mãe e as filhas LOCAL **enquanto a posição está aberta**, ou seja, no momento em que o sinal de saída precisa ser lido. | Guardar em memória o último texto e a cor de cada parcial, o último preço das linhas P1/P2 e o estado do arraste do SL. Só falar com o gráfico quando algo mudar. |
| 2 | `CopyFilha_Abrir` (L6697) e `CopyFilha_Fechar` (L6559) | Qualquer recusa (ret ≠ DONE) espera 500 ms (`COPY_TENT_INTERV_MS` / `COPY_FALHA_INTERV_MS`), inclusive as de variação de preço: 10004 requote, 10020 preço mudou, 10021 sem cotação. O desvio padrão `InpCopyDesvioPts = 50` pts (0,5 ponto no US100) é apertado em mercado rápido. | **+500 ms** por recusa. Na saída, a filha fica 0,5 s a mais posicionada. | Repetir **na hora**, uma vez, nas recusas de preço (10004/10020/10021). Manter os 500 ms para as demais. Conferir no log se aparece `ret=10004/10020/10021`. Se aparecer, aumentar também o desvio. |
| 3 | `OnTradeTransaction`, fechamento (L4436–4467) | Depois que uma posição fecha, o mesmo evento faz: limpeza das linhas, finalização das parciais, apagar GVs, estatística (`HistorySelectByPosition`), registro na Central (arquivo), painel e rótulos. São dezenas de chamadas síncronas ao gráfico. Na mãe, a publicação já saiu antes. **Na filha, nada disso deixa a próxima leitura da mãe acontecer** até terminar. | Alguns ms logo após cada saída, exatamente quando a mãe pode reentrar. | Fazer só a parte essencial no evento (estado das parciais, GVs) e deixar estatística, painel e linhas para o próximo timer, como já é feito na entrada (`AgendarProcessamentoEntrada`). |
| 4 | `CopyAtualizarStatusPainel` (L7007), a cada 20 ms em todos os terminais com copiador | Faz `ObjectFind` (síncrono) e monta os textos da faixa a cada 20 ms. | < 0,1 ms, mas 50 vezes por segundo. | Atualizar a faixa a cada 250 ms e guardar se o objeto existe. |
| 5 | `SincronizarStatusImpedimento` (a cada 5 ticks), `AtualizarBotaoSetup` | `ObjectFind` desnecessário. O texto completo já fica em `g_statusTextoCompleto`. `AtualizarBotaoSetup` procura um botão que não existe desde a v5.94 (`OBJ_BTN_SETUP`). | Pequeno | Tirar as consultas. |
| 6 | `InpCopyIntervaloMs = 20` | O Windows arredonda para ~15,6 ms, então a filha checa a cada 16–31 ms. A filha NT8 já usa 10 ms. | Média de 10–16 ms por cópia | Usar **10 ms** nas filhas (é só um parâmetro). Conferir o uso de CPU com vários terminais. |
| 7 | `CopyFilha_Processar`, chamado pelo timer e pelo tick | Timer e tick têm controles de intervalo separados: o arquivo pode ser lido duas vezes seguidas. No modo LOCAL, com o arquivo sem mudança e nada pendente, a conferência de todas as posições roda à toa. | Microssegundos por ciclo | Um controle de intervalo só. Pular a conferência quando nada mudou e não há nada pendente. |
| 8 | `CopyMae_EstadoPosicoes` (L6124) | Monta também o texto do log (`resumo`) em toda publicação, mesmo quando nada mudou: cada tick, cada 20 ms e cada transação. | Microssegundos | Montar o `resumo` só quando o estado mudar. |
| 9 | Filha NT8 (`SPCopyFilhaNT.cs`) | Pendente da revisão anterior (A11): depois de abrir, espera a posição aparecer (~250 ms na Tradovate). Um fechamento da mãe nesse intervalo espera. | ~250 ms em saídas muito rápidas | Liberar pela execução (`OnExecutionUpdate`) |

**Não recomendado (muda o comportamento):**
- **Filha com ordens assíncronas** (`SetAsyncMode(true)`): a filha não esperaria a corretora, mas a reconciliação, as tentativas e o mapeamento dependem da resposta síncrona.
- **Mãe publicar antes da confirmação:** a filha poderia entrar numa operação que a mãe não conseguiu abrir.

## B. Estabilidade da conexão mãe ↔ filhas

Está sólida. Nada crítico.

- **Arquivo lido no meio da gravação:** a filha confere o cabeçalho, a quantidade de linhas e o `END|seq`, e mantém o último estado válido.
- **Mãe parada:** o heartbeat de 250 ms e o limite de 3 s marcam a mãe como offline, e a filha deixa de abrir posições novas. As já abertas continuam sincronizadas.
- **Reinício de qualquer lado:** reconcilia sozinho, porque copia posições e não sinais. O ID da mãe fica no comentário da ordem e numa GV.
- **Arquivos compartilhados sem bloqueio entre leitor e gravador:** uma filha não trava a outra.
- **Pontos de atenção:**
  - antivírus verificando `Common\Files` (cada leitura passa por ele);
  - processador sobrecarregado com muitos terminais.

## C. Código morto e duplicado

O código morto não deixa o EA mais lento, mas confunde a manutenção.

- **6 funções sem uso:**
  - `EhBotaoExecPainel` e `EhBotaoPainelSP`: as chamadas saíram com o sistema de limites;
  - `EhLinhaVerticalNoGrafico`: a chamada saiu com a nova limpeza do SYNC;
  - `PontosFechamentoRapido`, `PontosPosicaoHistorico` e `SelecionarHistoricoDia`: substituídas na v6.02.
- **1 constante sem uso:** `SP_MSG_TRAIL_DIST`.
- **4 variáveis gravadas e nunca lidas:** `g_jBidNaArmacao`, `g_lBidNaArmacao`, `g_copyMaeAsk` e `g_statY_status`.
- **Botão `OBJ_BTN_SETUP`:** não existe desde a v5.94, mas aparece em 11 lugares, um deles com `ObjectFind`.
- **Copiador NT antigo:** `InpCopyNT_Ativo`, as 4 funções `CopyNT_*` e o arquivo `SP_NT_Copy_Signal.txt`. Foi substituído pela filha NT8, que lê o mesmo arquivo das filhas MT5. Fica desligado por padrão. Se alguém ligar, o arquivo cresce sem limite.
- **Restos sem efeito:**
  - laço `for(i = 0; i < 1; i++)` em `ConfirmarVolumeReduzido`, sobra do antigo `Sleep`;
  - nomes `C_AUX_LIMITS_*` usados por todos os botões auxiliares.
- **Duplicações:**
  - `BuyOrder`/`SellOrder` e `AvancarSLTrailAposP1`/`AvancarSLParaPontosP1`: só tamanho de código;
  - `TicketPosicaoSimbolo()` roda várias vezes no mesmo tick: a posição já é calculada no início do `OnTick`, mas outras rotinas procuram de novo. São microssegundos.

## D. Plano sugerido (nenhuma funcionalidade muda)

| Etapa | Itens | Ganho |
|---|---|---|
| 1 | A1: parciais, linhas P1/P2 e arraste sem consultar o gráfico a cada tick | Remove até vários ms por tick com posição aberta, na mãe e nas filhas |
| 2 | A2: nova tentativa imediata em recusa por preço | Até 500 ms por recusa |
| 3 | A3: parte visual do fechamento adiada para o timer | Alguns ms logo após cada saída |
| 4 | A4, A5, A7, A8: faixa a cada 250 ms, sem `ObjectFind` desnecessário, leitura única da mãe | Pequeno e constante |
| 5 | A6: `InpCopyIntervaloMs` = 10 nas filhas (parâmetro, sem código) | 5–10 ms em média |
| 6 | C: remover o código morto e o copiador NT antigo | Só limpeza |
| 7 | A9: filha NT8 libera a saída pela execução | ~250 ms em saídas rápidas no NT8 |

## Ambiente (sem código)

- **Antivírus:** excluir `%APPDATA%\MetaQuotes\Terminal\Common\Files` da verificação em tempo real.
- **Energia:** usar o plano "Alto desempenho" no Windows, para evitar atrasos do timer quando o processador reduz a frequência.
- **Terminais das filhas:**
  - deixar só o gráfico do ativo com o EA, sem indicadores pesados;
  - indicadores como o RM_NT8Espelho no mesmo gráfico do EA dividem a fila desse gráfico, então o item A1 também reduz essa disputa.
- **Configuração do MT5:** "Máx. barras no gráfico" baixo (ex.: 5.000) nos terminais das filhas.

## Implementado (08/11/2026)

Nenhuma funcionalidade mudou. A versão continua v6.05.

| Item | O que mudou |
|---|---|
| A1 | O status e a cor das parciais, as linhas P1/P2 e o arraste do SL ficam guardados em memória. O gráfico só é alterado quando algo muda. A cada 1 s, o EA confere as linhas P1/P2 e o arraste no gráfico (ex.: linha apagada à mão). Com posição aberta, o tick deixa de fazer cerca de 13 consultas que esperam o gráfico. |
| A2 | Abertura, fechamento e parcial da cópia repetem na hora, uma vez, em recusa por preço (10004/10020/10021). As outras recusas continuam esperando 500 ms. |
| A3 | No fechamento, o evento só cuida do estado das parciais e das GVs. Linhas, rótulos, estatística, painel e registro na Central vão para o próximo tick ou timer (`ProcessarFechamentosPendentes`). Se o EA for removido antes disso, o `OnDeinit` também processa. |
| A4 | A faixa do copiador é atualizada a cada 250 ms (antes: a cada 20 ms). |
| A5 | O status do painel não usa mais `ObjectFind`. As referências ao botão `SETUP`, que não existe mais, foram removidas. |
| A6 | `InpCopyIntervaloMs` passa a 10 ms por padrão. Um `.set` antigo continua usando o valor gravado nele (ex.: 20). |
| A7 | A leitura da mãe tem um único controle de intervalo (5 ms) para o timer e o tick. |
| A8 | O texto do log da mãe só é montado quando o estado muda, depois da gravação. |
| C | Removidas as 6 funções sem uso, a constante, as 4 variáveis nunca lidas, o laço que sobrou em `ConfirmarVolumeReduzido` e o copiador NT antigo (`InpCopyNT_Ativo` e as 4 funções `CopyNT_*`). |

**Ficou de fora:**
- **Pular a conferência da filha quando o arquivo não muda (parte do A7):** as tentativas de abertura dependem do tempo, então a conferência precisa rodar mesmo sem mudança.
- **A9:** filha NT8, em outro arquivo (`SPCopyFilhaNT.cs`).
