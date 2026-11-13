-- Codigo zerado (00, 000, ...) nao e lido (REPLACE(...,'0','') <> '' vale para Firebird e SQL Server).
-- Pentaho: FB - FUNCIONARIO (as tres transformacoes leem a mesma tabela; so ativos)
SELECT FUNCOD, FUNDES, FUNAPE, FUNCPF, FUNACE, FUNCAR, FUNCOM, FUNCOM2, FUNCOM3
     , FUNTPRC, FUNLIMDCN, FUNINATIVO, FUNCOMMT
  FROM FUNCIONARIO
 WHERE FUNINATIVO = 'N'
   AND REPLACE(FUNCOD, '0', '') <> ''
 ORDER BY 1
