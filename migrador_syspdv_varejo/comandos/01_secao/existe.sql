-- DESTINO: procura a secao no VarejoFacil.
-- As colunas devolvidas (fora o id) sao comparadas com o transformar.py:
-- se alguma mudou, roda o atualizar.sql.
SELECT secid, secdes, sec_situacao_sped
  FROM secao
 WHERE seccod = %(seccod)s
