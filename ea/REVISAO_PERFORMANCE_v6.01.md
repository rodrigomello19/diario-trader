# Revisão de performance do Scalper Pro v6.01

Data da revisão: 03/11/2026. Foco: atraso do copiador.

Esta é uma revisão só de leitura: nenhum código foi alterado. Os números de linha são da v6.01.

## Como o MT5 executa o EA

Cada terminal processa os eventos do EA **um de cada vez**: tick, timer, gráfico e transação. Enquanto um deles está rodando, os outros esperam na fila. Por isso, um `Sleep` ou uma leitura pesada do histórico em **qualquer** ponto do EA atrasa a próxima gravação da mãe e a próxima leitura da filha. Essa é a origem da maior parte do atraso.

## A. Atraso no copiador

Em ordem de impacto.

| # | Onde | O que acontece | Pior caso | Afeta |
|---|---|---|---|---|
| 1 | Estatística ao fechar a posição (`ProcessarEstatisticasFechamento`, L1982-2016, chamada no `OnTradeTransaction`) | Se os pontos da operação dão 0 (saída no zero a zero), repete 12 vezes com `Sleep(100)`. Cada repetição relê o histórico **inteiro** da conta (`HistorySelect(0,…)`). | **~1,1 s** travado | Mãe e **cada filha** ao fechar a cópia. Se a mãe reentra logo depois de sair no zero, a filha atrasa a nova cópia. Também cria diferença **entre** as filhas. |
| 2 | `ReconstruirEstatisticasDia` a cada 3 s no `OnTimer` (via `VerificarIntegridadeEstadoSeguranca`, L2380-2415) | Carrega o histórico **inteiro** da conta (L1849) e faz duas buscas por posição fechada | dezenas de ms a cada 3 s (depende do tamanho do histórico) | Todos os terminais. Uma cópia que chega nesse momento espera. |
| 3 | A mãe só publica depois de terminar o evento que enviou a ordem | Entradas J/L (dentro do `OnTick`): parciais, trailing, `PositionModify` do TP e a atualização do painel rodam antes da publicação. FECHA (`CloseAll`) fecha posição por posição e só publica no fim. | 1 ida e volta à corretora + o resto do evento | Mãe → todas as filhas |
| 4 | Parciais (`ConfirmarVolumeReduzido` L10157, `ProcessarParciaisPosicao` L10326) | Espera a confirmação com `Sleep(50)` × 15 e tenta de novo com `Sleep(100)` × 3. Com falha permanente (ex.: volume inválido), repete **a cada tick**. | **~1 s** por parcial | Mãe (atrasa a parcial nas filhas) e filhas com SL/TP local |
| 5 | Movimento do gráfico (`CHARTEVENT_CHART_CHANGE`, L8983) | A cada scroll ou zoom, o painel inteiro é reposicionado: até 12 varreduras de todos os objetos do gráfico, com leituras síncronas. A camada de exibição da v5.96 roda **duas vezes**. | vários ms por evento; um scroll gera dezenas de eventos | O terminal em que você mexe no gráfico (normalmente a mãe) |
| 6 | Ordem do `OnTimer` (L8957) | `Central_Processar` (leitura de arquivo a cada 250 ms e gravação a cada 1 s) roda **antes** da cópia. A filha grava o arquivo de presença (ACK) antes de processar a cópia. | < 1 ms (mais com antivírus) | Todos |
| 7 | Timer de 20 ms | O Windows arredonda o timer para ~15,6 ms. Na prática, cada filha checa a cada 16–31 ms. | média de 10–16 ms, até ~31 ms | Diferença natural entre filhas |
| 8 | Clique em botões do painel (L6774) | `Sleep` de até 150 ms para o efeito visual de "botão pressionado" | 150 ms | Qualquer terminal |
| 9 | A cada tick com parciais ativas | ~22 leituras de variáveis globais e ~14 operações em objetos do gráfico, mesmo quando nada mudou | décimos de ms por tick | Mãe |
| 10 | TP na corretora e trailing (`AplicarTPBrokerSeAusente` L4016) | Se a corretora recusa, reenvia o `PositionModify` **a cada tick**, sem intervalo | 1 ida e volta à corretora por tick | Mãe e filhas |
| 11 | Filha NT8 (`SPCopyFilhaNT.cs` L313-323) | Depois de abrir, espera a posição aparecer no `Account.Positions` (~250 ms na Tradovate). Se a mãe fechar nesse intervalo, o fechamento espera. | ~250 ms | NT8 em saídas rápidas |

### O que está bem feito
- A mãe publica logo no início do `OnTradeTransaction`.
- A filha MT5 envia a ordem antes de registrar logs e variáveis.
- A NT8 envia a ordem (`Submit`) antes de gravar o log.
- As filhas não travam umas às outras: os arquivos são compartilhados sem bloqueio.
- O cálculo antes do envio na filha leva microssegundos.

## B. Defeitos encontrados (não são de performance, mas importam)

