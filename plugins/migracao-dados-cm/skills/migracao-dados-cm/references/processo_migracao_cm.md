# Processo de Migração de Dados — Casa Magalhães (CM)

> Fonte oficial: apresentação "Migração de Dados — Para Softwares Casa Magalhães" (08.2026).
> Guia estruturado de atendimento, execução técnica, validação de dados e virada de loja.

Este documento é a **fonte única de verdade** sobre o processo de migração. Qualquer
resposta sobre etapas, prazos, ferramentas ou regras deve ser validada contra este
arquivo antes de ser dada ao usuário.

---

## Visão Geral — As 5 Etapas do Processo

| # | Etapa | Resumo |
|---|---|---|
| 1 | **Atendimento & Triagem** | Abertura de solicitações, criação de links e definição de SLA |
| 2 | **Contato & Alinhamento** | Solicitação de bases e conferência de cenários acordados |
| 3 | **Execução** | Início do processo de migração técnica, identificação dos softwares |
| 4 | **Validação** | Homologação detalhada dos dados e do cenário migrado |
| 5 | **Virada de Loja** | Transição para produção com acompanhamento especializado |

---

## 1. Atendimento & Triagem

**Entrada de Demanda**: ao receber uma solicitação de migração por parte do cliente ou
revenda, o setor Comercial realiza o primeiro atendimento e direciona a demanda para o
time de Migração.

### Fluxo — VarejoFacil
1. Abertura da solicitação — o time Comercial/Canais abre a solicitação de migração.
2. Criação do link — o time Comercial providencia a criação do link do varejo.
3. Direcionamento para Migração — a demanda é encaminhada ao setor de Migração.

### Fluxo — SysPDV
1. Abertura da solicitação — o time Comercial/Canais abre a solicitação de migração.
2. Criação do link — **não existe esse processo para SysPDV**.
3. Direcionamento para Migração — a demanda é encaminhada ao setor de Migração.

### SLA (prazos oficiais)

| Modalidade | Cliente | Sistema | Prazo |
|---|---|---|---|
| Migração de banco de dados (prazo unificado) | Clientes Diretos | Sistema próprio e terceiros | **10 dias úteis** |
| Migração | Clientes Revenda | Sistema Próprio | **3 dias (5 dias úteis)** |
| Migração | Clientes Revenda | Sistema de Terceiros | **7 dias (10 dias úteis)** |

> ⚠️ Clientes Diretos têm contrato de atendimento direto com prazo único de 10 dias úteis,
> independente do sistema. Clientes Revenda (demandas via canais de parceiros) têm prazos
> diferenciados: mais ágil para sistema próprio, estendido para terceiros.

---

## 2. Contato & Alinhamento

Objetivo: confirmar as informações solicitadas antes da execução.

1. **Solicitação do banco de dados**: se o link do banco não estiver preenchido no
   formulário, o time de Migração aciona o cliente (direto) ou a revenda para solicitar
   a cópia e prosseguir com o atendimento.
2. **Validação das informações**: após o recebimento do formulário, confere-se as
   informações selecionadas pelo cliente/revenda comparando-as com os dados disponíveis
   no banco. Etapa importante para identificar opções marcadas sem dados correspondentes,
   ou dados relevantes não marcados no formulário.

O formulário de migração contém os campos e etapas de preenchimento cadastral que
orientam o levantamento inicial do cenário do cliente.

---

## 3. Execução

Início do processo de migração técnica e identificação dos softwares envolvidos.

### 3.1 Sistemas Próprios (SysPDV / VarejoFacil)
- Já possuem migradores padrão.
- Adaptações são pontuais, conforme necessidade do cliente/revenda, mantendo alta
  padronização.
- **Prazo de finalização: até no máximo 1 dia útil** após o início.

### 3.2 Sistemas de Terceiros
- Análise de bancos de dados diversos: **PostgreSQL, SQL Server, Firebird, MongoDB,
  MariaDB, MySQL, DB2, planilhas, etc.**
