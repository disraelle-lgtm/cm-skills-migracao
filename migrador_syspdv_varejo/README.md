# Migrador SysPDV (Firebird) → VarejoFacil (PostgreSQL)

Migrador em Python, sem Pentaho. Uma tela só: **conexões** no topo e, logo abaixo, os
**dados a serem migrados** em checkboxes. Cada checkbox é uma pasta em `comandos/` com
os comandos daquela entidade, para você saber exatamente onde corrigir ou acrescentar.

```
migrador_syspdv_varejo/
├── comandos/                  ← AQUI ficam os comandos de cada item
│   ├── COMO_ADICIONAR.md      ← guia para criar novos itens
│   ├── _modelo/               ← copie esta pasta para criar um item novo
│   ├── 01_secao/              modulo.json, origem.sql, transformar.py, existe.sql, inserir.sql, atualizar.sql
│   ├── 02_grupo/              (+ validar.sql: a seção precisa existir)
│   ├── 03_subgrupo/           (+ validar.sql: o grupo precisa existir)
│   ├── 04_tabelas_basicas/    um checkbox, 10 etapas (uma subpasta por tabela)
│   ├── 05_impostos_federais/  (+ depois.sql: tabelas _geral/_atacado/_simples/_varejo)
│   ├── 06_ncm/                NCMs dos produtos que faltam, como inativos
│   ├── 07_loja/               2 etapas: pessoa + pessoa_loja
│   ├── 08_funcionario/        pessoa + pessoa_funcionario + vínculo com a loja MATRIZ + usuário
│   ├── 09_cliente/            pessoa (física / jurídica / sem documento) + pessoa_cliente
│   ├── 09_limite_credito/     limite_de_credito (checkbox separado do Cliente)
│   ├── 10_fornecedor/         pessoa (reaproveita se já existir) + pessoa_fornecedor
│   ├── 11_agente_financeiro/  pessoa (reaproveita se já existir) + pessoa_agente_financeiro
│   ├── 12_conta_corrente/     conta_corrente
│   ├── 13_finalizadora/       finalizadora (+ a 1 = Dinheiro movimenta conta)
│   ├── 19_ajustes_pessoas/    só SQL, sem checkbox: roda sozinho POR ÚLTIMO quando algum item de Pessoas é marcado
│   ├── 20_inicio_produto/     só SQL, sem checkbox: ALTER TABLE produto DISABLE TRIGGER ALL (+ finalizar.sql de garantia)
│   ├── 20_produto/            produto (tabela principal) + opção "Incluir produtos fora de linha"
│   ├── 21_impostos_federais_produto/  Pis/Cofins por produto
│   ├── 22_produto_auxiliar/   EAN / LITERAL (+ limpeza dos EANs)
│   ├── 23_produto_fornecedor/ referência do produto no fornecedor (+ fornecedor principal)
│   ├── 24_preco/              preço por loja (+ correção de preços negativos/desconto)
│   ├── 25_tributacao_produto/ situação fiscal, tabela tributária e itens (3 etapas)
│   ├── 26_familia/            família (similares) e produto na família
│   ├── 27_compostos/          composição + componentes (+ histórico)
│   ├── 28_kit/                kit + componentes (+ histórico)
│   ├── 29_encarte/            encarte, produtos e lojas do encarte (+ programação de preço)
│   ├── 30_cenario_fiscal_ncm/ classificação tributária + cenário fiscal por NCM
│   ├── 31_cenario_fiscal_produto/ cenário fiscal por produto
│   ├── 39_ajustes_produto/    só SQL, sem checkbox: "higieniza loccod" + "Ajusta Produto" + "Corrigi produtos sem composição" + Cadastro de operações + ENABLE TRIGGER, por último
│   ├── 40_inicio_estoque/     só SQL, sem checkbox: tipos de ajuste 9001/9002 + DISABLE TRIGGER da produto (+ finalizar.sql)
│   ├── 41_saldo_positivo/     saldo ≥ 0 do SysPDV
│   ├── 42_saldo_negativo/     saldo < 0 do SysPDV
│   ├── 43_estoque_minimo_maximo/ estoque mínimo e máximo
│   ├── 44_movimentacao_custo/ movimentação de custo, custo do dia, auditoria
│   ├── 49_fim_estoque/        só SQL, sem checkbox: ENABLE TRIGGER da produto
│   ├── 50_contas_receber/     conta, título aberto e parcial, movimentações, lançamentos
│   ├── 51_contas_pagar/       conta, título, movimentação, lançamentos
│   ├── 59_fim_financeiro/     só SQL, sem checkbox: Insert Item Configuração Lançamento Financeiro
│   └── 99_fila_panama/        só SQL, sem checkbox, em TODA migração (por último): InsertFilaPanama.sql
├── app/                       motor e tela (não precisa mexer para adicionar itens)
│   ├── motor.py               lê as pastas de comandos/ e executa
│   ├── ajudantes.py           inteiro(), texto(), numero(), so_digitos(), Pular
│   ├── firebird_conexao.py    conexão Firebird local/Docker, fbclient, charset
│   ├── docker_firebird.py     detecção de container do Firebird
│   └── main.py                servidor web
├── static/index.html          a tela (mostra a aba Linux ou Windows, conforme o sistema)
├── reports/                   relatório "linha a linha" de cada execução
├── requirements.txt
├── linux/                     ← SÓ quem usa Linux (Ubuntu): veja linux/LEIA-ME.md
│   ├── instalar.sh
│   └── iniciar-app.sh
└── windows/                   ← SÓ quem usa Windows: veja windows/LEIA-ME.md
    ├── instalar.bat  instalar-windows.ps1
    ├── iniciar-app.bat  parar-app.bat
    └── firebird_client_x64/   client Firebird 2.5.9 64 bits oficial
```

