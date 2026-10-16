# SPForcaMercado v1.9: força compradora x vendedora (NinjaTrader 8)

Indicador para futuros (MNQ, NQ, MGC, GC...) no gráfico de **1 minuto**. Ele mede **quem agrediu**, compradores ou vendedores, e **quanto o mercado está se mexendo** em relação ao normal daquele horário.

## O que ele calcula

| Medida | Como é calculada |
|---|---|
| **Delta do candle** | Volume comprado − volume vendido no candle. Cada negócio é classificado pela agressão: executado no ask ou acima = compra; no bid ou abaixo = venda; dentro do spread = direção do último preço. |
| **Delta acumulado** | Soma do delta desde a **abertura de NY** (09:30 ET por padrão), zerado todo dia. |
| **Compradores x Vendedores %** | Volume comprado e vendido na janela da abertura (padrão: 60 min) |
| **Amplitude relativa** | Amplitude do candle ÷ média do **mesmo minuto** nos últimos N dias (ex.: 2,3x = candle 2,3 vezes maior que o normal para aquele horário) |
| **RVOL** | Volume do candle ÷ média do mesmo minuto nos últimos N dias |
| **Amplitude da janela** | Máxima − mínima desde a abertura, comparada à média dos dias anteriores |

### No gráfico
- **Barras do delta** (painel do indicador): verde (compradores) ou vermelho (vendedores). A cor fica forte quando um lado dominou o candle, ou seja, quando |delta| ≥ 25% do volume (ajustável).
- **Setas e marcas EX** no gráfico de **preço** (v1.7).
- **Painéis** de volatilidade e de leitura do candle no painel do indicador, arrastáveis com o mouse.
- O horário de NY é convertido automaticamente para o fuso do NT8, inclusive no horário de verão.

## Novidades da v1.9: barras para cima e painel compacto

- **Barras do delta sempre para cima.** A altura é o tamanho do delta, mesmo que o gráfico salvo esteja no modo antigo "DeltaPorCandle". O modo DeltaAcumulado continua sendo uma linha.
- **Cor das barras** (grupo 2. Exibição):
  - **PelaAgressao** (padrão): verde quando os compradores dominaram o delta, vermelho quando foram os vendedores.
  - **PeloCandle**: verde em candle de alta, vermelho em candle de baixa.
  - Nos dois casos, a cor fica forte quando um lado ficou com 25% ou mais do volume.
- **Painel compacto** (padrão): uma caixa só, fonte 11, fundo 45% transparente e cerca de 6 linhas curtas:
  ```
  VOL LENTA 0,58x | alvo 40: 61%
  5min C 64% x 36% V  Δ+1.240
  Agora Δ+210 z+2,4 FORTE
  10:42 ALTA fech 88% z+2,6 RVOL 1,8x
  F 51% n387 | EX 52% n141 | EXc 67% n72
  Ult: EXc▲ 10:13
  ```
  - **Clique** no painel para alternar entre compacto e detalhado. **Arraste** para mover.
  - Tamanho da fonte e opacidade do fundo (0 = sem fundo) ficam no grupo 2. Exibição.

## Novidades da v1.8 (depois do estudo de 93 pregões)

**O que o estudo mostrou** (18/05 a 15/10/2026, 09:30–10:30 NY, alvo 40 antes de stop 40 em 15 candles; o acaso dá ~50%):

| Sinal | Casos | Acerto | Leitura |
|---|---|---|---|
| Seta F (v1.7, z contra os últimos 200 candles) | 1.779 | 49–50% | Sem vantagem. E aparecia em **35% dos candles**: o normal dos últimos 200 candles inclui o overnight calmo, então quase todo candle da abertura parecia "acima da média". |
| Seta com z do **mesmo minuto** (v1.8) | 387 (8,5% dos candles) | 48–53% | Mais seletiva, mas também **sem vantagem direcional**. Serve como informação de agressão, não como gatilho. |
| EX (v1.7) | 141 | 51% | Sem vantagem sozinho. 129 dos 149 EX caíram nos 10 primeiros minutos. |
| **EX + candle seguinte confirmando** | 72 | **67%** (±11) | Único resultado acima do acaso, **mas ainda não confirmado**: 54% na 1ª metade dos dias e 77% na 2ª. Testei cerca de 10 variações, e uma delas pode ter dado certo por sorte. Ele precisa repetir em dias **novos**. |

