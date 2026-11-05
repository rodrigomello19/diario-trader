# Painel do Scalper Pro (v6.04): opção A, tema claro

```
Scalper Pro  v5.94 | US100                    [-] [X]
┌ PARÂMETROS ─────────────────── [Normal|Volátil] ┐
│ Lote               Take profit             pts  │
│ [-][  0.20  ][+]   [-][   1500    ][+]        │
│ Stop loss     pts  Trail / Step     [ON]  FIXO  │
│ [-][  1000  ][+]   [  500    ] [  100        ]  │
└─────────────────────────────────────────────────┘
┌ PARCIAIS ─────────────────────────────── [ON] ┐
│     Gatilho (pts)   % do lote   Status         │
│ P1  [   500    ]    [  50  ]    [  ATIVO   ]   │
│ P2  [  1000    ]    [  30  ]    [  ATIVO   ]   │
└────────────────────────────────────────────────┘
[   COMPRA   ] [   FECHA   ] [   VENDA   ]
    tecla I        tecla O       tecla P
[  SYNC  ] [ LINHAS ] [ ESPELHO ] [ LIMITES ]
┌ LIBERADO │  Oper  │ Pontos │ Spread ┐
│          │  2/3   │  +840  │   12   │
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
- **Trail / Step:** a etiqueta **FIXO / DINÂMICO** à direita alterna o modo do trailing.
- **Botão ON/OFF do trailing (v6.04):** fica ao lado de "Trail / Step".
  - **OFF** (cinza): o trailing stop para. O SL fica onde está, e a linha azul do trailing some.
  - **ON** (verde): o trailing volta a funcionar a partir do próximo tick.
  - O botão vale também com uma posição aberta, e o estado fica salvo por ativo, mesmo depois de reiniciar o MT5.
  - Parciais, TP, SL e o copiador não mudam.
- **ESPELHO (v6.04):** esconde ou mostra a VWAP, as bandas, as bolhas e a absorção do indicador **RM_NT8Espelho** no mesmo gráfico.
  - Com o indicador escondido, o botão mostra **ESPELHO OFF**.
  - **Como funciona:** o EA envia um evento ao indicador, que muda só a visibilidade do que já desenhou. Nada é apagado nem recriado.
  - O indicador continua lendo os dados enquanto está escondido, então tudo volta atualizado.
  - Não há verificação periódica, e as ordens não são afetadas.
  - O estado fica salvo por gráfico, inclusive ao trocar o tempo gráfico ou reiniciar o MT5.
  - Precisa do **RM_NT8Espelho v2.1** (`mt5/RM_NT8Espelho.mq5`).
  - O parâmetro opcional "Prefixo dos objetos do indicador a esconder" (ex.: `RMN8_`) só serve para uma versão antiga do indicador. Com a v2.1, deixe vazio.
- **COMPRA / FECHA / VENDA:** mostram a tecla de atalho configurada nos parâmetros.
- **Bloco de estado do dia:** fica verde com LIBERADO e vermelho com BLOQUEADO.
- **Cores:** mensagens em verde, laranja e vermelho foram escurecidas para ficarem legíveis no fundo claro.

**Limites do MT5:** o painel usa objetos do MT5, que não têm cantos arredondados nem sombras. Os "cartões" são retângulos com borda fina.

## Linhas no gráfico

- **Trailing:** linha **azul contínua**.
- **P1 e P2:** linhas **finas, vermelhas e pontilhadas** no preço de cada parcial (entrada ± pontos). Cada linha some quando a sua parcial é executada, e as duas somem quando a posição fecha ou quando as parciais são desligadas.