1. **`HistoryDealSelect` dentro de laços de histórico** (L1495, 1665, 1906 e `DealDoSimboloAtivo` L1684). A documentação do MQL5 diz que essa função **substitui a lista selecionada por um único negócio**. A partir do 2º negócio, o laço não enxerga mais nada.
   - **Consequências:**
     - o preço médio ponderado das saídas parciais (v5.91) **não é aplicado** na prática, e os pontos usam só a saída final;
     - as estatísticas dependem de rotas alternativas, o que explica as repetições com `Sleep` do item A1.
2. **`ReconstruirEstatisticasDia` (L1888)** chama `HistorySelectByPosition` dentro do laço que percorre o histórico do dia. Isso troca a lista no meio da varredura. Como roda a cada 3 s, pode **regravar os pontos e o número de operações do dia** usando só a primeira operação. Isso afeta o painel e os limites diários do EA. Precisa ser confirmado ao vivo, comparando o painel com o histórico depois de 2 ou mais operações no dia.
3. Itens menores:
   - **`PodeOperarRapido` (L3816):** guarda o resultado do limite até o próximo tick.
   - **`DistanciaMinimaStops`:** usa `_Point`, enquanto o resto do EA usa `ObterPontoPreco()`.
   - **`AvancarSLParaPontosP1`:** usa uma tolerância diferente da usada após o P1.

## C. Código morto e duplicado

O código morto **não deixa o EA mais lento**, porque o compilador não executa o que nunca é chamado. Removê-lo só limpa o arquivo.

- **13 funções sem uso**, todas seguras para apagar: `CreateParamRowHoriz`, `CreateEdit`, `AplicarEstiloRotuloMetricaStatus`, `CorRotuloMetricaStatus`, `CreateSectionTitle`, `CreateDivider`, `DefinirVisibilidadeObjeto`, `ReposicionarParamRowLayout`, `ReposicionarTituloSecaoLayout`, `ReposicionarGlassBoxLayout`, `ReposicionarBotoesExec`, `ReposicionarObjetoY`, `ReposicionarSecaoParciais`.
- **~50 constantes e cores sem uso**, a maioria do layout antigo (ex.: `PANEL_H`, `BOX_GAP`, `C_AUX_SETUP_*`, `C_EXEC_SYNC_*`, `PARC_SEC_H`, `OBJ_PARC_SEP`). Também há **4 variáveis gravadas e nunca lidas**: `g_statY_status`, `g_jBidNaArmacao`, `g_lBidNaArmacao` e `g_copyMaeAsk`.
- **Botão `OBJ_BTN_SETUP`:** não existe mais desde a v5.94, mas ainda aparece em várias condições.
- **Duplicações com custo real:**
  - `PontosPosicaoHistorico` e `PontosFechamentoRapido` fazem a mesma varredura do histórico, chamadas em sequência;
  - 21 funções percorrem todas as posições para achar a do ativo.
- **Duplicações só de tamanho de código:** `BuyOrder`/`SellOrder`, `AvancarSLTrailAposP1`/`AvancarSLParaPontosP1` e estilos de botão.
- **Parâmetros de entrada:** todos são usados.

## D. Plano sugerido (sem mudar funcionalidades)

| Etapa | O que fazer | Ganho esperado |
|---|---|---|
| 1 | Estatística no fechamento sem `Sleep`: aceitar 0 ponto como resultado válido e, se o histórico ainda não estiver pronto, tentar de novo no timer. Selecionar só o histórico da posição ou do dia. Corrigir `HistoryDealSelect` nos laços (B1). | elimina até ~1,1 s nas saídas no zero a zero, em todas as contas |
| 2 | `ReconstruirEstatisticasDia`: histórico só do dia, refazer apenas quando houver negócio novo, e corrigir o laço (B2) | remove os travamentos a cada 3 s e protege os limites do dia |
| 3 | Mãe publica logo após cada `Buy`/`Sell`/`PositionClose` e no início do `OnTick` | a cópia sai antes do resto do processamento da mãe |
| 4 | Parciais sem `Sleep`: enviar, marcar "enviando" e confirmar pela transação (o mecanismo já existe). Publicar assim que o volume diminuir. Usar um intervalo entre tentativas em caso de falha. | até ~1 s por parcial |
| 5 | Ao mover o gráfico, reposicionar só os rótulos de SL/TP. O painel só é redesenhado quando a janela muda de tamanho. | elimina travamentos ao rolar ou dar zoom |
| 6 | `OnTimer`: copiador primeiro, Central depois. Filha grava a presença depois da cópia e também verifica a mãe no `OnTick`. | 10–30 ms por cópia |
| 7 | Botões sem `Sleep`; estado das parciais em memória; intervalo entre tentativas de TP e trailing recusados; filha NT8 libera a entrada pela execução | ganhos menores e constantes |
| 8 | Remover o código morto | só limpeza |

## Ambiente

- **Antivírus:** exclua `%APPDATA%\MetaQuotes\Terminal\Common\Files` da verificação em tempo real.
- **Gráficos e indicadores:** evite indicadores pesados nos terminais filhos. Os indicadores do mesmo ativo dividem a mesma linha de processamento do terminal.
- **Vários terminais na mesma máquina:** com o processador sobrecarregado, o atraso entre as filhas aumenta. Feche gráficos que não usa.
