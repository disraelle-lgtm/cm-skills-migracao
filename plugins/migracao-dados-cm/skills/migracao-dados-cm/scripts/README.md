# Índice de Scripts — Migração CM

> Todos os scripts abaixo foram revisados e **não contêm** credenciais, IPs internos,
> nem dados reais de clientes. Dois arquivos do repositório original foram
> deliberadamente excluídos por conterem segredos reais (ver aviso no rodapé).

## `sql/toolbox-migracao/` — Caixa de ferramentas SQL real do time de Migração

Scripts operacionais reais (schema VarejoFacil/PostgreSQL e Milênio/SQL Server), úteis
como referência de nomenclatura de tabelas/campos e de padrões de script já validados
pelo time. Alguns destaques por categoria:

| Categoria | Scripts |
|---|---|
| Ajuste de código (produto/cliente) | `AjustaCodigoCliente.sql`, `AlteraCodigoProdutoSemPassarCodigoAntigo.sql`, `AlteraCodigoUnicoProduto.sql`, `DescobreProximoCodigoValido.sql` |
| Limpeza / EAN | `Limpa_EAN.sql`, `InsereProdutoAuxiliar.sql` |
| Exclusão de produtos | `ExcluiProdutosComMovimentacao.sql`, `ExcluiProdutosSemMovimentacao.sql`, `DeletarInconsistencias.sql`, `DeleteVarejofacil.sql`, `DeletePanama.sql` |
| Preço / custo | `InserePrecoParaProdutosSemPreco.sql`, `SetarPrecoZeroParaOsProdutosQueNaoEstaoNaTabelaPreco.sql`, `ReplicaPreco.sql`, `ReplicaCusto.sql`, `InsereProgramacaoDePreco.sql` |
| Estoque / inventário | `InsertEstoqueMovimentacao.sql`, `ReabreInventarioDesfazendoAlteracoes.sql`, `ReabreInventarioSemDesfazerAlteracoes.sql` |
| Financeiro | `InsertLancamentosFinanceirosTitulos.sql`, `ReplicaContasAPagarNoMesmoLink.sql`, `MigraContasReceber.sql`, `ListaTitulosComSaldoNegativo.sql`, `InsereLimiteDeCreditoZeroParaClientesSemLimiteDeCredito.sql` |
| Impostos / fiscal | `InsereImpostosFederaisEImpostosFederaisProdutos.sql`, `fn_cnpj_cpf.sql` (função de validação de CNPJ/CPF) |
| Sincronização (fila Panama) | `InsertPanama.sql`, `InsertFilaPanama.sql` (em `sql/`), `DeletePanama.sql` |
| Milênio | `ClientesMilenio.sql`, `ProdutosMilenio.sql`, `ExtracaoCadastrosMilenio.sql`, `SelecionaProdutosMilenioPorDataDeMovimentacao.sql` (produtos com movimentação de estoque a partir de uma data, para migração parcial) |
| SysPDV | `ColetaProdutoESaldoEstoqueSysPDV.sql`, `BackupSysPDVSQLServer.sql` |
| Cadastro / operações padrão | `InsereOperacoesPadroes.sql`, `InsereProdutoLoja.sql`, `InsertPessoaFuncionarioLoja.sql`, `InsertUsuario.sql` |
| Utilitários gerais | `LozalizadorDeColunaPeloNomeEmTodasAsTabelasNoSQL.sql` (localiza uma coluna pelo nome em todas as tabelas do schema), `DesabilitandoTriggersDaTabelaProduto.sql`, `ComandosParaVerProcessoNoStage.sql` |
| Validação | `ScriptsDeValidacaoDaMigracao.sql`, `ScriptsBaseModeloGrandCru.sql` |
| Integrações com parceiros | `GetDadosProdutosSysPDVParaEmpresasParceiras/` (Mercafácil, TaxShield — exportação de dados de produto/movimentação para integrações comerciais) |
| Reprocessamento | `ReprocessamentoDeVendas.sql`, `ReplicacaoSoftTecnologia.sql` |
| Exemplos / documentação embutida | `ExemploIntegracaoPrevenda.sql`, `InstalarDorcker.sql` (guia de instalação de ambiente Docker local) |
| Senha (uso local/teste apenas) | `AlteracaoSenhaFuncionarioVarejofacil.sql` — reseta senha via hash md5 para ambiente local/homologação; nunca usar valor literal de senha real de produção |

## `sql/movimentacao-entre-lojas-vf/` — Migração entre lojas no mesmo link VarejoFacil

Scripts reais usados quando se migra saldo/movimentação de uma loja para outra dentro
do **mesmo link VarejoFacil** (loja de origem e destino são parametrizadas no início de
cada script — sempre ajustar os códigos de loja antes de executar):
`MigraContasPagar-varejofacil.sql`, `MigraContasReceber-varejofacil.sql`,
`MigrarEstoque_varejofacil.sql`, `MigrarPreco_varejofacil.sql`.

