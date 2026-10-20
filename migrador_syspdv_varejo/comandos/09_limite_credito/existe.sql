-- Pentaho: chave cli_codigo; o VALOR nao e atualizado (Update = N), so especie e situacao.
SELECT edc_codigo, lcr_situacao FROM limite_de_credito WHERE cli_codigo = %(cli_codigo)s LIMIT 1
