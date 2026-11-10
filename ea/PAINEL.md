# Painel do Scalper Pro (v6.06): opção A, tema claro

```
Scalper Pro  v5.94 | US100                    [-] [X]
┌ PARÂMETROS ─────────────────── [Normal|Volátil] ┐
│ Lote               Take profit                  │
│ [-][  0.20  ][+]   [-][   1500    ][+]        │
│ Stop loss          Trail / Step           [1]   │
│ [-][  1000  ][+]   [  500    ] [  100        ]  │
└─────────────────────────────────────────────────┘
┌ PARCIAIS ─────────────────────────────── [ON] ┐
│     Gatilho (pts)   % do lote   Status         │
│ P1  [   500    ]    [  50  ]    [  ATIVO   ]   │
│ P2  [  1000    ]    [  30  ]    [  ATIVO   ]   │
└────────────────────────────────────────────────┘
[   COMPRA   ] [   FECHA   ] [   VENDA   ]
    tecla I        tecla O       tecla P
[   SYNC   ] [  LINHAS  ] [  BOLHAS   ]
┌ LIBERADO │  Oper  │ Pontos │ Spread ┐
│          │   2    │  +840  │   12   │
└──────────┴────────┴────────┴────────┘
Status (última ação)
Copiador
```

- **Perfil Normal/Volátil:** fica no topo do cartão PARÂMETROS. Clique no perfil que quer usar.
- **Lote:** os botões − e + somam ou tiram **1 lote inteiro** (0.20 → 1.20 → 2.20).
- **Take profit e Stop loss:** os botões − e + mudam **100 pts** por clique (1000 → 1100 → 1200).
  - Digite um número inteiro (3, 20) e pressione **Enter** ou clique fora do campo: ele vira **3.00** ou **20.00**.
  - As casas decimais seguem o passo do lote do ativo, com no mínimo 2.
- **Clicar fora de um campo confirma o valor.** Antes, clicar fora descartava o que foi digitado. **Esc** continua cancelando.
- **Botão TS (v6.05):** fica à direita de "Trail / Step", no lugar da antiga etiqueta FIXO/DINÂMICO. Cada clique avança 0 → 1 → 2 → 0.

  | Botão | Trailing stop | O que acontece |
  |---|---|---|
  | **0** (cinza) | Desligado | O SL fica onde está, e a linha azul do trailing some. |
  | **1** (laranja) | Fixo | Funciona como o antigo FIXO. |
  | **2** (azul) | Dinâmico | A distância é Trail − Step, e o SL avança a cada Step. Exige Trail maior que Step; se não for, o clique pula do 1 para o 0 e avisa na barra de status. |

  - Vale também com uma posição aberta, e a mudança entra no próximo tick.
  - A escolha fica salva por ativo, mesmo depois de reiniciar o MT5.
  - Parciais, TP, SL e o copiador não mudam.
- **Take profit e Stop loss:** a etiqueta "pts" foi tirada (v6.06). Os valores continuam em pontos.
- **BOLHAS (v6.04, antes ESPELHO):** esconde ou mostra a VWAP, as bandas, as bolhas e a absorção do indicador **RM_NT8Espelho**.
  - Com o indicador escondido, o botão mostra **BOLHAS OFF**.
  - **Vale para todos os gráficos do mesmo ativo (v6.06),** inclusive o gráfico de estudo, e não só para o gráfico do EA.
  - **Como funciona:** o EA envia um evento ao indicador, que muda só a visibilidade do que já desenhou. Nada é apagado nem recriado. O indicador continua lendo os dados, então tudo volta atualizado. As ordens não são afetadas.
  - **Objetos `RMN8_`:** o EA também esconde direto os objetos do indicador (parâmetro "Prefixo dos objetos do indicador a esconder", agora `RMN8_` por padrão). Assim as bolhas e a absorção somem mesmo com uma versão antiga do indicador. A VWAP só some com a v2.2.
  - **Confirmação (v6.06):** 1,5 s depois do clique, a barra de status diz o resultado:
    - `Bolhas e VWAP escondidas (n gráfico(s))`: deu certo;
    - `BOLHAS: atualize o RM_NT8Espelho (v2.2) e compile`: o indicador no gráfico é uma versão antiga e não respondeu;
    - `BOLHAS: RM_NT8Espelho nao esta nos graficos de US100`: o indicador não foi encontrado. A aba Experts lista os indicadores do gráfico.
  - O estado fica salvo por gráfico, inclusive ao trocar o tempo gráfico ou reiniciar o MT5.
  - Precisa do **RM_NT8Espelho v2.2 ou mais nova** (`mt5/RM_NT8Espelho.mq5`), copiado para `MQL5\Indicators` e compilado com F7.
