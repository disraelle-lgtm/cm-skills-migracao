-- Pentaho: Insert/Update pela chave PROCOD = procod.
-- Grupo/subgrupo: quando o VarejoFacil nao tem o grupo, o "Ajusta Produto" deixa NULL; aqui o
-- valor do SysPDV e devolvido nesse caso para nao contar como "mudou" a cada rodada.
-- Datas que os ajustes poem como "hoje" nao entram na comparacao.
SELECT p.prodesrdz, p.prodes, p.seccod, p.trbid, p.prounid, p.propesvar, p.procomtip, p.procomcap, p.procompro, p.procomven, p.provld, p.profrtloj, p.proestmin, p.proestmax, p.proqtdetq, p.pronumser, p.proflgalt, p.protaba, p.probontip, p.probonfat, p.proctrest, p.proesp, p.procomp, p.proctrvld, p.proenvbal, p.funcod, p.prodesvar, p.proend, p.proiteemb, p.procstmed, p.proqtdmaxvda, p.propesbrt, p.propesliq, p.proforlin, p.proundcmp, p.loccod, p.proundref, p.promedref, p.protipipi, p.provlragr, p.protipagr, p.proprcvar, p.proiat, p.proippt, p.proncm, p.profin, p.pro_modelo, p.mar_codigo, p.proipi, p.proinczf, p.properpda, p.proncmexc, p.proiteembvda, p.procodanp, p.gencodigo, p.natcodigo, p.pro_compoe_total_nota_fiscal, p.procest, p.prod_bloqueado_compra, p.pro_permite_desconto, p.procodorigem, p.proiteembtrs, p.prod_dias_seguranca
     , COALESCE(p.grpcod, CASE WHEN (SELECT g.grpcod FROM grupo_produto g WHERE g.seccod = %(seccod)s AND g.grpcod = %(grpcod)s LIMIT 1) IS NULL THEN %(grpcod)s::int END) AS grpcod
     , COALESCE(p.sgpcod, CASE WHEN (SELECT s.sgpcod FROM subgrupo_produto s WHERE s.seccod = %(seccod)s AND s.grpcod = %(grpcod)s AND s.sgpcod = %(sgpcod)s LIMIT 1) IS NULL THEN %(sgpcod)s::int END) AS sgpcod
  FROM produto p
 WHERE p.procod = %(procod)s
