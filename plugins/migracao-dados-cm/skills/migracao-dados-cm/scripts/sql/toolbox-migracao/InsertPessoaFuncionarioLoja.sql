-- INSERT PESSOA_FUNCIONARIO_LOJA QUANDO O FUNCIONARIO EXISTIR 

INSERT INTO pessoa_funcionario_loja (pfl_id, fun_codigo, loj_codigo, pfl_ativo, pfl_principal)
     SELECT NEXTVAL('sq_pessoa_funcionario_loja')
          , fun_codigo
          , 1
          , 'S'
          , false
       FROM pessoa_funcionario
      WHERE fun_codigo NOT IN (SELECT fun_codigo 
                                 FROM pessoa_funcionario_loja
                                WHERE loj_codigo = 1 );