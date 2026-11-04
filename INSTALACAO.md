GUIA RÁPIDO DE INSTALAÇÃO — FERRAMENTAS SCALPER PRO
====================================================
Pacote de 04/11/2026

| Ferramenta | Versão | Onde roda |
|---|---|---|
| Scalper Pro (EA) | v6.02 | MetaTrader 5 (mãe e filhas) |
| Central de Controle | — | Windows |
| SPCopyFilhaNT (filha do copiador) | v1.3 | NinjaTrader 8 |
| SPForcaMercado (indicador, opcional) | v1.10 | NinjaTrader 8 |


CONTEÚDO DO PACOTE
------------------
```
1_MT5_ScalperPro\
    Scalper_Opt.mq5              EA Scalper Pro
    docs\                        COPIADOR, PARCIAIS, LINHAS, PAINEL
2_Central_de_Controle\
    SPCentral.cs, compilar.bat   Central de Controle (gera o SPCentral.exe)
    LEIAME.md
3_NinjaTrader\
    Strategies\SPCopyFilhaNT.cs  filha do copiador no NT8
    Indicators\SPForcaMercado.cs indicador de agressão/volatilidade (opcional)
    docs\
```


ANTES DE COMEÇAR
----------------
- **Mesmo computador:** o copiador só funciona com o MT5 da mãe, os MT5 das filhas e o NinjaTrader **no mesmo computador**. Eles trocam arquivos pela pasta:
  `%APPDATA%\MetaQuotes\Terminal\Common\Files`
- **Na máquina antiga, anote ou salve:**
  - os parâmetros do EA de cada terminal: na aba "Parâmetros de entrada", clique em **Salvar** e grave um arquivo `.set`;
  - os templates da estratégia no NinjaTrader;
  - a configuração da Central (contas, limites, horários);
  - o arquivo de linhas `SP_Linhas.txt` da pasta Common\Files, se você usa.
- **Ao copiar arquivos:** se já existir um arquivo com o mesmo nome, **substitua**. Não deixe cópias como `Arquivo (1).cs`, porque o NinjaTrader e o MT5 dão erro de "definição duplicada".


PASSO 1 — SCALPER PRO NO MT5 (repita em cada terminal: mãe e filhas)
-------------------------------------------------------------------
1. No MT5, abra **Arquivo > Abrir pasta de dados** e entre em `MQL5\Experts`.
2. Copie para lá o arquivo `1_MT5_ScalperPro\Scalper_Opt.mq5`.
3. Abra o **MetaEditor** (tecla F4), abra o `Scalper_Opt.mq5` e compile com **F7**. Não deve aparecer nenhum erro.
4. No MT5, arraste o **Scalper_Opt** para o gráfico do ativo (ex.: US100, M1).
5. Na aba **Comum**, marque "Permitir Algo Trading". Na barra do MT5, ligue o botão **Algo Trading**.
6. Na aba **Parâmetros de entrada**, configure. Se trouxe os `.set` da máquina antiga, use **Carregar**.
   - Grupo **Copiador MT5**:
     - "Modo do copiador": **Mae** no terminal principal e **Filha** nos demais;
     - "Canal": o **mesmo** em todos (ex.: SP1).
   - Grupos **Perfil NORMAL / VOLATIL** e **Parciais**: os seus valores.
7. Confira o painel. A faixa do copiador, no rodapé, deve mostrar:
   - na mãe: `MAE PRONTA | n FILHAS`;
   - nas filhas: `FILHA PRONTA | MAE ...`.
   - Se aparecer `COPY: DESLIGADO`, revise o "Modo do copiador".


PASSO 2 — CENTRAL DE CONTROLE (opcional, mas recomendada)
---------------------------------------------------------
1. Crie a pasta `C:\SPCentral` e copie para ela `SPCentral.cs` e `compilar.bat`.
2. Dê dois cliques em **compilar.bat**. Ele usa o .NET Framework que já vem no Windows e gera o `SPCentral.exe`.
3. Abra o **SPCentral.exe**. Na primeira vez, peça para **a outra pessoa** criar a **senha mestra** (mínimo de 6 caracteres).
4. Na aba **Configuração**, preencha a conta mãe, as contas filhas (as do NT8 no formato `NT-<conta>`), os limites, os horários, o reset diário e a janela de edição. Depois clique em **Salvar**.
5. A Central passa a ficar no **ícone do escudo**, perto do relógio do Windows. Ela abre sozinha quando o Windows inicia.

**Importante:**
- Com a Central instalada, ela **precisa estar aberta** para operar. Se for fechada, os EAs bloqueiam novas entradas em até 10 s ("central offline").
- Se **não** for usar a Central nesta máquina, não a instale. Os EAs funcionam normalmente sem ela.


