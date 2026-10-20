-- OPCIONAL. Sem ele, toda linha e inserida. As colunas devolvidas (fora o id) com o mesmo
-- nome de um campo do transformar.py sao comparadas: se mudou, roda o atualizar.sql.
SELECT id_tabela, descricao FROM tabela_varejofacil WHERE codigo = %(codigo)s
