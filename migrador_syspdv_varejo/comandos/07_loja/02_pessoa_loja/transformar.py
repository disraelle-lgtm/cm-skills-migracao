from app.ajudantes import Pular, inteiro, so_digitos, texto

REGIME_ESTADUAL = {"N": "1", "E": "2", "A": "3", "S": "4"}   # Value Mapper (PRPREGEST)
REGIME_MUNICIPAL = {"N": "N", "S": "S"}                      # Value Mapper 2 (REGIMEMUNICIPAL)


def _inteiro_ou_nulo(valor):
    t = texto(valor)
    return int(t) if t else None


def transformar(linha):
    documento = so_digitos(linha["prpcgc"])
    if not documento:
        raise Pular("loja sem CNPJ (PRPCGC)")
    regime = texto(linha["prpregest"]) or ""
    municipal = regime[:2]                                    # Strings cut: 2 primeiros caracteres
    return {
        "pes_num_documento": documento,                       # liga com a pessoa (Join Rows pelo CNPJ)
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "loj_chave_server": linha["prpchv"],
        "loj_versao_server": linha["prpver"],
        "loj_regime_federal": linha["prpregfed"],
        "loj_crt": _inteiro_ou_nulo(linha["prpcrt"]),
        "loj_porta": _inteiro_ou_nulo(linha["prpport"]),
        "loj_ip": linha["prphost"],
        "loj_matriz": "S",                                    # Add constants LOJA_MATRIZ
        "loj_preco_aplicado": _inteiro_ou_nulo(linha["prptipprc"]),
        "fig_codigo": 1,                                      # 1 AS fig_fiscal
        "ret_codigo": _inteiro_ou_nulo(REGIME_ESTADUAL.get(regime, regime)),
        "loj_sigla": (linha["prpdes"] or "")[:5] or None,      # ajuste: 5 primeiros caracteres
        "loj_regime_municipal": REGIME_MUNICIPAL.get(municipal, municipal) or None,
        "loj_perfil": "B",
        "loj_atividade": "COMERCIO",
        "cfnc_codigo_est_pag": 75,
        "cfnc_codigo_est_receb": 71,
        "cfnc_codigo_pagamentos": 90,
        "cfnc_codigo_recebimentos": 91,
        "cfnc_codigo_quebra": 92,
        "cfnc_codigo_sobra": 93,
        "loj_nome_exibicao": linha["prpfan"],
    }
