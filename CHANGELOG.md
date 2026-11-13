# Histórico

Uma entrada por merge na `main`. A data é a do merge; o autor fica no histórico do Git.

## 2026-11-13 — migrador 2026.11.41
- Traz para o repositório tudo o que a skill instalada já tinha desde a 2026.10.31 (o repositório estava na 10.31): tela nova com menu lateral e servidor MCP (11.02/11.03), **Validação de Integridade** (Firebird/SQL Server, backup .GBK/.FBK, "Usar este banco na migração"), driver ODBC do SQL Server no `instalar.sh`, erros por tabela (`<etapa>_erros.csv`), "Não migrados" do Produto com o motivo, limpeza dos códigos auxiliares (EAN) após a troca de códigos, menu **Relatórios** (formulário de validação em Word e relatório padrão do kit), "se já existe, passa" pelas chaves únicas, opção "Só com movimentação desde [data]", saldo pela diferença, benefício fiscal do produto (`20_produto_beneficio_fiscal`), barra de progresso e correção no ajuste de códigos.
- `tools/empacotar_migrador.py`: passa a aceitar arquivos binários do app (guardados em `arquivos_base64` no JSON da skill), necessário para o modelo `.docx` do formulário de validação.
- Skill: `SKILL.md` (volta a existir com esse nome), referência do migrador e `pentaho_migradores_repositorio.md` atualizados; `scripts/recriar_migrador.py` recria também os binários.

## 2026-10-20 — migrador 2026.10.27
- Tempo de cada etapa (tabela) e tempo total da migração: coluna **Tempo** na tabela de progresso (com tempo corrente da etapa em andamento), resumo "Tempo por etapa" e "TEMPO TOTAL DA MIGRAÇÃO" no log, e `reports/<id>/tempos.csv`.
- Traz para o repositório as mudanças da 2026.10.26 que ainda não estavam aqui: seção **4. Consultar códigos** (ajuste de códigos ≥ 999999 de clientes e produtos) e validação da senha do PostgreSQL (inclusive com `pg_hba.conf` em `trust`).
- Skill: `SKILL.md` e referência do migrador atualizados para a 2026.10.27.

## 2026-10-20 — repositório criado
- Skill `migracao-dados-cm` e código do migrador passam a ser mantidos aqui (antes: upload manual de `.skill`).
- Migrador `2026.10.25`: tempo de cada tabela/etapa e tempo total da migração no log de execução.