- Cria-se o migrador do zero ou atualiza-se o repositório existente, mantendo contato
  com a revenda para validar as informações mapeadas.

#### Identificação e Preparação
Ao receber uma solicitação envolvendo sistemas de terceiros:
1. Identifica-se o tipo de banco de dados usado pelo cliente.
2. Configura-se o banco em ambiente local para possibilitar extração e análise.

#### Mapeamento e Desenvolvimento
1. Mapeamento das tabelas e informações indicadas no formulário de migração.
2. Verificação de migrador compatível no repositório.
3. Se não existir migrador disponível: desenvolvimento de um novo, adaptado às
   estruturas dos bancos de origem e destino. **Prazo: até 5 dias úteis.**

#### Migração de Terceiros → SysPDV / VarejoFacil
- Identifica-se o sistema de origem e o tipo de banco.
- Avalia-se compatibilidade com migradores existentes.
- **SysPDV**: 114 migradores disponíveis no repositório.
- **VarejoFacil**: 156 migradores disponíveis no repositório.
- Se não houver migrador compatível, desenvolve-se um novo (prazo de até 5 dias úteis),
  com análise detalhada de cada tabela e campo do banco de origem.

### 3.3 Desafios Comuns em Migrações de Terceiros

| # | Desafio | Descrição |
|---|---|---|
| 1 | **Coleta de Backup** | Quando a revenda tem dificuldade de coletar o banco do cliente, a equipe de Migração atua diretamente na extração e disponibilização da base. |
| 2 | **Sistemas Legados e Fora de Produção** | Sistemas antigos exigem configuração de ambiente local com a mesma versão do SGBD de origem (ex.: MySQL 5.0, PostgreSQL 9.6). |
| 3 | **Mapeamento de Tabelas** | Identificação manual das tabelas de produtos — cada sistema tem sua própria nomenclatura (ex.: `estoque`, `estk`, `00052`, `snk001`, `prod`, `itens`, `tb_estoque_produto`, `est`). |
| 4 | **Divergência de Códigos** | O código de referência pode ser usado como código interno; exige validação adicional via capturas de tela do sistema de origem (ex.: REF_0007529684). |
| 5 | **Sistemas Homônimos** | Sistemas com nomes iguais/semelhantes podem usar bancos diferentes. Ex.: VR Solução (SQL Server), VR Gestor (PostgreSQL), Sistema VR (Firebird). Exige identificação correta antes de migrar. |
| 6 | **Não Relacionais e Complexos** | Bancos como Oracle e DB2 exigem mais tempo de montagem de cenário — dependem de instaladores e versões específicas compatíveis com o cliente. |

### 3.4 Ferramentas do Time de Migração

**Essenciais**
- Pentaho (ETL)
- Docker (principalmente para ambiente VarejoFacil local)
- Acesso ao Stage da AWS (EC2) — onde estão os bancos VarejoFacil Prod e Hml
- SGBD ou ferramenta similar de acesso a bancos (ex.: DBeaver) — SQL Server, Postgres,
  Firebird, MySQL, etc.
- Git/GitHub — versionamento dos migradores Pentaho e scripts SQL

**Complementares**
- Planilhas (LibreOffice / Excel / Google Sheets)
- Editor de texto / IDE (ex.: VS Code, com integração de IA/Copilot para scripts SQL)
- SGBD específico por banco (ex.: MySQL Workbench, MongoDB Compass)
- Ambiente Linux
- Ambiente VarejoFacil
- Acesso à AWS CLI

### 3.5 Passo a Passo Operacional (execução técnica)

1. **Iniciar o processo**: acessar o painel administrativo para configuração inicial.
2. **Parar o link do Varejo**: buscar pelo CNPJ do cliente e pausar a instância antes de
   gerar cópias/backups.
