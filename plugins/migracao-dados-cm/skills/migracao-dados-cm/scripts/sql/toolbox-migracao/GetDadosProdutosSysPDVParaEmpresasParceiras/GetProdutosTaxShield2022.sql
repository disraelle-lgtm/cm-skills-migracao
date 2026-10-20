--PODE SER TROCADO O CAMPO "P.PROCSTMED" POR OUTRO DE SUA PREFERENCIA PARA MULTIPLICAR

SELECT p.procod AS produto
     , pf.prfreffor AS referencia_fornecedor
     , p.prodes AS descricao
     , sc.secdes AS secao
     , grp.grpdes AS grupo
     , f.fordes AS fornecedor
     , p.proprcvdavar AS preco
     , p.proprccst AS custo
     , p.procstmed AS custo_medio
     , e.estatusdo AS qtd_atual
     , (p.procstmed * e.estatusdo) AS valor_estoque
  FROM produto p
  LEFT JOIN produto_fornecedor pf ON (p.procod = pf.procod)
  LEFT JOIN fornecedor f ON (pf.forcod = f.forcod)
  LEFT JOIN secao sc ON (p.seccod = sc.seccod)
  LEFT JOIN grupo grp ON (sc.seccod = grp.seccod AND p.grpcod = grp.grpcod)
  LEFT JOIN estoque e ON (p.procod = e.procod)
 ORDER BY p.procod ;