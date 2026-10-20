-- Pentaho: SQLs do fim do JOB-Produto_inicial, na mesma ordem, com triggers desligadas
-- como no job (Session Replication).
SET session_replication_role = replica;

-- ---------------------------------------------- "Produto higieniza Loccod" (T-Produto-higieniza-loccod)
UPDATE produto SET loccod = 0 WHERE loccod IS NULL;
UPDATE produto SET proiteemb = 1 WHERE proiteemb = 0;
UPDATE produto SET proiteembvda = 1 WHERE proiteembvda = 0;
UPDATE produto SET proesp = 'N' WHERE proesp = '0';
UPDATE produto SET propesvar = 'N' WHERE propesvar = '0';

-- ---------------------------------------------- "Ajusta Produto"
UPDATE produto SET gencodigo = CAST(SUBSTRING(proncm FROM 1 FOR 2) AS bigint);
UPDATE produto SET prodatcadinc = CURRENT_DATE WHERE prodatcadinc IS NULL;
UPDATE produto SET prodatcadalt = CURRENT_DATE;
UPDATE produto p SET grpcod = NULL
 WHERE p.grpcod NOT IN (SELECT t3.grpcod FROM grupo_produto t3 WHERE t3.seccod = p.seccod);
UPDATE produto p SET sgpcod = NULL
 WHERE p.sgpcod NOT IN (SELECT t2.sgpcod FROM subgrupo_produto t2
                         WHERE t2.seccod = p.seccod AND t2.grpcod = p.grpcod);
-- No Pentaho estava "= NULL", que nunca e verdadeiro no PostgreSQL (a linha nao fazia nada).
UPDATE item_tabela_tributacao SET itt_icms_desonerado = FALSE WHERE itt_icms_desonerado IS NULL;
UPDATE produto SET prodesrdz = SUBSTRING(prodes, 1, 20) WHERE prodesrdz IS NULL;
SELECT setval('sq_produto_familia', COALESCE((SELECT MAX(codigo) FROM produto_familia), 1));
UPDATE ncm n
   SET ncm_quantidade_produtos = c.qtd, ncm_status = 'INCONSISTENTE'
  FROM (SELECT proncm, COUNT(*) AS qtd FROM produto WHERE proncm IS NOT NULL GROUP BY proncm) c
 WHERE c.proncm = n.ncm_codigo;
UPDATE produto SET loccod = 0 WHERE loccod IS NULL;
UPDATE produto SET protipipi = 'P' WHERE protipipi IS NULL OR protipipi = '' OR protipipi = ' ';
UPDATE produto SET proinczf = 'N' WHERE proinczf IS NULL OR proinczf = '' OR proinczf = ' ';
UPDATE produto SET prod_dias_seguranca = 0 WHERE prod_dias_seguranca IS NULL;
UPDATE produto SET proiteembtrs = 1 WHERE proiteembtrs IS NULL;
UPDATE produto SET proundtrs = prounid WHERE proundtrs IS NULL;
UPDATE produto SET proctrvld = 'N' WHERE proctrvld = ' ' OR proctrvld IS NULL;
UPDATE produto SET prodesvar = 'N' WHERE prodesvar = ' ' OR prodesvar IS NULL;
UPDATE produto SET protipagr = NULL WHERE protipagr = ' ';
UPDATE produto SET procodanp = NULL WHERE procodanp = ' ';
UPDATE produto SET receita = NULL WHERE receita = ' ';
UPDATE produto SET proundref = prounid WHERE proundref IS NULL;
UPDATE produto SET promedref = 1.00 WHERE promedref IS NULL;
UPDATE produto SET procomtip = 'N' WHERE procomtip IS NULL;
UPDATE produto SET proundcmp = prounid WHERE proundcmp IS NULL;
UPDATE produto SET profrtloj = 'N' WHERE profrtloj IS NULL;
UPDATE produto SET pronumser = 'N' WHERE pronumser IS NULL;
UPDATE produto SET probontip = 'N' WHERE probontip IS NULL;
UPDATE produto SET proprcvar = 'N' WHERE proprcvar IS NULL;
UPDATE produto SET proenvbal = 'N' WHERE proenvbal IS NULL;
UPDATE produto SET proiat = 'A' WHERE proiat IS NULL;
UPDATE produto SET proippt = 'P' WHERE proippt IS NULL;
UPDATE produto SET profin = '1' WHERE profin IS NULL;
UPDATE produto SET prodatforlin = CURRENT_DATE WHERE proforlin = 'S';
UPDATE produto SET protaba = 0 WHERE protaba IS NULL;
UPDATE produto SET propesvar = 'N' WHERE propesvar IS NULL;
UPDATE produto SET provld = 0 WHERE provld IS NULL;
UPDATE produto SET proctrest = 'S' WHERE proctrest IS NULL OR proctrest = 'N';
UPDATE produto SET propesvar = 'S' WHERE prounid = 'KG';
UPDATE produto SET propesbrt = 1 WHERE propesbrt IS NULL OR propesbrt = 0;
UPDATE produto SET propesliq = 1 WHERE propesliq IS NULL OR propesliq = 0;
UPDATE produto SET proenvbal = 'S' WHERE propesvar = 'S';
UPDATE produto SET proprcvar = 'N' WHERE proprcvar = '0';
UPDATE produto SET natcodigo = NULL WHERE natcodigo = 0;
UPDATE produto SET proestmin = NULL WHERE proestmin = 0;
UPDATE produto SET proestmax = NULL WHERE proestmax = 0;
-- NAO levado: "update pesquisa_satisfacao set data_fim_vigencia = '2026-12-31' where id = 3"
-- (nada a ver com produto; sobra de outro cliente no Ajusta Produto do Pentaho).

