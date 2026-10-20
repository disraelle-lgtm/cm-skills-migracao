--INSERT PRODUTO LOJA

INSERT INTO produto_loja (loj_codigo, procod, ret_codigo, stf_codigo, stf_codigo_saida)
     SELECT loj_codigo
          , procod
          , ret_codigo
          , stf_codigo
          , stf_codigo_saida
       FROM v_produto_loja v
      WHERE NOT EXISTS(SELECT * 
                        FROM produto_loja pl 
                       WHERE pl.loj_codigo = v.loj_codigo
                         AND pl.procod = v.procod) ;