3. **Entrar na AWS**: acessar o AWS e conectar-se à instância do cliente.
4. **Gerar cópia do link de produção**: executar o comando de dump e salvar o link gerado
   do S3 para download local.
5. **Restaurar bancos e configurar ambiente local**:
   - *Banco de origem — SysPDV*: normalmente recebem-se arquivos `.gbk` ou `.fbk`
     (revenda ou cliente direto). Restaura-se para gerar o banco em formato `.fdb`,
     verificando integridade e possíveis inconsistências/corrupções antes de seguir.
   - *Banco de destino & Pentaho*: para VarejoFacil, o backup é feito direto na AWS —
     o link do cliente é interrompido, gera-se o comando de backup, faz-se o download e
     restaura-se o banco localmente. Em seguida configuram-se os dois bancos no Pentaho:
     SysPDV como origem, VarejoFacil como destino. O Pentaho lê a origem, aplica as
     transformações e insere no destino.

### 3.6 Estrutura do Migrador Pentaho (Spoon)

Fluxo geral de migração inicial de dados, dividido em módulos sequenciais:

| Módulo | Conteúdo |
|---|---|
| **a) Cadastros** | Estruturação e carga inicial das tabelas base e regras fiscais |
| **b) Pessoas** | Tratamento, higienização e carga dos dados de clientes e fornecedores |
| **c) Produto** | Estruturação, saneamento e carga do catálogo de produtos e regras tributárias |
| **d) Estoque e Movimentação/Custos** | Ajuste, zeramento opcional e carga dos dados de movimentação de estoque e custos |
| **e) Financeiro — Contas a Receber** | Carga das informações de contas a receber |
| **f) Financeiro — Contas a Pagar** | Carga das informações de contas a pagar |

> A ordem acima é a ordem lógica recomendada do fluxo Pentaho: cadastros e pessoas antes
> de produto; produto antes de estoque; estoque antes do financeiro.

---

## 4. Validação

Homologação detalhada dos dados e do cenário migrado.

### Migração para SysPDV
- Testes em ambiente local simulando o cenário real de uso do cliente.
- Validação contempla **100% dos dados migrados**, permitindo identificar e corrigir
  inconsistências antes da entrega.
- Cada informação migrada é registrada e validada individualmente no **documento de
  validação**, garantindo rastreabilidade e segurança do processo.

### Migração para VarejoFacil
- Execução de testes locais dos dados migrados antes de disponibilizar em produção
  (AWS).
- Validação das informações migradas para identificar/corrigir erros ou inconsistências.
- Preenchimento do documento de validação individual, garantindo registro e confirmação.

> Existem modelos padronizados de **Documento de Validação** usados nos dois fluxos
> (SysPDV e VarejoFacil).

---

## 5. Virada de Loja

Quando o cliente decide utilizar o sistema da Casa Magalhães como principal.

### Processo de Virada — SysPDV → VarejoFacil
1. **Definição da data de virada**: estabelecida previamente — data em que o cliente
   deixa de usar o SysPDV e passa a operar no VarejoFacil como sistema principal.
2. **Período de transição**: entre a migração inicial e a virada, o cliente continua
   usando o SysPDV; os dados continuam sendo movimentados no sistema de origem.
3. **Atualização final dos dados**: antes da virada definitiva, nova atualização das
   informações para contemplar movimentações desde a migração inicial.
4. **Virada**: realizada após o expediente, contemplando principalmente atualização do
   saldo de estoque e das informações financeiras.
5. **Início da operação**: no dia seguinte à virada, o cliente inicia atividades no
   VarejoFacil.
6. **Acompanhamento pós-virada**: o time de Migração permanece disponível para tratar
   inconsistências. Não há prazo formal, mas a boa prática é ~**30 dias**; após esse
   período, novas demandas vão para o Suporte.

### Processo de Virada — Terceiros → SysPDV / VarejoFacil
1. **Definição da data de virada**: definida previamente com a revenda ou equipe de
   Implantação — data limite para o cliente passar a usar SysPDV ou VarejoFacil como
   principal.
