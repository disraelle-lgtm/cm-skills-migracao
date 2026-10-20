-- Pentaho: "Insert Programacao de Preco". No Pentaho era "id NOT IN (SELECT id_produto_encarte ...)":
-- se UMA programacao tivesse id_produto_encarte vazio, o NOT IN nao devolvia nada e nenhuma
-- programacao era criada. Aqui NOT EXISTS (mesmo resultado, sem essa armadilha).
INSERT INTO programacao_preco (id, procod, lojcod, pprprctip, pprdatini, pprsta, pprdatfim, pprdatprg,
                               pprprcprog, pprprcantvda, pprprcantofe, id_produto_encarte)
SELECT NEXTVAL('sq_programacao_preco'), t1.procod, t3.loj_codigo, '1', t3.encdatini, t3.encstatus,
       t3.encdatfim, NOW(), t1.prcvdavar, t2.encproprcofe_preco_1, 0.00, t2.id
  FROM preco t1
  JOIN encarte_produto t2 ON t1.procod = t2.procod
  JOIN encarte t3 ON t2.enccod = t3.enccod
 WHERE NOT EXISTS (SELECT 1 FROM programacao_preco pp WHERE pp.id_produto_encarte = t2.id)
