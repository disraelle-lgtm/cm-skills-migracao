-- Pentaho: Merge Join do FORCGC com o documento da pessoa do fornecedor (convertido em numero - um
-- CNPJ com mascara dava erro). Aqui: codigo do fornecedor E documento so com digitos.
SELECT 1
  FROM pessoa_fornecedor f
  JOIN pessoa p ON (p.pes_codigo = f.pes_codigo)
 WHERE f.for_codigo = %(for_codigo)s
   AND p.pes_num_documento = %(forcgc)s