**Mudanças:**
- **Seta e z-score da leitura:** o delta agora é comparado ao **mesmo minuto dos últimos 20 dias**, como já acontecia com a amplitude e o RVOL. São necessários pelo menos 10 dias de base. Antes disso, vale o cálculo antigo. Com o padrão 2,0, a seta aparece em ~1 candle a cada 12 na abertura.
- **Nova marca EXc▲ / EXc▼:** aparece no candle **seguinte** a um EX quando ele fecha na direção da reversão (candle de alta, no EX▲) e acima do fechamento do EX. A entrada medida é o fechamento desse candle. A estatística é separada na caixa de leitura e no CSV.
- O arquivo de pesquisa ganhou a coluna `zscore_horario`.

## Novidades da v1.7: seta de agressão e esgotamento no gráfico

- **Saiu o painel "Força da abertura".** Ficam só a caixa de **volatilidade** e a de **leitura do candle**. A primeira caixa pode ser arrastada e leva a outra junto.
- Os sinais antigos **C/A/D ficam desligados por padrão**, porque o estudo não mostrou vantagem neles. Para religar, use "Mostrar sinais antigos C/A/D".

### Seta de agressão acima da média (↑ / ↓)
- Aparece no **fechamento** do candle quando o delta fica **pelo menos 2 desvios padrão** acima ou abaixo da média dos últimos 200 candles (z-score ≥ 2,0, ajustável). Isso acontece em cerca de 1 candle a cada 20.
- **↑ verde** abaixo da mínima = compradores agrediram muito acima do normal. **↓ vermelha** acima da máxima = vendedores.
- A seta não muda depois de desenhada, porque só é avaliada com o candle fechado. Para acompanhar a agressão **durante** o candle, use a linha "Candle em formação" da leitura, que mostra o z-score ao vivo.
- Precisa de dados de negócio (**Tick Replay** no histórico).

### Esgotamento / absorção (EX▲ / EX▼)
Exemplo na venda (EX▲, amarelo, abaixo da mínima):
1. Nos **5 candles anteriores**, pelo menos **3 foram de baixa** e o preço caiu no período.
2. Vem um candle com **amplitude ≥ 1,8x** e **volume ≥ 1,8x** a média dos 10 candles anteriores...
3. ...que faz **nova mínima** dos 5 candles.

Leitura: os vendedores podem ter gasto a força nesse empurrão, e há chance de os compradores entrarem a partir do fechamento desse candle ou dos próximos. Na compra é o espelho (**EX▼**, magenta, acima da máxima).

O texto do sinal na caixa de leitura classifica o candle:

| Classificação | Quando |
|---|---|
| **ABSORÇÃO** | O delta foi forte na direção da tendência (z ≥ 1,5), mas o candle voltou pelo menos 40% do extremo: a agressão bateu em ordens passivas |
| **REJEIÇÃO** | O candle voltou pelo menos 50% do extremo |
| **CLÍMAX** | Fechou no extremo (menos de 25% de volta). Pode haver mais um empurrão antes de virar, então é mais prudente esperar o candle seguinte confirmar |
| **ESGOTAMENTO** | Os demais casos |

- Usa só **preço e volume**, então funciona **também sem Tick Replay**. Com dados de negócio, o delta entra na classificação.
- O candle do EX é pintado (opção "Pintar o candle do sinal").

