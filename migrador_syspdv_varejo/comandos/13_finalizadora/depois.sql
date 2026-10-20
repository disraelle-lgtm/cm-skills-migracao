-- Pentaho: "VF - update_fzd_Dinheiro"
UPDATE finalizadora
   SET fzd_movimenta_conta = TRUE
     , fzd_cartao = FALSE
 WHERE fzdcod = 1
