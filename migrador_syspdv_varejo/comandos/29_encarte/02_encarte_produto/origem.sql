-- Filtro "(... OR :opcao_fora_de_linha = 1)": opcao "Incluir produtos fora de linha" do Produto.

-- Pentaho: FB - ENCARTE_PRODUTO. No Pentaho o filtro "proforlin = 'N'" era fixo; aqui segue a opcao.
SELECT ep.ENCCOD, ep.PROCOD, ep.ENCPROPRCOFE, ep.PROPRCOFE2, ep.PROPRCOFE3
  FROM ENCARTE_PRODUTO ep
 INNER JOIN PRODUTO p ON ep.PROCOD = p.PROCOD
 INNER JOIN ENCARTE e ON ep.ENCCOD = e.ENCCOD
 WHERE ep.ENCPROPRCOFE IS NOT NULL
   AND e.ENCSTATUS IN ('A', 'P')
   AND p.PRODES IS NOT NULL
   AND p.PROCOD <> '00000000000000'
   AND (COALESCE(p.PROFORLIN, 'N') = 'N' OR :opcao_fora_de_linha = 1)
 ORDER BY 1