## Uma lógica, duas instalações

Os **comandos** (`comandos/`), o **motor** (`app/`) e a **tela** (`static/`) são os mesmos para
Linux e Windows: uma alteração em `comandos/01_secao`, por exemplo, vale para os dois.

O que muda é só como instalar e abrir. Cada sistema tem a sua pasta e o seu passo a passo:

| Sistema | Pasta | Passo a passo | Abrir |
|---|---|---|---|
| Linux (Ubuntu) | `linux/` | [`linux/LEIA-ME.md`](linux/LEIA-ME.md) | `bash linux/iniciar-app.sh` |
| Windows | `windows/` | [`windows/LEIA-ME.md`](windows/LEIA-ME.md) | atalho "Migrador SysPDV" ou `windows\iniciar-app.bat` |

Os dois abrem a tela em http://127.0.0.1:8020. O servidor recarrega sozinho quando o código em
`app/` muda; as pastas de `comandos/` são lidas na hora (botão Recarregar).

## Usar

1. **Conexões**: a tela mostra só a aba do sistema em uso (**Linux** ou **Windows**); no
   Windows, o botão **Procurar...** navega pelas pastas e mostra os bancos .fdb. Preencha o Firebird e o PostgreSQL e teste cada um. Os campos, menos as senhas, ficam lembrados.
2. **Dados a serem migrados**: marque os itens. Os comandos de cada item ficam na pasta
   `comandos/` (ex.: `comandos/01_secao/origem.sql`).
3. Deixe **Simular** marcado na primeira vez: roda tudo e desfaz no final.
4. **Iniciar migração** → barra verde de 0% a 100% e acompanhamento por item (com **Na origem** = total da tabela no SysPDV e
   **Não migrados**, para bater os números) e baixe o relatório "linha a linha"
   (inserido / atualizado com antes→depois / sem_alteracao / pulado / erro).
5. Conferido, desmarque Simular e rode de novo para gravar.

