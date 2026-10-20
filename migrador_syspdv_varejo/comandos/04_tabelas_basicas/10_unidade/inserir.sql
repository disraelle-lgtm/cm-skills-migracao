-- ID pela sequence sq_unidade (igual ao Pentaho)
INSERT INTO unidade (undid, undcod, unddes, undfatref)
VALUES (nextval('sq_unidade'), %(undcod)s, %(unddes)s, %(undfatref)s)
