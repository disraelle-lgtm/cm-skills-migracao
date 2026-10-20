UPDATE pessoa_fornecedor
   SET for_codigo = %(for_codigo)s
 WHERE pes_codigo = (SELECT pes_codigo FROM pessoa
                      WHERE pes_num_documento = %(pes_num_documento)s
                      ORDER BY pes_codigo LIMIT 1)
