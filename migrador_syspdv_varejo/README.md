# Migrador SysPDV (Firebird) → VarejoFacil (PostgreSQL)

Migrador em Python, sem Pentaho. A tela tem um **menu lateral** (mesmo padrão do Portal de Revendas, que
pode ser recolhido para ganhar espaço) com as páginas **Conexões**, **Migração** (Inicial e Virada),
**Progresso** e **Códigos**. Em Migração, os **dados a serem migrados** ficam em checkboxes. Cada checkbox é uma
pasta em `comandos/` com os comandos daquela entidade, para você saber exatamente onde corrigir ou acrescentar.

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
│   ├── 20_produto_beneficio_fiscal/  sem checkbox, logo depois do Produto: PROBENFIS -> cbenef_produto_loja
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
│   ├── codigos/               consultar/ajustar códigos ≥ 999999 (scripts do kit-migracao)
│   ├── motor.py               lê as pastas de comandos/ e executa
│   ├── ajudantes.py           inteiro(), texto(), numero(), so_digitos(), Pular
│   ├── firebird_conexao.py    conexão Firebird local/Docker, fbclient, charset
│   ├── docker_firebird.py     detecção de container do Firebird
│   └── main.py                servidor web
├── comandos_virada/           só o que é exclusivo da virada (ver comandos_virada/LEIA-ME.md)
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
2. **Dados a serem migrados**: escolha a aba **Migração Inicial** ou **Migração Virada** (os mesmos
   itens, com o de-para de códigos: anexe as planilhas de códigos de clientes e/ou produtos geradas na
   página **Códigos** — ver `comandos_virada/LEIA-ME.md`). As duas abas abrem com tudo desmarcado. Os comandos de cada item ficam na pasta
   `comandos/` (ex.: `comandos/01_secao/origem.sql`).
3. **Iniciar migração** (a tela pede confirmação com o banco de destino e a quantidade de itens: a
   migração grava de verdade — use uma base de migração, não a de produção em uso) → barra verde com o tempo decorrido; cada item mostra o **tempo** de leitura e
   gravação da sua tabela (coluna Tempo, também no log) e, no fim, o **tempo total da migração**.
   A barra vai de 0% a 100% e o acompanhamento é por item (com **Na origem** = total da tabela no SysPDV e
   **Não migrados**, para bater os números) e baixe o relatório "linha a linha"
   (inserido / atualizado com antes→depois / sem_alteracao / pulado / erro). Rodar de novo é seguro:
   o que já foi gravado fica "sem alteração" (não duplica).
   Na página **Progresso**, cada etapa é uma linha: a que está rodando fica aberta (barra e números ao vivo), as
   concluídas se **recolhem sozinhas** e as com erro ficam abertas; clique na seta para abrir ou fechar qualquer etapa
   (ou use **Expandir todas** / **Recolher todas**). Ao terminar, um **pop-up** informa o resultado: concluída,
   concluída com avisos (etapas com registros com erro) ou parada com erro, com o tempo total e os totais.

Rodar de novo é seguro: com `existe.sql` + `atualizar.sql`, o que já existe é
atualizado ou mantido, sem duplicar.

Observação: a simulação desfaz os dados, mas as sequences do PostgreSQL não voltam
(é assim no PostgreSQL). Os IDs da gravação real podem começar alguns números à frente.

## Relatórios → Formulário de validação da migração

O menu **Relatórios** só aparece depois que uma **migração inicial termina** (registro em `reports/ultima_migracao.json`,
que continua valendo depois de fechar o migrador). Nele: **Nome do Cliente**, **Analista de Migração** (lembrado),
**"Teve troca de códigos dos produtos?"** e **"dos clientes?"** (lista Sim / Não) e o botão **Gerar formulário**, que conta nos bancos configurados em Conexões e gera
`formulario_migracao_<banco>_<data>.docx` a partir do modelo `app/formulario_modelo/validacao_migracao.docx`:

- **Migração:** "Migração Inicial — data", origem (SysPDV Firebird / SQL Server), destino e versão do migrador.
- **Dados Migrados:** **Tabelas | Origem SysPDV | Destino VarejoFácil** (diferença em vermelho quando não batem),
  contadas com as mesmas regras da migração.
- **Informações Complementares (1):** produtos em linha / fora de linha / balança, também Origem × Destino.
- **Informações Complementares (2):** Mudou Código Produto / Mudou Código Cliente = as respostas da tela.
- **Situação Fiscal** e **Impostos Federais** migrados, com a quantidade de produtos.

