# SPForcaMercado: força compradora x vendedora (NinjaTrader 8)

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
