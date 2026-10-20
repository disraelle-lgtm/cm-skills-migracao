-- SCRIPT PARA OBTENCAO DAS INFORMACOES
SELECT p.prodes AS descricao
     , p.procod AS codigo_produto
     , p2.procodaux AS cod_barras
     , p.seccod AS secao
     , sc.secdes AS nome_secao
     , p.grpcod AS grupo
     , grp.grpdes AS nome_grupo
     , p.sgrcod AS subgrupo
     , sbgrp.sgrdes AS nome_subgrupo
     , p.prounid AS unidade_medida
     , p.proprcvdavar AS preco
     , p.proprcofevar AS preco_promocional
     , CASE
          WHEN p.proforlin = 'S' THEN 'N'
          WHEN p.proforlin = 'N' THEN 'S'
        END AS produto_habilitado
     , est.estatusdo AS estoque
  FROM produto p
  LEFT JOIN produtoaux p2 ON (p.procod = p2.procod)
  JOIN secao sc ON (p.seccod = sc.seccod)
  LEFT JOIN grupo grp ON (grp.seccod = p.seccod AND grp.grpcod = p.grpcod)
  LEFT JOIN subgrupo sbgrp ON (sbgrp.seccod = p.seccod AND sbgrp.grpcod = p.grpcod AND sbgrp.sgrcod = p.sgrcod)
  JOIN estoque est ON (est.procod = p.procod)
 ORDER BY 2 ;