Rodar de novo é seguro: com `existe.sql` + `atualizar.sql`, o que já existe é
atualizado ou mantido, sem duplicar.

Observação: a simulação desfaz os dados, mas as sequences do PostgreSQL não voltam
(é assim no PostgreSQL). Os IDs da gravação real podem começar alguns números à frente.

## Itens prontos

| Pasta | SysPDV → VarejoFacil | Regras (iguais ao migrador Pentaho oficial) |
|---|---|---|
| `01_secao` | SECAO → secao | sem a seção '00'; TRIM; descrição em MAIÚSCULO; vazia = RENOMEAR; `sec_situacao_sped = 'OUTROS'`; ID por `sq_secao` |
| `02_grupo` | GRUPO → grupo_produto | só com seção existente, sem '00'; TRIM; vazia = RENOMEAR; ID por `sq_grupo_produto` |
| `03_subgrupo` | SUBGRUPO → subgrupo_produto | só com seção e grupo existentes, sem '00'; vazia = RENOMEAR; ID por `sq_sub_grupo_produto` |
| `04_tabelas_basicas` | APLICACAO, CARACTERISTICA, LOCAL, MARCA, RAMO, STATUS, TPPGT, TPREC, TIPODOCUMENTO, UNIDADE | `T-TabelasBasicas_inicial` sem os impostos: local só ativo e flag de avaria; marca, tipo de pagamento e recebimento em MAIÚSCULO (recebimento cortado em 30); status grava STABLQ em `statipbloq` e `stablc`; ramo só insere; unidade em MAIÚSCULO, fator vazio = 1, ID por `sq_unidade` |
| `05_impostos_federais` | IMPOSTOS_FEDERAIS → impostos_federais (+ _geral, _atacado, _simples, _varejo) | só com situação de entrada ≠ saída; tipo P/C/I/S/O → PIS/COFINS/IRPJ/CSLL/OUTROS; 4 IDs pelas sequences; depois, o SQL "VF - Imposto Federal Geral" do job |

