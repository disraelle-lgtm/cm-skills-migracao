# Histórico

Uma entrada por merge na `main`. A data é a do merge; o autor fica no histórico do Git.

## 2026-10-20 — migrador 2026.10.27
- Tempo de cada etapa (tabela) e tempo total da migração: coluna **Tempo** na tabela de progresso (com tempo corrente da etapa em andamento), resumo "Tempo por etapa" e "TEMPO TOTAL DA MIGRAÇÃO" no log, e `reports/<id>/tempos.csv`.
- Traz para o repositório as mudanças da 2026.10.26 que ainda não estavam aqui: seção **4. Consultar códigos** (ajuste de códigos ≥ 999999 de clientes e produtos) e validação da senha do PostgreSQL (inclusive com `pg_hba.conf` em `trust`).
- Skill: `SKILL.md` e referência do migrador atualizados para a 2026.10.27.

## 2026-10-20 — repositório criado
- Skill `migracao-dados-cm` e código do migrador passam a ser mantidos aqui (antes: upload manual de `.skill`).
- Migrador `2026.10.25`: tempo de cada tabela/etapa e tempo total da migração no log de execução.
