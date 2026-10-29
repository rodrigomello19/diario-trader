# Parciais no Scalper Pro (v5.93)

Sistema de parciais da v5.38, trazido para a versão atual.

## Como funciona

| | Padrão | O que faz |
|---|---|---|
| **P1** | 500 pts / 50% | Com 500 pts de lucro, fecha 50% do lote **inicial** |
| **P2** | 1.000 pts / 30% | Com 1.000 pts de lucro, fecha 30% do lote inicial |
| Resíduo | 20% | O que sobra (100% − P1 − P2) continua até o T.P., o SL ou o trailing. Não aparece no painel. |

- **SL depois do P1** ("Após P1"): vai para **entrada + 100 pts**, ou entrada − 100 pts na venda.
- **SL depois do P2** ("Após P2"): vai para o **nível do P1**, entrada + 500 pts.
- Se P1% + P2% passar de 100%, o P2 é reduzido automaticamente.
- Os volumes respeitam o lote mínimo e o passo de lote do ativo. Exemplo com lote 0,20: P1 fecha 0,10, P2 fecha 0,06 e sobram 0,04. Se a parcial deixasse um resto menor que o lote mínimo, ela é ajustada.
- **TP virtual:** se uma parcial ainda não executada estiver no mesmo nível do TP, ela sai primeiro.

## Painel

Nova seção **PARCIAIS** abaixo de PARÂMETROS, seguida de uma linha separadora:

```
PARCIAIS ─────────────────────── [ON]
P1 [ 500 ] pts  [ 50 ] %   [  ATIVO  ]
P2 [1000 ] pts  [ 30 ] %   [  ATIVO  ]
──────────────────────────────────────
[  COMPRA  ] [  FECHA  ] [  VENDA  ]
[NORMAL] [SYNC] [LINHAS] [LIMITES]
```

- **Pontos e %:** são editáveis como os outros campos (clique, digite, Enter). Ficam salvos.
- **ON/OFF:** liga e desliga as parciais. A escolha também fica salva.
- **Status:**

| Status | Significado |
|---|---|
| ATIVO | Aguardando o gatilho |
| Enviando... / Aguardando... | Ordem de fechamento parcial enviada |
| 50% | Parte do volume já saiu (a execução veio em partes) |
| Executada | A parcial saiu |
| Erro / Falhou | A ordem foi recusada. O motivo aparece na barra de status e na aba Experts. O EA tenta de novo no próximo tick. |
| Não exec. | A posição fechou antes de a parcial ser atingida |
| OFF | Parciais desligadas |

Os valores de pontos e % valem para os **dois perfis** (Normal e Volátil).

## Copiador

- **Mãe:** a parcial é publicada na hora, e as **filhas MT5 reduzem a cópia na mesma proporção**. Isso já era o comportamento do copiador.
- **Filhas MT5:** não fazem parcial própria nas posições copiadas, para não reduzir em dobro. Operações manuais feitas na própria filha seguem as parciais normalmente.
  - Na filha com "SL/TP/trailing da boleta da filha", o SL da cópia **não** avança junto com o da mãe depois do P1/P2. Ele segue o trailing da boleta da filha.
- **Filha NinjaTrader:** opera um número fixo de contratos e **não reduz** com as parciais da mãe.

## Pontos da operação

Com parciais, a operação tem várias saídas. Os pontos da operação (painel, limites do dia e Central de Controle) agora usam o **preço médio das saídas, ponderado pelo volume**. Antes era usado só o preço da última saída.

Exemplo: 50% sai a +500, 30% a +1.000 e 20% a +100. A operação conta (0,5 × 500 + 0,3 × 1.000 + 0,2 × 100) = **+570 pts**. Pelo cálculo antigo seriam só +100.

## Parâmetros (grupo "Parciais")

| Parâmetro | Padrão |
|---|---|
| Usar parciais | sim |
| P1: pontos / % do lote inicial | 500 / 50 |
| P2: pontos / % do lote inicial | 1000 / 30 |
| Após P1: SL vai para entrada + X pts | sim, X = 100 |
| Após P2: SL vai para o nível do P1 | sim |
| Tentativas de envio por parcial / espera entre tentativas | 3 / 100 ms |

Os parâmetros de entrada valem na primeira carga e sempre que forem alterados. Depois disso, valem os valores editados no painel.
