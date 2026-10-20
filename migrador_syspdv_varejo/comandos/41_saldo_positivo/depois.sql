-- Recalcula o estoque_resumo (loja matriz, local 1) com a soma da estoque_movimentacao.
-- LEFT JOIN: produto que ficou sem nenhum movimento (ex.: so tinha MIGRACAO e foi apagado) vai a 0;
-- sem ele, esse produto ficaria com o saldo antigo no resumo.
UPDATE estoque_resumo er
   SET res_saldo = COALESCE(mv.saldo, 0)
  FROM estoque_resumo base
  LEFT JOIN (SELECT em.procod, SUM(em.mov_quantidade) AS saldo
               FROM estoque_movimentacao em
              WHERE em.loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
                AND em.loc_codigo = 1
              GROUP BY em.procod) mv ON mv.procod = base.procod
 WHERE base.procod = er.procod AND base.loj_codigo = er.loj_codigo AND base.loc_codigo = er.loc_codigo
   AND er.loj_codigo = (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1)
   AND er.loc_codigo = 1
   AND er.res_saldo IS DISTINCT FROM COALESCE(mv.saldo, 0)
