UPDATE cenario_fiscal_produto_produto
   SET seccod = %(seccod)s, secdes = %(secdes)s, grpcod = %(grpcod)s, grpdes = %(grpdes)s, sgpcod = %(sgpcod)s, sgpdes = %(sgpdes)s
 WHERE cfp_codigo = %(cfp_codigo)s AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
