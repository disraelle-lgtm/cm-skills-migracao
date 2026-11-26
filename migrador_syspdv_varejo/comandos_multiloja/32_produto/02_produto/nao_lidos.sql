-- Produtos do SysPDV que a selecao do Produto (origem.sql) deixa de fora, com o MOTIVO. A tela mostra esta lista
-- no cartao do Produto para explicar os "Nao migrados" que nem chegam a ser lidos (pedido do usuario: "tinha 100
-- produtos e migrou 90: os 10 foram por codigo zerado ou sem descricao"). SQL comum: Firebird e SQL Server.
SELECT p.PROCOD AS REGISTRO
     , p.PRODES AS DESCRICAO
     , CASE WHEN p.PROCOD = '00000000000000' THEN 'código zerado (00000000000000)'
            WHEN p.PRODES IS NULL THEN 'produto sem descrição'
            WHEN COALESCE(p.PROFORLIN, 'N') <> 'N' AND :opcao_fora_de_linha = 0
                 THEN 'fora de linha (a opção "Incluir produtos fora de linha" está desmarcada)'
            ELSE 'sem movimentação desde a data escolhida (venda, nota fiscal, movimento de estoque ou cadastro)'
       END AS MOTIVO
  FROM PRODUTO p
 WHERE REPLACE(p.PROCOD, '0', '') <> ''          -- codigo zerado nao e contado (nem aparece aqui)
   AND (p.PRODES IS NULL
        OR (COALESCE(p.PROFORLIN, 'N') <> 'N' AND :opcao_fora_de_linha = 0)
        OR (:opcao_movimentacao = 1 AND NOT /*MOVIMENTADO(p)*/))
 ORDER BY 1
