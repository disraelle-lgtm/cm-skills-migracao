-- SQL-SERVER – COMO LOCALIZAR/PROCURAR COLUNA PELO NOME EM TODAS AS TABELAS DO BANCO

SELECT t.name AS tabela
     , c.name AS coluna
  FROM sys.sysobjects AS t (nolock)
  JOIN sys.all_columns AS c (nolock) ON t.id = c.object_id AND t.xtype = 'U'
 WHERE c.name LIKE '%nomedocampo%'
 ORDER BY t.name asc ;