INSERT INTO produto_fornecedor (prfid, procod, forcod, prfreffor, prfunid, prfqtd, prfnivel)
VALUES (nextval('sq_produto_fornecedor'), %(procod)s, %(forcod)s, %(prfreffor)s, %(prfunid)s, %(prfqtd)s, %(prfnivel)s)
