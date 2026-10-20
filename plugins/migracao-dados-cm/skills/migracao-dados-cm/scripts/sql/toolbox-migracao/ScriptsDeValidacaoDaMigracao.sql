-- QUANTIDADE DE PRODUTOS EM LINHA
SELECT COUNT(*) FROM produto WHERE proforlin = 'N' ;
-- QUANTIDADE DE PRODUTOS FORA DE LINHA
SELECT COUNT(*) FROM produto WHERE proforlin = 'S' ;
SELECT COUNT(*) FROM secao ;
SELECT COUNT(*) FROM grupo_produto ;
SELECT COUNT(*) FROM subgrupo_produto ;
-- PRODUTOS SEM PREÇO*
SELECT COUNT(*) FROM produto p WHERE procod NOT IN (SELECT procod FROM preco p2 WHERE prcvdavar != 0) ;
-- PRODUTOS COM PREÇO ZERO
SELECT COUNT(*) FROM preco WHERE prcvdavar = 0 ;
-- PRODUTOS DE BALANÇA
SELECT COUNT(*) FROM produto WHERE proenvbal = 'S' ;
-- PRODUTOS SEM UNIDADE DE MEDIDA**
SELECT COUNT(*) FROM produto WHERE prounid NOT IN (SELECT undcod FROM unidade) ;
-- PRODUTOS SEM CODIGO DE BARRAS
SELECT COUNT(*) FROM produto WHERE procod NOT IN (SELECT procod FROM produtoaux) ;
-- PRODUTOS SEM NCM***
SELECT COUNT(*) FROM produto WHERE proncm IS NULL OR proncm = '' ;
-- PRODUTOS SEM TRIBUTACAO****
SELECT COUNT(*) FROM produto WHERE stf_codigo IS NULL ;
-- QUANTIDADE DE FORNECEDORES
SELECT COUNT(*) FROM pessoa_fornecedor ;
-- QUANTIDADE DE CLIENTES
SELECT COUNT(*) FROM pessoa_cliente;
-- QUANTIDADE DE FUNCIONARIOS
SELECT COUNT(*) FROM pessoa_funcionario pf ;
-- PRODUTOS SEM PIS E COFINS
SELECT COUNT(*) FROM produto WHERE procod NOT IN (SELECT procod FROM impostos_federais_produto ifp) ;
-- TITULOS A RECEBER
SELECT COUNT(*) FROM conta_a_receber ;
-- TITULOS A PAGAR
SELECT COUNT(*) FROM conta_a_pagar ;

-- LISTAR SITUACAO FISCAO (TRIBUTACAO) MIGRADOS
SELECT stf_codigo || ' - ' || stf_descricao_reduzida
  FROM situacao_fiscal
 ORDER BY stf_codigo ;

-- LISTAR OS IMPOSTOS FEDERAIS MIGRADOS
SELECT impfedsim || ' - ' || impfeddes || ' - ' || impfedst || '/' || impfedstsai
  FROM impostos_federais if2
 ORDER BY impfedsim ;


-- LISTAR DOS PRODUTOS PRECO ZERO
SELECT p.procod AS "CÓDIGO PRODUTO"
     , p.prodes AS "DESCRIÇÃO PRODUTO"
  FROM produto p
  JOIN preco p2 ON p.procod = p2.procod
 WHERE p.procod NOT IN (SELECT procod FROM preco WHERE prcvdavar != 0)
 ORDER by 1;

-- LISTAGEM DOS PRODUTOS QUE O NCM ESTA INATIVO
SELECT procod AS "CÓDIGO PRODUTO"
     , prodes AS "DESCRIÇÃO"
     , proncm AS "NCM"
  FROM produto p
  JOIN ncm n ON p.proncm = n.ncm_codigo
 WHERE n.ncm_descricao = 'NCM INATIVO'
   AND ncm_ativo = FALSE
 ORDER BY 1 ;

#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
|                                                                                         POSSÍVEIS AJUSTES                                                                                          |
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#
| *    | Preço        | Produtos sem preço             | Inserir o preço zero para os produtos ao final da migração, não estiverem na tabela preço, para aquela loja                      | Script 1 |
| **   | Produto      | Produtos sem unidade de medida | Inserir uma unidade de medida padrão para estes casos, alinhar com o cliente ou revenda qual unidade deve ser                    | Script 2 |
| ***  | Ncm          | Produtos sem ncm               | Gerar listagem dos produtos Com NCM vazio e encaminhar para o cliente ou revenda, para que seja corrigido antes de subir o banco |          |
| **** | Produto      | Produtos sem tributação        | Gerar listagem e encaminhar para o cliente ou revenda para que seja corrigido antes de subir o banco                             |          |
|      | Produto Loja | Produto Loja Panamah           | Inserir os produtos na tabela produto_frente_loja                                                                                | Script 3 |
#----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------#


Script 1 - INSERE PREÇO LOJAS

INSERT INTO preco (lojcod, procod, prcvdavar, prcpreco1, prcdtultre, prcid)
     SELECT produto_loja.loj_codigo AS lojcod
          , produto_loja.procod
          , 0 AS prcvdavar
          , 0 AS prcpreco1
          , CURRENT_DATE AS prcdtultre
          , NEXTVAL('sq_preco') AS prcid
       FROM (SELECT p.procod
                  , l.loj_codigo
               FROM produto p
                  , pessoa_loja l
              ORDER BY 1) AS produto_loja
       LEFT JOIN preco pr ON (pr.procod = produto_loja.procod AND pr.lojcod = produto_loja.loj_codigo)
      WHERE pr.procod IS NULL 
        AND pr.lojcod IS NULL ;

Script 2 - AJUSTA UNIDADE DE MEDIDA VAZIA

UPDATE produto
   SET prounid = 'UN'
 WHERE prounid NOT IN (SELECT undcod FROM unidade) ;

Script 3 - INSERT PRODUTO_LOJA

INSERT INTO produto_loja (loj_codigo, procod, ret_codigo, stf_codigo, stf_codigo_saida)
     SELECT loj_codigo
          , procod
          , ret_codigo
          , stf_codigo
          , stf_codigo_saida
       FROM v_produto_loja v
      WHERE NOT EXISTS(SELECT * 
                        FROM produto_loja pl 
                       WHERE pl.loj_codigo = v.loj_codigo
                         AND pl.procod = v.procod) ;