| `06_ncm` | PRODUTO.PRONCM → ncm | sem pontos, zeros à esquerda até 8; NCM que falta entra como "NCM INATIVO" |
| `07_loja` | PROPRIO → pessoa, pessoa_loja | CNPJ só números (chave); e-mail vazio = cliente@cliente.com.br; matriz S, perfil B, COMERCIO, categorias 75/71/90/91/92/93; regime N/E/A/S → 1/2/3/4; sigla = 5 letras; depois, holcod da matriz |
| `08_funcionario` | FUNCIONARIO (ativos) → pessoa, pessoa_funcionario, pessoa_funcionario_loja, usuario | nome/apelido vazio = USUARIO; CPF só números; tipo FISICA; vínculo ativo na **loja matriz** do VarejoFacil (precisa de Dados da Loja antes); usuário com senha padrão 'admin' |
| `09_cliente` | CLIENTE → pessoa, pessoa_cliente | 3 caminhos do Pentaho: FISICA (CPF com zeros até 11), JURIDICA (até 14), sem documento (marcado no relatório); e-mail minúsculo, endereço MAIÚSCULO, número 0/vazio = SN, telefone sem ( ) - . e padrão 99999999999, IE vazia = ISENTO, país 1058; estado civil, sexo, situação e tipo de residência por extenso; depois: espécies BOLETO PAGAR/RECEBER, loja matriz nos clientes sem loja e holcod |
| `09_limite_credito` | CLIENTE.CLILIMCRE → limite_de_credito | vazio = 0; espécie 2; LIBERADO; o valor não é atualizado numa nova rodada (como no Pentaho). Precisa do Cliente migrado |
| `11_agente_financeiro` | AGENTE (exceto 0000) → pessoa, pessoa_agente_financeiro | documento = CNPJ ou CPF só números; pessoa achada pelo documento (reaproveita, não atualiza); sem documento = pessoa nova (marcada no relatório); fantasia = nome; banco 0; depois, holcod |
| `12_conta_corrente` | CONTA_CORRENTE → conta_corrente | C/B → CAIXA/BANCARIA, vazio = CAIXA; agente vazio = 0; loja = PRPCOD do PROPRIO |
| `13_finalizadora` | FINALIZADORA (exceto 000) → finalizadora | cartão, movimenta conta e carga geral = falso; agente só na inclusão; a 1 (Dinheiro) movimenta conta |
| `19_ajustes_pessoas` | (só SQL, automático) | SQLs finais do JOB-Pessoas: tipo/documento, holcod, IE duplicada = ISENTO, tipo contribuinte, sequences, bairro/fantasia/datas e padrões de cliente e fornecedor |
| `20_produto` | PRODUTO → produto | Opção **Incluir produtos fora de linha** (padrão: marcada = todos; desmarcada = só `PROFORLIN = 'N'`; o NCM segue a mesma opção). T-Produto_inicial: "FB - Ajuste Seção/Unidade" e "FB - Ajustes campos estourados" aplicados na leitura (unidade inexistente = UN, seção inexistente = maior seção, estoque/peso > 100000 = 0, preços/embalagens absurdos zerados); TRIM/MAIÚSCULO nas unidades; 11 Value Mappers e If null do Pentaho; NCM sem ponto com zeros até 8; funcod 1; `sq_produto`; triggers desligadas (Session Replication) durante a carga |
| `21_impostos_federais_produto` | IMPOSTOS_FEDERAIS_PRODUTO → impostos_federais_produto | só de produtos migrados (segue a opção fora de linha); chave imposto + produto; `sq_impostos_federais_produto`. O "Imp fed duplicidade" do Pentaho é só um SELECT e não foi levado |
| `22_produto_auxiliar` | PRODUTOAUX → produtoaux | código com zeros até 14; com caractere não numérico = LITERAL, senão EAN (`proauxcodigoean` = 13 primeiros caracteres, como no Pentaho — corta o último dígito de um EAN-13: confirmar); fator 0/vazio = 1; `depois.sql` = "Limpeza nos EAN's" (apaga EAN igual ao código do produto, EAN inválido vira LITERAL, define tributado e principal) |
| `23_produto_fornecedor` | PRODUTO_FORNECEDOR → produto_fornecedor | referência numérica sem zeros à esquerda ("Limpa 0" aplicado antes de gravar); unidade/nível MAIÚSCULO, vazios = UN/P, quantidade vazia = 1; fornecedor achado por código **e** CNPJ/CPF só dígitos (no Pentaho o CNPJ com máscara nunca batia); `depois.sql` = Define Principal + Limpa 0 |
| `24_preco` | PRODUTO → preco | loja = PRPCOD; preços "estourados" zerados na leitura; desconto > 99 = 99,99; custo/margem/custos negativos = 0; venda variável vazia = 0; `sq_preco` |
| `20_inicio_produto` | (só SQL, automático, PRIMEIRO do grupo Produto) | `ALTER TABLE produto DISABLE TRIGGER ALL` antes da carga dos produtos (pedido do usuário). Religado nos Ajustes finais e, por garantia, no `finalizar.sql`, que roda **sempre no fim, mesmo se a migração parar com erro** — o DISABLE fica gravado na tabela e não pode ficar ligado por acidente |
| `25_tributacao_produto` (3 etapas) | PRODUTO.TRBID / TRIBUTACAO → situacao_fiscal, tabela_tributacao, item_tabela_tributacao | situação fiscal por tributação usada ("Tributado-T18"; código = maior + 1) e `stf_codigo` nos produtos; tabela de SAÍDA por situação fiscal para o regime e a UF da loja matriz (vigência 01/01/2016); itens com % tributado/outros/isento como no Pentaho, CST vazio = 60, CFOP vazio = 5102. No Pentaho a chave do item era `itt_id IS NULL` (duplicava a cada execução); aqui é tabela + tributação + classificação |
| `26_familia` (2 etapas) | SIMILARES, ITEM_SIMILARES → familia_produto, produto_familia | família com descrição; produto na família pela `sq_produto_familia` |
| `27_compostos` (2 etapas) | COMPOSTO, COMPONENTE → composicao, componentes_composicao | produtos PROCOMP 'S'; componentes com preços vazios = 0; histórico (`hist_*`, ON CONFLICT DO NOTHING) |
| `28_kit` (2 etapas) | PRODUTO (PROCOMP 'K'), COMPONENTE → composicao, componentes_composicao | quantidade 1, baixa 'P', tipo S/N = PRECO/FATOR; o `comp_id` é mantido (no Pentaho era trocado a cada execução, deixando componentes sem composição) |
| `29_encarte` (3 etapas) | ENCARTE, ENCARTE_PRODUTO → encarte, encarte_produto, encarte_loja, programacao_preco | encartes A/P; tipo de preço 1/2/3 marca qual preço atualiza; produtos seguem a opção fora de linha (no Pentaho `proforlin = 'N'` fixo); programação de preço com NOT EXISTS (o NOT IN do Pentaho não criava nada se houvesse uma programação com `id_produto_encarte` vazio) |
| `30_cenario_fiscal_ncm` (4 etapas) | CLASSIFICACAO_TRIBUTARIA, NCM → classificacao_tributaria, cenario_fiscal_ncm (+ _ncm, _loja, _uf_destino) | um cenário por classificação usada nos NCMs do SysPDV; loja = matriz (no Pentaho era a constante 1); UF de destino = UF da matriz |
| `31_cenario_fiscal_produto` (3 etapas) | PRODUTO com classificação diferente da do NCM → cenario_fiscal_produto (+ _produto, _loja, _uf_destino) | descrição da classificação do VarejoFacil; produto ligado pelo nível mais detalhado (seção, grupo ou subgrupo); segue a opção fora de linha; loja = matriz. Tem `origem.sqlserver.sql` (sem TRIM) |
| `39_ajustes_produto` | (só SQL, automático com o grupo Produto) | "Produto higieniza Loccod" + "Ajusta Produto" + "Corrigi produtos sem composição" + **Cadastro de operações** (24 operações padrão; só entra o código que ainda não existe — no Pentaho uma 2ª execução dava chave duplicada) + `ALTER TABLE produto ENABLE TRIGGER ALL` (gênero = 2 primeiros do NCM, datas, grupo/subgrupo inexistente = NULL, KG pesável, padrões de campos, NCM INCONSISTENTE). Sem a linha de `pesquisa_satisfacao` (sobra de outro cliente) e com `itt_icms_desonerado IS NULL` corrigido (no Pentaho era `= NULL`, que não fazia nada) |
| `10_fornecedor` | FORNECEDOR (com CNPJ) → pessoa, pessoa_fornecedor | pessoa achada pelo CNPJ/CPF (reaproveita, não atualiza); tipo F/J/E; país vazio = 1058; fax até 14; transportadora S/N; regime S→4, N→1; RJ sem desoneração como desconto |

