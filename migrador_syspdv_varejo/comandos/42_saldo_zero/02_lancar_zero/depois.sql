-- Script do usuario ("INSERT ESTOQUE ... ZERADO"): um INSERT so, com o movimento zerado de todos os produtos
-- que ainda nao tem movimento na loja matriz / local 1. Ajustes: loja 1 fixa -> loja matriz; NOT IN -> NOT EXISTS
-- (o NOT IN montava a lista de todos os movimentos para cada produto); os tipos de ajuste 9001/9002 ja sao
-- criados pelo 40_inicio_estoque; o SELECT COUNT(*) do script era so conferencia.
INSERT INTO estoque_movimentacao (mov_id, procod, loj_codigo, loc_codigo, mov_quantidade, mov_data, mov_data_registro,
                                  mov_tipo, eta_codigo, mov_historico, fun_codigo)
SELECT NEXTVAL('sq_movimentacao_estoque'), p.procod, m.loj_codigo, 1, 0.00, CURRENT_DATE, CURRENT_DATE,
       'AJUSTE', 9002, 'MIGRACAO', 1
  FROM produto p
 CROSS JOIN (SELECT loj_codigo FROM pessoa_loja WHERE loj_matriz = 'S' ORDER BY loj_codigo LIMIT 1) m
 WHERE NOT EXISTS (SELECT 1 FROM estoque_movimentacao em
                    WHERE em.procod = p.procod AND em.loj_codigo = m.loj_codigo AND em.loc_codigo = 1)
 ORDER BY p.procod;

-- Recalcula o estoque_resumo (loja matriz, local 1) com a soma da estoque_movimentacao.
-- LEFT JOIN: produto que ficou sem nenhum movimento (ex.: so tinha MIGRACAO e foi apagado) vai a 0;
-- sem ele, esse produto ficaria com o saldo antigo no resumo.
-- Desempenho: atualiza as estatisticas antes do recalculo. Logo depois de gravar milhares de movimentos
-- (na mesma transacao) o PostgreSQL ainda "acha" que as tabelas estao vazias e cruza linha por linha
-- (15 mil x 15 mil): o recalculo levava mais de 1 minuto; com ANALYZE leva menos de 1 segundo.
ANALYZE estoque_movimentacao;
ANALYZE estoque_resumo;

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
