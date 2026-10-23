# Linhas do dia no Scalper Pro (v5.89)

Há duas formas de colocar suas linhas no gráfico de operação:

1. **Arquivo `SP_Linhas.txt`**: você cola os preços, salva e clica em **LINHAS** no painel. O Scalper Pro desenha as linhas.
2. **Botão SYNC**: copia as linhas que você traçou no **gráfico de estudo** para o gráfico de operação.

## 1. Arquivo de linhas

**Onde fica:** `%APPDATA%\MetaQuotes\Terminal\Common\Files\SP_Linhas.txt`. É a mesma pasta do copiador e da Central. No MT5, abra por **Arquivo > Abrir pasta de dados**, suba dois níveis e entre em `Common\Files`.

O arquivo é criado automaticamente na primeira vez que o Scalper Pro é carregado. Abra no Bloco de Notas:

```
TIPO NIVEL1    = PRETO, 3, SOLIDA
TIPO NIVEL2    = PRETO, 1, SOLIDA
TIPO TRACEJADA = CINZA, 1, TRACEJADA
TIPO DESTAQUE  = AZUL, 3, SOLIDA

NIVEL1:    29465,08; 29361,12; 29323,97
NIVEL2:    29306,39; 29280,02
TRACEJADA: 29510,05; 29493,30; 29443,74; 29423,21; 29401,98
DESTAQUE:  29361,12
```

- **Carregamento pelo botão (padrão):** salve o arquivo e clique em **LINHAS**. O EA não fica lendo o arquivo sozinho.
  - Opcional: "Redesenhar sozinho quando o arquivo for salvo". Com ele ligado, o EA confere a data do arquivo uma vez por segundo, sem impacto no desempenho.
  - Opcional: "Carregar SP_Linhas.txt ao iniciar o EA".
- **Separação dos preços:** use ponto e vírgula. A vírgula ou o ponto decimal funcionam (`29465,08` ou `29465.08`), e `29.465,08` também.
- **Aparência:** você pode mudar a cor, a espessura (1 a 5) e o estilo de cada tipo nas linhas `TIPO`.
  - Cores: PRETO, AZUL, AZULESCURO, VERMELHO, VERDE, CINZA, CINZACLARO, LARANJA, AMARELO, ROXO, BRANCO.
  - Estilos: SOLIDA, TRACEJADA, PONTILHADA, TRACO_PONTO.
  - Também dá para criar outros tipos, por exemplo `TIPO SUPORTE = VERDE, 2, SOLIDA` e depois `SUPORTE: ...`.
- **Proteção contra erro de digitação:**
  - Um preço que não é número (ex.: `29.4O1`, com a letra O) é ignorado.
  - Um preço a mais de **10%** do preço atual também é ignorado (ex.: `2946508`, sem a vírgula).
  - A barra de status mostra o resultado, por exemplo `LINHAS: 14 ok, 1 ignorada(s) (29.4O1)`, e o detalhe vai para a aba Experts.
- **Vale para todos os terminais:** o arquivo fica em `Common\Files`, então o botão LINHAS de qualquer terminal (mãe ou filha) desenha as mesmas linhas.
- **As linhas podem ser ajustadas:** dá para selecionar, arrastar, mudar a cor ou apagar com o mouse, como qualquer linha. Elas ficam salvas no gráfico, inclusive ao fechar o MT5 ou remover o EA.
- **Ao clicar em LINHAS de novo,** o EA apaga as linhas do arquivo, **inclusive os ajustes feitos nelas**, e redesenha a partir do arquivo. As linhas que você traçou à mão e as do SYNC continuam no gráfico.

**Atenção:** os preços precisam ser do **mesmo ativo e da mesma corretora** do gráfico. Futuro (NQ/MNQ) e CFD (US100) têm cotações diferentes.

## 2. SYNC: puxar as linhas do gráfico de estudo

1. Abra o gráfico de estudo **do mesmo ativo** no mesmo MT5, **sem** o Scalper Pro, e trace suas linhas horizontais.
2. No gráfico de operação, clique em **SYNC**.

O que o SYNC faz:
- **Escolhe o gráfico de estudo:** procura outro gráfico do mesmo ativo. Se houver mais de um, prefere o que **não tem EA**, para não puxar de outro gráfico de operação. O nome e o tempo gráfico do gráfico usado aparecem na barra de status, por exemplo `SYNC: 12 linhas de US100 M5`.
- **Copia cor, espessura e estilo** de cada linha horizontal. Também copia linhas de tendência traçadas na horizontal.
- **Substitui as linhas horizontais do gráfico de operação** pelas do estudo, inclusive as que você traçou à mão nele. As linhas do arquivo, as do SL/TP e as do trailing não são apagadas.
- **Estudo em outro ativo:** se o estudo estiver em outro ativo, preencha o parâmetro "SYNC: ativo do gráfico de estudo".

Ao fechar o MT5 ou remover o EA, as linhas copiadas pelo SYNC são apagadas. As do arquivo continuam no gráfico. Para guardar as linhas do estudo de um dia para o outro, passe os preços para o `SP_Linhas.txt`.

## Parâmetros novos

| Parâmetro | Padrão |
|---|---|
| Carregar SP_Linhas.txt ao iniciar o EA | não (só pelo botão LINHAS) |
| Redesenhar sozinho quando o arquivo for salvo | não |
| Ignorar preços a mais de X% do preço atual | 10 |
| SYNC: ativo do gráfico de estudo ("" = mesmo ativo deste gráfico) | "" |
