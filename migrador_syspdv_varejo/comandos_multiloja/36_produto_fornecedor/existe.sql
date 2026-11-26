SELECT prfid FROM produto_fornecedor
 WHERE procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text) AND forcod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'fornecedor' AND codigo_origem = %(forcod)s::text) AND prfreffor = %(prfreffor)s
