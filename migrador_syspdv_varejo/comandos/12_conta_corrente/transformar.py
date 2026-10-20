from app.ajudantes import inteiro, texto

TIPO = {"C": "CAIXA", "B": "BANCARIA"}   # Value Mapper; vazio = CAIXA (If null)


def transformar(linha):
    tipo = texto(linha["ctctip"])
    agente = texto(linha["agecod"])
    return {
        "cct_codigo": inteiro(linha["ctccod"], "CTCCOD"),
        "cct_descricao": texto(linha["ctcdes"]),
        "cct_tipo": TIPO.get(tipo, tipo) if tipo else "CAIXA",
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "agf_codigo": int(agente) if agente else 0,        # If null: 0
        "cct_agencia": texto(linha["ctcage"]),
        "cct_conta": texto(linha["ctcnum"]),
        "cct_local_pagamento": texto(linha["ctclocpag"]),
    }
