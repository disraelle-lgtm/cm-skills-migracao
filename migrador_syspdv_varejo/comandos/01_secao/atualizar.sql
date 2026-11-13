-- DESTINO: secao que ja existe e mudou (Insert/Update do Pentaho: atualiza descricao e sped).
UPDATE secao
   SET secdes = %(secdes)s
     , sec_situacao_sped = %(sec_situacao_sped)s
 WHERE seccod = %(seccod)s
