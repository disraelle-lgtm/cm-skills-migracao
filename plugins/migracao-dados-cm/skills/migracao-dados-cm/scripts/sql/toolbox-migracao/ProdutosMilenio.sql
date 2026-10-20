SELECT p.procod                           AS "Código"
     , p.prodes                           AS "Descrição"
     , CONCAT(s.secdes, ' - ', s.secdes)  AS "Seção"
     , CONCAT(g.grpcod, ' - ', g.grpdes)  AS "Grupo"
     , CONCAT(sg.sbgcod, ' -', sg.sbgdes) AS "SubGrupo"
     , a.agecgccpf                        AS "Fornecedor(CNPJ)"
     , est.esttot                         AS 'Contabiliza saldo em estoque'
     , r.refforlin                        AS  "Indisponível para venda"
     , CONCAT(m.marcod, ' - ', m.mardes)  AS "Marca"
     , p.proundvda                        AS "Unidade de venda"
     , CONCAT(t.trbid, ' - ', t.trbdes)   AS "Tributação"
     , t.trbtabb                          AS "CST ICMS"
     , t.trbalq                           AS "Alíquota de ICMS"
     , t.trbred                           AS "Alíquota de Redução do ICMS"
     , p.proipi                           AS "IPI"
     , p.promrg1                          AS "Margem/Markup Preço 1"
     , p.promrg2                          AS "Margem/Markup Preço 2"
     , p.promrg3                          AS "Margem/Markup Preço 3"
     , pr.prcvda1                         AS "Preço de Venda 1"
     , pr.prcvda2                         AS "Preço de Venda 2"
     , pr.prcvda3                         AS "Preço de Venda 3"
     , r.refncm                           AS "NCM"
     , im.imfcod_pis                      AS "Código Imposto PIS"
     , im.ifasittrbent_pis                AS "CST PIS Entrada"
     , im.ifaalqent_pis                   AS "ALQ PIS Entrada"
     , im.ifaredent_pis                   AS "ALQ Red PIS Entrada"
     , im.ifasittrbsai_pis                AS "CST PIS Saída"
     , im.ifaalqsai_pis                   AS "ALQ PIS Saída"
     , im.ifaredsai_pis                   AS "ALQ Red PIS Saída"
     , im.imfcod_cofins                   AS "Código Imposto COFINS"
     , im.ifasittrbent_cofins             AS "CST COFINS Entrada"
     , im.ifaalqent_cofins                AS "ALQ COFIN Entrada"
     , im.ifaredent_cofins                AS "ALQ Red COFINS Entrada"
     , im.ifasittrbsai_cofins             AS "CST COFINS Saída"
     , im.ifaalqsai_cofins                AS "ALQ COFINS Saída"x11
     , im.ifaredsai_cofins                AS "ALQ Red COFINS Saída"
     , im.imfcod_csll                     AS "Código Imposto CSLL"
     , im.ifasittrbent_csll               AS "CST CSLL Entrada"
     , im.ifaalqent_csll                  AS "ALQ CSLL Entrada"
     , im.ifaredent_csll                  AS "ALQ Red CSLL Entrada"
     , im.ifasittrbsai_csll               AS "CST CSLL Saída"
     , im.ifaalqsai_csll                  AS "ALQ CSLL Saída"
     , im.ifaredsai_csll                  AS "ALQ Red CSLL Saída"
     , im.imfcod_irrf                     AS "Código Imposto IRRJ"
     , im.ifasittrbent_irrf               AS "CST IRRF Entrada"
     , im.ifaalqent_irrf                  AS "ALQ IRRF Entrada"
     , im.ifaredent_irrf                  AS "ALQ Red IRRF Entrada"
     , im.ifasittrbsai_irrf               AS "CST IRRF Saída"
     , im.ifaalqsai_irrf                  AS "ALQ IRRF Saída"
     , im.ifaredsai_irrf                  AS "ALQ Red IRRF Saída"
     , p.propesbrtcmp                     AS "Peso bruto (kg)"
     , p.propesliqcmp                     AS "Peso líquido (kg)"
     , r.refdesrdz                        AS  "Descrição complementar"
     , p.proenvbal                        AS "Importado por balança"
     , p.proenvbal                        AS "Produto vendido por (balança)"
     , e.eancod                           AS "Código de barras"
     , CONCAT(cp.ctecod, ' - ', c.ctedes) AS "Características"
  FROM dbo.referencia r
  JOIN dbo.produto p ON r.procod = p.procod
  LEFT JOIN dbo.fornecedor f ON r.forcod = f.forcod
  LEFT JOIN dbo.agente a ON f.agecod = a.agecod
  JOIN secao s ON p.seccod = s.seccod
  LEFT JOIN grupo g ON (p.seccod = g.seccod AND p.grpcod = g.grpcod)
  LEFT JOIN subgrupo sg ON (p.seccod = sg.seccod AND p.grpcod = sg.grpcod AND p.sbgcod = sg.sbgcod)
  LEFT JOIN marca m ON p.marcod = m.marcod
  JOIN preco pr ON r.refplu = pr.refplu
  JOIN custo ct ON r.refplu = ct.refplu
  LEFT JOIN ean e ON r.refplu = e.refplu
  LEFT JOIN dbo.carac_pro cp ON p.procod = cp.procod
  LEFT JOIN dbo.caracteristica c ON cp.ctecod = c.ctecod
  JOIN dbo.estoque est ON r.refplu = est.refplu
  JOIN dbo.tributacao t ON p.trbid = t.trbid
  JOIN (SELECT pis.procod
     , pis.imfcod AS imfcod_pis
     , pis.ifasittrbent AS ifasittrbent_pis
     , pis.ifaalqent AS ifaalqent_pis
     , pis.ifaredent AS ifaredent_pis
     , pis.ifasittrbsai AS ifasittrbsai_pis
     , pis.ifaalqsai AS ifaalqsai_pis
     , pis.ifaredsai AS ifaredsai_pis
     , cofins.imfcod AS imfcod_cofins
     , cofins.ifasittrbent AS ifasittrbent_cofins
     , cofins.ifaalqent AS ifaalqent_cofins
     , cofins.ifaredent AS ifaredent_cofins
     , cofins.ifasittrbsai AS ifasittrbsai_cofins
     , cofins.ifaalqsai AS ifaalqsai_cofins
     , cofins.ifaredsai AS ifaredsai_cofins
     , csll.imfcod AS imfcod_csll
     , csll.ifasittrbent AS ifasittrbent_csll
     , csll.ifaalqent AS ifaalqent_csll
     , csll.ifaredent AS ifaredent_csll
     , csll.ifasittrbsai AS ifasittrbsai_csll
     , csll.ifaalqsai AS ifaalqsai_csll
     , csll.ifaredsai AS ifaredsai_csll
     , irrf.imfcod AS imfcod_irrf
     , irrf.ifasittrbent AS ifasittrbent_irrf
     , irrf.ifaalqent AS ifaalqent_irrf
     , irrf.ifaredent AS ifaredent_irrf
     , irrf.ifasittrbsai AS ifasittrbsai_irrf
     , irrf.ifaalqsai AS ifaalqsai_irrf
     , irrf.ifaredsai AS ifaredsai_irrf
  FROM (SELECT p.procod
             , f.imfcod
             , a.ifasittrbent
             , a.ifaalqent
             , a.ifaredent
             , a.ifasittrbsai
             , a.ifaalqsai
             , a.ifaredsai
          FROM imposto_federal f
          JOIN imposto_federal_aplicacao a ON f.imfcod = a.imfcod
          JOIN fat_pro imp ON f.imfcod = imp.imfcod
          JOIN produto p ON imp.procod = p.procod
         WHERE f.imfdes = 'PIS'
           AND a.ifaregfed = 'R') pis
  JOIN (SELECT p.procod
             , f.imfcod
             , a.ifasittrbent
             , a.ifaalqent
             , a.ifaredent
             , a.ifasittrbsai
             , a.ifaalqsai
             , a.ifaredsai
          FROM imposto_federal f
          JOIN imposto_federal_aplicacao a ON f.imfcod = a.imfcod
          JOIN fat_pro imp ON f.imfcod = imp.imfcod
          JOIN produto p ON imp.procod = p.procod
         WHERE f.imfdes = 'COFINS'
           AND a.ifaregfed = 'R') cofins ON pis.procod = cofins.procod
  LEFT JOIN (SELECT p.procod
                  , f.imfcod
                  , a.ifasittrbent
                  , a.ifaalqent
                  , a.ifaredent
                  , a.ifasittrbsai
                  , a.ifaalqsai
                  , a.ifaredsai
               FROM imposto_federal f
               JOIN imposto_federal_aplicacao a ON f.imfcod = a.imfcod
               JOIN fat_pro imp ON f.imfcod = imp.imfcod
               JOIN produto p ON imp.procod = p.procod
              WHERE f.imfdes = 'CSLL'
                AND a.ifaregfed = 'R') csll ON pis.procod = csll.procod
  LEFT JOIN (SELECT p.procod
                  , f.imfcod
                  , a.ifasittrbent
                  , a.ifaalqent
                  , a.ifaredent
                  , a.ifasittrbsai
                  , a.ifaalqsai
                  , a.ifaredsai
               FROM imposto_federal f
               JOIN imposto_federal_aplicacao a ON f.imfcod = a.imfcod
               JOIN fat_pro imp ON f.imfcod = imp.imfcod
               JOIN produto p ON imp.procod = p.procod
              WHERE f.imfdes = 'IRRF'
                AND a.ifaregfed = 'R') irrf ON pis.procod = irrf.procod) im ON im.procod = p.procod
 WHERE pr.lojcod = 1 
   AND ct.lojcod = 1
   AND est.lojcod = 1
   AND est.loccod = 1
 ORDER BY p.procod ;

/*
Obs 1: O script esta configurado para o regime R - Lucro Real. Caso o cliente seja de um regime direfente basta setar os campos ifaregfed para o valor desejado, conforme lista abaixo:

#----------------------#
| P - Lucro Presumido  |
| R - Lucro Real       |
| S - Simples Nacional |
#----------------------#

Obs2: O script está configurado para buscar os dados da loja 01. Caso o cliente necessite da informação nas demais lojas basta alterar o campo lojcod da loja para o desejado.

Obs3: O script está configurado para buscar os dados de estoque, para o local de estoque 01. Caso o cliente necessite da informação dos demais locais de estoque, basta alterar o campo loccod para o valor desejado.
*/