- **RM_NT8Espelho v2.3:**
  - **Bolhas atrás do painel:** as bolhas, os números (PCR, 2x, X2) e os pontos de absorção são desenhados **no fundo**, então o painel do Scalper Pro fica por cima. Se um ponto de absorção cair dentro do corpo de um candle, ele fica atrás do candle. Para voltar como era, use o parâmetro do indicador "DesenharNoFundo" = false.
  - **Linha de status discreta** (canto inferior esquerdo, cinza e pequena): mostra só `NT8 <contrato> | <hora da última leitura>` e o que pede atenção, em laranja (sem conexão, cópias repetidas do indicador, avisos). O texto completo aparece ao passar o mouse. Para a linha longa de antes, use "StatusDetalhado" = true.
  - **Cópias repetidas:** se a linha mostrar "2 copias do indicador (Ctrl+I)", há o indicador duas vezes no gráfico. Abra a lista com Ctrl+I e remova a cópia extra. Duas cópias desenham tudo em dobro.
- **Outro EA no mesmo ativo (v6.07):** a cada 2 s, o Scalper confere os outros gráficos do mesmo ativo neste MT5.
  - **Quando avisa:**
    - se algum gráfico tiver um EA ligado (ex.: DGX);
    - se existir posição ou ordem do ativo aberta por outro robô (magic diferente de 0 e do magic das cópias).
  - **Como avisa:** a barra de status fica **vermelha**, com `OUTRO EA: DGX (M5)`, e toca um **alerta** do MT5.
  - **Para fechar o gráfico do outro EA:** clique na barra de status. Ela pede confirmação: **clique de novo em até 4 s**.
  - **Antes de fechar,** o Scalper salva o gráfico como modelo `SP_salvo_<EA>_<ativo>`. Para reabrir: botão direito no gráfico > Modelos.
  - **Posições já abertas pelo outro EA continuam abertas.** Feche-as à mão, se for o caso.
  - **Por que não desligar só o Algo Trading do outro EA:** o MT5 não permite que um EA desligue o Algo Trading de outro. O botão geral "Algo Trading" desligaria também o Scalper Pro e o copiador.
- **COMPRA / FECHA / VENDA:** mostram a tecla de atalho configurada nos parâmetros.
- **Bloco de estado do dia:** segue a **Central de Controle**. Fica verde com LIBERADO e vermelho com BLOQUEADO quando a Central bloqueia, zera ou está offline.
- **Oper:** mostra só a quantidade de operações do dia. O máximo fica na Central.
- **Limites (v6.05):** o botão LIMITES, o PIN, o fechamento programado do MT5 e a trava do dia saíram do EA, porque a Central de Controle já faz tudo isso.
  - Sem a Central, o EA opera sem limites diários.
  - Os parâmetros "Fechamento por limites" e "Caixa de mensagem" não existem mais. Um `.set` antigo continua carregando: o MT5 ignora esses itens.
- **Cores:** mensagens em verde, laranja e vermelho foram escurecidas para ficarem legíveis no fundo claro.

**Limites do MT5:** o painel usa objetos do MT5, que não têm cantos arredondados nem sombras. Os "cartões" são retângulos com borda fina.

## Linhas no gráfico

- **Trailing:** linha **azul contínua**.
- **P1 e P2:** linhas **finas, vermelhas e pontilhadas** no preço de cada parcial (entrada ± pontos). Cada linha some quando a sua parcial é executada, e as duas somem quando a posição fecha ou quando as parciais são desligadas.
