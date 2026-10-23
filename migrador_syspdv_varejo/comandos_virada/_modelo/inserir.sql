-- OBRIGATORIO. Os valores do transformar.py entram como  por cento + (nome_do_campo) + s,
-- igual ao exemplo abaixo. Para um sinal de por cento literal no SQL, escreva dois seguidos.
INSERT INTO tabela_varejofacil (id_tabela, codigo, descricao)
VALUES (nextval('sq_tabela_varejofacil'), %(codigo)s, %(descricao)s)
