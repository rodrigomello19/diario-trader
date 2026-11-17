# Central de Controle (SPCentral) v2.1

Programa do Windows que segura o seu plano de trading, com **regras por conta e por ativo**.

- **Quando uma regra é atingida,** a central bloqueia aquela conta/ativo. Conforme o caso, ela também zera a conta, fecha os navegadores e fecha as plataformas.
- **Operações feitas fora do Scalper Pro, do copiador ou do DGX são zeradas na hora:** à mão no MT5, no celular, na web ou por outro robô.
- **Destravar** só acontece no reset diário ou com a **senha mestra**, que deve ficar com outra pessoa.

## Instalação

1. Copie `SPCentral.cs` e `compilar.bat` para uma pasta, por exemplo `C:\SPCentral`, e dê dois cliques em **compilar.bat**. Ele gera o **instalador** `SPCentral.exe`.
2. Dê dois cliques no `SPCentral.exe` e confirme. A central:
   - fica numa **pasta oculta** (`%LOCALAPPDATA%\SPCentralApp`, com atributos oculto e sistema);
   - cria o atalho **"Central de Controle"** na Área de Trabalho e no Menu Iniciar;
   - inicia junto com o Windows e fica no **ícone do escudo** perto do relógio.
3. Na primeira vez, peça para **a outra pessoa** criar a **senha mestra** (mínimo de 6 caracteres).
4. Cadastre as regras (aba **Regras por conta e ativo**) e confira a aba **Geral**.

**Uma central por vez.** Enquanto houver uma central instalada ou aberta, o instalador recusa, até se for a mesma versão. Para trocar de versão: **aba Senha mestra > Desinstalar** (pede a senha) e depois rode o novo `SPCentral.exe`.

**Vindo da v1.x:**
1. Na central antiga, use **Fechar a central** (senha).
2. Compile a v2.0 na mesma pasta e instale.
3. As configurações antigas viram **uma regra** para a conta mãe:
   - meta → pontos ganhos;
   - limite de perda → pontos perdidos;
   - início e limite → horário de bloqueio.
4. A senha mestra continua a mesma.

## Regras por conta e ativo

Cada regra vale para **uma conta** (login do MT5, ou `NT-<conta>` no NinjaTrader) e **um ativo**. O ativo pode ser `US100`, `MNQ`... ou `*` para todos os ativos da conta somados. `US100` vale também para `US100.cash`, e `MNQ` vale para `MNQ 12-26`.

| Campo | O que faz |
|---|---|
| **Horário de bloqueio** (das / até) | **Não opera dentro do intervalo.** Ex.: 12:00 até 14:00 = sem operações no almoço. Pode passar da meia-noite: 17:00 até 11:30 = só opera das 11:30 às 17:00. A opção "zerar quando o bloqueio começar" fecha a posição aberta. |
| **Pontos ganhos** | Ao ganhar isso (fechado + aberto): **sem novas entradas**. A operação aberta termina. |
| **Pontos perdidos** | Ao perder isso (fechado + aberto): **ZERA** a conta/ativo. |
| **Valor ganho** | Igual aos pontos ganhos, em dinheiro. |
| **Valor perdido** | Igual aos pontos perdidos, em dinheiro: **ZERA**. |
| **Quando atingido (valor)** | Ativa a **proteção de lucro**. Ao chegar nesse ganho, o sistema passa a proteger o resultado usando o Drawdown máximo, logo abaixo. Os dois trabalham juntos. |
| **Drawdown máximo (valor)** | Funciona junto com "Quando atingido". Se o resultado cair isso abaixo do **melhor resultado do dia** (inclui a operação aberta): **ZERA**. Se um dos dois estiver em 0, essa proteção fica desligada. |
| **Máximo de operações** | Ao fechar a última operação permitida: sem novas entradas. Parciais da mesma posição contam como 1 operação. |
| **Parar após perdas seguidas** | Trava depois de N operações perdedoras em sequência. |
| **Pausa após cada perda** | Sem novas entradas por X minutos. Não trava. |
| **Ao bloquear: fechar navegadores** | Em qualquer bloqueio dessa regra, fecha as janelas de navegador com TradingView, Tradovate, Apex ou NinjaTrader no título ou no endereço. |
| **Ao bloquear: fechar plataformas** | Quando a regra **trava** por limite e as posições estão zeradas, fecha o MT5, o NinjaTrader... |

- **Duração da trava:** até o **reset diário** (aba Geral). A senha mestra destrava antes: a regra selecionada (botão no Painel) ou tudo (aba Senha mestra). Ao destravar, a contagem daquela regra recomeça.
- **Valores em dinheiro:** precisam do **Scalper Pro v6.09+**, que envia o resultado e o flutuante em dinheiro.
- **Contas NT8:** o NinjaTrader não envia resultados para a central. Nessas contas valem o **horário de bloqueio** e os bloqueios/zeragens vindos de outras regras. Os limites de pontos e valores das filhas acompanham a mãe.

## Operações fora do sistema (aba Geral)

Com **"Zerar na hora qualquer operação que não venha do Scalper Pro..."** ligado, toda posição ou ordem da conta é **fechada/cancelada em até 0,5 s** se não vier de:
- o próprio Scalper Pro (número mágico próprio, padrão 53500001; as posições abertas pelas versões antigas também são reconhecidas);
- as cópias do copiador;
- um robô autorizado, cujos números mágicos você cadastra (ex.: o DGX). Para liberar operações manuais, cadastre `0`.

