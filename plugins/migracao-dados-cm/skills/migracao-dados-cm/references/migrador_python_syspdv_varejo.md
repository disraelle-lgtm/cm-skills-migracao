# Migrador Python SysPDV (Firebird) → VarejoFacil (PostgreSQL) — `migrador_syspdv_varejo`

Ferramenta interna criada pelo time (out/2026) para migrar SysPDV → VarejoFacil **sem
Pentaho**, com as mesmas regras do migrador Pentaho oficial
(`1 - Migrador Syspdv-Varejo(Firebird)` / `Migrador_Inicial.kjb`). O código completo está em
`assets/migrador_syspdv_varejo.json` — recrie a pasta com
`python3 scripts/recriar_migrador.py /tmp` (sem as DLLs do client Firebird — ver seção 6).

## Sumário
1. Visão geral e estrutura
2. Motor: contrato das pastas de comandos
3. Tela
4. Itens prontos (catálogo e regras)
5. Diferenças propositais em relação ao Pentaho
6. Instalação por sistema (Linux / Windows)
7. Método: converter um .ktr do Pentaho em pasta de comandos
8. Problemas comuns
9. Próximos passos (Produto em diante)
10. Histórico da ferramenta

---

## 1. Visão geral e estrutura

- Uma tela web local (FastAPI, http://127.0.0.1:8020): **conexões** no topo (só a aba do
  sistema em uso — Linux ou Windows, detectado sozinho) e, abaixo, **checkboxes** dos dados a
  migrar. **Sem opção Simular na tela** (retirada a pedido do usuário, v2026.10.31): a tela sempre
  grava, depois de um `confirm()` com a aba (inicial/virada), a quantidade de itens, o banco de
  destino e os arquivos de códigos anexados. Rodar de novo é seguro ("sem alteração").
- **Origem Firebird ou SQL Server** ("Banco de origem" na tela, nos dois sistemas); destino sempre
  PostgreSQL. SQL Server via ODBC (`pyodbc`, carregado só quando escolhido): driver escolhido
  sozinho (ODBC Driver 18 → 17 → Native Client 11 → "SQL Server" do Windows); campos host, porta
  (1433) ou instância, banco, usuário, senha, driver opcional; `ApplicationIntent=ReadOnly`.
  Linux precisa de `unixodbc` (o `instalar.sh` instala) + `msodbcsql18` da Microsoft (passo a passo
  no `linux/LEIA-ME.md`). Validado pelo usuário com SQL Server real.
- **Progresso**: barra verde 0–100% (cada item/etapa vale uma parte igual; o que está rodando
  avança por lidos ÷ "Na origem"; vermelha se terminar com erro) + tabela por item.
- Cada checkbox é uma **pasta em `comandos/`** com os comandos daquela entidade — é ali que se
  corrige ou acrescenta regra, sem mexer no código.
- **Lógica única** para Linux e Windows (`app/`, `comandos/`, `static/`); só a instalação é
  separada (`linux/` e `windows/`, cada uma com `LEIA-ME.md`).

```
migrador_syspdv_varejo/
├── app/                motor.py, main.py, ajudantes.py, firebird_conexao.py, sqlserver_conexao.py,
│                       senha_postgres.py, virada.py, docker_firebird.py, verificar_fbclient.py,
│                       codigos/ (ajuste.py + ajusta_cliente.sql/ajusta_produto.sql do kit)
├── comandos/           uma pasta por item (ver seção 4) + _modelo/ + COMO_ADICIONAR.md
├── comandos_virada/    só o exclusivo da virada (20_virada_codigos_produto) + LEIA-ME.md
├── static/index.html   a tela
├── reports/            relatório "linha a linha" (CSV) de cada execução
├── requirements.txt    fastapi, uvicorn, fdb, psycopg[binary], pyodbc
├── linux/              instalar.sh, iniciar-app.sh, LEIA-ME.md
└── windows/            instalar.bat, instalar-windows.ps1, iniciar-app.bat, parar-app.bat,
                        firebird_client_x64/ (client 2.5.9 64 bits oficial), LEIA-ME.md
```

Princípios: a origem (SysPDV) é aberta **somente leitura** (nunca alterar o banco do
cliente); senhas não são gravadas em disco; cada linha roda num savepoint (erro numa linha
não derruba as outras); rodar de novo é seguro (upsert, sem duplicar).

## 2. Motor: contrato das pastas de comandos

| Arquivo | Onde roda | Obrigatório | Para quê |
|---|---|---|---|
| `modulo.json` | — | recomendado | `nome` (checkbox), `grupo` (título na tela), `chave` (relatório), `mensagem_validacao`, `automatico_com_grupo` |
| `origem.sql` | Firebird / SQL Server | **sim** | SELECT das linhas a migrar (colunas chegam em minúsculo); escrever SQL comum aos dois bancos (CASE, COALESCE, CROSS JOIN, LEFT…) |
| `origem.sqlserver.sql` | SQL Server | não | versão só para origem SQL Server (ex.: `LTRIM(RTRIM(x))` no lugar de `TRIM(x)`, que só existe no SQL Server 2017+) |
| `transformar.py` | Python | não | `def transformar(linha) -> dict`; as chaves viram `%(campo)s` |
| `validar.sql` | Postgres | não | precisa devolver 1 linha (ex.: pai existe); senão erro com `mensagem_validacao` |
| `existe.sql` | Postgres | não | busca o registro; sem ele, sempre insere |
| `inserir.sql` | Postgres | **sim** | INSERT (ID via `nextval('sequence')`) |
| `atualizar.sql` | Postgres | não | UPDATE quando existe e algum valor mudou |
| `antes.sql` / `depois.sql` | Postgres | não | rodam 1 vez antes/depois do item (vários comandos com `;`, sem `%(campo)s`) |
| `finalizar.sql` | Postgres | não | roda **sempre no fim da execução, mesmo se a migração parar com erro** (commit próprio) — para desfazer o que não pode ficar pela metade (ex.: religar triggers) |

Fluxo por linha: `transformar.py → validar.sql → existe.sql →` não achou: `inserir.sql`
(inserido) · achou e mudou: `atualizar.sql` (atualizado) · achou e igual: nada (sem_alteracao).
"Mudou" = alguma coluna devolvida pelo `existe.sql` com o mesmo nome de um campo do
`transformar.py` tem valor diferente (o id não está no dicionário, então não é comparado).
Comparação tolerante a tipo (`_iguais` no motor): `0` = `'0'` = `Decimal('0.00')`, `'N '` = `'N'`
(CHAR com espaços) e `date` = `datetime` à meia-noite (o SQL Server devolve datetime) — sem isso, colunas numéricas recebidas como texto davam "atualizado" falso.
Truque usado: devolver no `existe.sql` uma expressão booleana com alias igual a um campo fixo
do `transformar.py` (ex.: `loja_matriz_ok`) para forçar atualização quando uma relação muda.

Variações suportadas:
- **Item com etapas**: pasta do item sem `origem.sql`, com subpastas (`01_aplicacao/`...) — um
  checkbox, várias tabelas (ex.: `04_tabelas_basicas`, `07_loja`).
- **Item só de SQL**: só `modulo.json` + `depois.sql` (ex.: `19_ajustes_pessoas`).
- **Item automático**: `"automatico_com_grupo": "Cadastro de Pessoas"` — some da tela e roda
  sozinho, na ordem da pasta, quando algum item do grupo é marcado.
- **Item automático sempre**: `"automatico_sempre": true` — some da tela e entra em TODA execução,
  na ordem da pasta, qualquer que seja o item marcado (ex.: `99_fila_panama`, por último).
- **Item automático por item**: `"automatico_com_itens": ["41_saldo_positivo", "42_saldo_negativo"]` — sem
  checkbox, entra só quando algum desses itens é marcado (ex.: `42_saldo_zero` não roda se só a Movimentação de
  custo for marcada). **Validação que pula**: `"validar_pula": true` — `validar.sql` sem linha = "pulado" (com a
  `mensagem_validacao`), não erro. **Sem contagem**: `"sem_contagem_origem": true` — sem "Na origem"/"Não migrados".