O Plano de Contas (T-Categoria_financeira_inicial) não foi incluído de propósito.

### Onde estão os SQLs de ajuste do Pentaho

| SQL do Pentaho | Onde ficou |
|---|---|
| holcod da matriz (Loja, Funcionário, Cliente, Fornecedor, Agente) | `depois.sql` de cada item |
| Atualiza a Sequence, Insert Usuario (Funcionário) | `08_funcionario/depois.sql` |
| Inserir Especie de Documento, update-Loja (Cliente) | `09_cliente/depois.sql` |
| Corrige Desoneração ICMS (Fornecedor) | `10_fornecedor/depois.sql` |
| update_fzd_Dinheiro (Agente) | `13_finalizadora/depois.sql` |
| cadeia final do JOB-Pessoas (Corrige Tipo Documento, Update Holcod, Corrige IE Duplicada, Corrige Tipo Contribuinte, Atualiza a sequence, Ajustes campos) | `19_ajustes_pessoas/depois.sql` - automático, por último |
| Cria/Dropa Campo Temporário | não precisam: os itens localizam pelos vínculos permanentes |
| FB - Ajuste CPF em branco / Ajusta CPF/CNPJ em branco | viraram filtro/regra no `origem.sql`/`transformar.py` (a origem não é alterada) |

