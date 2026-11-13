-- Pentaho: Merge Join do FORCOD com pessoa_fornecedor.for_codigo e do FORCGC com
-- pessoa.pes_num_documento. No Pentaho o FORCGC era comparado COM a mascara do SysPDV
-- (ex.: 11.111.111/0001-11) contra o documento gravado so com digitos - com mascara nada
-- batia e o produto ficava sem fornecedor. Aqui os dois lados sao so digitos.
SELECT 1
  FROM pessoa_fornecedor f
  JOIN pessoa p ON (p.pes_codigo = f.pes_codigo)
 WHERE f.for_codigo = %(forcod)s
   AND p.pes_num_documento = %(forcgc)s
