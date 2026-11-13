UPDATE encarte_produto
   SET encproprcofe_preco_1 = %(encproprcofe_preco_1)s, encproprcofe_preco_2 = %(encproprcofe_preco_2)s,
       encproprcofe_preco_3 = %(encproprcofe_preco_3)s
 WHERE enccod = %(enccod)s AND procod = %(procod)s
