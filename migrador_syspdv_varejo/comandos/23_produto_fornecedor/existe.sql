-- Pentaho: chave (procod, forcod, prfreffor); todos os campos com Update = N (so insere)
SELECT prfid FROM produto_fornecedor
 WHERE procod = %(procod)s AND forcod = %(forcod)s AND prfreffor = %(prfreffor)s
