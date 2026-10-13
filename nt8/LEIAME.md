# SPCopyFilhaNT: filha NinjaTrader 8 do copiador Scalper Pro

Copia as posições da conta **mãe no MT5** (Scalper Pro em modo `Mae`) para uma conta no **NinjaTrader 8**, por exemplo uma conta **Tradovate** conectada no NT8. Tudo roda na mesma máquina.

A lógica é a mesma da filha MT5: **o NT8 copia posições, não sinais**. A estratégia lê o mesmo arquivo de estado que a mãe grava em `Common\Files` e corrige as diferenças:

| Na mãe | Na filha NT8 |
|---|---|
| Abriu posição | Abre a mercado no contrato da estratégia, **sempre com SL/TP** (template ATM ou bracket em ticks) |
| Fechou a posição | Envia a ordem a mercado de saída e, logo em seguida, cancela o SL/TP (ou fecha o ATM). A estratégia continua habilitada. |
| Virou a mão | Zera a filha. A nova posição da mãe é copiada em seguida. |
| Continua aberta, mas a filha saiu por SL/TP | **Não reabre** |
| Reinício do MT5 ou do NT8 | O estado é reconciliado pelo arquivo. O estado da filha fica em `Documentos\NinjaTrader 8\SPCopy\`. |

A filha também grava `SP_CopyAck_<canal>_NT-<conta>.txt`. Assim a faixa da mãe no MT5 conta a filha NT8, por exemplo `MAE PRONTA | 2 FILHAS CONECTADAS`.

## Instalação

1. Copie `SPCopyFilhaNT.cs` para `Documentos\NinjaTrader 8\bin\Custom\Strategies\`.
2. No NT8, abra **Novo > Editor NinjaScript**, selecione a estratégia e compile com **F5**. Não deve aparecer erro na parte de baixo do editor.
3. Na **mãe (MT5)**: o Scalper Pro em `Modo do copiador = Mae`, com o canal desejado (ex.: `SP1`). Nada muda no MT5.
4. No NT8, na aba **Estratégias** do Painel de Controle, clique com o botão direito e escolha **Nova estratégia > SPCopyFilhaNT**:
   - **Conta:** a conta Tradovate da filha;
   - **Instrumento:** o contrato da filha (ex.: `MNQ 12-26`, `NQ 12-26`, `MGC 12-26`, `GC 12-26`);
   - **Canal:** o mesmo da mãe;
   - **SL/TP:** preencha o grupo "2. Ordem / SL-TP" (veja abaixo);
   - marque **Habilitado**.
5. Abra a janela **Output** (Novo > NinjaScript Output) para ver o log da cópia.

Para várias contas filhas, adicione **uma instância da estratégia por conta**. Cada instância tem conta, contrato e parâmetros próprios.

### Template de parâmetros por conta filha

Na janela de parâmetros da estratégia, clique com o botão direito e escolha **Template > Salvar** (ex.: `Apex-50k-MNQ`, `Tradovate-NQ`). Na próxima vez, use **Template > Carregar** para trazer canal, contrato, quantidade e SL/TP daquela conta.

## SL/TP obrigatório (exigência da mesa)

A filha **só abre posição com SL/TP**. Sem um dos dois modos abaixo configurado, nenhuma entrada é copiada, e o motivo aparece no log.

**Modo 1: template ATM (recomendado).** Crie um template ATM no NT8, por exemplo no Chart Trader ou no SuperDOM: **ATM Strategy > Custom > Salvar como**. Nele você define a **quantidade**, o **stop**, o **alvo** e, se quiser, trailing ou breakeven. Depois informe o nome em **Template ATM**. Cada conta filha pode ter o seu template.

**Modo 2: bracket próprio.** Deixe **Template ATM** vazio e preencha:
- **Contratos (sem ATM):** quantidade de contratos;
- **Stop loss (ticks)** e **Take profit (ticks)**: são enviados como ordens OCO logo após a execução da entrada.

Os valores podem ser distantes ("inalcançáveis"), porque a filha fecha junto com a mãe. Referência de distância por contrato:

| Contrato | 1 tick | 400 ticks (padrão de SL) | 800 ticks (padrão de TP) |
|---|---|---|---|
| NQ / MNQ | 0,25 ponto | 100 pontos | 200 pontos |
| GC / MGC | 0,10 dólar | 40 dólares | 80 dólares |

## Parâmetros

| Grupo | Parâmetro | Descrição |
|---|---|---|
| 1. Copiador | Canal | Igual ao da mãe |
| | Símbolo da mãe | Símbolo aceito do gráfico da mãe (ex.: `US100`, `XAUUSD`). Vazio = qualquer. Evita copiar ouro num contrato de NQ por engano. |
| | Intervalo de leitura (ms) | Padrão 10 |
| | Idade máxima da posição da mãe (s) | Não copia posições que já estavam abertas há mais tempo, por exemplo depois de um reinício. 0 = sem limite. |
| | Inverter direção | A filha opera o lado oposto |
| | Pasta Common\Files do MT5 | Vazio = `%APPDATA%\MetaQuotes\Terminal\Common\Files` |
| 2. Ordem / SL-TP | Template ATM | Nome do template ATM. Quando preenchido, a quantidade e o SL/TP vêm dele. |
| | Contratos / Stop loss / Take profit (ticks) | Usados quando não há template ATM |

## US100 e ouro ao mesmo tempo

Cada gráfico do Scalper Pro em modo Mãe publica **um canal**. Para copiar dois ativos, use canais diferentes:

| MT5 (mãe) | Canal | NT8 (filha) |
|---|---|---|
| Gráfico `US100` | `NQ` | SPCopyFilhaNT em `MNQ 12-26`, símbolo da mãe `US100` |
| Gráfico `XAUUSD` | `OURO` | SPCopyFilhaNT em `MGC 12-26`, símbolo da mãe `XAUUSD` |

## Rolagem de contrato

Na rolagem, desabilite a estratégia, troque o **Instrumento** (ex.: `MNQ 12-26` para `MNQ 03-27`) e habilite de novo. O MT5 não muda.

## Log

O log aparece na janela **Output** e também é gravado em `Documentos\NinjaTrader 8\SPCopy\log_AAAAMMDD.txt`. Para mandar para análise, anexe esse arquivo.

Exemplo:

```
22:19:39.671 SPCopy FILHA NT8 [APEX-123]: SELL ATM 'MNQ-Mesa' copiando mae #235827214 (US100 0.20) | ordem enviada 15 ms apos a gravacao da mae
22:19:39.820 SPCopy FILHA NT8 [APEX-123]: execucao entrada 2 @ 21450.25 | execucao 149 ms | desde gravacao da mae 164 ms
22:20:18.330 SPCopy FILHA NT8 [APEX-123]: fechando copia de #235827214 (mae fechou) | 13 ms desde a gravacao da mae
22:20:18.455 SPCopy FILHA NT8 [APEX-123]: execucao saida 2 @ 21440.00 | execucao 125 ms | desde gravacao da mae 138 ms
```

Os tempos acima são ilustrativos. Os seus vão depender do ping até a Tradovate. A linha `publicado` do log da mãe no MT5 usa o mesmo relógio, então dá para comparar direto.

O log também registra o motivo de qualquer posição da mãe não copiada:
- arquivo da mãe desatualizado;
- conta desconectada;
- SL/TP não configurado;
- posição antiga demais;
- conta já posicionada;
- ordem rejeitada (ex.: mercado fechado);
- template ATM inexistente.

## Cuidados

- **Não opere manualmente o mesmo contrato na conta filha** enquanto a estratégia estiver ativa. O fechamento cancela todas as ordens stop/limite ativas do contrato.
- **Não use "Zerar"/"Flatten" do NT8 no contrato da filha.** O NT8 desabilita as estratégias do contrato quando você zera por ali.
- Se a conta já estiver posicionada quando a mãe abrir, a cópia é ignorada e o motivo vai para o log.
- **Horários:** a CME para todo dia das 17h às 18h (horário de NY) e no fim de semana. Uma entrada da mãe nesse período é rejeitada, e a filha desiste após 3 tentativas.
- **Parciais da mãe não são copiadas.** A filha fecha tudo quando a mãe fecha a posição inteira. Reduzir uma posição protegida por ATM ou OCO exigiria ajustar a quantidade do SL/TP, e um descasamento poderia virar a mão.
- **Regras da mesa:** confirme se a mesa da conta Tradovate permite copy trade e automação.