-- ---------------------------------------------- "Corrigi produtos sem composição"
-- composto/kit sem componentes vira produto normal
UPDATE produto SET procomp = 'N'
 WHERE procomp IN ('K', 'C')
   AND procod IN (SELECT comp_procod FROM composicao
                   WHERE comp_id NOT IN (SELECT cc_comp_id FROM componentes_composicao));
-- composto/kit que nao esta na tabela composicao vira produto normal
UPDATE produto SET procomp = 'N'
 WHERE procomp IN ('K', 'C')
   AND procod NOT IN (SELECT comp_procod FROM composicao);
-- composicao de produto que nao e kit nem composto sai
DELETE FROM composicao
 WHERE comp_procod IN (SELECT procod FROM produto WHERE procomp NOT IN ('K', 'C'));
-- componentes sem composicao saem
DELETE FROM componentes_composicao WHERE cc_comp_id NOT IN (SELECT comp_id FROM composicao);
-- produto composto de si mesmo sai
DELETE FROM componentes_composicao
 WHERE cc_id IN (SELECT cp.cc_id FROM componentes_composicao cp
                   JOIN composicao c ON cp.cc_comp_id = c.comp_id AND c.comp_procod = cp.cc_procod);

-- ---------------------------------------------- "Cadastro-de-operacoes" (T-Cadastro-de-operacoes_inicial)
-- 24 operacoes padrao, com os codigos fixos do Pentaho. No Pentaho sao INSERTs diretos (uma 2a
-- execucao daria chave duplicada); aqui cada uma so entra se o codigo ainda nao existir.
-- O codigo e a 1a coluna da tabela operacao (os INSERTs do Pentaho sao posicionais).
DO $$
DECLARE
  col text;
  ja_existe boolean;
