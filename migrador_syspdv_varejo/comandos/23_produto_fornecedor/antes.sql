-- Pentaho: o JOB-Produto_inicial roda com "Session Replication = replica" (triggers desligadas).
-- Vale so para a conexao do migrador: se algo falhar, a conexao fecha e volta ao normal.
SET session_replication_role = replica
