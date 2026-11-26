UPDATE encarte
   SET encdes = %(encdes)s
     , encdatini = %(encdatini)s
     , encdatfim = %(encdatfim)s
     , encstatus = %(encstatus)s
     , enc_atualiza_preco_1 = %(enc_atualiza_preco_1)s
     , enc_atualiza_preco_2 = %(enc_atualiza_preco_2)s
     , enc_atualiza_preco_3 = %(enc_atualiza_preco_3)s
     , enc_produto_fora_linha = %(enc_produto_fora_linha)s
 WHERE enccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'encarte' AND codigo_origem = %(enccod)s::text) AND loj_codigo = {{loja_destino}}