**Grupo Estoque** (depois dos produtos; segue a opção "Incluir produtos fora de linha"):

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `40_inicio_estoque` | (só SQL, automático, PRIMEIRO do grupo) | tipos de ajuste 9001/9002 e `ALTER TABLE produto DISABLE TRIGGER ALL` (pedido do usuário: sem isso demora muito); `finalizar.sql` religa mesmo se a migração parar com erro |
| `41_saldo_positivo` | ESTOQUE (≥ 0) → estoque_movimentacao | ajuste 9002, histórico MIGRACAO, local 1, loja do PROPRIO; um movimento MIGRACAO por produto + recálculo do `estoque_resumo` (ver abaixo) |
| `42_saldo_negativo` | ESTOQUE (< 0) → estoque_movimentacao | idem |
| `43_estoque_minimo_maximo` | PRODUTO → produto_estoque | estourado > 100000 = 0; máximo < mínimo = mínimo; vazios = 0 |
| `44_movimentacao_custo` (3 etapas) | PRODUTO, ESTOQUE → movimentacao_de_custo, custo_dia, auditoria_custo | custos de produtos com estoque ≥ 0; custo fiscal/médio 0 ou vazio = reposição; sem duplicar (no Pentaho a chave era a sequence). Como no Pentaho, `moc_custo_medio` recebe o custo fiscal (a confirmar) |
| `49_fim_estoque` | (só SQL, automático, ÚLTIMO do grupo) | `ALTER TABLE produto ENABLE TRIGGER ALL` |

**Saldo de estoque** (sem o "Zerar o estoque" do Pentaho, a pedido do usuário): para cada produto,
o saldo do SysPDV é comparado com a soma dos movimentos **MIGRACAO** daquele produto (loja + local 1):
- igual e com um movimento só → sem alteração (nada é apagado nem inserido);
- diferente, ou com mais de um movimento MIGRACAO (ex.: os do "Zerar" do Pentaho) → apaga os
  movimentos MIGRACAO **só daquele produto** e lança o saldo correto num movimento só;
- sem movimento → lança o saldo.
No fim, o `estoque_resumo` (loja matriz, local 1) é recalculado com a soma da `estoque_movimentacao`
(com LEFT JOIN: produto que ficou sem movimento vai a 0). Apagar produto a produto garante que,
marcando só "Saldo positivo", o saldo dos produtos negativos não se perde. Movimentos que não são
MIGRACAO são mantidos (numa base nova não existem: o saldo fica igual ao do SysPDV).

**Grupo Financeiro**:

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `50_contas_receber` (5 etapas) | CONTARECEBER, CONTASRECEBERLIQUIDACAO → conta_a_receber, titulo_a_receber, movimentacao_titulo_receber (+ categoria, centro de custo, configuração de lançamento) | versão nova do `T-ContaReceber`: cliente pelo **código** e **categoria 9 fixa** (antes PLCRED); contas A e P de clientes migrados; documento vazio = id; título ABERTO (A) ou PARCIALMENTE_LIQUIDADO (P, ligado pelo id — no Pentaho pelo número do documento, o que marcava títulos de outros clientes); inclusão + liquidações parciais sem duplicar (no Pentaho dobravam a cada execução); sem o "Ajuste Juros e Mora" (particular de cada cliente) |
| `51_contas_pagar` (2 etapas) | CONTAPAGAR → conta_a_pagar, titulo_a_pagar, movimentacao_titulo_pagar (+ lançamentos) | em aberto e não excluídas; emissão vazia = vencimento − 30; fornecedor por código **e** CNPJ só dígitos; **categoria 32 fixa** (a constante do .ktr; antes PLCRED); movimentação ligada pela conta (no Pentaho pelo valor); o 1º passo do Pentaho (Cria Espécie) está todo comentado e não entra |
| `59_fim_financeiro` | (só SQL, automático, último do grupo) | "Insert Item Configuração Lançamento Financeiro" do Migrador_Inicial |