**Onde vale:**
- **MT5:** vale em **qualquer ativo da conta**. O MT5 pode ser um gráfico de estudo, o celular ou a web: basta um **Scalper Pro v6.09+ rodando nessa conta** em qualquer gráfico. Quem zera é o Scalper.
- **MT5 aberto sem Scalper Pro numa conta:** a central **não fecha** (pode ser estudo). Ela só avisa no Painel que operações manuais nessa conta não serão zeradas.
- **NinjaTrader (filha v1.6+):** posição no contrato **sem cópia ativa** é zerada, e ordens soltas são canceladas.

## Horário de edição (aba Geral)

As regras e as configurações podem ser alteradas **sem senha** só no horário de edição, por exemplo das 08:00 às 11:30 (início do pregão do Nasdaq). Fora dele, ou com qualquer trava ativa, alterar pede a senha mestra.

## Recuperação de senha

Esqueceu a senha mestra? Na aba **Recuperação de senha**, clique em **Esqueci a senha**.

1. Um aviso do pedido sai **na hora**, por e-mail e Telegram.
2. Uma **senha temporária** é enviada às **20:00 do dia do pedido**. Um pedido feito depois das 20:00 é entregue às 20:00 do dia seguinte.
3. A senha antiga só deixa de valer depois que pelo menos um envio der certo. Se falhar, a central tenta de novo a cada 5 minutos.
4. Use a temporária e troque por uma nova em **Senha mestra > Trocar senha mestra**.

Um pedido que não foi você pode ser cancelado com a senha mestra.

**Configurar** (salvar os contatos sempre pede a senha mestra):
- **E-mail (Gmail):**
  - servidor `smtp.gmail.com`, porta `587`;
  - a "conta que envia" é um Gmail com **senha de app** (Conta Google > Segurança > Senhas de app, exige verificação em duas etapas);
  - "Enviar para" é quem recebe a senha.
- **Telegram:**
  1. Crie um bot com o **@BotFather** e copie o **token**.
  2. Mande qualquer mensagem para o bot.
  3. Abra `https://api.telegram.org/bot<TOKEN>/getUpdates` e copie o número em `chat > id`.
- Use **Testar e-mail** e **Testar Telegram** depois de salvar.
- A senha do e-mail e o token ficam **cifrados pelo Windows**, para este usuário.

## Proteção contra alterações

- **Arquivos editados ou apagados:** se a configuração ou o estado forem alterados à mão ou apagados, a central bloqueia tudo até a senha mestra.
- **Proteção contra exclusão:**
  - o `.exe` instalado, a pasta de dados (`%LOCALAPPDATA%\SPCentral`, oculta) e a marca `SP_Central_Ativa.txt` negam a exclusão ("Acesso negado");
  - os atalhos e o início com o Windows são recriados a cada minuto.
- **Fechar a janela só minimiza.** Fechar a central (ícone do escudo ou aba Senha mestra) pede a senha.
- **Central fechada à força:** com a central fechada, os Scalper Pro e as filhas NT8 **bloqueiam novas entradas** em até 10 s ("central offline").
- **Botão BLOCK do Scalper Pro:** trava **tudo** até o reset e zera as outras contas (filhas). A posição de quem apertou segue até fechar.

> **Limite honesto:** isto é uma barreira contra o impulso, não um cofre. Quem tiver acesso de administrador e conhecimento técnico consegue contornar.

## Painel

- **Tamanho da tela (v2.1):** no canto superior do Painel, escolha **100% a 200%**.
  - Vale para todas as janelas da central e fica salvo.
  - Na primeira vez, a central escolhe sozinha pela resolução da tela.
  - As listas acompanham a janela: maximize para ver mais.

- **Estado geral:**
  - TUDO LIBERADO;
  - n REGRAS BLOQUEADAS;
  - TRAVA GERAL;
  - BLOQUEADA (central alterada).
- **Situação de cada regra:**
  - LIVRE, BLOQUEADA ou ZERANDO, com o motivo;
  - operações;
  - pontos e valor (fechado / aberto);
  - estado da proteção de lucro.
- **Avisos:** MT5 aberto sem Scalper Pro, pedido de recuperação, zerar-fora desligado.
- **Contas conectadas e Eventos:** os eventos também ficam em `%LOCALAPPDATA%\SPCentral\log_AAAAMMDD.txt`.
- **Testar navegadores:** mostra o que a central enxerga em cada janela de navegador, sem fechar nada.

## Comunicação com os EAs

Arquivos em `%APPDATA%\MetaQuotes\Terminal\Common\Files`:

| Arquivo | Quem grava | Conteúdo |
|---|---|---|
| `SP_Central_Ativa.txt` | central | Marca: os EAs passam a obedecer |
| `SP_Central_Cmd.txt` | central (0,5 s) | `CMD\|2\|tick\|LIVRE/BLOQ\|motivo\|ate` (geral); `F\|1/0\|magics` (zerar de fora); `B\|conta\|ativo\|motivo` (sem novas entradas); `Z\|conta\|ativo\|motivo` (zerar) |
| `SP_Central_St_<conta>_<ativo>.txt` | Scalper Pro / filha NT8 (1 s) | Posições e flutuante em pontos e em dinheiro |
| `SP_Central_Tr_<conta>.txt` | Scalper Pro | Uma linha por operação encerrada, com pontos e valor |
| `SP_Central_Pedido_<conta>.txt` | Scalper Pro | Botão BLOCK |

**Versões necessárias:** Scalper Pro **v6.09+** e SPCopyFilhaNT **v1.6+**. As versões antigas não entendem as linhas por conta/ativo.

## Desinstalar

Na aba **Senha mestra > Desinstalar** (senha), escolha:
- **Sim:** apaga também as regras, as configurações e a senha;
- **Não:** guarda tudo para a próxima instalação.

A central então retira as proteções, os atalhos e o início com o Windows. Também apaga a marca, e os EAs passam a operar **sem** a central. A pasta oculta é removida depois que a central fecha.
