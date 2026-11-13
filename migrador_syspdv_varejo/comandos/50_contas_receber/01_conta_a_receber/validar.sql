-- Pentaho: Merge Join com pessoa_cliente pelo codigo do cliente
SELECT 1 FROM pessoa_cliente WHERE cli_codigo = %(cli_codigo)s
