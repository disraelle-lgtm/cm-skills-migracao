UPDATE encarte_produto
   SET encproprcofe_preco_1 = %(encproprcofe_preco_1)s, encproprcofe_preco_2 = %(encproprcofe_preco_2)s,
       encproprcofe_preco_3 = %(encproprcofe_preco_3)s
 WHERE enccod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'encarte' AND codigo_origem = %(enccod)s::text) AND procod = (SELECT codigo_vf FROM migracao_multiloja.vinculo WHERE loj_codigo = {{loja_destino}} AND tipo = 'produto' AND codigo_origem = %(procod)s::text)
