-- A loja so pode ser gravada se: a pessoa da loja (CNPJ) existe; o codigo {{loja_destino}} nao e de OUTRA loja (outro CNPJ);
-- e este CNPJ nao e uma loja com OUTRO codigo. Protege a matriz e as demais lojas de serem sobrescritas.
SELECT 1
  FROM pessoa p
 WHERE p.pes_num_documento = %(pes_num_documento)s
   AND NOT EXISTS (SELECT 1 FROM pessoa_loja l JOIN pessoa q ON q.pes_codigo = l.pes_codigo
                    WHERE l.loj_codigo = {{loja_destino}} AND q.pes_num_documento IS DISTINCT FROM %(pes_num_documento)s)
   AND NOT EXISTS (SELECT 1 FROM pessoa_loja l WHERE l.pes_codigo = p.pes_codigo AND l.loj_codigo <> {{loja_destino}})
 LIMIT 1