PASSO 3 — FILHA DO COPIADOR NO NINJATRADER 8
--------------------------------------------
1. Copie `3_NinjaTrader\Strategies\SPCopyFilhaNT.cs` para:
   `Documentos\NinjaTrader 8\bin\Custom\Strategies\`
2. No NinjaTrader, abra **Novo > Editor NinjaScript** e compile com **F5**. Não deve aparecer erro.
3. **Conecte** a conta da filha (ex.: Tradovate). A conexão aparece em verde no canto inferior esquerdo.
4. No Painel de Controle, aba **Estratégias**, clique com o botão direito e escolha **Nova estratégia > SPCopyFilhaNT**. Preencha:
   - **Conta:** a conta conectada;
   - **Instrumento:** o contrato (ex.: `MNQ 12-26`);
   - **Canal:** igual ao da mãe;
   - **Pasta Common\Files do MT5:** deixe **vazio**;
   - **SL/TP:** um template ATM **ou** Contratos + Stop/Take em ticks.
5. **Marque "Habilitado"** e clique em OK.
6. A linha da estratégia deve ficar **verde**. Abra **Novo > NinjaScript Output** e confira se aparece:
   `FILHA NT8 ativa | canal=SP1 | conta=...`
   No MT5 da mãe, a filha NT8 passa a ser contada na faixa do copiador.
7. Salve um template de parâmetros (botão direito > Template > Salvar) e o workspace do NinjaTrader.


PASSO 4 — INDICADOR SPForcaMercado (opcional)
---------------------------------------------
1. Copie `3_NinjaTrader\Indicators\SPForcaMercado.cs` para:
   `Documentos\NinjaTrader 8\bin\Custom\Indicators\`
2. Compile com **F5**.
3. Abra um gráfico de **1 minuto** (ex.: MNQ). Em **Data Series**:
   - marque **Tick Replay**;
   - carregue **pelo menos 21 dias**.
4. Adicione o indicador **SPForcaMercado** ao gráfico.


PASSO 5 — LINHAS DO DIA (se você usa)
-------------------------------------
- O Scalper Pro cria o arquivo `SP_Linhas.txt` em `Common\Files` na primeira vez que roda. Se trouxe o seu arquivo da máquina antiga, substitua esse.
- Cole os preços no arquivo, salve e clique em **LINHAS** no painel.
- O botão **SYNC** puxa as linhas do gráfico de estudo, que deve estar **sem EA**.


TESTE FINAL (em conta demo/simulação)
-------------------------------------
- [ ] Mãe: a faixa do copiador mostra todas as filhas (MT5 e NT8)
- [ ] Abrir uma operação na mãe: as filhas abrem em seguida, com SL/TP
- [ ] Parcial P1 na mãe: as filhas MT5 reduzem na mesma proporção
- [ ] Fechar na mãe: todas as filhas fecham
- [ ] Central: mostra as contas online, e os contadores mudam ao fechar uma operação


PROBLEMAS COMUNS
----------------
| Sintoma | Solução |
|---|---|
| `COPY: DESLIGADO` na faixa | Os parâmetros voltaram ao padrão. Ajuste "Modo do copiador" e o "Canal", ou carregue o `.set`. |
| Mãe mostra 0 filhas | A aba Experts da mãe mostra o motivo a cada 30 s. Confira se o canal é o mesmo, se a estratégia NT8 está habilitada e verde, e se tudo está no mesmo computador. |
| NT8: "already contains a definition" | Existem dois arquivos da estratégia na pasta (ex.: `SPCopyFilhaNT (1).cs`). Apague o antigo e deixe só um `SPCopyFilhaNT.cs`. |
| Estratégia NT8 amarela | Há posição aberta na conta. Zere a conta ou mude "Start behavior" para "Immediately submit". |
| EA não envia ordens | Ligue **Algo Trading** e marque "Permitir Algo Trading" nas propriedades do EA. |
| Barra de status `CENTRAL: BLOQUEADO (central offline)` | A Central foi fechada. Abra o `SPCentral.exe`. |
| compilar.bat: "Compilador não encontrado" | Instale ou ative o **.NET Framework 4.8** no Windows ("Ativar ou desativar recursos do Windows"). |


ONDE FICAM AS COISAS
--------------------
| O quê | Onde |
|---|---|
| Arquivos do copiador e da Central | `%APPDATA%\MetaQuotes\Terminal\Common\Files` |
| Log da filha NT8 | `Documentos\NinjaTrader 8\SPCopy\` |
| Arquivos CSV do indicador | `Documentos\NinjaTrader 8\SPForca\` |
| Configuração e log da Central | `%LOCALAPPDATA%\SPCentral\` |

Guias completos: pastas `docs` de cada ferramenta e `2_Central_de_Controle\LEIAME.md`.
