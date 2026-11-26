SELECT 1 WHERE EXISTS (SELECT 1 FROM conta_a_receber WHERE ctr_id = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'conta_receber' AND codigo_origem = %(ctr_id)s::text))
   AND EXISTS (SELECT 1 FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'conta_receber' AND codigo_origem = %(ctr_id)s::text)
