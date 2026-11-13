-- Pentaho: pessoa_fornecedor com chave pes_codigo (achado pelo CNPJ/CPF); so for_codigo e atualizado.
SELECT pf.for_codigo
  FROM pessoa p
  JOIN pessoa_fornecedor pf ON (pf.pes_codigo = p.pes_codigo)
 WHERE p.pes_num_documento = %(pes_num_documento)s
 ORDER BY p.pes_codigo
 LIMIT 1
