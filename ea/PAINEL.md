# Painel do Scalper Pro (v5.94): opção A, tema claro

```
Scalper Pro  v5.94 | US100                    [-] [X]
┌ PARÂMETROS ─────────────────── [Normal|Volátil] ┐
│ Lote               Take profit             pts  │
│ [-][  0.20  ][+]   [ 1500                    ]  │
│ Stop loss     pts  Trail / Step           FIXO  │
│ [ 1000           ] [  500    ] [  100        ]  │
└─────────────────────────────────────────────────┘
┌ PARCIAIS ─────────────────────────────── [ON] ┐
│     Gatilho (pts)   % do lote   Status         │
│ P1  [   500    ]    [  50  ]    [  ATIVO   ]   │
│ P2  [  1000    ]    [  30  ]    [  ATIVO   ]   │
└────────────────────────────────────────────────┘
[   COMPRA   ] [   FECHA   ] [   VENDA   ]
    tecla I        tecla O       tecla P
[   SYNC    ] [  LINHAS   ] [  LIMITES  ]
┌ LIBERADO │  Oper  │ Pontos │ Spread ┐
│          │  2/3   │  +840  │   12   │
└──────────┴────────┴────────┴────────┘
Status (última ação)
Copiador
```

- **Perfil Normal/Volátil:** fica no topo do cartão PARÂMETROS. Clique no perfil que quer usar.
- **Lote:** os botões − e + mudam o lote pelo passo do ativo.
  - Digite um número inteiro (3, 20) e pressione **Enter** ou clique fora do campo: ele vira **3.00** ou **20.00**.
  - As casas decimais seguem o passo do lote do ativo, com no mínimo 2.
- **Clicar fora de um campo confirma o valor.** Antes, clicar fora descartava o que foi digitado. **Esc** continua cancelando.
- **Trail / Step:** a etiqueta **FIXO / DINÂMICO** à direita alterna o modo do trailing.
- **COMPRA / FECHA / VENDA:** mostram a tecla de atalho configurada nos parâmetros.
- **Bloco de estado do dia:** fica verde com LIBERADO e vermelho com BLOQUEADO.
- **Cores:** mensagens em verde, laranja e vermelho foram escurecidas para ficarem legíveis no fundo claro.

**Limites do MT5:** o painel usa objetos do MT5, que não têm cantos arredondados nem sombras. Os "cartões" são retângulos com borda fina.
