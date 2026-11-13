-- DESTINO: secao nova. O ID vem da sequence sq_secao (igual ao Pentaho).
INSERT INTO secao (secid, seccod, secdes, sec_situacao_sped)
VALUES (nextval('sq_secao'), %(seccod)s, %(secdes)s, %(sec_situacao_sped)s)