BEGIN
  SELECT column_name INTO col FROM information_schema.columns
   WHERE table_schema = current_schema() AND table_name = 'operacao' AND ordinal_position = 1;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 1)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (1,'ENTRADA - COMPRA P/COMERCIALIZAÇÃO - A PRAZO','E','A','',true,true,true,false,true,true,true,'T',0,1403,2403,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 2)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (2,'ENTRADA -COMPRA P/COMERCIALIZAÇÃO - A VISTA','E','L','',true,true,true,false,true,true,true,'T',0,1403,2403,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 3)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (3,'ENTRADA -COMPRA MATERIAL P/CONSUMO - A VISTA','E','L','',true,true,true,false,true,true,true,'T',0,1556,2556,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 4)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (4,'ENTRADA-COMPRA MATERIAL P/ CONSUMO - A PRAZO','E','L','',true,true,true,true,true,false,true,'T',0,1556,2556,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 5)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (5,'ENTRADA - BONIFICAÇÃO P/COMERCIALIZAÇÃO','E','N','',false,true,false,false,false,false,true,'T',0,1910,2910,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 6)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (6,'ENTRADA - BRINDES RECEBIDOS DE FORNECEDORES','E','N','',false,true,false,false,false,false,true,'T',0,1910,2910,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 7)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (7,'ENTRADA-COMPRA P/ ATIVO IMOBILIZADO','E','A','',false,true,true,false,true,true,true,'T',0,1551,2551,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 8)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (8,'ENTRADA-TRANSFERÊNCIA MERCADORIA P/COMERCIALIZAÇÃO','E','N','',false,true,false,false,false,false,true,'T',0,1152,2152,null,false,false,null,'TRANSFERENCIA','NOTA_FISCAL',false,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 9)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (9,'ENTRADA-TRANSFERÊNCIA ATIVO IMOBILIZADO','E','N','',false,true,false,false,false,false,true,'T',0,1552,2552,null,false,false,null,'TRANSFERENCIA','NOTA_FISCAL',false,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 10)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (10,'ENTRADA-DEVOLUÇÃO VENDA C/NOTA DE ENTRADA PROPRIA','E','A','',false,true,true,false,true,true,true,'P',0,1202,2202,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 11)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (11,'ENTRADA-DEVOLUÇÃO VENDA MERC ADQ OU RECEB TERCEIRO','E','A','',false,true,true,false,true,true,true,'T',0,1202,2202,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,true);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 12)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (12,'ENTRADA - PRODUTOR RURAL','E','A','',true,true,true,false,true,true,true,'P',0,1102,2102,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 13)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (13,'ENTRADA -DEVOLUÇÃO DE NOTA DE TRANSFERÊNCIA','E','N','',false,true,false,false,false,false,true,'T',0,1209,2209,null,false,false,null,'TRANSFERENCIA','NOTA_FISCAL',false,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 14)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (14,'ENTRADA -CONHECIMENTO DE FRETE','E','A','',true,true,true,false,true,true,true,'T',0,1353,2353,null,false,false,null,'NORMAL','CONHECIMENTO_TRANSPORTE',true,false,true);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 15)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (15,'ENTRADA-COMPRA ENERGIA ELÉTRICA POR ESTABEL.COML','E','A','',false,false,false,false,false,false,true,'T',0,1253,2253,null,false,false,null,'SIMPLIFICADA','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 16)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (16,'ENTRADA - COMPRA SERVIÇO DE COMUNICAÇÃO/INTERNET','E','A','',false,false,false,false,false,false,false,'T',0,1303,2303,null,false,false,null,'SIMPLIFICADA','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 17)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (17,'ENTRADA-RETORNO DE MERCADORIA ENVIADA P/ CONSERTO','E','N','',false,false,false,false,false,false,true,'T',0,1916,2916,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 18)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (18,'ENTRADA-MERCADORIAS RECEB EM DEMONSTRAÇÃO','E','N','',false,true,true,false,true,true,true,'T',0,1912,2912,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 19)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (19,'ENTRADA -COMPRA SEM DOCUMENTO FISCAL','E','A','',false,true,false,false,false,false,false,'T',0,1102,2102,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 20)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (20,'SAIDA-VENDA DE MERCADORIAS ','S','A','',false,true,true,false,true,true,true,'P',0,5102,6102,null,false,false,null,'NORMAL','NOTA_FISCAL',true,true,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 21)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (21,'SAIDA-VENDA ACOBERTADA COM CUPOM FISCAL','S','N','',false,false,false,false,false,false,true,'P',0,5929,6929,null,false,false,null,'CUPOM','NOTA_FISCAL',false,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 22)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (22,'SAÍDA-BAIXA DE ESTOQUE PERDA/ROUBO/DETERIORAÇÃO','S','N','',false,true,true,false,true,true,true,'P',0,5927,6949,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 23)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (23,'SAÍDA-TRANSFERÊNCIA DE MERCAD P/COMERCIALIZAÇÃO','S','N','F',false,true,false,false,false,false,true,'P',0,5152,6152,null,false,false,null,'TRANSFERENCIA','NOTA_FISCAL',false,false,false);
  END IF;
  EXECUTE format('SELECT EXISTS (SELECT 1 FROM operacao WHERE %I = 24)', col) INTO ja_existe;
  IF NOT ja_existe THEN
    INSERT INTO operacao VALUES (24,'SAIDA-DEVOLUÇÃO DE COMPRA P/ COMERCIALIZAÇÃO','S','A','',false,true,true,false,true,true,true,'P',0,5202,6202,null,false,false,null,'NORMAL','NOTA_FISCAL',true,false,false);
  END IF;
END $$;

SET session_replication_role = DEFAULT;

-- Religa as triggers da tabela produto (desligadas em 20_inicio_produto). Por garantia o
-- 20_inicio_produto/finalizar.sql religa de novo no fim, mesmo se algo der erro no meio.
ALTER TABLE produto ENABLE TRIGGER ALL