2. **Período de transição**: até a data da virada, o cliente opera normalmente no
   sistema de terceiros; atualizações de dados são feitas nesse período para reduzir
   divergências entre sistemas.
3. **Atualização final dos dados**: antes da virada, atualização final das informações
   desde a última carga.
4. **Virada**: realizada fora do horário comercial, permitindo a carga final dos dados
   (estoque e financeiro) sem impactar a operação do cliente.
5. **Início da operação**: no dia seguinte à virada, o cliente inicia operações no
   SysPDV ou VarejoFacil como sistema principal.
6. **Acompanhamento pós-virada**: mesma regra dos ~30 dias antes de direcionar ao
   Suporte.

---

## Regras de Negócio Adicionais (extraídas dos formulários reais)

Estas regras vêm dos formulários oficiais de migração (Sistema Próprio e Sistema
Terceiros) e do modelo de validação — não estavam na apresentação, mas são regras
vigentes do processo:

- **Fila FIFO**: a migração segue a fila — quem chega primeiro é entregue primeiro.
- **Produtos sem descrição não são migrados.**
- **Só são migrados títulos em aberto e/ou parcialmente liquidados** das contas a
  receber (e a pagar) — títulos já liquidados/cancelados não entram na migração.
- **Fornecedores e clientes sem CNPJ/CPF não são migrados** (cadastro nem títulos
  associados a eles).
- **Só são migrados encartes em aberto ou programados.**
- **Multi-loja**: se o cliente tem mais de 1 loja, a partir da segunda loja só são
  migrados produtos que tenham código de barras e clientes/fornecedores que tenham
  CPF/CNPJ preenchido.
- **Local de estoque**: por padrão, só o primeiro local de estoque é migrado no
  SysPDV — se o cliente usa mais de um local, isso deve ser informado explicitamente.
- **Pós-virada**: na virada de loja, a base antiga do cliente é mantida apenas como
  base de consulta; cria-se uma nova base para sincronização com o sistema principal.
- **Atualização de migração já concluída**: deve ser solicitada por e-mail para
  `migracao@casamagalhaes.com.br` com **5 dias úteis de antecedência** da data prevista
  da virada, incluindo nome do cliente, CNPJ, data e hora da virada. Só pode ser
  solicitada depois que a migração inicial já tiver sido concluída.
- **Milênio também é considerado "sistema próprio"** ao lado de SysPDV e VarejoFacil —
  aparece como opção de destino nos formulários e tem seus próprios migradores
  (Migrador Milenio-Milenio, Migrador Syspdv-Milenio, Migrador Milenio-Varejo).

## Estrutura do Formulário de Migração (campos reais)

Existem dois formulários oficiais — **Sistema Próprio** e **Sistema Terceiros** — com
estrutura quase idêntica; a diferença principal é que o de Terceiros pede também o
**nome do sistema atual** e o **tipo de banco de dados de origem**.

Seções do formulário:
1. **Dados do Cliente/Revenda**
2. **Tipo de Migração** — tipo de banco de origem (Firebird/SQL Server/PostgreSQL/outro)
   e sistema de destino (SysPDV/VarejoFacil/Milênio)
3. **Link do Banco de Origem**
4. **Responsável pela Implantação** (nome, telefone, e-mail)
5. **Caso seja migração para VarejoFacil**: link de origem, link de destino, loja de
   origem da informação (padrão: loja Matriz)