O arquivo baixa como **`<Nome do Cliente> (<CNPJ>) - Validação de Migração.docx`** (nome vazio = razão social da loja
matriz; CNPJ da loja matriz no VarejoFácil). Todas as tabelas saem com **bordas pretas explícitas** (não somem ao salvar em PDF). Uma contagem que falhar vira "—". Precisa da biblioteca
`python-docx` (instalada pelo instalador, via `requirements.txt`). No fim da migração inicial o pop-up avisa que o
formulário está em Relatórios.

**Relatório padrão** (mesma página): as listagens padrão do **kit-migração** (`app/relatorios/varejo.py`,
`gera_relatorio_padrao`), copiadas sem alteração para `app/relatorio_padrao.py`: LISTAGEM DOS PRODUTOS PRECO ZERO,
LISTAGEM DOS PRODUTOS QUE O NCM ESTA INATIVO e LISTAGEM DOS PRODUTOS UNIDADE DE MEDIDA ERRADO — CSV separado por `;`,
com cabeçalho, UTF-8 com BOM (acentos no Excel), os mesmos nomes do kit; a tela mostra quantos produtos saíram em cada
uma e oferece cada arquivo e um .zip com os três (`reports/relatorios/`). Consulta o VarejoFácil de Conexões; nada é
gravado.

## Relatórios → Relatório padrão (kit-migração)

No menu Relatórios, o quadro **Relatório padrão (kit-migração)** gera as três listagens do kit
(`3-menu-migracao/app/relatorios/varejo.py`, opção "Gerar relatório padrão" do banco VarejoFácil), com os mesmos
nomes e as mesmas consultas: `LISTAGEM DOS PRODUTOS PRECO ZERO.csv`, `LISTAGEM DOS PRODUTOS QUE O NCM ESTA INATIVO.csv`
e `LISTAGEM DOS PRODUTOS UNIDADE DE MEDIDA ERRADO.csv` (`;` + cabeçalho, UTF-8 com BOM para o Excel), mais
`Relatório padrão - <banco>.zip` com as três (`app/relatorio_padrao.py`, rota `/relatorios/padrao`). O relatório
padrão "SysPDV" do kit é para migrações PARA o SysPDV e não entra aqui.

## "Na origem" e "Não migrados"

**"Na origem"** conta exatamente o que a **seleção do item** lê (mesmos filtros e opções): códigos zerados, grupo/subgrupo
órfão (seção ou grupo que não existe no SysPDV), funcionário inativo, cliente sem nome, fornecedor sem CNPJ/CPF,
encartes encerrados etc. **não entram na conta**. Assim **"Não migrados" só aparece quando um registro lido deu erro ou
foi pulado** — e o cartão lista cada um com o motivo. Exceção: o **Produto**, que conta a tabela (sem os códigos
zerados) e lista no cartão os produtos que a seleção deixou de fora, com o motivo (sem descrição, fora de linha).
O motor conta com `SELECT COUNT(*) FROM (<seleção>)` (sem o ORDER BY final); se a seleção tiver coluna sem nome ou
repetida (o Firebird e o SQL Server recusam na subconsulta), usa no fim o total lido.

## Página Migração: grupos um abaixo do outro