### Estatística no seu histórico
Na caixa de leitura aparece, para cada sinal ligado, o resultado no histórico carregado:
```
Sinais no seu historico (40 pregao(oes) com negocios; alvo 40 antes de stop 40 pts em ate 15 candles):
  F▲ 52% (31/60) +4 neutros, a favor 38 / contra 41 pts   |   F▼ 49% (28/57) +3 neutros, a favor 36 / contra 40 pts
  EX▲ 58% (11/19), a favor 45 / contra 33 pts   |   EX▼ 50% (8/16) +1 neutros, a favor 39 / contra 37 pts
Ultimo sinal: EX▲ 10:12 ET - esgotamento da venda (possivel entrada compradora): ABSORCAO: vendedores agrediram forte e o preco nao acompanhou | ...
```
(números ilustrativos)
- Entrada no fechamento do candle do sinal, alvo 40 antes de stop 40 em até 15 candles, como nos outros sinais. "A favor / contra" é a média do maior movimento a favor e contra no prazo.
- Com alvo = stop, o acaso dá **~50%**. Só confie numa taxa **acima disso, com 30 casos ou mais**. O EX é raro (alguns por semana na janela), então precisa de muitos dias carregados.
- Todos os sinais vão também para `sinais_<contrato>.csv`.
- Por padrão os sinais só aparecem no **horário dos sinais (09:30–10:30 NY)**. Para vê-los o dia todo, desmarque "Sinais só no horário abaixo".

### Parâmetros (grupo "3a. Setas e esgotamento")

| Parâmetro | Padrão | Descrição |
|---|---|---|
| Seta de agressão acima da média | sim | Liga as setas |
| Seta: z-score mínimo do delta | 2,0 | 2,0 ≈ 1 candle em 20; 3,0 ≈ 1 em 100 |
| Marcar esgotamento/absorção (EX) | sim | Liga as marcas EX |
| EX: candles da tendência anterior | 5 | Quantos candles olhar para trás |
| EX: mínimo de candles na direção | 3 | Quantos deles precisam fechar na direção da tendência |
| EX: candles para a média de amplitude e volume | 10 | Base de comparação do candle grande |
| EX: amplitude mínima (x a média) | 1,8 | Quanto maior, mais raro e mais "climático" |
| EX: volume mínimo (x a média) | 1,8 | Idem para o volume |

## Novidades da v1.6: leitura do candle em tempo real

O estudo de regiões e padrões (v1.4 e v1.5) foi **retirado**. No lugar, abaixo do filtro de volatilidade, entra a caixa **LEITURA DO CANDLE**, com as três informações para a hora da operação:

```
LEITURA DO CANDLE
Agressao ultimos 5 min: COMPRADORES 64% x 36% VENDEDORES (delta +1.240)
Candle em formacao: compradores 71% | delta +210 (z +2,4: FORTE)
Ultimo candle 10:42: COMPRA | fechou a 88% do extremo | corpo 75% | delta +860 (z +2,6: FORTE, 31% do volume) | RVOL 1,8x | amplitude 1,6x
Continua (rompe a maxima antes da minima em ate 5 min): 87% no seu historico (n=812) | pela posicao do fechamento: 88% -> a agressao NAO mudou a chance (dif. -1 p.p.)
Sinais: agressao forte a favor e fechou no extremo
```

| Linha | O que mostra |
|---|---|
| Agressão últimos 5 min | Quem dominou os últimos 5 minutos (candle atual incluído). A borda da caixa fica verde ou vermelha conforme o lado. |
| Candle em formação | Agressão do candle atual, ao vivo, com o nível pelo z-score: fraca (< 1), moderada (1–2), **FORTE** (2–3), **EXTREMA** (≥ 3) |
| Último candle | Tipo, posição do fechamento (100% = no extremo a favor), tamanho do corpo, delta, z-score, % do volume, RVOL e amplitude relativa |
| **Continua** | Em candles parecidos no seu histórico (mesma faixa de posição do fechamento e de agressão), quantas vezes o preço **rompeu o extremo a favor antes do oposto** nos 5 minutos seguintes. Ao lado, a chance **só pela posição do fechamento**: um candle que fecha na máxima tem a máxima a 1 tick e a mínima longe, então "continuar" é quase automático. A diferença entre os dois números é o que a **agressão acrescentou de fato**. |
| Sinais | Descrição do candle: agressão forte a favor; absorção ou esgotamento (agressão forte, mas o candle fechou longe do extremo); agressão contrária; pavio de rejeição; candle climático (amplitude e volume ≥ 2x) |

