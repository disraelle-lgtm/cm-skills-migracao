UPDATE finalizadora
   SET fzddes = %(fzddes)s, fzd_movimenta_conta = %(fzd_movimenta_conta)s
     , fzd_cartao = %(fzd_cartao)s, fzd_carga_geral = %(fzd_carga_geral)s
 WHERE fzdcod = %(fzdcod)s
