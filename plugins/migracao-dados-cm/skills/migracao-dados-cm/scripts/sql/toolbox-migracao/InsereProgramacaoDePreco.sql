INSERT INTO public.programacao_preco (id, procod, lojcod, pprprctip, pprdatini, pprsta, pprdatfim, pprdatprg, pprprcprog, pprprcantvda, pprprcantofe, id_produto_encarte)
     SELECT NEXTVAL('sq_programacao_preco')
          , t1.procod
          , t3.loj_codigo
          , '1'
          , t3.encdatini
          , t3.encstatus
          , t3.encdatfim
          , NOW()
          , t1.prcvdavar
          , t2.encproprcofe_preco_1
          , 0.00
          , t2.id
       FROM preco t1
       JOIN encarte_produto t2 ON t1.procod = t2.procod
       JOIN encarte t3 ON t2.enccod = t3.enccod 
      WHERE t2.id_produto_encarte NOT IN (SELECT id_produto_encarte 
                                            FROM programacao_preco) ;