## `sql/InsertFilaPanama.sql`

Script de exemplo que popula a fila de sincronização ("Panama") após uma migração,
cobrindo as entidades: forma de pagamento, holding, loja, funcionário, acesso, cliente,
seção, grupo, subgrupo, produto, EAN, título a pagar e título a receber.

## `ferramentas/migrador-cli.sh`

CLI interno (bash) usado pelo time de Migração no dia a dia: menu com opções para abrir
Jupyter, autenticar/acessar AWS (SSO, perfis `vfprod` e `sustentacao-sdv-cmadmin`),
iniciar o Pentaho (Spoon), operações PostgreSQL (criar banco, restaurar, backup),
preparar ambiente de cliente (SysPDV/Firebird ou VarejoFacil/Postgres) e backup do
sistema local. Referência de fluxo operacional — os identificadores de perfil AWS e de
instância que aparecem no script são identificadores internos, não segredos, mas ainda
assim específicos da infraestrutura da CM.

## `ferramentas/migrador-cli.sh` e `ferramentas/migrador-cli-v2.sh`

Duas versões do CLI interno (bash) usado pelo time de Migração no dia a dia. A v1 tem
menu com opções para abrir Jupyter, autenticar/acessar AWS (SSO, perfis `vfprod` e
`sustentacao-sdv-cmadmin`), iniciar o Pentaho (Spoon), operações PostgreSQL (criar
banco, restaurar, backup), preparar ambiente de cliente (SysPDV/Firebird ou
VarejoFacil/Postgres) e backup do sistema local. A v2 (variante mais antiga/alternativa)
adiciona: conexão a diferentes Stages (versão antiga vs nova do Postgres), reparo de
banco Firebird via `gbak` (backup + restore), atualização automática do VarejoFacil via
`versoes.varejofacil.com`, e start/stop do VarejoFacil via Docker. Referência de fluxo
operacional — os identificadores de perfil AWS e de instância que aparecem nos scripts
são identificadores internos, não segredos, mas ainda assim específicos da
infraestrutura da CM.

## `references/manual_migracao_2022.pdf` e `references/dicionario_dados_syspdv.pdf`

Documentos oficiais mantidos como PDF (não transcritos para markdown, por serem longos
e estruturados): o manual dos "8 passos" voltado a cliente/revenda, e o dicionário de
dados completo do SysPDV (centenas de tabelas). Leia-os diretamente quando a pergunta
exigir o texto completo ou a definição exata de uma tabela/campo do SysPDV.

## Arquivos deliberadamente excluídos (segurança)

Dois arquivos do repositório de origem **não foram incluídos** por conterem segredos
reais em texto puro:
- `ConfigurandoAcessoAoStage.sql` — continha uma AWS Access Key ID e Secret Access Key
  reais e ativas, além de senha de console. **Se esse arquivo ainda existir em algum
  repositório Git, a chave deve ser revogada/rotacionada imediatamente na AWS.**
- `AlteracaoSenhaFuncionarioMilenio.sql` — continha uma senha real em texto puro usada
  para reset de acesso administrativo do Milênio.

Da mesma forma, a pasta `.kettle/` do repositório de migradores Pentaho (que contém
`kettle.properties`, `db.cache-*`, `repositories.xml`, `shared.xml`) **nunca** deve ser
copiada para fora do ambiente de trabalho — ela guarda credenciais reais de banco de
dados e IPs internos dos servidores de migração. Essa mesma pasta apareceu novamente
em um segundo envio de arquivos soltos (`kettle.properties` e `shared.xml` na raiz do
zip) e foi excluída pelo mesmo motivo.

Também não foram incluídos, por não serem material de referência utilizável em texto/
scripts (e por precaução de segurança): um executável Windows (`dbMonitor.exe`), uma
imagem de fundo de tela, e um arquivo `.7z` que continha o **histórico completo do Git**
do repositório de migração (`.git/objects`, `.git/refs`) — ver aviso no `SKILL.md`
sobre a implicação disso para a credencial AWS relatada anteriormente.

Em um terceiro envio (`Layouts.zip` + `Base_Modelo.zip`):
- Os arquivos `Modelos de entrada .../*.csv` do `Layouts.zip` **não foram incluídos**
  por conterem dados reais de clientes (razão social, CNPJ/CPF, endereço, telefone,
  e-mail) usados como exemplo de preenchimento — não são dados anonimizados/fictícios.
  Foi incluído apenas o layout de campos (sem os exemplos de linha) equivalente, já
  presente em `layout_migrador_pdi_*.csv`.
