-- Pentaho: "VF - Session Replication = replica" (desliga triggers durante a carga).
-- Vale so para a conexao do migrador: se algo falhar, a conexao fecha e volta ao normal.
SET session_replication_role = replica
