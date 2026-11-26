-- Antes de criar a pessoa da loja: o codigo {{loja_destino}} nao pode ser de OUTRA loja (outro CNPJ) e este CNPJ nao
-- pode ja ser uma loja com OUTRO codigo (a mesma checagem da etapa Pessoa Loja, antes de gravar qualquer coisa).
SELECT 1
 WHERE NOT EXISTS (SELECT 1 FROM pessoa_loja l JOIN pessoa q ON q.pes_codigo = l.pes_codigo
                    WHERE l.loj_codigo = {{loja_destino}} AND q.pes_num_documento IS DISTINCT FROM %(pes_num_documento)s::varchar)
   AND NOT EXISTS (SELECT 1 FROM pessoa_loja l JOIN pessoa q ON q.pes_codigo = l.pes_codigo
                    WHERE q.pes_num_documento = %(pes_num_documento)s::varchar AND l.loj_codigo <> {{loja_destino}})
