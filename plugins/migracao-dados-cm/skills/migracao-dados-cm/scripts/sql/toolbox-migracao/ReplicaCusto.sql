BEGIN ;

UPDATE preco p 
   SET prccst = (SELECT p1.prccst FROM preco p1 WHERE p1.lojcod = 1 AND p1.procod = p.procod),
       proprccstmed = (SELECT p1.proprccstmed FROM preco p1 WHERE p1.lojcod = 1 AND p1.procod = p.procod),
       proprccstfis = (SELECT p1.proprccstfis FROM preco p1 WHERE p1.lojcod = 1 AND p1.procod = p.procod)
 WHERE p.lojcod IN (3) ;

INSERT INTO auditoria_custo(ac_id, loj_codigo, procod, ac_origem, ac_data_registro, ac_custo_reposicao, ac_custo_fiscal, fun_codigo)
     SELECT NEXTVAL('sq_auditoria_custo'), 
	    	  pl.loj_codigo, 
	    	  procod, 
	    	  'AJUSTE', 
	    	  CURRENT_DATE, 
	    	  prccst, 
        	  proprccstfis,
        	  1
       FROM preco
       JOIN pessoa_loja pl ON (pl.loj_codigo IN (3))
      WHERE lojcod = 1 ;
     
INSERT INTO custo_dia(cd_id, loj_codigo, procod, cd_data, cd_data_registro, cd_custo_reposicao, cd_custo_fiscal, cd_custo_medio)
     SELECT NEXTVAL('sq_mov_custo_dia'), 
            pl.loj_codigo, 
            procod,
            CURRENT_DATE,
            CURRENT_DATE, 
            prccst, 
            proprccstfis,
            proprccstmed
       FROM preco
       JOIN pessoa_loja pl ON (pl.loj_codigo IN (3))
      WHERE lojcod = 1
         ON CONFLICT (cd_data, loj_codigo, procod) DO UPDATE SET cd_data_registro = CURRENT_DATE ;