- **Erros por tabela** (v2026.11.16): a cada erro o motor guarda `amostra_erros` (até 50: chave + motivo) e no fim
  grava `<etapa>_erros.csv` (`relatorio_erros`: chave, mensagem, tecnico, origem). A tela abre sozinha o cartão da
  tabela com erros, mostra "Erros (N)" (Registro × Motivo) e o botão "Baixar só os erros (N) .csv". `motor.mensagem`
  traduz os erros comuns do PostgreSQL (`_traduzir_erro_pg`, pelo `sqlstate`/`diag`): 23503 chave estrangeira ("procod X
  não existe na tabela produto do VarejoFácil (o registro de que ele depende não foi migrado)"), 23505 único, 23502
  obrigatório vazio, 22001 texto grande, 22003 número grande, 22P02 formato, 23514 check; a mensagem técnica original vai
  na coluna `tecnico` da planilha.
- **Não migrados pela regra da seleção** (v2026.11.17, pedido do usuário: "tinha 100 produtos e migrou 90 — mostrar
  o motivo dos 10"): arquivo opcional `nao_lidos.sql` na pasta da etapa — SELECT na ORIGEM dos registros que o
  `origem.sql` deixa de fora, com as colunas `REGISTRO`, `DESCRICAO`, `MOTIVO` (aceita `:opcao_x`; SQL comum Firebird/
  SQL Server). O motor roda depois da leitura (`nao_lidos_total`, `nao_lidos` até 50; `<etapa>_nao_migrados.csv` em
  `relatorio_nao_lidos`). A tela abre o cartão sozinha e mostra, em laranja (erros ficam em vermelho), "Não migrados
  pela regra da seleção (N)" com Registro × Descrição × Motivo + "Baixar os não migrados (N) .csv". Hoje só no
  `20_produto`: código zerado (`00000000000000`), sem descrição, fora de linha (opção desmarcada). "Não migrados" =
  origem − (inseridos + atualizados + sem alteração): inclui os não lidos (esta lista) e os erros/pulados (lista de erros).
- **"Na origem" = o que a seleção lê** (v2026.11.25, pedido do usuário: "Não migrados" só quando for erro/pulado):
  `_contar_origem` conta `SELECT COUNT(*) FROM (<origem.sql sem comentários, com as opções e sem o ORDER BY final>)
  contagem` (`_sem_order_by`: o SQL Server não aceita ORDER BY em subconsulta). Se a subconsulta falhar (coluna sem
  nome ou repetida — Firebird e SQL Server recusam), no fim da leitura `total_origem = lidos`. `contagem_origem`/
  `tabela_origem` explícitos só no `20_produto` (conta a tabela sem código zerado + `nao_lidos.sql` com o motivo).
  Antes: grupo/subgrupo "órfão" (seção/grupo inexistente no SysPDV), funcionário inativo, cliente sem nome,
  fornecedor sem CNPJ apareciam como "1 não migrado" sem erro no log.
- **Ajuste de códigos: barra de progresso** (v2026.11.41, pedido do usuário): `ajuste.ajustar(..., progresso)`
  mantém `{"tipos": {q: {total, feitos, pct, fase}}}`; os scripts do kit dão RAISE NOTICE a cada código trocado
  ("CODIGO ANTIGO: …" / "AJUSTANDO PRODUTO DE …"), recebidos ao vivo pelo `add_notice_handler` → troca = 0–85% real;
  limpeza dos EAN (7 passos, `_limpeza_ean(..., passo)`) 85–95%; planilhas 95–100%. `/codigos/status` devolve
  `progresso {pct (média dos tipos), tempo, tipos}`; a tela mostra a barra geral (`#codBarra`, mesmo visual da
  migração) e uma barra por tipo (`#codTipos`). Testado: 300 clientes + 3.000 produtos, 0→100% em 11 s.
- **Ajuste de clientes falhava** (achado na 11.41; defeito antigo): depois da troca o migrador remove a coluna
  temporária do kit (`ALTER TABLE pessoa_cliente DROP COLUMN codigo_cliente_antigo`) na mesma transação, e as FKs
  `DEFERRABLE INITIALLY DEFERRED` do VarejoFácil deixavam conferências pendentes → "cannot ALTER TABLE … because it has
  pending trigger events" e o ajuste inteiro era desfeito. Agora `SET CONSTRAINTS ALL IMMEDIATE` antes do DROP COLUMN
  (as chaves são conferidas na hora; errada = erro e rollback) e `SET CONSTRAINTS ALL DEFERRED` depois. Antes só
  tinha sido testado com produtos e poucas linhas.
- **Saldo de estoque pela DIFERENÇA, sem apagar movimentos** (v2026.11.40; caso real SQL Server: 9.103 e 4.751
  erros "mov_id … ainda é usado na tabela item_inventario" — o VarejoFácil já tinha inventários apontando para os
  movimentos MIGRACAO e o `atualizar.sql` antigo fazia DELETE + INSERT). Em `41_saldo_positivo`, `42_saldo_negativo`
  e `42_saldo_zero/01_zerar_lancados`: `existe.sql` devolve o saldo ATUAL (`COALESCE(SUM(mov_quantidade),0)` de TODOS
  os movimentos da loja/local 1 — a mesma conta do recálculo do `estoque_resumo` no `depois.sql`); igual = sem
  alteração; diferente = `atualizar.sql` faz UM INSERT (mov_id novo, MIGRACAO, eta 9002, quantidade com sinal) com
  `%(mov_quantidade)s::numeric - SUM(...)` e `HAVING diferença <> 0`; todos os parâmetros com cast (preparo). Testado:
  inventário intacto, +15 para 45→60, rodar de novo = sem alteração.
- **Produto não migrado é IGNORADO nas demais tabelas** (v2026.11.40, pedido do usuário): o motor já tinha
  `exige_produto` (carrega os `procod` do VarejoFácil uma vez por etapa e transforma a linha em `Pular` "produto X não
  foi migrado para o VarejoFácil (veja o cartão do Produto)"), mas NENHUM item usava. Agora em 19 etapas:
  20_produto_beneficio_fiscal, 21, 22, 23, 24 (`procod`), 26/02 (`codigo_produto`), 27/01 e 28/01 (`comp_procod`),
  27/02 e 28/02 (`cc_procod`, `procod`), 29/02, 31/02, 41, 42, 42_saldo_zero/01, 43, 44/01-03 (`procod`). Ficam de
  fora o Produto, NCM, tributação, cenário NCM e 31/01 (não são registros de um produto).
- **Caracteres de controle** (v2026.11.40; caso real: "invalid literal for int() with base 10: '0\x105'" no Produto,
  um `\x10` no meio de um código): `ajudantes.sem_controle` (remove `[\x00-\x1f\x7f]`) em `texto()` e `inteiro()`;
  o `_int_ou_nulo` do Produto usa `texto()` e o erro passa a dizer o campo ("GRPCOD não numérico: …"). O quadro "Regras
  da migração" ganhou as duas regras novas (produto não migrado ignorado; saldo existente ajustado pela diferença).
- **Impostos federais com CST vazio** (v2026.11.39; caso real: base SysPDV com IMPFEDST nulo em quase todos os
  impostos → só 1 migrava). A regra do Pentaho `IMPFEDST <> IMPFEDSTSAI` deixava o nulo de fora (NULL <> X não é
  verdadeiro). Agora `(IMPFEDST IS NULL OR IMPFEDSTSAI IS NULL OR IMPFEDST <> IMPFEDSTSAI)` em `05_impostos_federais/
  origem.sql`, no "preferir os migrados" do `21_impostos_federais_produto` (origem e nao_lidos) e na contagem do
  formulário: o imposto vai com o CST vazio (colunas aceitam nulo em `impostos_federais` e `impostos_federais_geral`;
  o `depois.sql` compara com IS DISTINCT FROM) para corrigir na aplicação. CST iguais continuam de fora (Pentaho).
  Depois de atualizar: rodar Impostos Federais e Impostos federais do produto de novo.
- **Página Migração: grupos um abaixo do outro** (v2026.11.38, pedido do usuário; vale para Inicial e Virada,
  Firebird e SQL Server — mesma montagem em `carregarModulos`): `.grupos-grade` em coluna (flex, max-width 1100px,
  alinhada à esquerda), na ordem **Exceção** (grupo novo, no topo, só com as `opcoes` dos `modulo.json` — "Incluir
  produtos fora de linha" e "Só com movimentação desde [data]", data ao lado; some se nenhum item tiver opção),
  Cadastros Padrão, Cadastro de Pessoas, Cadastro de Produto, Estoque, Financeiro. Dentro do grupo os itens seguem em
  colunas.
- **Achado na 11.38:** a página Consultar códigos aparecia deslocada à direita porque a limpeza do relatório padrão
  duplicado (11.36) deixou um `</div>` a mais na página Relatórios, fechando antes da hora o bloco das páginas. Depois
  de mexer no `index.html`, conferir o equilíbrio `<div>`/`</div>` de cada `<section class="pagina">` (e da página
  inteira) e procurar ids repetidos; nas capturas, esperar a lista de itens carregar (`#listaModulos .grupo-card`).
- **Relatórios → Relatório padrão (kit-migração)** (v2026.11.36–37, `app/relatorio_padrao.py`, rota
  `/relatorios/padrao`, quadro abaixo do formulário): as três listagens do kit (`kit-migracao/3-menu-migracao/app/
  relatorios/varejo.py`, "Gerar relatório padrão" do banco VarejoFácil) com as MESMAS consultas: `LISTAGEM DOS
  PRODUTOS PRECO ZERO.csv` (no kit estava "LISTAR…" — corrigido a pedido do usuário), `LISTAGEM DOS PRODUTOS QUE O
  NCM ESTA INATIVO.csv`, `LISTAGEM DOS PRODUTOS UNIDADE DE MEDIDA ERRADO.csv` (`;` + cabeçalho; psycopg em vez do
  `\copy` do kit; UTF-8 com BOM para o Excel) + `Relatório padrão - <banco>.zip`. O relatório padrão "SysPDV" do kit
  (`syspdv.py`) é para migrações PARA o SysPDV — não entra. O kit também tem o formulário (`formulario_padrao`,
  contagens só do destino; modelos `validacao_migracao.docx` e `validacao_migracao_syspdv.docx`), a Correção
  (`ajusta_produto.sql`/`ajusta_cliente.sql`, usados sem alteração no menu Códigos), PostgreSQL (backup) e AWS.
- **Nome do formulário** (v2026.11.36): baixa como `<Nome do Cliente> (<CNPJ>) - Validação de Migração.docx`
  (`formulario.nome_arquivo`: nome vazio = razão social da loja matriz; CNPJ = `pes_num_documento` da loja matriz;
  tira `/ \ : * ? " < > |`), numa subpasta por geração; a rota `/download/{exec_id}/{arquivo:path}` entrega os de
  `relatorios` com o próprio nome (os da migração levam o id da execução).
- **Formulário: composição e kit** (v2026.11.35; caso real: SysPDV com 39 produtos `PROCOMP = 'S'` e 9 `'K'` sem
  nenhum registro em COMPOSTO/COMPONENTE → o formulário mostrava 39/9 × 0). Contam como a migração e o Pentaho: produto
  marcado E com `EXISTS` na `COMPOSTO` (composição) / `COMPONENTE` (kit); no destino, `composicao` com `comp_tipo`
  vazio (composição) ou preenchido (kit: PRECO/FATOR).
- **Cuidado ao mexer na tela/servidor** (achado na 11.36): uma versão anterior do relatório padrão já estava nos
  arquivos e a nova ficou DUPLICADA (2 quadros, 2 rotas `/relatorios/padrao`, 2 tratadores, CSS repetido) — o teste
  passou porque o FastAPI usa a primeira rota. Antes de acrescentar algo, procurar se já existe; depois, conferir ids
  repetidos no `index.html` e rotas repetidas no `main.py`.
- **Parâmetros: UM tipo por parâmetro** (v2026.11.33; erro real "inconsistent types deduced for parameter $14 …
  text versus character varying" no Item da tabela tributária, introduzido na 11.28). O psycopg PREPARA o comando a
  partir da 6ª execução e o PostgreSQL recusa o mesmo parâmetro deduzido com tipos diferentes (ex.: `%(itt_uf)s` sem
  tipo na lista do SELECT = text e numa comparação com coluna varchar = varchar). Regra: o MESMO cast em todas as
  ocorrências (`%(x)s::varchar` em todas). Testes com poucas linhas NÃO pegam isso: testar cada validar/existe/
  inserir/atualizar com `con.execute(sql, {nomes: None}, prepare=True)` numa transação desfeita, num banco do
  VarejoFácil (o backup vazio serve) e olhar só "inconsistent types deduced"/"could not determine data type" — 184
  arquivos passam na 11.33 (antes falhava o `25_tributacao_produto/03/inserir.sql`; também uniformizados 08/09/11
  inserir e 20_produto existe).
- **Cenário fiscal por NCM › NCMs do cenário** (v2026.11.33; caso real: 4.756 erros): 4.728 eram NCM com
  `CLATRBCODNFCE` EM BRANCO ('      ', não nulo — só o nulo era descartado) e 28 eram NCM que nenhum produto migrado
  usa (o `06_ncm` só leva os NCMs dos produtos → FK em `ncm`). A seleção agora: classificação preenchida
  (`<> ''`), JOIN (não LEFT) com `CLASSIFICACAO_TRIBUTARIA` com CST e só NCMs usados por produtos migrados (segue
  fora de linha/movimentação). O VarejoFácil vazio já traz a tabela OFICIAL de NCM (11.038, 10.517 ativos); NCM que
  "tem no SysPDV e não no VarejoFácil" é descontinuado — o `06_ncm` cria como INATIVO só os usados por produtos.
  Alternativas apresentadas ao usuário (cenário de todos os NCMs do SysPDV existentes no VarejoFácil; migrar todos os
  NCMs) — ele decidiu MANTER como está.
- **Desempenho: lista montada uma vez** (v2026.11.34; a 11.33 deixou o cenário NCM muito lento). Evitar
  `coluna IN (SELECT coluna FROM PRODUTO …)` quando a coluna não é a chave (PRONCM, TRBID não têm índice): o Firebird
  refaz a busca na PRODUTO para cada linha de fora. Usar `FROM (SELECT DISTINCT p.PRONCM FROM PRODUTO p WHERE …)
  usados JOIN NCM t1 ON t1.NCMCOD = usados.PRONCM` (a âncora do filtro de produto continua dentro da subconsulta e a
  contagem pela seleção funciona). Medido (10.500 NCMs, 60 mil produtos): NCMs do cenário 105 s → 0,11 s; item da
  tabela tributária (`CROSS JOIN PROPRIO`) 5,5 s → 0,05 s, mesmo resultado. Comparar pela chave (`PROCOD IN (SELECT
  PROCOD …)`, SECAO, UNIDADE) é rápido.
- **Limite de crédito sempre BOLETO RECEBER** (v2026.11.30; caso real: base que já tinha espécies → os Ajustes do
  Cliente criaram BOLETO RECEBER com o código 3 e o código 2 fixo do limite era BOLETO PAGAR). `09_limite_credito`
  procura a espécie pelo NOME (`UPPER(TRIM(edc_descricao)) = 'BOLETO RECEBER'`, preferindo sigla BR e gênero R) no
  inserir/atualizar; `antes.sql` cria a espécie se faltar (mesmo INSERT dos Ajustes do Cliente); `existe.sql` devolve
  `especie_boleto_receber` (o transformar manda True) → limite com outra espécie é corrigido ao rodar de novo.
- **Opção "Só com movimentação desde [data]"** (v2026.11.31; `20_produto/modulo.json` opção `movimentacao`, tipo
  "data"; a tela mostra o campo de data abaixo da caixa, exige a data e lembra; opcoes `movimentacao` +
  `movimentacao_data` ISO). Consulta da equipe, conferida no dicionário do SysPDV: venda `ITEVDA.TRNDAT`, nota
  `ITEM_NOTA_FISCAL` JOIN `NOTAFISCAL` (`NFSCTR`, `NFSDATEMI`), `ESTOQUE_MOVIMENTACAO` (`MOVTIP` V,E,C,T,N — sem o 3 =
  ordem de produção; `MOVDAT`) ou `PRODUTO.PRODATCADINC`, todos `>= data`. Mudanças em relação ao script da equipe:
  data como PARÂMETRO (o texto '10.11.2026' vira 11/10 no SQL Server mdy), sem IN aninhado/GROUP BY, sem
  `proforlin = 'N'` fixo (combina com a opção fora de linha). Implementação: `motor.RE_FORA_DE_LINHA` — toda seleção
  ligada a produto (26 origem*.sql, inclusive as .sqlserver) tem `(COALESCE(<alias>.PROFORLIN, 'N') = 'N' OR
  :opcao_fora_de_linha = 1)`; com a opção marcada, `_sql_com_opcoes` acrescenta `AND filtro_movimentacao(alias)` logo
  depois dele (âncora; item novo de produto que siga o padrão ganha o filtro sozinho); `:param_mov_data` = data;
  `/*MOVIMENTADO(alias)*/` para uso explícito (o `nao_lidos.sql` do Produto lista "sem movimentação desde a data
  escolhida"). `valores_opcoes` mantém o valor das opções `*_data`. Formulário: contagens de produto com o filtro
  (`CAST('AAAA-MM-DD' AS DATE)`) e a data no "Migrador Usado"; confirmação da migração mostra a data. Testado no
  Firebird. Atenção: ITEVDA costuma ser enorme — se ficar lento, calcular a lista de produtos uma vez.
- **Quadro "Regras da migração"** (v2026.11.32, `static/index.html`, `regras-migracao`): na página Migração (Inicial
  e Virada), recolhível, por grupo — geral, cadastros, pessoas, produto, estoque, financeiro, final — com as regras
  fixas (código zerado; rodar de novo sem duplicar; grupo/subgrupo com seção existente; funcionário ativo e principal;
  cliente com nome e limite BOLETO RECEBER; fornecedor com CNPJ/CPF; produto sem descrição/fora de linha/
  movimentação/loccod 0/1 imposto por tipo/código de barras/encarte A-P; saldo zero; contas a receber em aberto ou
  parcial (CTRTIPPAG A/P) sem juros; contas a pagar em aberto de fornecedor com CNPJ; fila do Panamá; formulário em
  Relatórios). **Ao mudar uma regra do migrador, atualizar o texto do quadro.**
- **"Se já existe, passa" — chaves únicas do VarejoFácil** (v2026.11.28–29, erros reais numa virada). Regra geral: o
  `existe.sql` tem de procurar pela MESMA chave única que o VarejoFácil impõe; se achar o registro por essa chave com
  outro "dono" (outro código), devolve os PRÓPRIOS valores do SysPDV (`CASE WHEN <mesmo código> THEN coluna::text ELSE
  %(campo)s::text END`; booleanos sem ::text) → o motor vê "sem alteração" e passa, sem duplicar nem sobrescrever.
  * `25_tributacao_produto/03_item_tabela_tributacao`: único por `(tbt_id, itt_uf, itt_classificacao_pessoa)`
    (`itemtributacao_unique_key`); antes procurava por trbid → "já existe outro registro com tbt_id, itt_uf,
    itt_classificacao_pessoa". Mesmo trbid = atualiza; outro trbid = passa; inserir com NOT EXISTS pela chave única.
  * `29_encarte/03_encarte_loja/depois.sql` (programação de preço): único por `(procod, lojcod, pprprctip, pprdatini,
    pprdatfim, pprsta)` (`chave_programacao_preco`); só encartes A/P; preço cruzado por produto **e loja**; NOT EXISTS
    pela chave (mesmos dados = passa; dado diferente = inclui) + DISTINCT ON. Antes: só conferia `id_produto_encarte`
    → erro de chave e a etapa inteira falhava; com preço em várias lojas, repetia.
  * `08_funcionario`: `pessoa.pes_num_documento` (CPF) é único (`unq_pessoa_pes_num_documento`); o existe procura por
    código OU CPF (mesmo código = compara/atualiza; mesmo CPF com outro código = passa); o inserir reaproveita a pessoa
    de mesmo CPF que não é funcionário (ex.: cliente) e só cria o funcionário. Antes: "já existe outro registro com
    pes_num_documento".
  Para achar as chaves: `SELECT pg_get_indexdef(indexrelid) FROM pg_index WHERE indrelid = '<tabela>'::regclass AND
  indisunique`.
- **Impostos federais do produto: 1 por tipo** (v2026.11.27; caso real: 2050 duplicidades — o VarejoFácil aceita 1
  PIS, 1 COFINS, 1 IRPJ, 1 CSLL e 1 OUTROS por produto, e o SysPDV pode ligar o produto a mais de um do mesmo tipo).
  `21_impostos_federais_produto/origem.sql` lê um por (produto, IMPFEDTIP): o de **menor IMPFEDSIM**, preferindo os que
  o `05_impostos_federais` migra (`IMPFEDST <> IMPFEDSTSAI`) — `COALESCE((MIN entre os migrados), (MIN entre todos))`.
  `nao_lidos.sql` lista os descartados (REGISTRO = produto, DESCRICAO = código do imposto, MOTIVO por tipo; sem
  concatenação, que difere entre Firebird `||` e SQL Server `+`); `contagem_origem` = todas as ligações (Não migrados =
  descartados). `existe.sql` busca o imposto do MESMO tipo (`impfedtip` do VarejoFácil) e devolve `qtd_mesmo_tipo`
  (o transformar manda 1): duplicidade já gravada ou código diferente → `atualizar.sql` mantém UM registro (o de mesmo
  código ou o menor `impfpid`), troca o imposto e apaga os demais do tipo. Rodar o item de novo corrige bases migradas
  antes. Formulário: "Imp. Federais Produtos" conta (PROCOD, IMPFEDTIP) distintos. Regra do "menor código" escolhida
  pelo Claude e aceita pelo usuário ("vamos ver se haverá reclamação"): se mudar o critério, é só o `ESCOLHIDO` do
  origem/nao_lidos. Consulta de conferência do usuário: produtos com mais de um impostos_federais_produto do mesmo
  `impfedtip` (deve voltar vazia).
- **Funcionário** (v2026.11.26): o vínculo `pessoa_funcionario_loja` com a loja matriz é gravado e atualizado com
  **`pfl_principal = TRUE`** (coluna boolean NOT NULL, padrão false; os 3 funcionários padrão do VarejoFácil vazio já
  vêm true); `existe.sql` compara `pfl_principal`, então rodar o item de novo corrige bases migradas antes (false →
  true). Funcionário de **código 0** não é migrado: filtro `REPLACE(FUNCOD, '0', '') <> ''` (testado com FUNCOD
  inteiro, CHAR e VARCHAR com espaço) + `Pular` no `transformar.py`. Funcionário 0 em bases migradas antes da
  2026.11.20: limpar com, numa transação, `DELETE FROM usuario WHERE funcod = 0`, `DELETE FROM
  pessoa_funcionario_loja WHERE fun_codigo = 0` e `DELETE` da `pessoa_funcionario` (fun_codigo 0) + a `pessoa` dela
  — se o funcionário 0 estiver em uso (dezenas de tabelas têm FK para `pessoa_funcionario`, ex.
  `pessoa_cliente.fun_codigo_vendedor`), o PostgreSQL recusa e nada é apagado.
- **Código zerado não é lido** (v2026.11.20): `REPLACE(codigo, '0', '') <> ''` (Firebird e SQL Server; vale para
  00/000/000…): seção, grupo/subgrupo (SECCOD/GRPCOD/SGRCOD), funcionário, cliente, fornecedor, agente, finalizadora,
  produto. O `nao_lidos.sql` do Produto não lista mais o código zerado.
- **`loccod = 0` sempre no produto** (v2026.11.20): o VarejoFácil não tem local de impressão como o SysPDV (LOCCOD 95
  dava erro de chave); `transformar.py` grava 0 e o `39_ajustes_produto` faz `UPDATE produto SET loccod = 0 WHERE
  loccod IS DISTINCT FROM 0`. Por isso o LOCALIMP do migrador Pentaho de SQL Server não foi levado.
- **Menu Relatórios → Formulário de validação** (v2026.11.20–23; `app/formulario.py` + modelo
  `app/formulario_modelo/validacao_migracao.docx` = formulário da Casa Magalhães; `python-docx` no requirements). O menu
  só aparece depois que uma MIGRAÇÃO INICIAL termina (`reports/ultima_migracao.json`, gravado em `_registrar_migracao`;
  rota `/relatorios/estado`). Página: Nome do Cliente, Analista (lembrado), "Teve troca de códigos dos produtos/
  clientes?" (lista Sim/Não) → `/relatorios/formulario` (usa as conexões de Conexões; gera em `reports/relatorios/`).
  Preenche: título "Migração Inicial — data", nome do cliente, analista, origem, destino, versão; **Dados Migrados**
  em 3 colunas `Tabelas | Origem SysPDV | Destino VarejoFácil` (`_tres_colunas`; diferença em vermelho no destino),
  contagens com as regras da migração (SQL comum Firebird/SQL Server; falha = "—"); **Informações Complementares**
  em 2 tabelas: (1) produtos em linha / fora de linha / balança Origem × Destino, (2) Mudou Código Produto/Cliente =
  respostas (Multi Loja e Juros e Multas saíram); **Situação Fiscal** e **Impostos Federais** com a quantidade de
  produtos. `_bordas_pretas`: todas as tabelas com bordas pretas explícitas (sz 4) e sem bordas por célula — as do
  modelo (cor automática) sumiam ao salvar em PDF. Validado com `validate.py` da skill docx. O formulário NÃO é mais
  gerado no fim da migração (o pop-up aponta para Relatórios). O modelo .docx fica na skill em `arquivos_base64` do
  `assets/migrador_syspdv_varejo.json` (o `recriar_migrador.py` grava os binários).
- **Comparação com o migrador Pentaho de SQL Server** (`2 - Migrador Syspdv-Varejo(SQL Server)`): 119 ktr/33 kjb,
  quase tudo igual ao de Firebird com passos renomeados (FB → SQL). "Ajustes campos" da virada de pessoas (12
  UPDATEs) e o "Ajusta Produto" já estão nos nossos ajustes; `forpais = '01058'` já é o padrão do fornecedor; LOCALIMP
  não se aplica (loccod = 0). Nada a adicionar.
- **Desempenho** (v2026.11.14–15, medido com o banco real do VarejoFácil): (1) nunca `%(x)s IN (SELECT col FROM t)` em
  `existe.sql`/`validar.sql` — monta a lista inteira a cada linha; usar `EXISTS (SELECT 1 FROM t WHERE col = %(x)s)`
  (o `existe.sql` do EAN tinha isso: 2,5 → 0,1 ms por EAN; 10 min → ~1–3 min no usuário); (2) depois de gravar
  milhares de linhas, `ANALYZE <tabela>;` no início do `depois.sql` antes de comandos em lote — na mesma transação o
  PostgreSQL ainda "vê" a tabela vazia e cruza linha por linha (o recálculo do `estoque_resumo` levava >1 min;
  com ANALYZE < 1 s). Aplicado em 41/42/42_saldo_zero, 22 (limpeza dos EANs) e 39 (Ajustes de Produto).
  Itens de produto rodam em `session_replication_role = replica` (triggers da produtoaux etc. não disparam); o
  saldo NÃO (a trigger `processa_estoque` do VarejoFácil mantém `estoque_dia`/`estoque_resumo`: ~0,8 ms por movimento).
- **Origem que pode não existir**: `"ignorar_se_origem_falhar": true` — se o SELECT da origem falhar
  (coluna/tabela de versão nova do SysPDV, ex.: `PROBENFIS`), o item termina "concluído" com o aviso
  "o SysPDV não tem a coluna X - etapa ignorada, o fluxo continua" (`motor._motivo_origem`, entende
  Firebird "Column/Table unknown" e SQL Server "Invalid column/object name") e a migração segue.
- **Aviso no relatório**: chave `"_aviso"` no dicionário do `transformar.py` (não vai ao banco).
- **Opções ao lado do checkbox**: `"opcoes": [{"id": "fora_de_linha", "rotulo": "...", "padrao": true,
  "dica": "..."}]` no `modulo.json` → checkbox **antes** do item na tela; no `origem.sql` (Firebird)
  `:opcao_fora_de_linha` vira `?` com 1/0; nos `.sql` do Postgres `%(opcao_fora_de_linha)s`. Vale
  para a execução inteira (outros itens usam sem declarar); o `padrao` vem de TODOS os itens.
- **Contagem na origem**: antes de cada etapa conta a tabela do **FROM principal** do `origem.sql`
  (ignora FROM dentro de parênteses/subconsultas — um `(SELECT MAX(SECCOD) FROM SECAO)` no SELECT
  fazia o Produto contar a SECAO) ou `"tabela_origem"` / `"contagem_origem"` do `modulo.json`
  (subconsulta no FROM do Firebird precisa de apelido). Tela: colunas **Na origem** e **Não
  migrados** (= origem − inseridos − atualizados − sem alteração; negativo mostra "-").
- **Gravar várias tabelas numa linha**: um único comando com CTEs (`WITH nova AS (INSERT ...
  RETURNING pes_codigo) INSERT ...`) — pessoa + vínculo atômicos, sem coluna temporária.

Regras de escrita: linhas `--` são removidas antes de executar (um `%` em comentário não
quebra); `%` literal dentro de SQL do Postgres = `%%`; parâmetro que pode ser nulo em
`... IS NOT NULL` precisa de cast (`%(doc)s::text`); o mesmo `%(campo)s` repetido em contextos de
tipos diferentes dá `inconsistent types deduced for parameter` → declarar o tipo (`%(trbid)s::varchar`);
**nunca** `CAST(%(valor)s AS bigint)` sobre parâmetro que pode ser texto, nem dentro de `CASE` (o
PostgreSQL pode calcular constantes antes) — converta no `transformar.py`. Comentário `--` no FIM de
uma linha do `origem.sql` comenta o resto dela (um `)` depois dele some): comentários sempre em
linha própria. Ordem de execução = nome da pasta
(`01_`, `02_`...; pastas com `_` no início são ignoradas). Simulação (só pela API, campo
`simular` do `/migrar`, útil em testes de desenvolvimento; a tela não oferece) = uma transação só,
desfeita no final (as sequences do Postgres NÃO voltam). Execução real = commit por etapa.
Ajudantes: `inteiro()`, `texto(maiusculo, vazio, tamanho)`, `numero()`, `so_digitos()`, `Pular`.

## 3. Tela

- Conexões lado a lado (Firebird | PostgreSQL), botão Testar = só "✔ Conexão com sucesso" ou
  "✖ Erro: motivo". Só a aba do sistema em uso aparece; cada sistema guarda a sua configuração
  (localStorage, sem senhas). Windows: botão **Procurar...** (navegador de pastas do próprio
  servidor, mostra só `.fdb/.gdb` — o navegador web não revela caminho completo de arquivo).
- Checkboxes limpos (só o nome), por grupo; ⚠️ com o motivo abaixo da lista se uma pasta
  estiver incompleta. Botões Marcar/Desmarcar todos e Recarregar (relê `comandos/`).
- Progresso por item/etapa: lidos, inseridos, atualizados, sem alteração, pulados, erros e
  link do relatório "linha a linha" (status + mensagem + linha de origem).
- Servidor sobe com `--reload --reload-dir app` (recarrega ao mudar código); `/saude` devolve
  app, pasta, versão e sistema — usado pelos iniciar-app para derrubar servidor antigo.
- **Tela (estrutura da v2026.11.02, feita pela equipe e unificada na v2026.11.03)**: menu lateral no
  padrão do Portal de Revendas (faixa verde com a logo, bloco "Migrador de Dados / Versão X", itens com
  ícones e "Recolher menu" no rodapé) com as páginas **Página Inicial**, **Conexões**, **Migração** ›
  Migração Inicial / Migração Virada (checkboxes; a virada com os anexos de códigos), **Progresso** (página
  própria) e **Códigos** (consulta/ajuste ≥ 999999). Os IDs dos campos não mudaram.
- **Progresso em cartões, um por etapa**: a etapa rodando fica aberta (barra e números ao vivo: na
  origem, lidos, inseridos, atualizados, sem alteração, pulados, erros, não migrados), as concluídas se
  recolhem sozinhas e as com erro ficam abertas; seta abre/fecha qualquer uma; botões **Expandir todas /
  Recolher todas**; resumo "N de M etapas concluídas. Em andamento: X". A mensagem da etapa (ex.: o aviso
  do `ignorar_se_origem_falhar`) aparece no cartão aberto — hoje em vermelho, como erro (o usuário pode
  pedir laranja para avisos). O `/status` ainda manda `grupo`, `item_id`, `item`, `etapa`, `automatico`.
- **Pop-up no fim**: concluída / concluída com avisos (etapas com registros com erro) / parada com erro
  (com a etapa e o motivo), com o tempo total e os totais.
- **Ordem do menu** (v2026.11.19, sugestão da equipe): Página Inicial › **Conexões** › **Validação de Integridade**
  (Firebird / SQL Server) › Migração (Inicial / Virada) › Progresso › Códigos. O SERVIDOR (Firebird ou SQL Server: host,
  porta, usuário, senha) é configurado UMA vez em Conexões; a Validação usa esse servidor (linha "Servidor … (de
  Conexões) — alterar em Conexões"; sem senha, avisa e leva para Conexões) e só escolhe o ARQUIVO/BANCO. Botão "Usar
  este banco na migração" (validação sem problemas): põe o banco validado (`banco_validado` do `/validacao/status` =
  caminho como o servidor vê; no backup, o .FDB restaurado) como origem em Conexões e abre a Migração Inicial; no SQL
  Server, só no modo Banco. Página servida com `Cache-Control: no-store`.

### Validação de Integridade (`app/validacao.py`, rotas `/validacao/iniciar` e `/validacao/status/{id}`)

Usa o SERVIDOR configurado em Conexões (v2026.11.19; antes tinha campos próprios + "Copiar de Conexões") e só
escolhe o arquivo/banco; nada é gravado no banco validado; roda em
segundo plano; veredito íntegro / com avisos / com problemas. Cada aba tem o seu "O que é verificado".
- **Firebird** — arquivo **.FDB / .GDB / .GBK / .FBK** (Procurar... com `/arquivos?tipo=firebird_validar`; tipos
  aceitos: firebird, firebird_validar, bak, mdf, ldf), servidor de Conexões e **onde está o servidor**: Automático
  (container do Firebird rodando + arquivo numa pasta compartilhada → Docker, traduz o caminho; senão local) /
  Instalado neste computador / Docker (container opcional). Verificações:
  1. *Conexão e cabeçalho* (versão, ODS, OIT/OAT/Next — aviso de sweep se Next − OIT > 20000). No Linux local,
     antes de abrir confere as permissões do usuário `firebird` no arquivo e nas pastas e devolve os comandos
     (`sudo chmod o+x "<pasta>"`, `sudo chmod 666 "<arquivo>"`) — era o erro "caminho errado ou sem permissão".
  2. *Validação do servidor, somente leitura* (`svc.repair(read_only_validation=1)` = `gfix -v -n`). Com erros,
     lê o `firebird.log` (local, ou `docker exec tail` no container) e mostra só o bloco da última validação
     ("Data page N … is bad in table X"). Firebird 2.5: "secondary server attachments cannot validate" = há
     outras conexões abertas no banco (fechar SysPDV/IBExpert).
  3. *Leitura completa de cada tabela* (todas as linhas): aponta a tabela quebrada. **Bugcheck**: ler um registro
     corrompido ("internal Firebird consistency check …") derruba a conexão e o servidor BLOQUEIA o banco
     ("can't attach after bugcheck") até ser reiniciado — a conexão morta é descartada sem erro (`_descartar`)
     e as tabelas seguintes ficam "não verificada" (aviso), com a orientação de reiniciar o servidor/container.
  **Backup .GBK/.FBK** (v2026.11.19): não existe "verificar sem restaurar" no gbak — restaura (`svc.restore`) num .FDB
  novo ao lado do backup (`<nome>_RESTAURADO_<data>.FDB`) e valida o restaurado (pronto para a migração); falha =
  backup danificado/incompleto, o .FDB parcial é apagado; no Linux a pasta precisa permitir gravação para o usuário do
  Firebird (`sudo chmod o+wx "<pasta>"`, checado antes).
  Na tela, só as tabelas com problema ficam abertas; as OK ficam em "✔ N tabela(s) sem erro — clique para ver".
- **SQL Server** — servidor, porta/instância, usuário, senha, driver, e: **Banco** (estado ONLINE/SUSPECT,
  verificação de página, `DBCC CHECKDB WITH NO_INFOMSGS, ALL_ERRORMSGS, TABLERESULTS` — sysadmin/db_owner —,
  `msdb.dbo.suspect_pages`); **Arquivo .bak** (`RESTORE HEADERONLY`, `FILELISTONLY`, `VERIFYONLY` com CHECKSUM
  quando o backup tiver; sem CHECKSUM = aviso); **Arquivos .MDF + .LDF** (`DBCC CHECKPRIMARYFILE` lê o cabeçalho
  sem anexar e avisa se a versão é mais antiga que a do servidor; `CREATE DATABASE … FOR ATTACH` (sem LDF:
  `FOR ATTACH_REBUILD_LOG`) como `MIGRADOR_VALIDACAO_<data>`; `DBCC CHECKDB`; SEMPRE `sp_detach_db` no fim; a tela
  exige confirmar que são CÓPIAS — anexar atualiza a versão do arquivo). Caminhos do .bak/.MDF/.LDF são do
  servidor SQL Server. Conexão própria com `autocommit=True`. Testado só com respostas simuladas (sem SQL Server
  no ambiente de desenvolvimento): testar com servidor real antes de usar com cliente.
- **Reparo do Firebird** (`reparar_firebird`, rota `/validacao/reparar`) — implementado e testado, **SEM botão
  na tela** (o usuário pediu para tirar por enquanto). Ordem segura: cópia de trabalho do arquivo ANTES de ler
  dados do original → `gfix -mend -full -ignore` na cópia (`repair(mend_database=1, ignore_checksums=1,
  validate_database=0, validate_record_fragments=1)` — o validate padrão dá "incompatible switch combination")
  → `gbak -b -g -ig` → restore num arquivo novo `_REPARADO_<data>.FDB` (+ `.FBK`) → valida → compara registros por
  tabela com o original. Uma conexão de serviço por passo (um passo com erro deixa a conexão "busy"). Funciona
  com o original bloqueado por bugcheck (trabalha na cópia). Registros realmente destruídos se perdem.

- **Login: PENDENTE** — o usuário pediu "a regra de login igual à do portal de revendas", mas essa regra
  não está documentada na skill: perguntar (campos, onde a senha é conferida) antes de implementar.
  O bloco do usuário no menu já está pronto para mostrar o nome/perfil logado.
- **Senha do PostgreSQL sempre validada** (`app/senha_postgres.py`, usado em todo `_pg()`): senha
  vazia é recusada antes de conectar; se o servidor não usou a senha (`con.pgconn.used_password`
  falso = `pg_hba.conf` em `trust`, que aceita qualquer senha), a senha informada é conferida contra
  a senha gravada em `pg_authid` (SCRAM-SHA-256: PBKDF2 + ClientKey/StoredKey; ou MD5). Mensagens:
  "Informe a senha", "Usuário ou senha incorretos", "Senha do PostgreSQL incorreta", "O usuário 'x'
  não existe" (antes do "banco não existe": o texto de erro do PostgreSQL é parecido).

### Tempo de cada etapa e tempo total

Coluna **Tempo** no Progresso (leitura + gravação + commit da tabela; o item rodando conta ao vivo,
em laranja), "— concluído em X" na linha de fim de cada etapa no log, tempo decorrido dentro da
barra ("74% · 12min 05s") e "⏱ Tempo total da migração" no status e na última linha do log (também
quando termina com erro). Formato: 0,8s / 45s / 2min 05s / 1h 02min 05s (`motor.formatar_duracao`
e `formatarDuracao` na tela). `/status` devolve `duracao` por item e `tempo_total`.

### Abas "Migração Inicial" e "Migração Virada" (seção 2 da tela)

- As duas abas abrem **sempre com tudo desmarcado** (inclusive ao trocar de aba); não troca de aba
  com migração em andamento. As abas Linux/Windows usam a classe `abas-sistema` (não confundir).
- **Inicial** = itens de `comandos/`. **Virada** = os MESMOS itens de `comandos/` + os exclusivos de
  `comandos_virada/` (`motor.descobrir_conjunto`). `/modulos?conjunto=` e `/migrar` com `conjunto`.
- **De-para de códigos** (`app/virada.py`): na aba Virada, anexar as planilhas
  `cod_novo_cod_antigo_<cliente|produto>_todos_<banco>.csv` da seção 4 (aceita também o formato do
  Pentaho: `codigo_novo`, `codigo_antigo`/`Cod_Antigo`; separador `;` ou `,`; BOM). Sem arquivo, o
  item roda como na inicial (só produtos mudaram → anexa só o de produtos).
  - `modulo.json` declara os campos: `"depara": {"procod": "produto"}` (21 etapas: limite de
    crédito, contas a receber, impostos, EAN, fornecedor, preço, família, compostos, kit, encarte,
    cenário por produto, saldos, mín/máx, custo) e, no item principal, `"depara_gera"` (Cliente:
    `cli_codigo` + `"reaproveitar"` = SQL pelo CPF/CNPJ; Produto: `procod` + `"balanca": "proenvbal"`).
  - Registro FORA da planilha (cadastrado no SysPDV depois da inicial): balança mantém; código válido
    (1..999998) que não é destino de outro registro na planilha mantém; EAN (≥ 999999) ou código de
    outro → **próximo código vago e válido** (produto a partir de 10001, cliente a partir de 1) —
    pedido do usuário: "sempre o último código vago e válido, sem ser o EAN".
  - Rodar de novo não duplica: produto reaproveita a troca anterior (lida de
    `alteracao_produto_sped` no início), cliente reaproveita pelo mesmo CPF/CNPJ. Testado 3 rodadas.
  - Relação numa **tabela temporária** `mapa_codigos` (tipo, antigo, novo, novo_na_virada) da conexão
    — some no fim; nada permanente na base.
  - `comandos_virada/20_virada_codigos_produto` (automático, logo depois do Produto): EAN antigo dos
    produtos novos vira código de barras (mesma regra do kit: LPAD 14, tributado e principal) e a
    `alteracao_produto_sped` segue o **padrão do kit** (`ajusta_produto.sql`, etapas 10–11): MANTÉM as
    alterações anteriores com as datas delas, insere só as trocas que faltam (NOT EXISTS procod +
    aps_procod_anterior; loja matriz) e grava `aps_data_exportacao = CURRENT_DATE` num UPDATE
    **depois** do INSERT, só nas linhas desta virada ainda sem data (dentro do INSERT a data não
    fica gravada — comentário do kit). Correção da v2026.10.30: a versão anterior apagava a tabela
    (como o "Insert SPED" do Pentaho) e perdia as datas da primeira migração.
  - No fim: planilhas `virada_cod_novo_cod_antigo_<tipo>_todos|alterados_<banco>.csv` para download.
  - Relatório do item principal mostra "codigo SysPDV X -> VarejoFacil Y".
  - Ordem na virada com Produto marcado: 20_inicio_produto → 20_produto → 20_produto_beneficio_fiscal →
    20_virada_codigos_produto → 21_impostos_federais_produto …
  - Texto da aba Virada em tópicos (pedido do usuário): **Clientes** (se houve troca de códigos de
    clientes na inicial, anexar `cod_novo_cod_antigo_cliente_todos_…csv`), **Produtos** (idem com o de
    produtos) e **Sem arquivo** (roda como na inicial).

### 4. Consultar códigos (seção 4 da tela, depois da migração)

Tirado do **kit-migracao** do time (`3-menu-migracao/app/correcao`: "Ajustar Código de Cliente /
Produto"). Os scripts `app/codigos/ajusta_cliente.sql` e `ajusta_produto.sql` são os do kit, **sem
alteração**; `app/codigos/ajuste.py` os roda pelo psycopg (linhas `\echo`/`\set` do psql ignoradas).
- Tópicos na tela (só estes três, pedido do usuário): regra de Clientes, regra de Produtos, e
  Consultar × Ajustar.
- ☐ Clientes ☐ Produtos · **Consultar** = tabela-resumo (cabeçalho azul): Código ≥ 999999, Menor,
  Maior — nada é alterado e **nenhuma planilha** é gerada.
- **Ajustar códigos** = prévia + `confirm()` → roda em **segundo plano** (`/codigos/ajustar` devolve
  `ajuste_id`; a tela consulta `/codigos/status/{id}?desde=N`) com o **registro ao vivo** (RAISE
  NOTICE "CODIGO ANTIGO: X, CODIGO NOVO: Y" / "AJUSTANDO PRODUTO DE X - Y" chegam enquanto o script
  roda — testado). Tudo numa **transação só** (script + planilhas + DROP da coluna auxiliar): erro
  = nada gravado (testado). Não roda com migração ou outro ajuste em andamento.
- Regras do kit: clientes ≥ 999999 → menor código livre (limite de crédito, conta a receber,
  cobrança, transações acompanham); produtos ≥ 999999 e `proenvbal = 'N'` → código livre de 10001 a
  999998 (`descobre_proximo_codigo`), o antigo vira EAN em `produtoaux` e vai para
  `alteracao_produto_sped`; o script desliga/religa trigger da produto, remove/recria constraints e a
  `estoque_movimentacao_trigger`.
- Depois do ajuste, cada linha ganha **um botão** "⬇ Download clientes/produtos" que baixa **dois
  arquivos** (um clique, dois downloads — o navegador pode pedir permissão para vários arquivos):
  `cod_novo_cod_antigo_<cliente|produto>_todos_<banco>.csv` e
  `cod_novo_cod_antigo_<cliente|produto>_alterados_<banco>.csv` (`;`, cabeçalho
  `CODIGO NOVO;CODIGO ANTIGO;NOME CLIENTE|DESCRICAO`, UTF-8 com BOM), em `reports/codigos/ajuste_*/`.

- **Limpeza dos códigos auxiliares depois da troca dos produtos** (v2026.11.18, script do usuário, sempre rodado após
  a mudança de códigos): `app/codigos/limpeza_ean.sql`, executado por `ajuste._limpeza_ean` logo depois do
  `ajusta_produto.sql` e antes das planilhas, na MESMA transação (erro = nada gravado). Passos (separados por
  `-- PASSO: <descrição>`; o log mostra quantos registros cada um alterou): apaga o EAN igual ao código do produto;
  EAN inválido vira LITERAL (`validar_ean`, `validar_gs1`); EAN tributado para produto sem nenhum tributado
  (DISTINCT ON procod, menor fator e código); tributado vira principal; principal para produto sem tributado;
  principal nulo = FALSE. Ajuste no script: o `CAST(procodaux AS BIGINT)` só converte códigos numéricos
  (`procodaux ~ '^[0-9]{1,18}$'`) — um LITERAL com letras dava erro e desfazia a troca inteira. Testado no
  VarejoFácil real: nenhum produto com EAN fica sem tributado.

## 4. Itens prontos (regras tiradas dos .ktr oficiais)

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `01_secao` | SECAO → secao | sem seção '00'; TRIM; MAIÚSCULO; vazia = RENOMEAR; `sec_situacao_sped='OUTROS'`; `sq_secao` |
| `02_grupo` | GRUPO → grupo_produto | só com seção existente, sem '00'; vazia = RENOMEAR; `sq_grupo_produto` |
| `03_subgrupo` | SUBGRUPO → subgrupo_produto | só com seção e grupo; coluna destino `sgpcod`; `sq_sub_grupo_produto` (com "sub_grupo") |
| `04_tabelas_basicas` (10 etapas) | APLICACAO, CARACTERISTICA, LOCAL, MARCA, RAMO, STATUS, TPPGT, TPREC, TIPODOCUMENTO, UNIDADE | T-TabelasBasicas_inicial sem impostos: local só ativo, flag `loc_avaria` se descrição 'AVARIA', `loc_estoque='PROPRIO'`; marca/tipo pgto/tipo receb MAIÚSCULO (receb corta 30); status grava STABLQ em `statipbloq` e `stablc`; ramo só insere (update_bypassed); unidade rtrim+MAIÚSCULO, fator nulo=1, `sq_unidade` |
| `05_impostos_federais` | IMPOSTOS_FEDERAIS → impostos_federais (+_geral/_atacado/_simples/_varejo) | só `impfedst <> impfedstsai`; P/C/I/S/O → PIS/COFINS/IRPJ/CSLL/OUTROS; 4 IDs por sequences; `depois.sql` = "VF - Imposto Federal Geral" |
| `06_ncm` | PRODUTO.PRONCM → ncm | sem pontos, zeros à esquerda até 8; NCM que falta entra 'NCM INATIVO', inativo |
| `07_loja` (2 etapas) | PROPRIO → pessoa, pessoa_loja | CNPJ só dígitos (chave); e-mail nulo = cliente@cliente.com.br; matriz 'S', perfil 'B', COMERCIO; cfnc 75/71/90/91/92/93; regime N/E/A/S → 1/2/3/4; sigla 5 letras; holcod |
| `08_funcionario` | FUNCIONARIO (ativos) → pessoa, pessoa_funcionario, pessoa_funcionario_loja, usuario | nome/apelido nulo = USUARIO; CPF dígitos; FISICA; vínculo com a **loja matriz do VarejoFacil** (pedido do usuário; `validar.sql` exige matriz); usuário senha md5('admin'); sequences `sq_funcionario_loja` (insert) e `sq_pessoa_funcionario_loja` (setval) como no job |
| `09_cliente` | CLIENTE → pessoa, pessoa_cliente | 3 caminhos: FISICA (CPF lpad 11), demais (CNPJ lpad 14), sem documento (pessoa nova, `_aviso`); e-mail minúsculo, endereço MAIÚSCULO; número 0/vazio = SN; telefone sem `()-.`, cortado 11, nulo = 99999999999; IE nula = ISENTO; país 1058; estado civil/sexo/situação/tipo residência por extenso; `depois.sql`: espécies BP/BR, loja matriz nos clientes sem loja, holcod |
| `09_limite_credito` | CLIENTE.CLILIMCRE → limite_de_credito | checkbox separado do Cliente (pedido do usuário); nulo = 0; espécie 2; LIBERADO; valor não é atualizado; `sq_limite_credito` |
| `10_fornecedor` | FORNECEDOR (com CNPJ) → pessoa, pessoa_fornecedor | pessoa pelo documento, reaproveita sem atualizar; tipo F/J/E; país nulo 1058; fax 14; transportadora S/N; regime S→4, N→1; RJ sem desoneração como desconto |
| `11_agente_financeiro` | AGENTE (≠ '0000') → pessoa, pessoa_agente_financeiro | documento = COALESCE(CNPJ, CPF) dígitos; reaproveita pessoa; sem documento = pessoa nova; fantasia = nome; banco 0 |
| `12_conta_corrente` | CONTA_CORRENTE × PROPRIO → conta_corrente | C/B → CAIXA/BANCARIA, nulo = CAIXA; agente nulo = 0; loja = PRPCOD |
| `13_finalizadora` | FINALIZADORA (≠ '000') → finalizadora | cartão/movimenta/carga geral = false; agente só na inclusão; a 1 (Dinheiro) movimenta conta |
| `19_ajustes_pessoas` | (só SQL, automático com o grupo Pessoas) | cadeia final do JOB-Pessoas: Corrige Tipo Documento, Update Holcod, IE Duplicada, Tipo Contribuinte, Atualiza sequence (`pes_codigo < 4444444`), Ajustes campos |

| `20_inicio_produto` | (só SQL, automático, PRIMEIRO do grupo Produto) | `ALTER TABLE produto DISABLE TRIGGER ALL` (pedido do usuário); `finalizar.sql` = `ENABLE TRIGGER ALL` de garantia |
| `20_produto` | PRODUTO → produto | opção **Incluir produtos fora de linha** (padrão marcada = todos; desmarcada = `COALESCE(PROFORLIN,'N') = 'N'`; o NCM e todos os itens de produto seguem a opção); "FB - Ajuste Seção/Unidade" e "FB - Ajustes campos estourados" viram `CASE` na leitura (unidade inexistente = UN preservando NULL, seção inexistente = maior seção, estoque/peso > 100000 = 0, embalagem ≥ 789e9 = 1, custos ≥ 7,89e12 = 0); 68 colunas do Insert/Update; 11 Value Mappers (vazio usa a entrada '' do mapa; sem correspondência = padrão ou mantém); NCM sem ponto com zeros até 8; funcod 1; `sq_produto`; aplica no `transformar.py` os ajustes do "Ajusta Produto"/"higieniza" (gênero = 2 primeiros do NCM, KG pesável etc.); grupo/subgrupo inexistente no destino = NULL via subconsulta (o `existe.sql` devolve o valor da origem nesse caso); datas "hoje" fora da comparação |
| `20_produto_beneficio_fiscal` | PRODUTO.PROBENFIS → cbenef_produto_loja | `contagem_origem` = só produtos com PROBENFIS (a PRODUTO inteira daria milhares de "Não migrados"); **sem checkbox** (`automatico_com_grupo` Produto), roda logo depois do Produto e antes dos Impostos federais do produto, na inicial e na virada — uma pasta só para `T-Produto_Codigo_Beneficio_fiscal_inicial` e `_virada` (na virada o `"depara": {"procod": "produto"}` grava pelo código novo, inclusive produtos novos da virada); TRIM + MAIÚSCULO; só de produtos migrados (filtro padrão + opção fora de linha; `validar.sql` = produto existe); loja = PRPCOD; chave procod + loj_codigo, `cpl_cbenef` atualiza; `sq_cbenef_produto_loja`; `ignorar_se_origem_falhar` (SysPDV sem a coluna: aviso, segue) |
| `21_impostos_federais_produto` | IMPOSTOS_FEDERAIS_PRODUTO → impostos_federais_produto | só insere; `sq_impostos_federais_produto` |
| `22_produto_auxiliar` | PRODUTOAUX → produtoaux | zeros até 14; caractere não numérico = LITERAL, senão EAN; `proauxcodigoean` = 13 PRIMEIROS caracteres (como no Pentaho — corta o último dígito de um EAN-13; usuário ainda não confirmou se é intencional); fator 0/vazio = 1; EAN igual ao código de um produto não é gravado; `depois.sql` = "Limpeza nos EAN's" (usa `validar_ean`/`validar_gs1` do VarejoFacil; CAST protegido por `CASE` sobre a coluna) |
| `23_produto_fornecedor` | PRODUTO_FORNECEDOR → produto_fornecedor | fornecedor validado por código **e** CNPJ só dígitos; referência numérica sem zeros à esquerda antes de gravar ("Limpa 0"); unidade/nível MAIÚSCULO (UN/P); `depois.sql` = Define Principal |
| `24_preco` | PRODUTO → preco | loja = PRPCOD; estourados zerados na leitura; desconto > 99 = 99,99; custos/margem negativos = 0; venda variável nula = 0; `sq_preco` |
| `25_tributacao_produto` (3 etapas) | TRBID / TRIBUTACAO → situacao_fiscal, tabela_tributacao, item_tabela_tributacao | situação fiscal por TRBID usado ("Tributado-T18", código = máx + 1) e `stf_codigo`/`stf_codigo_saida` nos produtos; tabela de SAÍDA por situação para regime e UF da loja matriz (vigência 2016-01-01); itens: % tributado/outros/isento do Pentaho, CST vazio 60, CFOP vazio 5102, classificação SAIDA_PARA_NAO_CONTRIBUINTE, só tributações usadas |
| `26_familia` (2 etapas) | SIMILARES, ITEM_SIMILARES → familia_produto, produto_familia | `sq_produto_familia` |
| `27_compostos` (2 etapas) | COMPOSTO, COMPONENTE → composicao, componentes_composicao | PROCOMP 'S' (vira 'C'); componentes preços nulos = 0; histórico `hist_*` ON CONFLICT DO NOTHING |
| `28_kit` (2 etapas) | PRODUTO 'K', COMPONENTE → composicao, componentes_composicao | quantidade 1, baixa P, tipo S/N = PRECO/FATOR; `comp_id` mantido |
| `29_encarte` (3 etapas) | ENCARTE, ENCARTE_PRODUTO → encarte, encarte_produto, encarte_loja, programacao_preco | encartes A/P; tipo de preço 1/2/3 marca qual preço atualiza (outro = nulo); produtos seguem a opção fora de linha (Pentaho: `proforlin = 'N'` fixo); programação de preço com NOT EXISTS |
| `30_cenario_fiscal_ncm` (4 etapas) | CLASSIFICACAO_TRIBUTARIA, NCM (do SysPDV) → classificacao_tributaria, cenario_fiscal_ncm (+ _ncm, _loja, _uf_destino) | classificação: chave ct_codigo, só % de redução atualiza; cenário por classificação usada nos NCMs (cfn_codigo = ID_NUM, descrição corte 200, funcionário nulo = 1); NCMs ligados pelo CST + classificação; loja = **matriz** (Pentaho: constante 1); UF de destino = UF da matriz |
| `31_cenario_fiscal_produto` (3 etapas) | PRODUTO com classificação ≠ da do NCM → cenario_fiscal_produto (+ _produto, _loja, _uf_destino) | descrição da classificação do VarejoFacil; produto ligado pelo nível mais detalhado (seção / +grupo / +subgrupo; '000' = vazio); segue a opção; loja = matriz; tem `origem.sqlserver.sql` |
| `39_ajustes_produto` | (só SQL, automático, último do grupo Produto) | "Produto higieniza Loccod" + "Ajusta Produto" (sem a linha de `pesquisa_satisfacao`; `itt_icms_desonerado IS NULL` corrigido) + "Corrigi produtos sem composição" + **Cadastro de operações** (24 operações padrão, sem checkbox, pedido do usuário; bloco DO que só insere o código que não existe — 1ª coluna da tabela `operacao`, os INSERTs do Pentaho são posicionais) + `ALTER TABLE produto ENABLE TRIGGER ALL`; depois do `ENABLE TRIGGER ALL` (e fora do modo replica) **recarrega as tabelas de carga** (script do usuário: `DELETE FROM item_carga WHERE tipo IN ('CODIGO_AUXILIAR'|'PRODUTO'|'PRECO')` + `UPDATE produtoaux SET id_externo = NULL`, `produto SET mix_id = NULL`, `preco SET id_externo = NULL` da loja matriz — os SELECT DISTINCT do script eram só conferência e o `lojcod = 1` fixo virou a matriz), para as triggers alimentarem ITEM_CARGA_PRODUTO/PRECO/PRODUTOAUX e PRODUTO_LOJA, que ficam vazias com as triggers desligadas |

**Grupo Estoque** (depois dos produtos; tudo segue a opção fora de linha; pedido do usuário: um
checkbox por parte):

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `40_inicio_estoque` | (só SQL, automático, primeiro) | tipos de ajuste 9001 SAIDA / 9002 ENTRADA (AJUSTE_MIGRACAO) + `ALTER TABLE produto DISABLE TRIGGER ALL` (pedido do usuário: sem isso demora muito); `finalizar.sql` = ENABLE de garantia |
| `41_saldo_positivo` / `42_saldo_negativo` | ESTOQUE (**> 0** / < 0; v2026.11.15) → estoque_movimentacao | ajuste 9002, histórico MIGRACAO, local 1, loja do PROPRIO, funcionário 1; estratégia de saldo abaixo |
| `43_estoque_minimo_maximo` | PRODUTO → produto_estoque | estourado > 100000 = 0; máximo < mínimo = mínimo; vazios = 0; só insere |
| `44_movimentacao_custo` (3 etapas) | PRODUTO, ESTOQUE → movimentacao_de_custo, custo_dia, auditoria_custo | produtos com estoque ≥ 0 e custo; custo fiscal/médio 0 ou vazio = reposição; `moc_custo_medio` recebe o **custo fiscal** como no Pentaho (usuário confirmou: manter); sem duplicar (movimento: loja+produto+AJUSTE_CUSTO; custo do dia: loja+produto, atualiza) |
| `49_fim_estoque` | (só SQL, automático, último) | `ALTER TABLE produto ENABLE TRIGGER ALL` |

**Grupo Financeiro**:

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `50_contas_receber` (5 etapas) | CONTARECEBER, CONTASRECEBERLIQUIDACAO → conta_a_receber, titulo_a_receber, movimentacao_titulo_receber + definicao_lancamento_financeiro_categoria/_centro_custo, configuracao_lancamento_financeiro | `T-ContaReceber_inicial` **versão nova do usuário**: cliente pelo **código** (`CLICOD = cli_codigo`) e **`cfnc_codigo = 9` fixo** (antes PLCRED); contas A e P de clientes migrados (validar pessoa_cliente); `ctr_id` = CTRID; documento vazio = id **antes** de gravar; título ABERTO (A) / PARCIALMENTE_LIQUIDADO (P, saldo = nominal) ligado pelo **id**; INCLUSAO_DE_TITULO por título; liquidações parciais (finalizadora 1, conta corrente vazia = 1, usuário 1) com **número de ordem** entre liquidações iguais do título (não duplica, nem as idênticas no mesmo dia); depois: Ajusta Sequence + Ajusta Categoria Financeira. **Sem** "VF - Ajuste Juros e Mora Diaria" (particular de cada cliente) e **sem** "VF - Insert Panama" |
| `51_contas_pagar` (2 etapas) | CONTAPAGAR → conta_a_pagar, titulo_a_pagar, movimentacao_titulo_pagar + lançamentos | 1º passo do Pentaho (Cria Espécie) todo comentado: não entra; em aberto (`CTPDATPGT` nulo, A) e não excluídas; emissão vazia = vencimento − 30 (`origem.sqlserver.sql` com DATEADD); fornecedor por código **e** CNPJ só dígitos; **`cfnc_codigo = 32` fixo** (constante do .ktr; pedido do usuário, antes PLCRED); espécie 1; título ABERTO prazo 1; INCLUSAO ligada pela conta; depois: Atualiza Sequence + Ajusta Categoria Financeira. **Sem** "VF - Insert Panama" |
| `59_fim_financeiro` | (só SQL, automático, último do grupo) | "Insert Item Configuração Lançamento Financeiro" do `Migrador_Inicial.kjb` (NOT EXISTS) |
| `99_fila_panama` | (só SQL, **automático sempre**, último de toda migração) | script `InsertFilaPanama.sql` do usuário, sem alteração: apaga `fila_sincronizacao` e `fila_sincronizacao_panama` e enfileira finalizadoras, holding, lojas, funcionários, acesso, clientes, seções, grupos, subgrupos, produtos, EAN e títulos a pagar/receber |

**Saldo zero** (`42_saldo_zero`, v2026.11.15, pedido do usuário "tudo automatizado"): o saldo positivo passou a ler
só ESTATUSDO > 0 (contagem "Na origem" com `contagem_origem` própria, > 0 / < 0). Item sem checkbox
(`automatico_com_itens` 41/42), depois do negativo: (1) `01_zerar_lancados` — ESTATUSDO = 0 no SysPDV; `validar_pula`
só deixa seguir quem já tem movimento MIGRACAO (virada / rodar de novo) e o substitui por zero; os demais ficam
"pulados"; (2) `02_lancar_zero` — script do usuário em LOTE: um INSERT do movimento zerado (9002, MIGRACAO) para
todos os produtos sem movimento na loja matriz / local 1 (`NOT EXISTS`; o script tinha loja 1 fixa e `NOT IN`) +
ANALYZE + recálculo do resumo. Medido no VarejoFácil real (15 mil produtos, 20 mil EANs): EAN 49 → 9 s; saldos
172 → 10 s; virada (produto que zerou → 0, que ganhou saldo → atualiza) sem duplicar. No usuário: produto
10 min → 1 min 24 s, EAN 3 min, saldo positivo 1 s, negativo 1,5 s, zero 17 s.

**Estratégia do saldo** (o "VF - Zerar todo o estoque" do Pentaho foi RETIRADO a pedido do usuário;
estratégia escolhida com ele: apagar os movimentos MIGRACAO e relançar):
- `existe.sql`: soma dos movimentos MIGRACAO do produto (loja + local 1); com mais de um movimento
  devolve NULL (conta como diferente, para consolidar o histórico).
- igual e com 1 movimento → sem alteração; diferente / vários → `atualizar.sql` = CTE que apaga os
  movimentos MIGRACAO **só daquele produto** e insere o saldo num movimento só; sem movimento → insere.
- `depois.sql`: recalcula `estoque_resumo` (loja matriz, local 1) = soma da `estoque_movimentacao`,
  com LEFT JOIN (produto sem movimento vai a 0 — o UPDATE…FROM do script do usuário não alcançava
  esses produtos).
- Apagar produto a produto (e não DELETE geral): marcando só "Saldo positivo", o saldo dos negativos
  não se perde (testado). Movimentos que não são MIGRACAO são mantidos e somam no saldo (base nova
  não tem). Zerar a quantidade (UPDATE = 0) foi descartado: deixaria linhas de 0 acumulando.

Grupo "Cadastro de Produto" na tela: `☑ Incluir produtos fora de linha │ ☑ Produto  ☑ Impostos federais
do produto  ☑ Produto Auxiliar (EAN)  ☑ Produto Fornecedor  ☑ Preço  ☑ Tributação do produto
☑ Família (produtos similares)  ☑ Compostos  ☑ Kit  ☑ Encarte  ☑ Cenário fiscal por NCM
☑ Cenário fiscal por produto`. Estoque: `☑ Saldo positivo ☑ Saldo negativo ☑ Estoque mínimo e
máximo ☑ Movimentação de custo`. Itens de produto também usam
`SET session_replication_role = replica/DEFAULT` em `antes.sql`/`depois.sql` (como o job), além do
DISABLE TRIGGER pedido pelo usuário.

**Triggers da produto**: `ALTER TABLE ... DISABLE TRIGGER` fica gravado na tabela (diferente do
Session Replication, que é só da conexão). Por isso o religamento existe em dois lugares: nos
Ajustes finais e no `finalizar.sql` do `20_inicio_produto`, que roda mesmo com erro no meio
(testado: erro proposital no Preço → triggers terminaram ligadas). O ALTER TABLE precisa de lock
exclusivo: rodar com o VarejoFacil fechado.

Excluídos de propósito, a pedido do usuário: **Série de Nota Fiscal** e **Plano de Contas /
Categoria Financeira**. Grupos na tela: "Cadastros Padrão" (01–06), "Cadastro de Pessoas" (07–13; ajustes 19
automáticos por último), "Cadastro de Produto" (20–31; 20_inicio e 39 automáticos) e "Estoque"
(41–44; 40 e 49 automáticos), "Financeiro" (50–51; 59 automático) e, sem checkbox, `99_fila_panama`
em toda migração. Tabelas Relacionais, Série NF e Plano de Contas ficam de fora
(pedido do usuário). Pastas renomeadas nesta evolução (apagar a antiga ao atualizar):
`11_ajustes_pessoas`→`19`, `29_ajustes_produto`→`39`, `40_saldo_estoque` e `41_movimentacao_custo`
→ 40–44/49 (o `instalar.bat` apaga sozinho; no Linux `rm -rf`).

Onde ficaram os SQLs de apoio do Pentaho: holcod da matriz → `depois.sql` de Loja, Funcionário,
Cliente, Fornecedor e Agente; Atualiza Sequence + Insert Usuario → `08_funcionario/depois.sql`;
Espécie de Documento + update-Loja → `09_cliente/depois.sql`; Desoneração ICMS RJ →
`10_fornecedor/depois.sql`; update_fzd_Dinheiro → `13_finalizadora/depois.sql`; cadeia final →
`19_ajustes_pessoas`. Cria/Dropa Campo Temporário: desnecessários (vínculos permanentes).

## 5. Diferenças propositais em relação ao Pentaho

Todas para poder **rodar de novo sem duplicar/quebrar** ou para **não alterar a origem**:

- **SQLs que alteram o SysPDV** ("FB - Ajuste CPF em branco", "FB - Ajusta CPF/CNPJ em
  branco"): viraram filtro no `origem.sql`/regra no `transformar.py`.
- **Colunas temporárias** (`fun_codigo_syspdv`, `cli_codigo_syspdv`, `age_codigo_syspdv`): o
  Pentaho localizava a pessoa por elas e as apagava no fim — numa segunda execução criava
  pessoas de novo. Aqui o registro é achado pelo vínculo permanente (`pessoa_funcionario`,
  `pessoa_cliente`, `pessoa_agente_financeiro`).
- **Clientes com o mesmo CPF/CNPJ**: no Pentaho só o último ficava (o primeiro se perdia);
  aqui os dois apontam para a mesma pessoa. Em novas rodadas aparecem como "atualizado" com o
  conflito no relatório (alerta de documento repetido na origem — esperado).
- **Impostos Federais**: o UPDATE não troca os 4 IDs (o Pentaho gerava IDs novos a cada
  execução); o `depois.sql` só insere nas tabelas complementares o que falta (NOT EXISTS).
- **Cliente/Finalizadora** aplicam nos próprios campos as correções dos ajustes finais
  (bairro vazio, fantasia vazia, CPF com 14 dígitos = JURIDICA, Dinheiro movimenta conta)
  para não "atualizar" à toa a cada rodada.
- **Sequence só é consumida em INSERT** (o Pentaho consome uma por linha lida).
- **Código não numérico** = erro só daquela linha (no Pentaho para a transformação).

- **Item da tabela tributária**: chave `itt_id IS NULL` no Pentaho (sempre inseria — duplicava a
  cada execução); aqui tabela + TRBID + classificação.
- **Kit**: o Pentaho trocava o `comp_id` a cada execução (Update = Y), órfãos nos componentes; aqui é mantido.
- **Produto Fornecedor**: o Pentaho comparava `FORCGC` com máscara contra o documento só dígitos
  (com máscara nada batia e as referências sumiam).
- **Programação de preço (Encarte)**: `NOT IN (SELECT id_produto_encarte ...)` → `NOT EXISTS`
  (com um `id_produto_encarte` nulo na tabela, o NOT IN não criava nenhuma programação — provado).
- **Constantes de loja**: `loj_codigo` 1 fixo nos cenários fiscais (NCM e produto) e no "Zerar
  estoque" → loja matriz. **Filtro `proforlin = 'N'` fixo** no Encarte, Estoque e Custo → opção.
- **Cadastro de operações**: INSERTs diretos (2ª execução = chave duplicada) → só insere o que falta.
- **Movimentação de custo / custo do dia**: chave = sequence (duplicava a cada execução) → chave
  loja + produto.
- **Migrador de virada do Pentaho** (`Migrador_virada.kjb`): caminhos dos CSV fixos nos .ktr,
  misturando pastas de dois técnicos e dois clientes no mesmo job → arquivo anexado na tela;
  produto novo recebia código de um contador fixo (Sequence local `start_at` 38221340, acima de
  999999 — quebra o VarejoFácil) → próximo código vago e válido; `proforlin = 'N'` fixo → opção;
  `JOB-TituloReceber_virada` não ligado ao fluxo → item normal com de-para; regeração de CSV no meio
  do job ("Nova listagem") → tabela temporária; virada repetida duplicava produtos novos → reaproveita;
  "Insert SPED" apagava a `alteracao_produto_sped` inteira (perdia a `aps_data_exportacao` e renumerava
  as trocas da primeira migração) → mantém as anteriores e só insere as novas, com a data de hoje.
- **Benefício fiscal** (`T-Produto_Codigo_Beneficio_fiscal_virada`, enviado pelo usuário): caminho fixo
  do CSV com nome de cliente/técnico; Merge Join INNER com a planilha deixava os produtos novos da
  virada sem o código; sem TRIM/MAIÚSCULO (a inicial tinha); a inicial não filtrava produtos não
  migrados → uma pasta só com de-para, filtro e validação.
- **Financeiro**: o `T-ContaReceber` novo trocou a chave do Merge Join para o código do cliente mas
  os Sort rows continuaram ordenando pelo documento (Merge Join exige a mesma ordenação: perde
  títulos) → busca direta pelo código; título parcial ligado pelo **número do documento** (marcava
  o título aberto de outro cliente com o mesmo número como parcial) → pelo id; liquidações parciais
  e movimentações com chave = sequence (dobravam a cada execução) → número de ordem; movimentação a
  pagar ligada pelo **valor** (`ttlp_valor = ctp_valor_nominal`: contas de mesmo valor trocavam a
  data) → pela conta; documento vazio preenchido depois de gravar (2ª rodada duplicava) → antes.
- **SQLs do Pentaho que não fazem nada** (só SELECT dentro de "Execute SQL"): "Imp fed duplicidade"
  e "Limpa Duplicidade" do fornecedor (monta texto de DELETEs sem executar) — não levados.

Sobras de clientes específicos encontradas nos .ktr/.kjb e NÃO levadas (ver também
`pentaho_migradores_repositorio.md`):
- `T-Funcionario-Loja_inicial`: filtro fixo `loj_codigo = 3` ("estava inserindo os funcionários
  da loja 03").
- `JOB-Pessoas_inicial` / "VF - Corrige IE Duplicada": `pes_codigo != 21` fixo → trocado por
  "pessoa de qualquer loja".
- "Ajusta Produto": `update pesquisa_satisfacao set data_fim_vigencia = '2026-12-31' where id = 3`.

Pendente de confirmação do usuário (mantido igual ao Pentaho, isolado no topo do
`comandos/20_produto/transformar.py`): "Null if" de marca 0/3/6 e local 0/1/2/97 (podem ser sobra
de cliente) e o corte do EAN em 13 caracteres (`22_produto_auxiliar`).

## 6. Instalação por sistema

**Linux (Ubuntu)** — na pasta do migrador: `bash linux/instalar.sh` (instala
`python3-venv`, `libfbclient2`, `curl` se faltar; cria `.venv`), depois
`bash linux/iniciar-app.sh`. Client Firebird = `libfbclient2` (FB 3.0), conecta em servidor
2.5. O client 2.5 de `/opt/firebird` exige `libncurses5` (ausente no Ubuntu 24.04) — o
migrador só usa um fbclient depois de confirmar que ele carrega. Firebird em Docker: porta
publicada (ex.: 3051) e caminho **de dentro do container**; `.fdb` com `chmod 666`.

**Windows** — `windows\instalar.bat` (pede administrador): instala, um por um, **só o que
faltar**, achando os instaladores na pasta **Downloads** (vêm do Drive interno; sem pasta
`instaladores` no pacote): Firebird 2.5 (`Firebird-*.exe`, Inno `/VERYSILENT`, SYSDBA/masterkey),
PostgreSQL 15 (`postgresql-15*.exe`, InstallBuilder `--mode unattended`, porta 5432, senha
`SENHA_POSTGRES` do .bat, sem pgAdmin/StackBuilder embutidos), pgAdmin 4 (`pgadmin4-*.exe`) e
Python 64 bits (`python-3*amd64*.exe`; sem ele baixa o 3.12 do python.org); copia para
`C:\migrador_syspdv_varejo` (sem `linux/`), cria `.venv`, confere o client Firebird e cria o
atalho "Migrador SysPDV". Logs: `%TEMP%\migrador_instaladores`.

**Por que o client 64 bits no Windows**: `psycopg-binary` só existe para Windows **64 bits**,
então o Python tem de ser 64 bits — e não carrega o `fbclient.dll` 32 bits do Firebird 2.5 do
SysPDV (`WinError 193`). O pacote traz em `windows\firebird_client_x64\` as DLLs do pacote
oficial `Firebird-2.5.9.27139-0_x64.zip` (GitHub FirebirdSQL, release R2_5_9, SHA-256
`707e05bae8994b06cec60815a292078db82d8e75616f4dd514b7e417a3ee2137`): `fbclient.dll`,
`msvcr80.dll`, `msvcp80.dll`, `Microsoft.VC80.CRT.manifest`, `icudt30/icuin30/icuuc30.dll`,
mais `IPLicense.txt`/`IDPLicense.txt`. Conversa normalmente com o servidor 32 bits; o Firebird
instalado não é alterado. Campo "fbclient" da tela: **deixar vazio**. (O DBeaver funciona
porque usa Jaybird/Java, sem fbclient.)


**`linux/instalar.sh` e repositórios de outros programas** (v2026.11.04, caso real: repositório do MySQL com
chave vencida — "Erro GPG … EXPKEYSIG B7B3B788A8D3785C" / "O repositório … não está assinado"): o instalador
primeiro tenta `apt-get install` sem atualizar a lista; se precisar, roda `apt-get update` e, se ele falhar por
causa de outro repositório, só avisa e segue (os pacotes do migrador vêm do repositório oficial do Ubuntu);
se ainda faltar pacote, para com a orientação de desativar o repositório com problema
(`sudo mv /etc/apt/sources.list.d/mysql.list …desativado`). Avisos de "chaveiro legado trust.gpg" são só avisos.

**Driver ODBC do SQL Server no Linux** (v2026.11.13, caso real: "Nenhum driver ODBC do SQL Server instalado …
Drivers encontrados: nenhum" com o SQL Server instalado na máquina). Ter o SQL Server instalado NÃO basta: o
migrador conversa com ele pelo DRIVER ODBC (`msodbcsql18`), outro pacote. O `instalar.sh` agora: se
`odbcinst -q -d` não lista nenhum driver "SQL Server", instala o `msodbcsql18` (`ACCEPT_EULA=Y`); se o pacote
não está disponível, adiciona o repositório da Microsoft da versão do Ubuntu da máquina
(`packages.microsoft.com/config/ubuntu/<VERSION_ID>/packages-microsoft-prod.deb`) e atualiza a lista; se não
conseguir (sem internet, distro que não é Ubuntu), só AVISA e segue — só o SQL Server fica indisponível. Já
tem driver → pula. Comando manual: `sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc` (quem instalou o
SQL Server pelo repositório da Microsoft já tem o repositório); conferir com `odbcinst -q -d`; não precisa
reiniciar o migrador.

**Windows**: não dá esse erro porque o migrador escolhe, nesta ordem, ODBC Driver 18 → 17 → Native Client 11
→ "SQL Server" (este vem com o Windows). O "SQL Server" do Windows é antigo e pode falhar com SQL Server que
exige criptografia moderna (TLS 1.2): o recomendado é o ODBC Driver 18. O `windows\instalar.bat` ainda NÃO
instala o ODBC Driver 18 (ideia oferecida ao usuário: procurar `msodbcsql.msi` na pasta Downloads, como os
outros instaladores).
## 7. Método: converter um .ktr do Pentaho em pasta de comandos

1. Ler o `.kjb` do módulo: ordem das entradas (hops a partir do START) e os SQLs de apoio.
2. Para cada `.ktr`, ler passo a passo (tipo, SQL, campos) e mapear:

| No .ktr | Na pasta |
|---|---|
| Table input (conexão SysPDV) | `origem.sql` (filtros iguais; trocar UPDATEs na origem por filtro) |
| String operations, Select values (tipos), If field value is null, Value Mapper, Strings cut, Replace in string, Add constants, Null if | `transformar.py` |
| Sequence | `nextval('...')` no `inserir.sql` (nome exato da sequence) |
| Insert/Update: tabela e campos | `inserir.sql` |
| Insert/Update: "keys" | `WHERE` do `existe.sql`/`atualizar.sql` |
| Insert/Update: campos `Update = Y` | `SET` do `atualizar.sql` e colunas do `existe.sql` |
| Insert/Update `update_bypassed = Y` | sem `atualizar.sql` (só insere) |
| Join Rows / Merge Join para achar `pes_codigo` | subconsulta ou CTE no `inserir.sql` |
| Entradas SQL do job antes/depois | `antes.sql` / `depois.sql` (ou item só de SQL) |

3. Atenção ao ler: XML do Insert/Update tem `<key><name>`=campo do fluxo e `<field>`=coluna da
   tabela; `<value><name>`=coluna e `<rename>`=campo do fluxo; tabela em `lookup/table`.
   Value Mapper sem default mantém o valor original; string vazia no Kettle = nulo.
4. Procurar sobras de outro cliente (códigos fixos, comentários "no caso em questão...").
5. Testar (base de teste): gravação → 2ª rodada (tudo "sem alteração", salvo conflitos reais) e
   conferir cada regra no banco. Casos difíceis de propósito (nulos, documento formatado,
   duplicados, órfãos).
6. Nunca inventar nome de tabela/coluna/sequence: confirmar no `.ktr`, nos scripts SQL do time
   ou no banco.

## 8. Problemas comuns

| Sintoma | Causa / solução |
|---|---|
| `WinError 193 ... não é um aplicativo Win32 válido` | fbclient 32 bits com Python 64: deixar o campo fbclient vazio (usa `windows\firebird_client_x64`) |
| `libncurses.so.5` | `sudo apt install libfbclient2` e deixar o fbclient vazio |
| ⚠️ "falta origem.sql; falta inserir.sql" em itens com etapas/só SQL | **servidor antigo ainda rodando** (motor antigo na memória): rodar o iniciar-app de novo (derruba qualquer migrador na porta 8020 e confere a versão) |
| Internal Server Error ao abrir | outro servidor (projeto antigo) respondendo na porta: parar e rodar o iniciar-app |
| `campo 'x' nao existe na linha` | `transformar.py` usa coluna que o `origem.sql` não traz |
| `query parameter missing: x` | `.sql` usa `%(x)s` que o `transformar.py` não devolve |
| `null value in column ... violates not-null` | coluna obrigatória faltando no `inserir.sql` |
| Sempre "inserido" de novo | falta `existe.sql` |
| Acentos trocados | charset da conexão ≠ banco (SysPDV costuma ser WIN1252/ISO8859_1) |
| "Na origem" com número de outra tabela | `FROM` de subconsulta antes do principal (motor já ignora); ou declarar `"tabela_origem"` |
| `inconsistent types deduced for parameter` | mesmo `%(campo)s` em dois contextos: declarar o tipo (`::varchar`) |
| `Unexpected end of command` no Firebird | comentário `--` no fim de linha engoliu um `)` |
| Migração parou com erro no meio da parte de produto | o `finalizar.sql` religa as triggers da `produto` — conferir no log "finalizar.sql executado" |
| "Nenhum driver ODBC do SQL Server instalado" | Linux: `msodbcsql18` (passo a passo no `linux/LEIA-ME.md`); Windows: ODBC Driver 18 (o "SQL Server" do Windows também serve) |
| SQL Server: não conecta | TCP/IP habilitado no SQL Server Configuration Manager; porta 1433 ou instância (com instância a porta é ignorada) |
| PostgreSQL aceita senha vazia/errada | `pg_hba.conf` em `trust`: o migrador já recusa (confere contra `pg_authid`); para o servidor também conferir, trocar para `scram-sha-256` |
| Download do ajuste baixou só um arquivo | o navegador bloqueou "vários downloads": permitir para 127.0.0.1:8020 |
| Virada: "precisa das colunas CODIGO NOVO e CODIGO ANTIGO" | anexar a planilha `..._todos_...csv` da seção 4 (Download), não outra |
| "o SysPDV não tem a coluna X - etapa ignorada" | SysPDV de versão antiga sem a informação (ex.: `PROBENFIS`): é só aviso, o fluxo continua |
| Virada: produto novo ganhou código diferente do esperado | só mantém código válido (1..999998) que não seja destino de outro registro na planilha; EAN ganha o próximo vago |
| `alteracao_produto_sped` sem `aps_data_exportacao` depois de uma virada da v2026.10.29 | a v2026.10.29 apagava a tabela: atualizar para a 2026.10.30; recuperar as datas com `UPDATE ... SET aps_data_exportacao = CURRENT_DATE WHERE aps_procod_anterior = <EAN novo da virada>` e depois `SET aps_data_exportacao = DATE '<data da 1a migração>', aps_data_final = DATE '<idem>' WHERE aps_data_exportacao IS NULL` |
| Tela antiga depois de atualizar (ex.: botão que já saiu continua aparecendo) | versão anterior à 2026.11.12 servia a página com cache: Ctrl+F5 no navegador; a partir da 2026.11.12 a página vem com `no-store` |
| Validação: "O servidor não conseguiu abrir o .FDB: caminho errado ou sem permissão" | Linux local: a validação mostra os `chmod` exatos; Docker: escolher Automático/Docker (o caminho tem de estar numa pasta compartilhada com o container ou ser o de dentro dele) |
| "Nenhum driver ODBC do SQL Server instalado … Drivers encontrados: nenhum" (Linux) | falta o driver (o servidor SQL Server instalado não traz): `sudo ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc` ou rodar de novo o `instalar.sh` (v2026.11.13+) |
| Validação: tabelas "não verificada" depois de um "internal Firebird consistency check" | o servidor bloqueou o banco depois do bugcheck: reiniciar o servidor Firebird/container e validar de novo |
| Grupo/Subgrupo (ou outro item) com "1 Não migrado" e nada no log | versões antes da 2026.11.25: registro que a seleção filtra (órfão, inativo, sem CNPJ…) contava em "Na origem"; a partir da 11.25 a contagem segue a seleção. Órfãos: `SELECT * FROM GRUPO WHERE SECCOD NOT IN (SELECT SECCOD FROM SECAO)` |
| Ajustar códigos de clientes: "cannot ALTER TABLE pessoa_cliente because it has pending trigger events" (ajuste desfeito) | antes da 2026.11.41: FKs deferidas pendentes ao remover a coluna temporária; atualizar o migrador |
| Saldo: "mov_id … ainda é usado na tabela item_inventario" | antes da 2026.11.40 o saldo apagava o movimento MIGRACAO para relançar; agora lança só a diferença — atualizar e rodar os saldos de novo |
| "invalid literal for int() with base 10: '0\x10…'" | caractere de controle invisível num código do SysPDV; a partir da 2026.11.40 é removido |
| Custo/preço/estoque com "procod X não existe na tabela produto" | produto que não foi migrado; a partir da 2026.11.40 vira "pulado" (exige_produto) — veja o motivo no cartão do Produto |
| Poucos impostos federais migrados (base com IMPFEDST/IMPFEDSTSAI nulo) | antes da 2026.11.39 o CST vazio ficava de fora: atualizar e rodar Impostos Federais e Impostos federais do produto; completar o CST na aplicação |
| Uma página da tela aparece deslocada (ex.: Consultar códigos à direita) | `<div>` aberto/fechado a mais numa página anterior do `index.html`: contar `<div` × `</div>` por `<section class="pagina">` (corrigido na 2026.11.38) |
| Formulário com "Produto Composição"/"Produto Kit" na origem e 0 no destino | antes da 2026.11.35 contava os marcados PROCOMP S/K sem componentes; a migração (e o Pentaho) só leva os que têm COMPOSTO/COMPONENTE |
| "inconsistent types deduced for parameter $N … text versus character varying" | o mesmo parâmetro com tipos diferentes no SQL (aparece só a partir da 6ª linha, quando o comando é preparado): usar o mesmo cast em todas as ocorrências; corrigido na 2026.11.33 |
| Cenário fiscal por NCM: milhares de "não há cenário fiscal por NCM com este CST" / "ncm_codigo não existe na tabela ncm" | antes da 2026.11.33: NCM com classificação em branco e NCM sem produto migrado eram lidos |
| Cenário fiscal por NCM muito lento | 2026.11.33 (IN por NCM): atualizar para a 2026.11.34 |
| Limite de crédito do cliente como BOLETO PAGAR | versão anterior à 2026.11.30 (código 2 fixo): atualizar e rodar só o Limite de Crédito de novo (corrige para BOLETO RECEBER) |
| Migração de produtos lenta com "Só com movimentação desde" | ITEVDA muito grande: medir o tempo dos itens de produto; se preciso, calcular o conjunto de produtos uma vez e reaproveitar |
| Virada: "já existe outro registro com tbt_id, itt_uf, itt_classificacao_pessoa" / "...procod, lojcod, pprprctip, pprdatini..." (Encarte › Lojas com erro) / "...pes_num_documento" (Funcionário) | versão anterior à 2026.11.28/29: o existe não procurava pela chave única do VarejoFácil; atualizar o migrador e rodar de novo (passa o que já existe) |
| Produto com 2 PIS (ou 2 COFINS...) na `impostos_federais_produto` | migração antes da 2026.11.27: rodar de novo o item Impostos federais do produto (fica 1 por tipo — o de menor código — e os outros são apagados; o cartão lista os descartados) |
| Funcionário de código 0 no VarejoFácil / `pfl_principal` false | migração feita antes da 2026.11.20 (código 0) / 2026.11.26 (principal): rodar o Funcionário de novo (corrige o principal) e limpar o funcionário 0 com os DELETEs numa transação (seção do Funcionário) |
| Erro de chave no `loccod` do produto (ex.: 95) | o VarejoFácil não tem local de impressão: a partir da 2026.11.20 o produto vai sempre com `loccod = 0` |
| Formulário: "falta a biblioteca python-docx" | rodar de novo o instalador (`requirements.txt` tem `python-docx`) |
| Produto com "Não migrados" e Erros 0 | não são erros: produtos que a seleção deixa de fora (código zerado, sem descrição, fora de linha com a opção desmarcada); v2026.11.17+: lista com o motivo no cartão do Produto |
| "Tabela X teve N erros e não sei quais" | v2026.11.16+: o cartão da tabela no Progresso lista Registro × Motivo e tem "Baixar só os erros .csv"; versões anteriores: `reports/<execução>/<etapa>.csv`, filtrar status = erro |
| Etapa lenta com milhares de linhas | procurar `%(x)s IN (SELECT ...)` no existe/validar (trocar por EXISTS) e comandos em lote no depois.sql sem `ANALYZE` antes |
| Item roda duas vezes após atualização | pasta renomeada que ficou da versão anterior (ex.: `11_ajustes_pessoas` → `19_ajustes_pessoas`): apagar a antiga |

## 9. Próximos passos

O fluxo do `Migrador_Inicial.kjb` está completo: Cadastros Padrão, Pessoas, Produto (com Encarte e
cenários fiscais), Estoque, Financeiro e a fila do Panamá — testado pelo usuário em Linux e Windows,
origem Firebird e SQL Server. Pendentes/possíveis:
- "Relatório padrão" do `Migrador_Inicial.kjb` (não pedido).
- Outros módulos do kit-migracao (relatórios de validação .docx, backup, AWS, servidores Firebird)
  ainda não estão na tela; a "Correção" (ajuste de códigos) já está (seção 4 da tela).
- Juros e multa do Contas a Receber: o usuário vai tratar à parte (particular de cada cliente).
- Instalação no EC2 da AWS (onde ficam os bancos do VarejoFacil): destino `localhost`, tela só por
  túnel SSH/SSM (não abrir a 8020), lista de bancos na tela, backup antes de gravar, horário de
  menor movimento.
- Para novos itens: método da seção 7 (ler .kjb/.ktr, sobras de cliente, constantes de loja,
  `proforlin` fixo, SQLs que alteram a origem, chaves que duplicam, triggers).

## 9b. Servidor MCP (`servidor_mcp/`, v2026.11.02 — feito pela equipe)

Servidor MCP que mora dentro do migrador e dá ao Claude dois modos (detalhes em `servidor_mcp/LEIA-ME-MCP.md`):
- **Leitura** (sem aprovação): consultas em Firebird, SQL Server e PostgreSQL para conferir dados,
  comparar origem × destino e investigar chamados. Só conexões `"uso": "leitura"` (usuários somente
  leitura no banco — a proteção que não falha); `seguranca.py` valida o SQL (bloqueia
  INSERT/UPDATE/DELETE/DDL, `$$`, funções perigosas do PostgreSQL, procedures do SQL Server…),
  limita linhas e mascara colunas de senha/token.
- **Migração** (com aprovação a cada pedido): `solicitar_execucao` cria um PEDIDO (nada roda) → o
  usuário aprova num **terminal interativo** (`aprovar.bat <ID>` / `aprovar.sh`), digitando `SIMULAR` ou
  o **nome do banco de destino** → `executar_pedido_aprovado` roda UMA vez → `status_execucao`. Uma
  etapa por pedido (`max_itens_por_aprovacao: 1`), validade 15 min, aprovação presa a um hash do
  conteúdo dos SQL/Python que vão rodar (inclusive itens automáticos e o arquivo de códigos da virada):
  mudou algo → pedido `invalidada`. O destino tem de ser PostgreSQL com `"uso": "migracao"` (usuário
  com escrita, nunca usado em consultas).
- Usa a **mesma API** da tela (`/modulos`, `/migrar`, `/status`, `/codigos/*`) — por isso a simulação
  continua existindo pela API (a tela não tem Simular). Avisos da aprovação: a simulação confirma o
  `finalizar.sql` e não volta sequences; o `99_fila_panama` (apaga e recria as filas) entra em toda execução.
- Instalação: `servidor_mcp\instalar-mcp.bat` (instala `mcp` no `.venv` do migrador e cria o
  `conexoes.json` a partir de `conexoes.exemplo.json`); senhas SÓ em variáveis de ambiente do usuário
  (`MCP_FB_ORIGEM_SENHA`, `MCP_PG_LEITURA_SENHA`, `MCP_PG_DESTINO_SENHA`…) — nunca no `conexoes.json`
  nem no pedido. O `conexoes.json` real não vai no pacote.
- Testes: `servidor_mcp/tests` (pytest; 106 testes — segurança, aprovação, fluxo) — passaram contra a
  v2026.11.03 unificada.

## 10. Entregar o migrador para alguém (pacote pronto)

Quando alguém pedir o migrador ("me passa o migrador", "quero instalar"), gerar o zip completo a
partir da cópia guardada na skill — não reescrever:

```bash
python3 scripts/recriar_migrador.py /tmp            # cria /tmp/migrador_syspdv_varejo (sem as DLLs)
cd /tmp && curl -sL -o fb64.zip https://github.com/FirebirdSQL/firebird/releases/download/R2_5_9/Firebird-2.5.9.27139-0_x64.zip
echo "707e05bae8994b06cec60815a292078db82d8e75616f4dd514b7e417a3ee2137  fb64.zip" | sha256sum -c -
cd /tmp/migrador_syspdv_varejo/windows/firebird_client_x64 && unzip -q -j /tmp/fb64.zip \
   bin/fbclient.dll bin/msvcr80.dll bin/msvcp80.dll bin/Microsoft.VC80.CRT.manifest \
   bin/icudt30.dll bin/icuin30.dll bin/icuuc30.dll && unzip -q -j /tmp/fb64.zip IDPLicense.txt IPLicense.txt
cd /tmp && zip -qr migrador_syspdv_varejo.zip migrador_syspdv_varejo
```

Se o download do GitHub não for possível, entregar sem as DLLs e avisar: no Windows, o usuário
copia as DLLs para `windows\firebird_client_x64` (ver o LEIA-ME da pasta); no Linux não são usadas.
Depois: Linux `bash linux/instalar.sh` + `bash linux/iniciar-app.sh`; Windows `windows\instalar.bat`
(instaladores dos programas na pasta Downloads, vindos do Drive interno).

## 11. Histórico da ferramenta

- Tentativas anteriores, substituídas por esta: `migrador_auto` (Tkinter, API/Postgres) e
  `migrador-syspdv-varejofacil` (web multi-origem + execução do Pentaho via Kitchen). Decisão
  do usuário: Python puro com pastas de comandos, uma tela só, sem abas além da do sistema.
- Versão atual do app: `VERSAO = "2026.11.41"` em `app/main.py` (porta 8020). Histórico recente: 11.04
  instalador Linux tolerante a repositórios de terceiros; 11.05–11.10 Validação de Integridade (Firebird local/
  Docker, SQL Server banco/.bak/MDF+LDF, menu antes de Conexões (na 11.19 passou para depois), abas e explicações separadas, tabelas OK
  recolhidas, bugcheck); reparo do Firebird só no servidor (sem botão); 11.11 recarga das tabelas de carga nos
  Ajustes de Produto; 11.12 página sem cache e tela só com o Validar; 11.13 `instalar.sh` instala o driver
  ODBC do SQL Server (msodbcsql18) — validado pelo usuário com SQL Server real no Linux; 11.14 EAN com EXISTS;
  11.15 saldo positivo só > 0 + `42_saldo_zero` em lote + ANALYZE antes dos recálculos; 11.16 erros por tabela
  (lista no cartão, `<etapa>_erros.csv`, mensagens traduzidas); 11.17 não migrados do Produto com o motivo
  (`nao_lidos.sql`) — validado pelo usuário; 11.18 limpeza dos códigos auxiliares (EAN) depois da troca de códigos; 11.19 Conexões antes da
  Validação (servidor configurado uma vez), validação de backup .GBK/.FBK (restaura e valida) e "Usar este banco na migração"; 11.20–11.23 loccod = 0, código
  zerado fora da leitura, menu Relatórios + formulário de validação (Word, 3 colunas, bordas pretas); 11.24–11.25 "Na
  origem" = o que a seleção lê (grupo/subgrupo órfão etc.); 11.26 funcionário com `pfl_principal = true` e sem o
  código 0; 11.27 impostos federais do produto: 1 por tipo (sem duplicidade de PIS/COFINS); 11.28–11.29 "se já existe,
  passa" pelas chaves únicas (item da tabela tributária, programação de preço do encarte, funcionário pelo CPF) —
  validado pelo usuário numa virada; 11.30 limite de crédito sempre BOLETO RECEBER (pelo nome); 11.31 opção "Só com
  movimentação desde [data]" em todos os itens de produto/estoque; 11.32 quadro "Regras da migração"; 11.33 um tipo
  por parâmetro (teste com prepare=True) e NCMs do cenário sem classificação em branco/sem produto; 11.34 lista
  montada uma vez (cenário NCM 105 s → 0,1 s) — validado pelo usuário; 11.35 formulário: composição/kit só com
  componentes; 11.36 relatório padrão do kit no menu Relatórios e nome "<Cliente> (<CNPJ>) - Validação de
  Migração.docx"; 11.37 "LISTAGEM DOS PRODUTOS PRECO ZERO"; 11.38 página Migração com grupos um abaixo do outro e o
  grupo Exceção (opções), Consultar códigos de volta no lugar (div a mais) — validado pelo usuário; 11.39 impostos
  federais com CST de entrada/saída vazio também migram (campo vazio); 11.40 saldo pela diferença (sem apagar
  movimentos), produto não migrado ignorado nas demais tabelas (exige_produto) e limpeza de caracteres de controle;
  11.41 barra de progresso no ajuste de códigos e correção do ajuste de clientes (SET CONSTRAINTS ALL IMMEDIATE). Migração SQL Server → VarejoFácil validada pelo usuário. A 2026.11.02 foi feita
  pela equipe a partir da 2026.10.31 da skill (tela nova + servidor MCP); a 2026.11.03 junta essa estrutura
  com o que só a 2026.10.33 tinha (benefício fiscal, `ignorar_se_origem_falhar`, grupo/item no
  `/status`) e devolve as DLLs do client Firebird 64 bits, que o pacote da equipe não trazia.
- **Vários colaboradores**: skill compartilhada é somente leitura para quem recebe; quem muda algo gera o
  `.skill` atualizado e envia para a dona, que salva por cima (todos recebem). Ao receber um pacote de outra
  pessoa, comparar com a versão atual (`diff -rq`) antes de adotar: pode ter sido feito a partir de uma
  versão anterior e não ter as mudanças mais recentes.
- Ambientes validados pelo usuário: Linux (Ubuntu 24.04, Firebird 2.5 em Docker, PostgreSQL 15)
  e Windows (Firebird 2.5.1 32 bits, PostgreSQL 15.19, pgAdmin 4 9.18, Python 3.12 64 bits);
  origem SQL Server validada pelo usuário.
- Ao entregar uma versão nova: gerar o zip completo (nunca arquivos soltos), mudar `VERSAO`
  quando o código de `app/` mudar, e lembrar de apagar pastas renomeadas.
