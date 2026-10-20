# Revisão por Segundo Analista (Peer Review) e Achados Comuns de Validação

> Fonte: documentos internos "Iniciativa: Analista revisor de migração de dados" e
> "Levantamento das validações realizadas" — sem dados de cliente.

## Proposta: Analista Revisor

Ao final de cada migração (Próprio ou Terceiros), um **segundo analista** (o
"Analista Revisor", diferente do "Analista de Migração" que executou) faz uma segunda
validação seguindo um roteiro, antes de a migração ser considerada entregável.
**Objetivo**: eliminar ajustes pós-entrega decorrentes de erros não percebidos pelo
próprio analista que migrou.

A validação do revisor cobre o projeto como um todo, não só a rotina do sistema:

1. **Movidesk** (ticket): checar a observação do formulário com o que foi de fato
   migrado; comparar o formulário (solicitado) com o banco de dados de destino, e
   verificar o que não foi migrado conforme solicitado — anexando prints quando for o
   caso de algo marcado no formulário/Pipefy que não existe na origem (ex.: revenda
   marcou migrar contas a pagar, mas a origem não tem essa informação). O analista da
   migração registra as correções indicadas pelo revisor no Movidesk e, por já ter a
   estrutura montada, normalmente é ele mesmo quem aplica as correções.
2. **Pentaho** (necessário só quando o migrador é novo/de terceiros): validar os
   steps — identificar se os principais dados do campo/tabela estão sendo enviados;
   montar scripts para identificar dados obrigatórios ausentes (ex.: preços com o
   campo de venda nulo); confirmar que as tabelas de origem correspondem ao que foi
   solicitado. Se algum dado foi inserido por fora do migrador (via script manual), um
   step explicativo de como o script foi montado facilita a revisão/manutenção
   futura. O migrador finalizado sobe para o Git antes da revisão, para o revisor
   poder baixar e conferir na própria máquina.
3. **Banco de dados**: scripts padrão comparando quantidades entre banco e rotina do
   VarejoFacil/SysPDV (ex.: quantidade de títulos, saldo de estoque, liquidação de
   títulos). As informações quantitativas de cadastros migrados (a mesma "de-para" já
   preenchida na planilha de validação pós-migração) ajudam o revisor a saber quantos
   registros existiam na origem e no destino sem precisar reprocessar tudo — conferir
   o total via rotina do sistema pode ser lento em bases grandes (>50.000 cadastros).

**Fluxo de status**: classificar no Movidesk que o atendimento está "em validação"
(tag/status), com responsável pela validação definido. **Tempo estimado de
validação**: ~1 turno (3–4h). Por já ter a estrutura montada, a correção de erros
encontrados na revisão normalmente cabe ao próprio Analista de Migração, não ao
revisor.

## Evolução do Documento de Validação — campo "Analista Revisor"

Versões mais recentes do Documento de Validação (V1, V2, V3 — todas eram apenas
gabaritos em branco, sem dados de cliente) adicionaram um campo **"Analista Revisor"**
ao lado de "Analista de Migração", formalizando a etapa de peer review acima. A V3
também reorganizou a seção "Dados Migrados" em colunas Sim/Não/Quantidade lado a lado
para duas listas de itens (cadastro padrão de um lado, produto/tributação do outro).

## Achados Comuns em Revisões (sem identificação de cliente)

Lista de divergências já observadas por revisores em migrações reais (útil como
checklist do que verificar):
- Quantidade de estoque divergente quando o cliente tem múltiplos locais de estoque.
- Produtos sem `NATUREZA` informado para PIS e COFINS.
- Produtos sem `LOCCOD` informado.
- Produtos sem `PROTIPIPI` informado.
- Produtos sem `PROINCZF` informado.
- Produtos sem `PROD_DIAS_SEGURANCA` informado.
- Produtos sem `PROITEEMBTRS` informado.
- Cadastros de clientes incompletos (endereço, bairro, CEP, IBGE etc.).
- Mapeamento de campo incorreto: já ocorreu de migrar para `CLI_COMP_TABELA_RAZO` o
  valor `000` quando o correto seria `PRZ` — sempre confirme o mapeamento de campos
  pouco comuns antes de assumir um valor padrão.