- A estatística de continuação usa os candles do **horário dos sinais** (padrão 09:30–10:30 NY), com dados de negócio (Tick Replay), e fica mais precisa conforme você carrega mais dias.
- **Liga/desliga:** grupo **7. Leitura do candle**.

**O que os seus 93 pregões mostraram:**
- A chance de continuar segue quase exatamente a posição do fechamento. Fechou a 90% ou mais do extremo: ~94% de continuação, contra ~95% esperados pelo acaso. Fechou abaixo de 30%: ~22%, contra ~22%.
- **Descontado isso, a agressão não mudou a chance em nenhuma faixa** (diferenças de ±3 p.p., sem repetir entre as duas metades dos dados).
- A caixa mostra os dois números para você acompanhar ao vivo se isso continua valendo.

## Novidades da v1.4

### Filtro de volatilidade
Abaixo do resumo aparece uma caixa colorida:

```
VOLATILIDADE LENTA: 0,58x o normal do horario (ultimos 3 candles) | historico nessa faixa: alvo de 40 pts alcancavel em 15 min em 61% (n=1160), maior movimento medio 47 pts
```

- **LENTA** (laranja), **NORMAL** (cinza) ou **RÁPIDA** (verde): média da amplitude dos últimos 3 candles comparada à amplitude normal do mesmo minuto nos últimos 20 dias. Os limites padrão são 0,65x e 1,28x, tirados do estudo da abertura.
- **O percentual é calculado no seu próprio histórico carregado:** é a fração das vezes, naquela faixa de volatilidade, em que o preço andou pelo menos o alvo (40 pts) para algum dos lados em até 15 minutos. Ele responde à pergunta "há volatilidade suficiente para o meu alvo agora?".
- Parâmetros no grupo **6. Volatilidade**: liga/desliga, número de candles e os limites de lenta e rápida.

### Estudo do método regiões + volatilidade + gatilho
O modo pesquisa agora registra as **regiões** e os **quatro padrões** do método.

**Regiões** (só as já conhecidas no momento do candle):

| Região | Como é calculada |
|---|---|
| max_ontem / min_ontem / fech_ontem | Máxima, mínima e fechamento do pregão anterior (09:30–16:00 NY) |
| max_overnight / min_overnight | Máxima e mínima do overnight (16:00 até a abertura) |
| max_faixa5 / min_faixa5 | Faixa dos 5 primeiros minutos (disponível a partir do minuto 6) |
| max_faixa15 / min_faixa15 | Faixa dos 15 primeiros minutos (disponível a partir do minuto 16) |
| vwap | VWAP do pregão, desde a abertura |

**Padrões** (exemplo na compra; na venda é o espelho). O gatilho é sempre o fechamento do candle indicado:

| Padrão | Tipo | Regra |
|---|---|---|
| **climax** | continuação | O candle fecha acima da região, vindo de baixo, com amplitude ≥ 1,2x o normal e fechamento nos 30% superiores. Compra no fechamento. |
| **pullback** | continuação | Depois de romper, o preço volta e testa a região (pavio até 5 pts dela) sem fechar abaixo. Em até 3 candles, um candle fecha **acima da máxima do candle do teste**. Compra. |
| **falha** | reversão | Rompeu para cima e, em até 5 candles, fecha **de volta abaixo** da região. Venda. |
| **reversao** | reversão | Depois de subir ≥ 60 pts em 15 candles, toca a região por baixo (pavio até 5 pts) sem romper. Em até 3 candles, um candle fecha **abaixo da mínima do candle do toque**. Venda. |

- Só um evento por padrão, região, lado e dia, sempre dentro do horário dos sinais (padrão 09:30–10:30 NY).
- Os eventos ficam em `Documentos\NinjaTrader 8\SPForca\padroes_<contrato>.csv`, com:
  - região, nível, distância, volatilidade e delta no momento;
  - resultado do alvo e stop (40/40 em 15 candles), movimento a favor em 15 min e máximo a favor e contra.
