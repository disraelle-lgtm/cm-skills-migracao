cd /migracao

rm panorama*.csv

\copy (SELECT * FROM impostos_federais ORDER BY impfedsim ASC) TO '/home/ec2-user/migracao/panorama_impostos_federais.csv' DELIMITER ';' CSV HEADER;
\copy (SELECT * FROM impostos_federais_geral ORDER BY impfedgeralid ASC) TO '/home/ec2-user/migracao/panorama_impostos_federais_geral.csv' DELIMITER ';' CSV HEADER;
\copy (SELECT * FROM impostos_federais_atacado ORDER BY impfedatacadoid ASC) TO '/home/ec2-user/migracao/panorama_impostos_federais_atacado.csv' DELIMITER ';' CSV HEADER;
\copy (SELECT * FROM impostos_federais_varejo ORDER BY impfedvarejoid ASC) TO '/home/ec2-user/migracao/panorama_impostos_federais_varejo.csv' DELIMITER ';' CSV HEADER;
\copy (SELECT * FROM impostos_federais_simples ORDER BY impfedsimplesid ASC) TO '/home/ec2-user/migracao/panorama_impostos_federais_simples.csv' DELIMITER ';' CSV HEADER;
\COPY (SELECT * FROM situacao_fiscal ORDER BY stf_codigo ASC) TO '/home/ec2-user/migracao/panorama_situacao_fiscal.csv' DELIMITER ';' CSV HEADER ;
\COPY (SELECT * FROM tabela_tributacao ORDER BY tbt_id ASC) TO '/home/ec2-user/migracao/panorama_tabela_tributaria.csv' DELIMITER ';' CSV HEADER ;
\COPY (SELECT * FROM item_tabela_tributacao ORDER BY itt_id ASC) TO '/home/ec2-user/migracao/panorama_item_tabela_tributaria.csv' DELIMITER ';' CSV HEADER ;
\COPY (SELECT * FROM operacao ORDER BY ope_codigo ASC) TO '/home/ec2-user/migracao/panorama_item_tabela_operacao.csv' DELIMITER ';' CSV HEADER ;

-- banco de destino

SELECT COUNT(*) FROM impostos_federais ;
SELECT COUNT(*) FROM impostos_federais_geral ;
SELECT COUNT(*) FROM impostos_federais_atacado ;
SELECT COUNT(*) FROM impostos_federais_varejo ;
SELECT COUNT(*) FROM impostos_federais_simples ;
SELECT COUNT(*) FROM situacao_fiscal ;
SELECT COUNT(*) FROM tabela_tributacao ;
SELECT COUNT(*) FROM item_tabela_tributacao ;
SELECT COUNT(*) FROM operacao ;

UPDATE produto SET stf_codigo = NULL,stf_codigo_saida = NULL ;
DELETE FROM situacao_fiscal ;
DELETE FROM item_tabela_tributacao ;
DELETE FROM tabela_tributacao ;

\copy impostos_federais FROM '/home/ec2-user/migracao/panorama_impostos_federais.csv' DELIMITER ';' CSV HEADER;
\copy impostos_federais_geral FROM '/home/ec2-user/migracao/panorama_impostos_federais_geral.csv' DELIMITER ';' CSV HEADER;
\copy impostos_federais_atacado FROM '/home/ec2-user/migracao/panorama_impostos_federais_atacado.csv' DELIMITER ';' CSV HEADER;
\copy impostos_federais_varejo FROM '/home/ec2-user/migracao/panorama_impostos_federais_varejo.csv' DELIMITER ';' CSV HEADER;
\copy impostos_federais_simples FROM '/home/ec2-user/migracao/panorama_impostos_federais_simples.csv' DELIMITER ';' CSV HEADER;
\copy situacao_fiscal FROM '/home/ec2-user/migracao/panorama_situacao_fiscal.csv' DELIMITER ';' CSV HEADER ;
\copy tabela_tributacao FROM '/home/ec2-user/migracao/panorama_tabela_tributaria.csv' DELIMITER ';' CSV HEADER ;
\copy item_tabela_tributacao FROM '/home/ec2-user/migracao/panorama_item_tabela_tributaria.csv' DELIMITER ';' CSV HEADER ;
\copy operacao FROM '/home/ec2-user/migracao/panorama_item_tabela_operacao.csv' DELIMITER ';' CSV HEADER ;

SELECT SETVAL('sq_impostos_federais_geral', (SELECT MAX(impfedgeralid) + 1 FROM impostos_federais_geral), FALSE) ;
SELECT SETVAL('sq_impostos_federais_atacado', (SELECT MAX(impfedatacadoid) + 1 FROM impostos_federais_atacado), FALSE) ;
SELECT SETVAL('sq_impostos_federais_simples', (SELECT MAX(impfedsimplesid) + 1 FROM impostos_federais_simples), FALSE) ;
SELECT SETVAL('sq_impostos_federais_varejo', (SELECT MAX(impfedvarejoid) + 1 FROM impostos_federais_varejo), FALSE) ;
SELECT SETVAL('sq_tabela_tributacao', (SELECT MAX(tbt_id) + 1 FROM tabela_tributacao), FALSE) ;
SELECT SETVAL('sq_item_tabela_tributacao', (SELECT MAX(itt_id) + 1 FROM item_tabela_tributacao), FALSE) ;