-- Pentaho: T-Produto_Composicao_E_Componentes_Historico (ON CONFLICT DO NOTHING: pode rodar de novo)
INSERT INTO hist_composicao (hist_comp_id, hist_comp_procod, hist_comp_tipo, hist_comp_oferta, hist_comp_composicao,
                             hist_comp_quantidade, hist_comp_baixa, hist_comp_data)
SELECT comp_id, comp_procod, comp_tipo, comp_oferta, comp_composicao, comp_quantidade, comp_baixa,
       to_date('01/01/2017', 'DD/MM/YYYY')
  FROM composicao ON CONFLICT DO NOTHING;
INSERT INTO hist_componentes_composicao (hist_cc_id, hist_cc_procod, hist_cc_quantidade, hist_cc_preco1, hist_cc_preco2,
                                         hist_cc_preco3, hist_cc_comp_id)
SELECT cc_id, cc_procod, cc_quantidade, cc_preco1, cc_preco2, cc_preco3, cc_comp_id
  FROM componentes_composicao ON CONFLICT DO NOTHING;
SELECT SETVAL('sq_composicao_hist', (SELECT MAX(hist_comp_id) + 1 FROM hist_composicao), FALSE);
SELECT SETVAL('sq_comp_composicao_hist', (SELECT MAX(hist_cc_id) + 1 FROM hist_componentes_composicao), FALSE);

SET session_replication_role = DEFAULT
