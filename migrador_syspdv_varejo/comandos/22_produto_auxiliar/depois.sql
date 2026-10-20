-- Pentaho: "VF - Limpeza nos EAN's" (T-ProdutoAuxiliar_limpeza_inicial)

-- Apaga o EAN igual ao codigo do produto. No Pentaho o CAST era feito em todos os codigos
-- (inclusive LITERAL com letras, o que pode dar erro); aqui so converte quando e numerico.
DELETE FROM produtoaux
 WHERE proauxtipo = 'EAN'
   AND (CASE WHEN procodaux ~ '^[0-9]{1,18}$' THEN CAST(procodaux AS bigint) END) IN (SELECT procod FROM produto);

-- EAN invalido vira LITERAL (funcoes validar_ean e validar_gs1 do VarejoFacil)
UPDATE produtoaux SET proauxtipo = 'LITERAL', proauxcodigoean = NULL, proeantrib = FALSE
 WHERE validar_ean(procodaux) = FALSE;
UPDATE produtoaux SET proauxtipo = 'LITERAL', proauxcodigoean = NULL, proeantrib = FALSE
 WHERE validar_gs1(procodaux) = FALSE;

-- Define o EAN tributado (o de menor fator/codigo de cada produto que ainda nao tem)
UPDATE produtoaux SET proeantrib = TRUE
 WHERE procodaux IN (SELECT DISTINCT ON (procod) procodaux
                       FROM produtoaux
                      WHERE proauxtipo = 'EAN'
                        AND procod NOT IN (SELECT DISTINCT procod FROM produtoaux
                                            WHERE proauxtipo = 'EAN' AND proeantrib IS TRUE)
                      ORDER BY procod, proauxfat, procodaux);

-- EAN tributado e o principal; produto sem tributado: um EAN qualquer vira principal
UPDATE produtoaux SET proeanprinc = TRUE WHERE proeantrib = TRUE;
UPDATE produtoaux SET proeanprinc = TRUE
 WHERE proauxtipo = 'EAN'
   AND procodaux IN (SELECT DISTINCT ON (procod) procodaux
                       FROM produtoaux t1
                      WHERE t1.procod NOT IN (SELECT DISTINCT t1.procod
                                                FROM produto t1 JOIN produtoaux t2 ON t2.procod = t1.procod
                                               WHERE proauxtipo = 'EAN' AND proeantrib = TRUE));
UPDATE produtoaux SET proeanprinc = FALSE WHERE proeanprinc IS NULL;

SET session_replication_role = DEFAULT
