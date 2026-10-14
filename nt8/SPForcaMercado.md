# SPForcaMercado v1.2: força compradora x vendedora (NinjaTrader 8)

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
| Divergência: candles da máxima/mínima | 10 | Tamanho da janela usada para identificar a nova máxima ou mínima |
| Sinais só no pregão de NY | sim | Da abertura até 16:00 ET |
| Pintar o candle do sinal | sim | Pinta o candle no gráfico de preço |
| Alerta sonoro em tempo real | não | Toca um som e registra na aba Alertas |
| Alvo / Stop para contar acerto (pontos) | 20 / 20 | Critério da estatística |
| Candles para avaliar | 10 | Prazo máximo para alvo ou stop |

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
