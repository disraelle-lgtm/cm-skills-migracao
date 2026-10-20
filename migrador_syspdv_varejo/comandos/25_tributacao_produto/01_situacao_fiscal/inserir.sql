-- T-define-sequence-stf-codigo: codigo = maior codigo + 1 (calculado a cada insercao)
INSERT INTO situacao_fiscal (stf_codigo, stf_tributacao_rms, stf_descricao_reduzida, stf_descricao_completa)
VALUES ((SELECT COALESCE(MAX(stf_codigo), 0) + 1 FROM situacao_fiscal),
        %(trbid)s, %(stf_descricao_reduzida)s, %(stf_descricao_completa)s)
