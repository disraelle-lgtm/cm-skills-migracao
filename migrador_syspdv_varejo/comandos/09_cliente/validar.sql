-- O VarejoFacil aceita UM cliente por pessoa (gatilho pessoa_cliente_trigger: "clientes {a,b} com o mesmo codigo de
-- pessoa"). O SysPDV pode ter clientes DIFERENTES com o mesmo CPF/CNPJ: o primeiro e migrado; os outros ficam como
-- "pulado" (validar_pula) em vez de erro. Sem documento: passa (nao ha como repetir).
SELECT 1
 WHERE NULLIF(%(pes_num_documento)s::varchar, '') IS NULL
    OR NOT EXISTS (SELECT 1 FROM pessoa_cliente pc JOIN pessoa p ON p.pes_codigo = pc.pes_codigo
                    WHERE p.pes_num_documento = %(pes_num_documento)s::varchar AND pc.cli_codigo <> %(cli_codigo)s)