- O arquivo `pesquisa_<contrato>.csv` ganhou colunas com a **distância do fechamento até cada região**, os movimentos de 5 e 15 minutos, a volatilidade recente e um indicador de existência de dados de negócio.
- Parâmetros no grupo **5. Pesquisa**: tolerância de toque (5 pts) e movimento mínimo para a reversão (60 pts).

### Sem Tick Replay
O modo pesquisa funciona **também sem Tick Replay**. Nesse caso as colunas de delta ficam zeradas e `tem_negocios = 0`. Isso permite estudar os padrões de preço e as regiões em **1 a 2 anos de dados de 1 minuto**, que carregam rápido. O efeito do delta continua sendo estudado nos dias com Tick Replay.

## Novidades da v1.3 (pesquisa da abertura)

- **Horário dos sinais:** por padrão, só das **09:30 às 10:30 de NY**, que corresponde a **10:30 às 11:30 em Brasília** enquanto os EUA estão no horário de verão. Quando o horário de verão americano termina (novembro a março), as mesmas 09:30–10:30 de NY passam a ser **11:30–12:30 em Brasília**. O indicador sempre usa o horário de NY, então não é preciso mudar nada.
  - **Atenção:** "Abertura de NY" e o horário dos sinais são **em horário de NY**. Não coloque 10:30 pensando em Brasília.
- **Divergência mais seletiva:**
  - usa a máxima ou mínima dos últimos **20 candles** (antes eram 10);
  - exige que o delta acumulado fique pelo menos **1 desvio padrão** (do delta por candle) abaixo do topo, ou acima do fundo, anterior.
- **Alvo e stop padrão de 40 / 40 pontos**, avaliados em até **15 candles**. No MNQ, 40 pontos equivalem ao alvo de 1.000 pontos usado na Hantec.
- **Modo pesquisa (ligado por padrão):** grava **todos os candles do horário dos sinais**, não só os sinais, em `Documentos\NinjaTrader 8\SPForca\pesquisa_<contrato>.csv`.

### Colunas do arquivo de pesquisa

| Coluna | Significado |
|---|---|
| data, hora_ET, min_desde_abertura | Quando o candle fechou |
| abertura, maxima, minima, fechamento, volume | OHLC e volume |
| compra, venda, delta, zscore, pct_volume | Agressão do candle |
| fechamento_no_candle_pct | Onde fechou dentro do candle (0 = mínima, 100 = máxima) |
| rvol, amplitude, amplitude_rel | Volume e amplitude comparados à média do mesmo minuto |
| delta_acum, delta_acum_5min | Delta acumulado desde a abertura e quanto ele variou nos últimos 5 minutos |
| pos_na_faixa_pct | Posição do fechamento na faixa da abertura até agora (0 = mínima, 100 = máxima) |
| sinal | Sinal marcado nesse candle, se houver |
| fwd5_pts, fwd10_pts, fwd15_pts | Quanto o preço andou 5, 10 e 15 minutos depois |
| max_alta15_pts, max_baixa15_pts | Maior alta e maior baixa nos 15 minutos seguintes |
| compra_alvo_antes_stop / venda_alvo_antes_stop | O que uma compra ou venda no fechamento teria feito: `alvo`, `stop` ou `nenhum` (critério alvo/stop, conservador) |
| compra_candles / venda_candles | Em quantos candles o alvo ou o stop foi atingido |

Com esse arquivo é possível descobrir **quais condições da abertura antecedem continuação ou reversão**, em vez de testar só as regras prontas dos sinais.

Para gerar: carregue os dias com Tick Replay. Os arquivos são gravados quando o gráfico termina de carregar o histórico.

## Novidades da v1.2

