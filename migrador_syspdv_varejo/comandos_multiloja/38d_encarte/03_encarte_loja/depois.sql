INSERT INTO programacao_preco (id, procod, lojcod, pprprctip, pprdatini, pprsta, pprdatfim, pprdatprg,
                               pprprcprog, pprprcantvda, pprprcantofe, id_produto_encarte)
SELECT NEXTVAL('sq_programacao_preco'), x.procod, x.lojcod, '1', x.encdatini, x.encstatus, x.encdatfim, NOW(),
       x.prcvdavar, x.encproprcofe_preco_1, 0.00, x.id_produto_encarte
  FROM (SELECT DISTINCT ON (t1.procod, t3.loj_codigo, t3.encdatini, t3.encdatfim, t3.encstatus)
               t1.procod, t3.loj_codigo AS lojcod, t3.encdatini, t3.encstatus, t3.encdatfim,
               t1.prcvdavar, t2.encproprcofe_preco_1, t2.id AS id_produto_encarte
          FROM encarte t3
          JOIN encarte_produto t2 ON t2.enccod = t3.enccod
          JOIN preco t1 ON t1.procod = t2.procod AND t1.lojcod = t3.loj_codigo
         WHERE t3.encstatus IN ('A', 'P')
           AND NOT EXISTS (SELECT 1 FROM programacao_preco pp WHERE pp.id_produto_encarte = t2.id)
           AND NOT EXISTS (SELECT 1 FROM programacao_preco pp
                            WHERE pp.procod = t1.procod AND pp.lojcod = t3.loj_codigo AND pp.pprprctip = '1'
                              AND pp.pprdatini = t3.encdatini AND pp.pprdatfim = t3.encdatfim
                              AND pp.pprsta = t3.encstatus)
         ORDER BY t1.procod, t3.loj_codigo, t3.encdatini, t3.encdatfim, t3.encstatus, t2.id) x
