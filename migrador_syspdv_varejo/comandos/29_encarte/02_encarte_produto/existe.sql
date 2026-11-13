-- Pentaho: chave (enccod, procod); precos com Update = Y
SELECT encproprcofe_preco_1, encproprcofe_preco_2, encproprcofe_preco_3
  FROM encarte_produto WHERE enccod = %(enccod)s AND procod = %(procod)s