Na Migração Inicial e na Virada (Firebird e SQL Server), os itens aparecem em grupos **um abaixo do outro**, alinhados
à esquerda: grupo **Exceção** no topo (só as opções que mudam o que é migrado: "Incluir produtos fora de linha" e "Só
com movimentação desde [data]"), depois Cadastros Padrão, Cadastro de Pessoas, Cadastro de Produto, Estoque e
Financeiro. As opções vêm do `modulo.json` dos itens (`opcoes`) e são reunidas no grupo Exceção.

## Quadro "Regras da migração" (página Migração)

Acima da lista de itens (Inicial e Virada), um quadro recolhível com as regras padrão que valem sempre, por grupo:
geral (código zerado, rodar de novo sem duplicar, "Não migrados" só com erro/pulado), cadastros (grupo/subgrupo só
com seção/grupo existente), pessoas (funcionário ativo e principal na matriz; cliente com nome e limite em BOLETO
RECEBER; fornecedor com CNPJ/CPF), produto (sem descrição, fora de linha, "Só com movimentação desde", local de
impressão 0, 1 imposto federal por tipo, código de barras, encarte aberto/programado), estoque (saldo zero automático),
financeiro (contas a receber em aberto/parcial, contas a pagar em aberto de fornecedor com CNPJ) e final (fila do
Panamá, formulário em Relatórios). Ao mudar uma regra no migrador, atualizar também o texto do quadro
(`static/index.html`, `regras-migracao`).

## Opção "Só com movimentação desde [data]" (Cadastro de Produto)

Marcada, migra **só os produtos com movimento a partir da data**: venda no PDV (`ITEVDA.TRNDAT`), nota fiscal
(`ITEM_NOTA_FISCAL` + `NOTAFISCAL.NFSDATEMI`), movimentação de estoque de venda/entrada/cancelamento/troca/nota
(`ESTOQUE_MOVIMENTACAO.MOVTIP` V, E, C, T, N — sem a ordem de produção, tipo 3) ou cadastro/entrada em linha
(`PRODUTO.PRODATCADINC`) — a consulta da equipe, conferida no dicionário de dados do SysPDV. O filtro vale para
**todos os itens ligados ao produto**: produto, benefício fiscal, impostos federais, código de barras, fornecedor,
preço, tributação, família, compostos, kit, encarte, cenário fiscal, NCM e todo o estoque (saldos, mínimo/máximo,
custo). O motor acrescenta o filtro logo depois do trecho da opção "fora de linha", que toda seleção de produto tem
(`app/motor.py`, `filtro_movimentacao`); a data vai como parâmetro (o texto `'10.11.2026'` pode virar 11/10 no SQL
Server). Os produtos sem movimento aparecem no cartão do Produto como não migrados ("sem movimentação desde a data
escolhida"); a confirmação da migração e o formulário de validação mostram a data.

## Desempenho nas seleções do SysPDV: lista montada uma vez

Evite `coluna IN (SELECT coluna FROM PRODUTO WHERE ...)` quando a coluna NÃO é a chave do produto (ex.: `PRONCM`,
`TRBID`): o Firebird refaz a busca na PRODUTO para cada linha de fora (essas colunas costumam não ter índice). Monte a
lista uma vez e ligue: `FROM (SELECT DISTINCT p.PRONCM FROM PRODUTO p WHERE ...) usados JOIN NCM t1 ON ...`. Medido com
10.500 NCMs e 60 mil produtos: NCMs do cenário 105 s → 0,11 s; item da tabela tributária 5,5 s → 0,05 s (mesmo
resultado). Comparar pela chave (`PROCOD IN (SELECT PROCOD FROM PRODUTO ...)`) usa o índice e é rápido.

## Ajuste de códigos: barra de progresso

Em Códigos → Ajustar códigos, a tela mostra a barra geral (percentual e tempo, como a da migração) e uma barra por tipo
(Clientes, Produtos) com a fase: os scripts do kit avisam (RAISE NOTICE) a cada código trocado, então a troca anda de
verdade ("1.250 de 22.710 códigos", 0–85%); a limpeza dos códigos de barras (produtos) e as planilhas completam até
100%. Antes de remover a coluna temporária do kit, o ajuste roda `SET CONSTRAINTS ALL IMMEDIATE`: as FKs deferidas do
VarejoFácil deixavam conferências pendentes e o `ALTER TABLE ... DROP COLUMN` falhava ("pending trigger events"),
desfazendo o ajuste de clientes.

## Saldo de estoque: ajuste pela diferença (sem apagar movimentos)

Saldo positivo, saldo negativo e "zerar saldo já lançado" comparam o saldo do SysPDV com o saldo ATUAL do produto no
VarejoFácil (soma de todos os movimentos da loja/local 1, a mesma conta do recálculo do `estoque_resumo`). Igual =
"sem alteração"; diferente = UM movimento novo (mov_id novo, histórico MIGRACAO) com a diferença. Nada é apagado:
antes o migrador apagava o movimento MIGRACAO e lançava de novo, e o banco recusava quando ele já era usado num
inventário ("mov_id … ainda é usado na tabela item_inventario").

## Produto não migrado é ignorado nas demais tabelas

Os itens que gravam registros de produto (benefício fiscal, impostos federais, código de barras, fornecedor, preço,
família, composição, kit, encarte, cenário por produto, saldos, mínimo/máximo, custo) declaram `exige_produto` no
`modulo.json`: se o produto não existe no VarejoFácil (sem descrição, código zerado, fora de linha, erro no Produto…)
a linha fica como "pulado" com o motivo, e não como erro de chave.

## Caracteres de controle

Textos e códigos do SysPDV passam por `sem_controle` (`app/ajudantes.py`): caracteres invisíveis de bases antigas
(ex.: `'0\x105'`) são removidos — `'0\x105'` vira 5 e a descrição sai limpa (evita problema na nota fiscal). Código que
ainda não for número dá erro com o nome do campo ("GRPCOD não numérico: …").

## Parâmetros dos SQL: um tipo só por parâmetro

O motor **prepara** os comandos repetidos (a partir da 6ª linha), e o PostgreSQL recusa um parâmetro deduzido com
tipos diferentes no mesmo comando ("inconsistent types deduced for parameter $N"): ex. `%(itt_uf)s` sem tipo na lista
do SELECT (vira text) e numa comparação com coluna varchar (vira varchar). Use o MESMO cast em todas as ocorrências
(`%(x)s::varchar` em todas). Para conferir todos os SQL: executar cada validar/existe/inserir/atualizar com
`prepare=True` e parâmetros nulos numa transação desfeita, num banco do VarejoFácil (184 arquivos passam).

## Códigos zerados e local de impressão

- Registros com **código zerado** (seção `00`, grupo/subgrupo `000`, funcionário `000`, cliente `000…`, fornecedor,
  agente, finalizadora, produto `00000000000000`) **não são lidos** e **não entram em "Na origem"** — assim
  Na origem = Lidos (antes: seção com 6 na origem, 5 lidos). Regra comum a Firebird e SQL Server:
  `REPLACE(codigo, '0', '') <> ''`.
- **`loccod = 0` sempre** no produto: o VarejoFácil não tem local de impressão como o SysPDV (um LOCCOD 95, por
  exemplo, dava erro). Os Ajustes finais de Produto também corrigem produtos já migrados.

## Erros de cada tabela

No **Progresso**, o cartão de uma tabela que terminou com erros **abre sozinho** e mostra a lista **"Erros (N)"**: o
**registro** (a chave, ex.: o código do produto) e o **motivo**, em português (até 50 na tela). O botão **"Baixar só os
erros .csv"** baixa `<tabela>_erros.csv` com **todos** os erros: chave, motivo, a mensagem técnica original do banco e os
dados que vieram do SysPDV. O "Relatório linha a linha" continua com todas as linhas da tabela.

**Não migrados pela regra da seleção** (Produto): quando "Na origem" é maior que "Lidos", o cartão do Produto lista
os produtos que a seleção deixou de fora e o **motivo** — código zerado (`00000000000000`), produto sem descrição ou
fora de linha (com a opção "Incluir produtos fora de linha" desmarcada) — e o botão "Baixar os não migrados .csv"
(`20_produto_nao_migrados.csv`). Feito pelo arquivo `comandos/20_produto/nao_lidos.sql` (dá para usar em outros itens).

Erros comuns traduzidos: registro de que ele depende não migrado (chave estrangeira), registro repetido (único), campo
obrigatório vazio, texto maior que o campo, número maior que o campo, valor em formato inválido.

## Validação de Integridade (menu: Conexões → Validação de Integridade → Migração)

O **servidor** (Firebird ou SQL Server: host, porta, usuário, senha) é configurado **uma vez só em Conexões**; a
Validação usa esse servidor e você escolhe **só o arquivo/banco** a validar — nada de digitar a conexão de novo.
Valide antes de migrar; se estiver tudo ok, o botão **"Usar este banco na migração"** já coloca o banco validado como
origem em Conexões e abre a Migração Inicial. **Nada é gravado** no banco do SysPDV.

- **Firebird**: banco **.FDB / .GDB** ou backup **.GBK / .FBK** (Procurar... mostra os quatro). **Backup**: não existe
  verificação "sem restaurar" — o migrador **restaura num .FDB novo** ao lado do backup
  (`<nome>_RESTAURADO_<data>.FDB`) e valida o restaurado, que já fica pronto para a migração; backup que não restaura
  = danificado/incompleto (o .FDB incompleto é apagado). No Linux, a pasta do backup precisa permitir gravação para o
  usuário do Firebird (a validação mostra o `chmod`).
  1. *Conexão e cabeçalho* — versão, ODS, página e transações (avisa se precisa de sweep);
  2. *Validação do servidor Firebird, somente leitura* (como `gfix -v -n`) — acha páginas e registros
     corrompidos. Com o servidor Firebird **neste computador**, a tela mostra as linhas do `firebird.log`
     daquela validação (ex.: "Data page 495 ... is bad in table PRODUTO"). No Firebird 2.5 pode exigir
     o banco sem outras conexões (feche o SysPDV) e o usuário SYSDBA;
  3. *Leitura completa de cada tabela* — aponta **qual tabela** está quebrada (é onde a migração pararia).
- **Reparo do Firebird** (`validacao.reparar_firebird`, rota `/validacao/reparar`): implementado e testado
  (cópia de trabalho → `gfix -mend` → `gbak` ignorando erros → restore num arquivo novo `_REPARADO_`), mas
  **sem botão na tela por enquanto** (pedido do usuário: a tela tem só o Validar). Para voltar, basta recolocar
  o botão e a exibição original × reparado na aba Firebird.
- **Bloqueio do Firebird depois de um erro grave**: ao ler um registro corrompido o servidor dá "bugcheck" e
  passa a **recusar o banco** ("can't attach after bugcheck") até ser reiniciado. A validação mostra as
  tabelas seguintes como "não verificada". Para o banco voltar a abrir, reinicie o servidor Firebird (ou o
  container) e valide de novo.
- Na tela, as tabelas **sem erro ficam recolhidas** ("✔ N tabela(s) sem erro — clique para ver"); só as com
  problema aparecem abertas. No menu, **Validação de Integridade › Firebird / SQL Server**; cada aba tem a
  sua explicação "O que é verificado".
- **SQL Server** — servidor, porta/instância, usuário e senha, e o que validar:
  - **Banco**: estado (ONLINE / SUSPECT...), **DBCC CHECKDB** (precisa de sysadmin ou db_owner) e
    páginas suspeitas (`msdb.dbo.suspect_pages`);
  - **Arquivo .bak**: `RESTORE HEADERONLY` (banco, data, tamanho, CHECKSUM), `RESTORE FILELISTONLY` e
    `RESTORE VERIFYONLY` (com CHECKSUM quando o backup tiver; sem CHECKSUM = aviso);
  - **Arquivos .MDF + .LDF** (o banco físico): lê o cabeçalho do MDF **sem anexar** (`DBCC
    CHECKPRIMARYFILE`: nome e versão — avisa se o arquivo é de um SQL Server mais antigo), **anexa como
    banco temporário** `MIGRADOR_VALIDACAO_<data>` (sem LDF, o log é recriado), roda o **DBCC CHECKDB** e
    **sempre desanexa** no fim. **Use uma cópia dos arquivos**: ao anexar, o SQL Server pode atualizá-los
    para a versão dele (não abrem mais em SQL Server mais antigo) — a tela exige essa confirmação.
  Os caminhos do .bak/.MDF/.LDF são do **servidor SQL Server** (é ele quem lê os arquivos; o serviço dele
  precisa de acesso à pasta). O **Procurar...** mostra as pastas deste computador.

## Consultar códigos (página Códigos, depois da migração)

Clientes e produtos com código **≥ 999999** quebram o VarejoFácil. Na página **Códigos**
do menu (a troca é feita depois da migração), marque **Clientes** e/ou **Produtos**:

- **Consultar**: mostra, para Clientes e Produtos, quantos códigos ≥ 999999 existem, o menor e o maior.
  Nada é alterado e nenhuma planilha é gerada.
- **Ajustar códigos**: mostra a prévia, pede confirmação e roda os scripts do **kit-migracao**
  (`app/codigos/ajusta_cliente.sql` e `ajusta_produto.sql`, sem alteração):
  - clientes: código ≥ 999999 recebe o menor código livre (limite de crédito, contas a receber,
    cobrança e transações acompanham);
  - produtos (exceto balança): recebem um código livre de 10001 a 999998; o código antigo vira EAN
    do produto e vai para a `alteracao_produto_sped`;
  - depois da troca dos produtos, **limpeza dos códigos auxiliares** (`app/codigos/limpeza_ean.sql`, script do
    usuário): apaga o EAN igual ao código do produto, EAN inválido vira LITERAL (`validar_ean`/`validar_gs1`),
    **todo produto com EAN fica com pelo menos um tributado** e define o principal. Mesma transação (erro = nada
    gravado); o log mostra quantos registros cada passo alterou;
  - o registro das trocas aparece ao vivo enquanto altera; no fim, cada linha da tabela ganha o botão
    **Download clientes** / **Download produtos**, que baixa os dois arquivos:
    `cod_novo_cod_antigo_<cliente|produto>_todos_<banco>.csv` (todos) e
    `cod_novo_cod_antigo_<cliente|produto>_alterados_<banco>.csv` (só os alterados), guardados em `reports/codigos/`.

Usa a conexão de destino da página Conexões. Tudo numa transação só (script + planilhas + remoção da coluna
auxiliar): se algo falhar, o banco fica como estava. Não roda enquanto houver migração em andamento.

**Senha do PostgreSQL**: o migrador sempre confere usuário e senha. Se o servidor estiver em modo
`trust` no `pg_hba.conf` (aceita conexão sem senha), a senha informada é conferida contra a senha
gravada do usuário no PostgreSQL (SCRAM-SHA-256 ou MD5): senha vazia ou errada é recusada.

## Itens prontos

| Pasta | SysPDV → VarejoFacil | Regras (iguais ao migrador Pentaho oficial) |
|---|---|---|
| `01_secao` | SECAO → secao | sem a seção '00'; TRIM; descrição em MAIÚSCULO; vazia = RENOMEAR; `sec_situacao_sped = 'OUTROS'`; ID por `sq_secao` |
| `02_grupo` | GRUPO → grupo_produto | só com seção existente, sem '00'; TRIM; vazia = RENOMEAR; ID por `sq_grupo_produto` |
| `03_subgrupo` | SUBGRUPO → subgrupo_produto | só com seção e grupo existentes, sem '00'; vazia = RENOMEAR; ID por `sq_sub_grupo_produto` |
| `04_tabelas_basicas` | APLICACAO, CARACTERISTICA, LOCAL, MARCA, RAMO, STATUS, TPPGT, TPREC, TIPODOCUMENTO, UNIDADE | `T-TabelasBasicas_inicial` sem os impostos: local só ativo e flag de avaria; marca, tipo de pagamento e recebimento em MAIÚSCULO (recebimento cortado em 30); status grava STABLQ em `statipbloq` e `stablc`; ramo só insere; unidade em MAIÚSCULO, fator vazio = 1, ID por `sq_unidade` |
| `05_impostos_federais` | IMPOSTOS_FEDERAIS → impostos_federais (+ _geral, _atacado, _simples, _varejo) | só com situação de entrada ≠ saída; tipo P/C/I/S/O → PIS/COFINS/IRPJ/CSLL/OUTROS; 4 IDs pelas sequences; depois, o SQL "VF - Imposto Federal Geral" do job; imposto com a situação tributária (CST) de entrada ou de saída **vazia** no SysPDV também é migrado, com o campo vazio, para corrigir na aplicação (antes ficava de fora) |

| `06_ncm` | PRODUTO.PRONCM → ncm | sem pontos, zeros à esquerda até 8; NCM que falta entra como "NCM INATIVO" |
| `07_loja` | PROPRIO → pessoa, pessoa_loja | CNPJ só números (chave); e-mail vazio = cliente@cliente.com.br; matriz S, perfil B, COMERCIO, categorias 75/71/90/91/92/93; regime N/E/A/S → 1/2/3/4; sigla = 5 letras; depois, holcod da matriz |
| `08_funcionario` | FUNCIONARIO (ativos) → pessoa, pessoa_funcionario, pessoa_funcionario_loja, usuario | nome/apelido vazio = USUARIO; CPF só números; tipo FISICA; vínculo ativo na **loja matriz** do VarejoFacil (precisa de Dados da Loja antes); usuário com senha padrão 'admin'; vínculo com a loja matriz sempre com **`pfl_principal = true`** (o padrão da coluna é false; rodar de novo corrige os já migrados); funcionário de **código 0 não é migrado** (filtro na seleção + segunda proteção na transformação); procura pelo **código e pelo CPF** (o CPF da pessoa é único no VarejoFácil): já cadastrado com o mesmo CPF e outro código = passa ("sem alteração"); CPF de uma pessoa que não é funcionário (ex.: cliente) = reaproveita a pessoa e só cria o funcionário |
| `09_cliente` | CLIENTE → pessoa, pessoa_cliente | 3 caminhos do Pentaho: FISICA (CPF com zeros até 11), JURIDICA (até 14), sem documento (marcado no relatório); e-mail minúsculo, endereço MAIÚSCULO, número 0/vazio = SN, telefone sem ( ) - . e padrão 99999999999, IE vazia = ISENTO, país 1058; estado civil, sexo, situação e tipo de residência por extenso; depois: espécies BOLETO PAGAR/RECEBER, loja matriz nos clientes sem loja e holcod |
| `09_limite_credito` | CLIENTE.CLILIMCRE → limite_de_credito | vazio = 0; espécie 2; LIBERADO; o valor não é atualizado numa nova rodada (como no Pentaho). Precisa do Cliente migrado; espécie **sempre BOLETO RECEBER, procurada pelo nome** (sigla BR, gênero R), qualquer que seja o código dela no VarejoFácil (antes: código 2 fixo, que numa base com espécies já cadastradas era BOLETO PAGAR); cria a espécie se faltar; rodar de novo corrige limites gravados com outra espécie |
| `11_agente_financeiro` | AGENTE (exceto 0000) → pessoa, pessoa_agente_financeiro | documento = CNPJ ou CPF só números; pessoa achada pelo documento (reaproveita, não atualiza); sem documento = pessoa nova (marcada no relatório); fantasia = nome; banco 0; depois, holcod |
| `12_conta_corrente` | CONTA_CORRENTE → conta_corrente | C/B → CAIXA/BANCARIA, vazio = CAIXA; agente vazio = 0; loja = PRPCOD do PROPRIO |
| `13_finalizadora` | FINALIZADORA (exceto 000) → finalizadora | cartão, movimenta conta e carga geral = falso; agente só na inclusão; a 1 (Dinheiro) movimenta conta |
| `19_ajustes_pessoas` | (só SQL, automático) | SQLs finais do JOB-Pessoas: tipo/documento, holcod, IE duplicada = ISENTO, tipo contribuinte, sequences, bairro/fantasia/datas e padrões de cliente e fornecedor |
| `20_produto` | PRODUTO → produto | Opção **Incluir produtos fora de linha** (padrão: marcada = todos; desmarcada = só `PROFORLIN = 'N'`; o NCM segue a mesma opção). T-Produto_inicial: "FB - Ajuste Seção/Unidade" e "FB - Ajustes campos estourados" aplicados na leitura (unidade inexistente = UN, seção inexistente = maior seção, estoque/peso > 100000 = 0, preços/embalagens absurdos zerados); TRIM/MAIÚSCULO nas unidades; 11 Value Mappers e If null do Pentaho; NCM sem ponto com zeros até 8; funcod 1; `sq_produto`; triggers desligadas (Session Replication) durante a carga |
| `20_produto_beneficio_fiscal` | PRODUTO.PROBENFIS → cbenef_produto_loja | **sem checkbox**, roda sozinho logo depois do Produto (antes dos Impostos federais do produto), na inicial e na virada (com o arquivo de códigos, grava pelo código novo — inclusive produtos novos da virada, que no Pentaho ficavam de fora); TRIM + MAIÚSCULO; loja do PROPRIO; chave produto + loja; `sq_cbenef_produto_loja`; "Na origem" conta só produtos com PROBENFIS. SysPDV sem a coluna PROBENFIS: aviso e o fluxo continua (`ignorar_se_origem_falhar`) |
| `21_impostos_federais_produto` | IMPOSTOS_FEDERAIS_PRODUTO → impostos_federais_produto | só de produtos migrados (segue a opção fora de linha); chave imposto + produto; `sq_impostos_federais_produto`. O "Imp fed duplicidade" do Pentaho é só um SELECT e não foi levado; **um imposto por tipo** (PIS, COFINS, IRPJ, CSLL, OUTROS) por produto — o VarejoFácil só aceita 1 de cada: com mais de um do mesmo tipo no SysPDV fica o de **menor código** (preferindo os que o item Impostos Federais migra); os descartados aparecem no cartão com o motivo; rodar de novo **apaga as duplicidades** já gravadas |
| `22_produto_auxiliar` | PRODUTOAUX → produtoaux | código com zeros até 14; com caractere não numérico = LITERAL, senão EAN (`proauxcodigoean` = 13 primeiros caracteres, como no Pentaho — corta o último dígito de um EAN-13: confirmar); fator 0/vazio = 1; `depois.sql` = "Limpeza nos EAN's" (apaga EAN igual ao código do produto, EAN inválido vira LITERAL, define tributado e principal) |
| `23_produto_fornecedor` | PRODUTO_FORNECEDOR → produto_fornecedor | referência numérica sem zeros à esquerda ("Limpa 0" aplicado antes de gravar); unidade/nível MAIÚSCULO, vazios = UN/P, quantidade vazia = 1; fornecedor achado por código **e** CNPJ/CPF só dígitos (no Pentaho o CNPJ com máscara nunca batia); `depois.sql` = Define Principal + Limpa 0 |
| `24_preco` | PRODUTO → preco | loja = PRPCOD; preços "estourados" zerados na leitura; desconto > 99 = 99,99; custo/margem/custos negativos = 0; venda variável vazia = 0; `sq_preco` |
| `20_inicio_produto` | (só SQL, automático, PRIMEIRO do grupo Produto) | `ALTER TABLE produto DISABLE TRIGGER ALL` antes da carga dos produtos (pedido do usuário). Religado nos Ajustes finais e, por garantia, no `finalizar.sql`, que roda **sempre no fim, mesmo se a migração parar com erro** — o DISABLE fica gravado na tabela e não pode ficar ligado por acidente |
| `25_tributacao_produto` (3 etapas) | PRODUTO.TRBID / TRIBUTACAO → situacao_fiscal, tabela_tributacao, item_tabela_tributacao | situação fiscal por tributação usada ("Tributado-T18"; código = maior + 1) e `stf_codigo` nos produtos; tabela de SAÍDA por situação fiscal para o regime e a UF da loja matriz (vigência 01/01/2016); itens com % tributado/outros/isento como no Pentaho, CST vazio = 60, CFOP vazio = 5102. No Pentaho a chave do item era `itt_id IS NULL` (duplicava a cada execução); aqui é tabela + tributação + classificação; item da tabela tributária procurado pela **chave única do VarejoFácil** (tabela, UF, classificação da pessoa): já cadastrado com outro código de tributação = passa ("sem alteração", sem sobrescrever); mesmo código = atualiza o que mudou |
| `26_familia` (2 etapas) | SIMILARES, ITEM_SIMILARES → familia_produto, produto_familia | família com descrição; produto na família pela `sq_produto_familia` |
| `27_compostos` (2 etapas) | COMPOSTO, COMPONENTE → composicao, componentes_composicao | produtos PROCOMP 'S'; componentes com preços vazios = 0; histórico (`hist_*`, ON CONFLICT DO NOTHING) |
| `28_kit` (2 etapas) | PRODUTO (PROCOMP 'K'), COMPONENTE → composicao, componentes_composicao | quantidade 1, baixa 'P', tipo S/N = PRECO/FATOR; o `comp_id` é mantido (no Pentaho era trocado a cada execução, deixando componentes sem composição) |
| `29_encarte` (3 etapas) | ENCARTE, ENCARTE_PRODUTO → encarte, encarte_produto, encarte_loja, programacao_preco | encartes A/P; tipo de preço 1/2/3 marca qual preço atualiza; produtos seguem a opção fora de linha (no Pentaho `proforlin = 'N'` fixo); programação de preço com NOT EXISTS (o NOT IN do Pentaho não criava nada se houvesse uma programação com `id_produto_encarte` vazio); programação de preço só de encartes **Abertos/Programados**, cruzando preço por produto **e loja**; programação com os **mesmos dados** (produto, loja, tipo, datas, situação) já existente = passa; algum dado diferente = inclui (vale para a inicial e a virada) |
| `30_cenario_fiscal_ncm` (4 etapas) | CLASSIFICACAO_TRIBUTARIA, NCM → classificacao_tributaria, cenario_fiscal_ncm (+ _ncm, _loja, _uf_destino) | um cenário por classificação usada nos NCMs do SysPDV; loja = matriz (no Pentaho era a constante 1); UF de destino = UF da matriz; NCMs do cenário: só NCM com classificação tributária **preenchida** (a em branco não é lida) e com CST, e **usado por produto migrado** (segue fora de linha e movimentação) |
| `31_cenario_fiscal_produto` (3 etapas) | PRODUTO com classificação diferente da do NCM → cenario_fiscal_produto (+ _produto, _loja, _uf_destino) | descrição da classificação do VarejoFacil; produto ligado pelo nível mais detalhado (seção, grupo ou subgrupo); segue a opção fora de linha; loja = matriz. Tem `origem.sqlserver.sql` (sem TRIM) |
| `39_ajustes_produto` | (só SQL, automático com o grupo Produto) | "Produto higieniza Loccod" + "Ajusta Produto" + "Corrigi produtos sem composição" + **Cadastro de operações** (24 operações padrão; só entra o código que ainda não existe — no Pentaho uma 2ª execução dava chave duplicada) + `ALTER TABLE produto ENABLE TRIGGER ALL` (gênero = 2 primeiros do NCM, datas, grupo/subgrupo inexistente = NULL, KG pesável, padrões de campos, NCM INCONSISTENTE). Sem a linha de `pesquisa_satisfacao` (sobra de outro cliente) e com `itt_icms_desonerado IS NULL` corrigido (no Pentaho era `= NULL`, que não fazia nada); depois de religar as triggers, **recarrega as tabelas de carga** (apaga `item_carga` de PRODUTO, PRECO e CODIGO_AUXILIAR e faz `UPDATE produto SET mix_id = NULL`, `produtoaux SET id_externo = NULL` e `preco SET id_externo = NULL` da loja matriz, para as triggers alimentarem ITEM_CARGA_PRODUTO, ITEM_CARGA_PRECO, ITEM_CARGA_PRODUTOAUX e PRODUTO_LOJA, que ficam vazias com as triggers desligadas) |
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
| `41_saldo_positivo` | ESTOQUE (**> 0**) → estoque_movimentacao | ajuste 9002, histórico MIGRACAO, local 1, loja do PROPRIO; um movimento MIGRACAO por produto + recálculo do `estoque_resumo` (com `ANALYZE` antes) |
| `42_saldo_negativo` | ESTOQUE (< 0) → estoque_movimentacao | idem |
| `42_saldo_zero` (2 etapas) | ESTOQUE (= 0) → estoque_movimentacao | **sem checkbox**: roda sozinho quando Saldo positivo ou negativo é marcado. 1) zera o saldo que a migração já tinha lançado para os produtos que hoje estão zerados no SysPDV (virada / rodar de novo; os demais ficam "pulados"); 2) **um INSERT só** com o movimento zerado de todos os produtos sem movimento na loja matriz / local 1 (script do usuário, com NOT EXISTS) |
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
Roda em toda migração.

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
