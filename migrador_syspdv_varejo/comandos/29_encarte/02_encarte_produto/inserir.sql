INSERT INTO encarte_produto (id, enccod, procod, encproprcofe_preco_1, encproprcofe_preco_2, encproprcofe_preco_3)
VALUES (nextval('sq_encarte_produto'), %(enccod)s, %(procod)s, %(encproprcofe_preco_1)s, %(encproprcofe_preco_2)s, %(encproprcofe_preco_3)s)
