DO language plpgsql $$
DECLARE
   codigoAntigo pessoa_cliente.cli_codigo%TYPE;
   proximoCodigo pessoa_cliente.cli_codigo%TYPE;
BEGIN
   for codigoAntigo in SELECT cli_codigo FROM pessoa_cliente where cli_codigo  > 999999
   LOOP
           SELECT CASE
                     WHEN (SELECT MIN(p1.cli_codigo) FROM pessoa_cliente p1) > 1 THEN 1
                     WHEN (SELECT MIN(p1.cli_codigo) FROM pessoa_cliente p1) IS NULL THEN 1
                     ELSE (SELECT MIN(p1.cli_codigo + 1)
                             FROM pessoa_cliente p1
                             LEFT OUTER JOIN (SELECT cli_codigo - 1 AS codigo FROM pessoa_cliente) p2 ON p1.cli_codigo = p2.codigo
                            WHERE p2.codigo IS NULL)
                      END into proximoCodigo
                     FROM proprio ;

           UPDATE pessoa_cliente SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           UPDATE limite_de_credito SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           UPDATE conta_a_receber SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           UPDATE cobranca SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           --UPDATE codigos_internos SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           UPDATE transacao_liquidacao SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           UPDATE transacao_venda_prazo SET cli_codigo = proximoCodigo WHERE cli_codigo = codigoAntigo ;
           RAISE NOTICE '%', 'CODIGO ANTIGO: ' || codigoAntigo || ', CODIGO NOVO: ' || proximoCodigo ;
           
   END LOOP;
   
END;
$$