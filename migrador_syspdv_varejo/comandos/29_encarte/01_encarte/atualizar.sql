UPDATE encarte
   SET encdes = %(encdes)s
     , encdatini = %(encdatini)s
     , encdatfim = %(encdatfim)s
     , encstatus = %(encstatus)s
     , enc_atualiza_preco_1 = %(enc_atualiza_preco_1)s
     , enc_atualiza_preco_2 = %(enc_atualiza_preco_2)s
     , enc_atualiza_preco_3 = %(enc_atualiza_preco_3)s
     , enc_produto_fora_linha = %(enc_produto_fora_linha)s
 WHERE enccod = %(enccod)s AND loj_codigo = %(loj_codigo)s
