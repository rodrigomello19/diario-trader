# SPForcaMercado v1.5: força compradora x vendedora (NinjaTrader 8)

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
- **Barras do delta:** verde (compradores) ou vermelho (vendedores).
- **Cor forte:** quando um lado dominou o candle, ou seja, quando |delta| ≥ 25% do volume do candle (ajustável).
- **Resumo no canto superior esquerdo do painel**, por exemplo:
  ```
  FORCA DA ABERTURA DE NY (09:30 ET, 60 min)
  Compradores 58%  x  Vendedores 42%   |   Delta +3.420   |   Delta acumulado +3.420
  Candle atual: delta +210 | amplitude 42,5 (2,3x a media do horario) | volume 4.812 (RVOL 1,9x)
  Amplitude da janela: 185,25 pts (1,3x a media de 20 dias: 140,1 pts)
  ```
- O horário de NY é convertido automaticamente para o fuso do NT8, inclusive no horário de verão.

## Novidades da v1.5: as suas regiões no estudo

O estudo de padrões agora usa **as regiões que você opera**:

| Região | Origem |
|---|---|
| **Suas linhas e zonas** | Desenhadas por você no gráfico do NT8 (veja abaixo) |
| **vwap** | VWAP do pregão, desde a abertura |
| **max_dia / min_dia** | Máxima e mínima do dia **incluindo o overnight** (desde 18:00 NY do dia anterior), conhecidas até o candle anterior |

As regiões automáticas da v1.4 (dia anterior, overnight separado, faixas de 5 e 15 min) **não entram mais nos padrões**. Continuam só como colunas de distância no arquivo de pesquisa.

### Como marcar as regiões
Use as ferramentas de desenho do NT8 no gráfico do MNQ, o mesmo em que está o indicador:
- **Linha horizontal** (*Horizontal Line*): uma região num preço. **Vale a partir do horário do ponto onde você clicou.** Clique no candle do dia em que identificou a região, normalmente antes da abertura.
- **Destaque de região Y** (*Region Highlight Y*): uma **zona** de preço (ex.: 21.400–21.420). Também vale a partir do horário do ponto clicado.
- **Retângulo** (*Rectangle*): uma zona válida **só entre o horário inicial e o final** do retângulo. É útil para marcar regiões em dias passados e montar o histórico do estudo.

**Regras das zonas no estudo:**
- Na compra, o rompimento é pela **borda superior** e o toque vindo de baixo é pela **borda inferior**. Na venda, é o contrário.
- Uma linha é uma zona de espessura zero.

**Por que a regra do "a partir de":** uma região identificada hoje não pode ser usada para avaliar operações de semanas atrás, porque isso seria olhar o futuro. Por isso cada desenho só vale do ponto de clique em diante, e o retângulo só no seu intervalo.

**Depois de desenhar ou alterar regiões,** recarregue o indicador para refazer os arquivos: clique com o botão direito no gráfico e escolha **Recarregar NinjaScript**, ou use **F5** no gráfico. O cabeçalho de `padroes_<contrato>.csv` informa quantas regiões suas foram lidas (`suas regioes no grafico: N`).

### Como montar o estudo
1. **Daqui para frente (recomendado):** todo dia, antes da abertura, desenhe as suas regiões, como já faz. O indicador registra os padrões em tempo real, e o arquivo cresce a cada pregão. Esse é o teste mais fiel do seu método.
2. **Para o histórico (opcional):** escolha alguns dias passados e marque com **retângulos** as regiões que você teria identificado naquele dia, antes da abertura. Cada retângulo deve cobrir só aquele dia.

O arquivo de pesquisa ganhou as colunas `dist_max_dia`, `dist_min_dia` e `dist_sua_regiao`, que é a distância até a borda da sua região válida mais próxima (0 = dentro de uma zona).

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

As marcas aparecem no painel do indicador, e o candle do sinal é pintado com a mesma cor no gráfico de preço (opcional). Por padrão, só são gerados sinais no pregão de NY (da abertura até 16:00 ET).

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
| Mostrar sinais | sim | Liga as marcas e a estatística |
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

Se usar o indicador duas vezes (delta por candle e delta acumulado), deixe **"Mostrar sinais" ligado em só uma** das instâncias. Assim as marcas e o alerta não aparecem em dobro.

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
| Gráfico | DeltaPorCandle | DeltaPorCandle (barras) ou DeltaAcumulado (linha) |
| Limiar de candle forte | 0,25 | Fração do volume num só lado para pintar com a cor forte |
| Mostrar resumo no gráfico | sim | Texto no canto superior esquerdo do painel |

## Como ler
- **Delta acumulado subindo junto com o preço:** a alta tem agressão compradora real por trás.
- **Divergência:** o preço faz nova máxima e o delta acumulado não acompanha. A alta perde força, porque a agressão compradora está diminuindo.
- **Candle com amplitude ou RVOL bem acima de 1x:** o mercado está mais ativo que o normal para aquele horário. Isso costuma acontecer na abertura e em notícias.
- **Compradores x Vendedores na janela:** resume quem dominou a abertura. Perto de 50/50 indica uma abertura disputada.

Os indicadores descrevem o que já aconteceu. Use como contexto do seu plano, não como sinal isolado.