- Os arquivos do `Base_Modelo.zip` (`.backup` do Postgres/VarejoFacil e `.fdb` do
  Firebird/SysPDV — bases "zeradas" usadas como modelo/template para montar ambiente
  de cliente) **não foram incluídos**: são dumps binários de banco de dados (~87 MB no
  total), não material de referência em texto, e não é algo que a skill (ou o Claude)
  consiga interpretar ou restaurar de forma útil. Esse tipo de arquivo pertence à
  infraestrutura própria do time (S3, repositório com Git LFS, etc.), não a uma skill.

Em um quarto envio, a exclusão mais crítica até agora:
- **`E-CNPJ - Casa Magalhães - ....pfx`** — um **certificado digital (e-CNPJ)** real da
  empresa. Um `.pfx` contém a chave privada do certificado; ele nunca foi aberto/lido
  por esta skill e **não foi incluído em nenhuma circunstância**.
- **`Anotações Saulo.sql`** e **`DiaDia_Saulo.sql`** — arquivos de notas pessoais que
  continham, em texto puro: usuário/senha de acesso a um banco de sustentação via
  DBeaver, a **senha do certificado digital** (`Senha Certificado` /
  `Senha Certificado envio NFE`), um Token/CSC de NFC-e, uma chave de API ativa
  (`x-api-key`) para `api.panamah.io`, uma senha de PostgreSQL de produção junto com o
  IP do servidor, e CNPJs reais. **Nenhum desses dois arquivos foi incluído.**
- Dois executáveis (`VerificaIndice.exe`, `PopulaPisCofins(SQL)_V1.7.exe`) e dois `.jar`
  de driver JDBC (`jt400`, `jcc`) — binários, sem valor como referência em texto.
- `kettle-scripts.zip` (repositório completo de migradores, >10.000 arquivos) — só o
  catálogo de nomes de pastas foi incorporado (ver `pentaho_migradores_repositorio.md`);
  o conteúdo de arquivo individual não foi copiado em massa, por ser inviável conferir
  cada um contra segredos embutidos.
- `DicionarioSysPDV_ATUALIZADO...pdf/docx` — conteúdo idêntico ao dicionário já
  presente na skill; não duplicado.

> ⚠️ **Ação recomendada, com urgência**: a senha do certificado digital e o próprio
> arquivo `.pfx` passaram pelo mesmo envio. Trate isso como uma exposição do
> certificado — verifique com quem administra os certificados digitais da Casa
> Magalhães se é necessário revogar/reemitir junto à Autoridade Certificadora, e nunca
> mantenha a senha do certificado em arquivo de texto. Da mesma forma, a chave de API
> do Panamah e a senha do usuário de sustentação (DBeaver) encontradas em
> `Anotações Saulo.sql` devem ser rotacionadas.

Em um quinto envio (`data-integration.zip`, `Arquivos_antigos.zip`, formulário
"respostas", e um reenvio de "Scripts e arquivos soltos"):
- `data-integration-...zip` (461 MB) — é apenas o instalador do Pentaho Data
  Integration em si (ferramenta de terceiros, código aberto), sem nenhum conteúdo
  específico da CM. Não incluído (não é conhecimento de processo, é o software).
- Toda a árvore `Arquivos antigos/Projetos/Grand Cru/` — projeto de um **cliente real**
  (múltiplas lojas, cada uma com CNPJ real listado em `Migrações Grand Cru.xlsx`),
  incluindo dois arquivos `.backup` reais desse cliente. **Não incluído** — específico
  de um cliente, não é material genérico reutilizável.
- `PLANILHA_RETORNO_CONTAB_MIGRACAO.xlsx` — catálogo de produtos real de um cliente
  específico (28 mil linhas). **Não incluído** — dado de negócio de cliente, não é
  template genérico.
- `arquivos-kettle-...zip` (dentro do reenvio de "Scripts e arquivos soltos") — mesmo
  par `kettle.properties` + `shared.xml` com credenciais reais já visto antes.
  **Excluído** pelo mesmo motivo.
- O restante de "Documentos_Migração_-_Scripts_e_arquivos_soltos.zip" é uma repetição
  do primeiro envio já incorporado — não duplicado.
- Já incorporados como novidade: os documentos genéricos "Iniciativa: Analista
  revisor", "Levantamento das validações de revisão", as versões V1–V3 do Documento de
  Validação (mostrando a evolução do campo "Analista Revisor"), a tabela padrão de
  tributação CST/CSOSN/Simbologia, o modelo de tributação de produto composto, e os
  campos adicionais do formulário Google Forms (extraídos só do cabeçalho, sem
  respostas reais).


## Migrador Python

- `recriar_migrador.py` — recria a pasta do migrador Python (`migrador_syspdv_varejo`) a partir de `assets/migrador_syspdv_varejo.json`: `python3 scripts/recriar_migrador.py /tmp`. Ver `references/migrador_python_syspdv_varejo.md`.