**Fila do Panamá** (`99_fila_panama`, item **automático sempre**: sem checkbox, entra em toda migração,
por último, qualquer que seja o item marcado): roda o script `InsertFilaPanama.sql` do usuário —
apaga `fila_sincronizacao` e `fila_sincronizacao_panama` e coloca na fila do Panamá todas as
finalizadoras, holding, lojas, funcionários, acesso, clientes, seções, grupos, subgrupos, produtos,
EAN e títulos a pagar/receber. Os "VF - Insert Panama" do Pentaho (receber e pagar) não rodam mais.
Em Simular, é desfeito como o resto.

**Origem Firebird ou SQL Server**: na tela, "Banco de origem". Os mesmos `origem.sql` servem para os
dois (SQL comum); onde precisa, a pasta tem `origem.sqlserver.sql`. SQL Server via ODBC (`pyodbc`):
Windows já tem o driver "SQL Server" (recomendado: ODBC Driver 18); Linux precisa do `msodbcsql18`
(passo a passo em `linux/LEIA-ME.md`).

Diferenças propositais em relação ao Pentaho, para poder rodar de novo sem duplicar:
- **Agente Financeiro**: localizado pela `pessoa_agente_financeiro`, sem a coluna temporária
  `age_codigo_syspdv`.
- **Funcionário**: localizado pela `pessoa_funcionario`, sem a coluna temporária
  `fun_codigo_syspdv` (o Pentaho criava a pessoa de novo a cada execução). O filtro fixo
  `loj_codigo = 3` do `T-Funcionario-Loja` (sobra de outro cliente) não foi levado.
- **Cliente**: localizado pela `pessoa_cliente`, sem a coluna temporária `cli_codigo_syspdv`.
  Clientes com o MESMO CPF/CNPJ ficam ligados à mesma pessoa (no Pentaho o primeiro se perdia);
  numa nova rodada eles aparecem como "atualizado" com o conflito no relatório - é o alerta de
  documento repetido no SysPDV. O Cliente já aplica nos seus campos as correções dos Ajustes
  finais (bairro, fantasia, CPF com 14 dígitos = JURIDICA), para não "atualizar" à toa.
- **Ajustes finais de Pessoas**: o "Corrige IE Duplicada" tinha `pes_codigo != 21` fixo (a loja
  daquele cliente); aqui a exceção é a pessoa de qualquer loja.
- **SQLs que alteravam o SysPDV** ("FB - Ajusta CPF/CNPJ em branco", "FB - Ajuste CPF em branco"): viraram filtro no
  `origem.sql`, com o mesmo efeito, sem mexer na origem.

Diferenças propositais em Impostos Federais, para poder rodar de novo sem quebrar:
o UPDATE não troca os 4 IDs (o Pentaho gerava IDs novos a cada execução), e o
`depois.sql` só insere nas tabelas complementares o que ainda não existe.

## Adicionar novos itens

Veja **`comandos/COMO_ADICIONAR.md`**: o que cada arquivo faz, o passo a passo, como
traduzir uma transformação do Pentaho (.ktr) para uma pasta, e os erros mais comuns.

## Segurança

- Senhas não são gravadas em disco: vão em cada requisição.
- A origem é aberta em modo **somente leitura**: o migrador nunca altera o SysPDV.
- Os relatórios em `reports/` têm dados do cliente: não compartilhe fora do ambiente
  de migração.
