SELECT 1 WHERE EXISTS (SELECT 1
  FROM pessoa_fornecedor f
  JOIN pessoa p ON (p.pes_codigo = f.pes_codigo)
 WHERE f.for_codigo = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'fornecedor' AND codigo_origem = %(for_codigo)s::text)
   AND p.pes_num_documento = %(forcgc)s)
   AND EXISTS (SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'fornecedor' AND codigo_origem = %(for_codigo)s::text)
