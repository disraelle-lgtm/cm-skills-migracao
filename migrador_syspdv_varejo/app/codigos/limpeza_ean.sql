-- Limpeza dos codigos auxiliares DEPOIS da troca de codigos dos produtos (script do usuario).
-- Roda na mesma transacao do ajuste (erro = nada gravado). Cada comando e separado por "-- PASSO: <descricao>":
-- o migrador executa um por um e mostra no log quantos registros cada passo alterou.
-- Ajuste em relacao ao script original: o CAST(procodaux AS BIGINT) so converte codigos numericos (um LITERAL
-- com letras, ex.: ABC-123, dava erro e desfazia a troca inteira).

-- PASSO: código auxiliar igual ao código do produto (apagado)
DELETE
  FROM produtoaux
 WHERE (CASE WHEN procodaux ~ '^[0-9]{1,18}$' THEN CAST(procodaux AS BIGINT) END) IN (SELECT procod FROM produto)
   AND proauxtipo = 'EAN';

-- PASSO: EAN inválido virou LITERAL (validar_ean)
UPDATE produtoaux
   SET proauxtipo = 'LITERAL'
     , proauxcodigoean = NULL
     , proeantrib = FALSE
 WHERE validar_ean(procodaux) = FALSE;

-- PASSO: EAN inválido virou LITERAL (validar_gs1)
UPDATE produtoaux
   SET proauxtipo = 'LITERAL'
     , proauxcodigoean = NULL
     , proeantrib = FALSE
 WHERE validar_gs1(procodaux) = FALSE;

-- PASSO: EAN definido como tributado (produto sem nenhum tributado)
UPDATE produtoaux
   SET proeantrib = TRUE
 WHERE procodaux IN (SELECT DISTINCT ON (procod) procodaux
                       FROM produtoaux
                      WHERE proauxtipo = 'EAN'
                        AND procod NOT IN (SELECT DISTINCT procod
                                             FROM produtoaux
                                            WHERE proauxtipo = 'EAN'
                                              AND proeantrib IS TRUE)
                      ORDER BY procod
                          , proauxfat
                          , procodaux);

-- PASSO: EAN tributado definido como principal
UPDATE produtoaux
   SET proeanprinc = TRUE
 WHERE proeantrib = TRUE;

-- PASSO: EAN definido como principal (produto sem tributado)
UPDATE produtoaux
   SET proeanprinc = TRUE
 WHERE proauxtipo = 'EAN'
   AND procodaux IN (SELECT DISTINCT ON (procod) procodaux
                       FROM produtoaux t1
                      WHERE t1.procod NOT IN (SELECT DISTINCT t1.procod
                                                FROM produto t1 JOIN produtoaux t2 ON t2.procod = t1.procod
                                               WHERE proauxtipo = 'EAN'
                                                 AND proeantrib = TRUE));

-- PASSO: principal vazio virou FALSE
UPDATE produtoaux
   SET proeanprinc = FALSE
 WHERE proeanprinc IS NULL;