6. **Dados a serem migrados (detalhar)**, organizados em 4 blocos de checkbox:
   - **Cadastro Padrão**: Seção, Grupo, Sub Grupo, Cadastro de Tributação, Cadastro de
     Impostos Federais, Também migrar produtos fora de linha
   - **Cadastro Pessoas**: Dados da Loja, Funcionário, Cliente, Limite de Crédito,
     Fornecedor, Agente Financeiro, Conta Corrente, Finalizadora
   - **Cadastro Produto**: Impostos Federais Produtos (PIS/COFINS), Código Auxiliares
     (EAN), Código Referência de Fornecedor, Preço, Composto, Kit, Similares/Famílias,
     Encarte
   - **Cadastro Movimentação**: Saldo de Estoque Positivo, Saldo de Estoque Negativo,
     Movimentação de Custo, Títulos a Receber (aberto/parcial), Títulos a Pagar (aberto)

### Campos adicionais do formulário (versão Google Forms, respostas ao vivo)

O formulário eletrônico (Google Forms) usado atualmente tem alguns campos que não
apareciam na versão .docx do formulário: `Regime Fiscal`, `Participa do Decreto
29560/08`, `Quantidade de usuário`, `Quantidade de Lojas`, `Segmento(s)`, `Versão do
Sistema`, `Tipo de banco`, `Tamanho do banco`, e — no formulário de Terceiros — `CNPJ
DO ESTABELECIMENTO`, `CIDADE/UF`, `PESSOA DE CONTATO / TELEFONE`, `E-MAIL` já na
entrada (o de Sistema Próprio pede esses mesmos dados só ao final do formulário).

## Estrutura do Documento de Validação (modelo real)

O documento de validação (preenchido pelo analista revisor após a migração) registra:

- **Cabeçalho**: Cliente (razão social + CNPJ), Analista de Migração, Sistema de
  Origem, Sistema de Destino, Migrador Usado.
- **Dados Migrados** (contagem por categoria): Seção, Grupo, Subgrupo, Impostos
  Federais, Local Estoque, Loja, Funcionário, Cliente, Limite de Crédito, Fornecedor,
  Agente Financeiro, Produto, Impostos Federais Produtos, Produto Com/Sem Auxiliar,
  Produto Fornecedor, Preço Maior/Igual a Zero, Tributação/Situação Fiscal, Produto
  Família, Produto Composição, Produto Kit, Encarte, Estoque Positivo/Negativo/Zero
  (frequentemente marcados como "MIGRAR NA VIRADA" quando a carga real só ocorre na
  virada de loja), Contas a Receber/Pagar (idem).
- **Informações Complementares**: Multi Loja, Mudança de Código de Produto, Mudança de
  Código de Cliente, Juros e Multas, Produtos em Linha/Fora de Linha/Balança, e a
  contagem por Local de Estoque.
- **Situação Fiscal**: tabela comparando Situação Fiscal Migrada x Situação Fiscal
  Criada (ex.: Fonte-F00, Isento-I00, Tributado-T17).
- **Imposto Federais**: tabela comparando Imp. Federal Migrada x Imp. Federal Criada
  (ex.: PIS/COFINS Tributado, Alíquota Zero, Monofásico, Suspensão, Outras Entradas,
  Substituição Tributária).

> Ao preencher ou revisar um documento de validação, nunca inclua dados reais de
> clientes (razão social, CNPJ, nome do analista) em exemplos ou modelos genéricos —
> use placeholders como `[CLIENTE]`, `[CNPJ]`, `[ANALISTA]`.

## Glossário Rápido

| Termo | Significado |
|---|---|
| `.gbk` / `.fbk` | Formatos de backup recebidos de sistemas de origem (ex.: Firebird) |
| `.fdb` | Formato de banco restaurado (Firebird) usado como origem no Pentaho |
| Link do Varejo | Instância/link de acesso do cliente no VarejoFacil, pausável por CNPJ |
| Stage AWS (EC2) | Ambiente onde estão os bancos VarejoFacil Prod e Hml |
| Spoon | Interface gráfica do Pentaho onde os fluxos de transformação (ETL) são montados |
| Migrador | Script/fluxo Pentaho (ou equivalente) que extrai, transforma e carrega dados de um sistema de origem para o destino (SysPDV ou VarejoFacil) |