- **Barras só para cima (padrão "Gráfico = DeltaColorido"):** a altura é o tamanho do delta e a cor mostra o lado (verde = compradores, vermelho = vendedores). A cor fica forte quando um lado dominou o candle. Os modos antigos continuam disponíveis: DeltaPorCandle (para cima e para baixo) e DeltaAcumulado.
- **Resumo arrastável:** clique no quadro e arraste para qualquer posição do painel. A posição fica salva no workspace e no template do gráfico.
- **Resultado de cada sinal no gráfico:** quando o sinal é decidido, o rótulo ganha **✓** (acerto), **✗** (erro) ou **•** (neutro). Ex.: `C▲ ✓`.
- **Arquivo com todos os sinais (comprovante):** `Documentos\NinjaTrader 8\SPForca\sinais_<contrato>.csv` (ex.: `sinais_MNQ_12-26.csv`).
  - Abre no Excel, separado por ";". Tem uma linha por sinal decidido, com data, hora ET, tipo, preço de entrada, delta, z-score, % do volume, onde o candle fechou, RVOL, resultado, hora do resultado, candles até o resultado e o **máximo a favor e contra** (em pontos).
  - O arquivo é refeito a cada carga do gráfico com todo o histórico, e os sinais em tempo real são acrescentados ao final.
- **O resumo informa em quantos pregões havia dados de negócio** (Tick Replay). Isso mostra se a estatística tem base suficiente.

## Sinais de agressão (v1.1)

Cada candle fechado é avaliado. A **agressão forte** é medida pelo **z-score do delta**: quantos desvios padrão o delta do candle ficou acima do normal dos últimos 200 candles (padrão: 2,0). O que diferencia os sinais é **como o preço reagiu** a essa agressão:

| Marca | Nome | Condição | Leitura |
|---|---|---|---|
| **C▲** (verde) / **C▼** (vermelho) | Continuação | Agressão forte, ≥ 25% do volume num só lado, RVOL ≥ 1,2 e o candle **fechou no extremo** a favor (30% superior ou inferior) | A agressão moveu o preço. Há tendência de continuação. |
| **A▲** (azul) / **A▼** (laranja) | Absorção | Agressão forte, mas o candle **fechou contra** a agressão. Ex.: venda forte e candle de alta. | Ordens passivas seguraram o preço. Possível reversão no sentido da seta. |
| **D▲** / **D▼** (violeta) | Divergência | Nova máxima (ou mínima) dos últimos 10 candles **sem o delta acumulado confirmar** | O movimento perdeu agressão. Possível exaustão ou reversão. |

A partir da v1.7 as marcas aparecem no gráfico de preço, e o candle do sinal é pintado com a mesma cor no gráfico de preço (opcional). Por padrão, só são gerados sinais no pregão de NY (da abertura até 16:00 ET).

### Probabilidade medida no seu histórico
O indicador **testa cada sinal nos dias carregados** e mostra a taxa de acerto no resumo:

```
Acerto dos sinais (alvo 20 antes de stop 20 pts, ate 10 candles):
  C▲ 61% (27/44)   |   C▼ 57% (21/37)
  A▲ 54% (13/24)   |   A▼ 48% (10/21) +3 neutros
  D▲ 52% (16/31)   |   D▼ 58% (19/33) +2 neutros
Ultimo sinal: A▲ 10:42 ET - absorcao da venda (reversao p/ cima): delta -1.250 (z -2,8), 41% do volume, fechou a 72% do candle
```

Os números acima são ilustrativos.

- **Acerto:** o preço andou **+alvo** a favor do sinal antes de andar **−stop** contra, dentro de K candles. A entrada é o fechamento do candle do sinal.
- Se alvo e stop forem tocados no **mesmo candle**, o caso conta como **erro** (critério conservador).
- **Neutro:** nem alvo nem stop dentro do prazo.

**Como interpretar:**
- Com alvo igual ao stop, o acaso dá cerca de **50%**. Um sinal só tem vantagem se ficar consistentemente acima disso **com amostra grande**: 30 casos ou mais. Com poucos casos, a porcentagem engana.
- Teste os parâmetros que combinam com o seu operacional. Por exemplo, alvo e stop iguais ao TP/SL da sua boleta, e "Candles para avaliar" igual ao tempo médio das suas operações.
- Carregue mais dias (60 ou mais, com Tick Replay) para ter amostras maiores. O gráfico demora mais para abrir.
- **Resultado passado não garante resultado futuro.** Use os sinais como contexto do seu plano, não como gatilho automático.

