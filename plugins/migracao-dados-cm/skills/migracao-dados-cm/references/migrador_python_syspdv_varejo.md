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
  migrar. Opção **Simular** (marcada por padrão): roda tudo e desfaz no final.
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
│                       docker_firebird.py, verificar_fbclient.py
├── comandos/           uma pasta por item (ver seção 4) + _modelo/ + COMO_ADICIONAR.md
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
(`01_`, `02_`...; pastas com `_` no início são ignoradas). Simulação = uma transação só,
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
| `39_ajustes_produto` | (só SQL, automático, último do grupo Produto) | "Produto higieniza Loccod" + "Ajusta Produto" (sem a linha de `pesquisa_satisfacao`; `itt_icms_desonerado IS NULL` corrigido) + "Corrigi produtos sem composição" + **Cadastro de operações** (24 operações padrão, sem checkbox, pedido do usuário; bloco DO que só insere o código que não existe — 1ª coluna da tabela `operacao`, os INSERTs do Pentaho são posicionais) + `ALTER TABLE produto ENABLE TRIGGER ALL` |

**Grupo Estoque** (depois dos produtos; tudo segue a opção fora de linha; pedido do usuário: um
checkbox por parte):

| Pasta | Origem → destino | Regras principais |
|---|---|---|
| `40_inicio_estoque` | (só SQL, automático, primeiro) | tipos de ajuste 9001 SAIDA / 9002 ENTRADA (AJUSTE_MIGRACAO) + `ALTER TABLE produto DISABLE TRIGGER ALL` (pedido do usuário: sem isso demora muito); `finalizar.sql` = ENABLE de garantia |
| `41_saldo_positivo` / `42_saldo_negativo` | ESTOQUE (≥ 0 / < 0) → estoque_movimentacao | ajuste 9002, histórico MIGRACAO, local 1, loja do PROPRIO, funcionário 1; estratégia de saldo abaixo |
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
5. Testar: simulação → gravação → 2ª rodada (tudo "sem alteração", salvo conflitos reais) e
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
| Item roda duas vezes após atualização | pasta renomeada que ficou da versão anterior (ex.: `11_ajustes_pessoas` → `19_ajustes_pessoas`): apagar a antiga |

## 9. Próximos passos

O fluxo do `Migrador_Inicial.kjb` está completo: Cadastros Padrão, Pessoas, Produto (com Encarte e
cenários fiscais), Estoque, Financeiro e a fila do Panamá — testado pelo usuário em Linux e Windows,
origem Firebird e SQL Server. Pendentes/possíveis:
- "Relatório padrão" do `Migrador_Inicial.kjb` (não pedido).
- Juros e multa do Contas a Receber: o usuário vai tratar à parte (particular de cada cliente).
- Instalação no EC2 da AWS (onde ficam os bancos do VarejoFacil): destino `localhost`, tela só por
  túnel SSH/SSM (não abrir a 8020), lista de bancos na tela, backup antes de gravar, horário de
  menor movimento.
- Para novos itens: método da seção 7 (ler .kjb/.ktr, sobras de cliente, constantes de loja,
  `proforlin` fixo, SQLs que alteram a origem, chaves que duplicam, triggers).

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
- Versão atual do app: `VERSAO = "2026.10.25"` em `app/main.py` (porta 8020).
- 2026.10.25 (pedido do usuário em 19/10/2026): tempos no log de execução. `app/motor.py`:
  `duracao()` formata `0,8s` / `42,3s` / `3min 07s` / `1h 02min 05s`; cada etapa loga
  "início às HH:MM:SS" e "fim em <duração>: lidos ..." (no erro: "ERRO após <duração>") e guarda
  `tempo` (segundos) no status da etapa. `app/main.py`: "Migração iniciada em dd/mm/aaaa HH:MM:SS"
  e, no fim, "Migração concluída|terminou com erro em ... — tempo total: <duração>"
  (`estado["duracao"]`). A linha do tempo total entra no log ANTES de mudar o status, porque a
  tela para de ler o log quando o status deixa de ser `em_andamento`. Tela inalterada (possível
  próximo passo: coluna "Tempo" na tabela de progresso usando `tempo`).
- Ambientes validados pelo usuário: Linux (Ubuntu 24.04, Firebird 2.5 em Docker, PostgreSQL 15)
  e Windows (Firebird 2.5.1 32 bits, PostgreSQL 15.19, pgAdmin 4 9.18, Python 3.12 64 bits);
  origem SQL Server validada pelo usuário.
- Ao entregar uma versão nova: gerar o zip completo (nunca arquivos soltos), mudar `VERSAO`
  quando o código de `app/` mudar, e lembrar de apagar pastas renomeadas.
