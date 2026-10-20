-- INSERE LIMITE DE CREDITO ZERADO PARA CLIENTES SEM LIMITE DE CREDITO

INSERT INTO limite_de_credito (lcr_id, cli_codigo, edc_codigo, lcr_situacao, lcr_valor) 
     SELECT NEXTVAL('sq_limite_credito')
          , cli_codigo
          , 2
          , 'LIBERADO'
          , 0.00
       FROM pessoa_cliente
      WHERE cli_codigo NOT IN (SELECT cli_codigo
                                 FROM limite_de_credito) ;