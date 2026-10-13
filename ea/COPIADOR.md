# Copiador MT5 do Scalper Pro (v5.84)

Copia as posições de uma conta **mãe** para uma ou mais contas **filhas** em terminais MT5 da **mesma máquina**.
A comunicação é feita por um arquivo em `Terminal\Common\Files`, uma pasta que todos os terminais do usuário enxergam. Não usa DLL, porta nem IP.

## Como ligar

1. **Terminal da mãe**: no gráfico do ativo (ex.: `US100`), defina `Modo do copiador = Mae` e um `Canal` (ex.: `SP1`).
2. **Terminal da filha**: no gráfico do ativo equivalente na outra corretora (ex.: `US100.cash`), defina `Modo do copiador = Filha` e o **mesmo canal**.
3. Em ambos, deixe o AutoTrading ligado.

O mapeamento de símbolo é automático: cada lado usa o símbolo do próprio gráfico.
A mãe grava `Common\Files\SP_Copy_<canal>.txt`, e a filha lê esse arquivo a cada `Intervalo` ms (padrão 20 ms).

## Como funciona

- **Copia posições, não sinais.** A mãe publica a lista de posições do símbolo (id, direção, volume, entrada, SL e TP). A filha compara com as cópias dela e corrige as diferenças:
  - abre uma cópia quando aparece uma posição nova na mãe;
  - fecha a cópia quando a posição some da mãe;
  - reduz a cópia na mesma proporção quando a mãe faz uma parcial;
  - ajusta SL/TP sempre que a mãe muda (trailing, arraste, tecla R).
- **A mãe publica no `OnTradeTransaction`**, antes de qualquer outro processamento da entrada. Além disso, regrava o arquivo a cada 250 ms (heartbeat).
- **Reinícios:** como o estado inteiro é publicado, a filha se reconcilia sozinha quando qualquer terminal reinicia. Fechar o EA da mãe não fecha nada na filha.
- **Sem reabertura:** uma cópia estopada na filha não é reaberta enquanto a posição da mãe continuar aberta.
- **As cópias usam um magic próprio** (`Filha: magic`), e o comentário da ordem é `SPC|<id da mãe>`. No modo de SL/TP diferente de "LOCAL", o trailing, o TP do perfil e a reversão de SL manual do EA **não** mexem nas cópias.
- **Log da filha:** cada cópia registra o tempo de execução e o tempo total desde a gravação da mãe.

## Parâmetros (grupo "Copiador MT5")

| Parâmetro | Lado | Descrição |
|---|---|---|
| Modo do copiador | ambos | Desligado / Mae / Filha |
| Canal | ambos | Nome do canal. Tem que ser igual na mãe e nas filhas. Use canais diferentes para pares independentes. |
| Intervalo de envio/leitura (ms) | ambos | Timer do copiador. As rotinas de 1 s do EA continuam a cada 1 s. |
| Calculo do lote | filha | `Lote da mae x multiplicador`, `Mesma exposicao (tam. contrato) x multiplicador`, `Lote fixo` ou `Risco % do saldo ate o SL` |
| Multiplicador / lote fixo / risco % | filha | Valor usado pelo modo de lote escolhido |
| Lote maximo | filha | Teto do lote da cópia (0 = sem limite) |
| Como copiar SL/TP | filha | Ver abaixo |
| SL emergencia | filha | SL em pontos a partir da entrada da filha, usado quando a mãe não tem SL ou no modo "só fecha" (0 = não usar) |
| Inverter direcao | filha | A filha opera o lado oposto (SL e TP da mãe trocam de papel) |
| Idade maxima da posicao da mae (s) | filha | Não copia posições abertas na mãe há mais tempo que isso. Evita entrar atrasado depois de um reinício. 0 = sem limite. |
| Desvio maximo na execucao (pts) | filha | Slippage aceito na ordem a mercado |
| Fechar copias se a mae ficar offline (s) | filha | Fecha as cópias se a mãe parar de gravar por esse tempo. 0 = nunca. |
| Magic das ordens copiadas | filha | Precisa ser maior que 0. Use um magic diferente para cada canal no mesmo terminal. |

### Modos de SL/TP da filha

- **Preco da mae + diferenca de cotacao** (padrão): SL e TP ficam no mesmo nível de mercado da mãe. A diferença entre as cotações das duas corretoras é medida no momento da cópia (bid da filha − bid da mãe). Esse modo evita a filha ser estopada num nível diferente da mãe.
- **Mesma distancia a partir da entrada da filha**: copia a distância em preço entre a entrada e o SL/TP da mãe. É o comportamento do DGX.
- **SL/TP/trailing do proprio EA**: copia só entrada e saída. SL, TP e trailing seguem o perfil do Scalper na filha.
- **Nao copia SL/TP**: a filha fecha quando a mãe fechar. Use `SL emergencia` como proteção.

Se o SL/TP da mãe já estiver atingido no preço da filha, a filha fecha (ou não abre) a cópia.

## Limitações

- O copiador não funciona no Strategy Tester, onde ele é desligado automaticamente.
- Contas **netting** funcionam, mas cada símbolo tem uma posição só. O suporte foi pensado para contas hedging.
- Mesas proprietárias (ex.: FTMO) têm regras próprias sobre copy trade. Confirme com elas antes de usar.