### Parâmetros dos sinais

| Parâmetro | Padrão | Descrição |
|---|---|---|
| Mostrar sinais antigos C/A/D | não (v1.7) | Liga as marcas C/A/D e a estatística delas |
| Agressão forte: z-score do delta | 2,0 | Quanto maior, mais raros e mais fortes os sinais |
| Continuação: RVOL mínimo | 1,2 | Volume do candle em relação à média do mesmo minuto. 0 = não exigir. |
| Divergência: candles da máxima/mínima | 20 | Tamanho da janela usada para identificar a nova máxima ou mínima |
| Sinais só no horário abaixo | sim | Usa o horário dos sinais (padrão 09:30–10:30 NY) |
| Horário dos sinais: início / fim (NY) | 09:30 / 10:30 | Janela dos sinais e do modo pesquisa |
| Divergência: diferença mínima do delta acumulado | 1,0 | Em desvios padrão do delta por candle. 0 = qualquer diferença. |
| Modo pesquisa | sim | Grava todos os candles da janela em `pesquisa_<contrato>.csv` |
| Pintar o candle do sinal | sim | Pinta o candle no gráfico de preço |
| Alerta sonoro em tempo real | não | Toca um som e registra na aba Alertas |
| Alvo / Stop para contar acerto (pontos) | 40 / 40 | Critério da estatística e do modo pesquisa |
| Candles para avaliar | 15 | Prazo máximo para alvo ou stop |

Se usar o indicador duas vezes (delta por candle e delta acumulado), deixe **os sinais e as setas ligados em só uma** das instâncias. Assim as marcas e o alerta não aparecem em dobro.

## Instalação

1. Copie `SPForcaMercado.cs` para `Documentos\NinjaTrader 8\bin\Custom\Indicators\`.
2. No NT8, abra **Novo > Editor NinjaScript** e compile com **F5**. Se aparecer erro, envie as mensagens.
3. Abra um gráfico do **MNQ** (ou NQ) de **1 minuto**.
4. Em **Data Series**, configure:
   - **Tick Replay: marcado.** Sem ele, o histórico fica sem delta e o cálculo começa só quando o gráfico abre.
   - **Days to load:** pelo menos o número de "Dias para a média do horário" + 1 (padrão 20 → 21 dias).
5. Adicione o indicador **SPForcaMercado** em **Indicadores**.
6. Para ver as duas visões ao mesmo tempo, adicione o indicador **duas vezes**: uma com "Gráfico = DeltaPorCandle" e outra com "Gráfico = DeltaAcumulado".

O Tick Replay carrega todos os negócios do histórico. Com muitos dias, o gráfico demora mais para abrir e usa mais memória.

## Parâmetros

| Parâmetro | Padrão | Descrição |
|---|---|---|
| Abertura de NY (horário de NY) | 09:30 | Início da contagem do delta acumulado e da janela |
| Janela da abertura (min) | 60 | Período resumido no painel. 0 = sessão toda. |
| Dias para a média do horário | 20 | Base da amplitude relativa, do RVOL e da amplitude média da abertura |
| Gráfico | DeltaColorido | DeltaColorido (barras para cima), DeltaPorCandle ou DeltaAcumulado (linha) |
| Limiar de candle forte | 0,25 | Fração do volume num só lado para pintar com a cor forte |
| Mostrar painéis | sim | Caixas de volatilidade e leitura do candle no painel do indicador |

## Como ler
- **Delta acumulado subindo junto com o preço:** a alta tem agressão compradora real por trás.
- **Divergência:** o preço faz nova máxima e o delta acumulado não acompanha. A alta perde força, porque a agressão compradora está diminuindo.
- **Candle com amplitude ou RVOL bem acima de 1x:** o mercado está mais ativo que o normal para aquele horário. Isso costuma acontecer na abertura e em notícias.

Os indicadores descrevem o que já aconteceu. Use como contexto do seu plano, não como sinal isolado.
