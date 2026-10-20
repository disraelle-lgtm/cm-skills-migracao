INSERT INTO usuario (funcod, usunom, ususen, administrador, ativo, ultima_alteracao_senha)
     SELECT pf.fun_codigo
          , p.pes_nome
          , md5('admin')
          , FALSE
          , TRUE
          , NOW()
      FROM pessoa_funcionario pf
      JOIN pessoa p on pf.pes_codigo = p.pes_codigo 
     WHERE pf.fun_codigo NOT IN (SELECT u.funcod 
                                   FROM usuario u) ;