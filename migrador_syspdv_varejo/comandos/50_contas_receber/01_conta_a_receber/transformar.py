"""T-ContaReceber_inicial (versao nova): cliente pelo CODIGO; categoria financeira 9 fixa (antes vinha
do PLCRED); a vista, 1 titulo, modalidade S, AVULSO, especie 2 (promissoria), agente 0, juros/multa 0
(juros e multa sao particulares de cada cliente - ajustados a parte). Observacao cortada em 100.
Documento vazio = o proprio id (o "VF - Ajusta Sequence" fazia isso DEPOIS de gravar, e a 2a rodada
nao achava a conta pelo documento)."""
from app.ajudantes import inteiro, texto


def transformar(linha):
    ctr_id = inteiro(linha["ctrid"], "CTRID")
    valor = linha["ctrvlrnom"]
    return {
        "ctr_id": ctr_id,
        "cli_codigo": inteiro(linha["clicod"], "CLICOD"),
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "ctr_num_documento": texto(linha["ctrnum"]) or str(ctr_id),
        "ctr_observacao": None if linha["ctrobs"] is None else str(linha["ctrobs"])[:100],
        "ctr_data_emissao": linha["ctrdatemi"],
        "ctr_primeiro_vencimento": linha["ctrdatvnc"],
        "ctr_valor_nominal": valor,
        "ctr_valor_bruto": valor,
        "cfnc_codigo": 9,
    }
