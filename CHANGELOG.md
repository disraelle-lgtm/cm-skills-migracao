# Histórico

Uma entrada por merge na `main`. A data é a do merge; o autor fica no histórico do Git.

## 2026-10-22 — migrador 2026.10.31 (v13 da skill)
- **Migração Virada**: seção 2 da tela com as abas **Migração Inicial** e **Migração Virada** (sempre desmarcadas). A virada usa os mesmos itens da inicial, mais os exclusivos de `comandos_virada/`, e faz o **de-para de códigos** de clientes e produtos pelas planilhas anexadas (`app/virada.py`). Registro novo ganha o próximo código vago e válido (nunca EAN; balança mantém); virada repetida não duplica.
- `comandos_virada/20_virada_codigos_produto`: EAN antigo dos produtos novos vira código de barras e a `alteracao_produto_sped` segue o padrão do kit, mantendo as datas de exportação das trocas anteriores (correção da 2026.10.30, que apagava a tabela).
- Tela sem a opção **Simular**: confirmação (aba, itens, banco e arquivos de códigos) antes de gravar. A simulação continua só pela API, para testes.
- Referência do Pentaho: achados do `Migrador_virada` (caminhos fixos de CSV, sequence acima de 999999, Insert SPED que perde datas, job de contas a receber desligado).
- Skill: `SKILL.md` e referência do migrador atualizados para a 2026.10.31; parágrafo "Fonte oficial" mantido.

## 2026-10-20 — migrador 2026.10.27
- Tempo de cada etapa (tabela) e tempo total da migração: coluna **Tempo** na tabela de progresso (com tempo corrente da etapa em andamento), resumo "Tempo por etapa" e "TEMPO TOTAL DA MIGRAÇÃO" no log, e `reports/<id>/tempos.csv`.
- Traz para o repositório as mudanças da 2026.10.26 que ainda não estavam aqui: seção **4. Consultar códigos** (ajuste de códigos ≥ 999999 de clientes e produtos) e validação da senha do PostgreSQL (inclusive com `pg_hba.conf` em `trust`).
- Skill: `SKILL.md` e referência do migrador atualizados para a 2026.10.27.

## 2026-10-20 — repositório criado
- Skill `migracao-dados-cm` e código do migrador passam a ser mantidos aqui (antes: upload manual de `.skill`).
- Migrador `2026.10.25`: tempo de cada tabela/etapa e tempo total da migração no log de execução.
