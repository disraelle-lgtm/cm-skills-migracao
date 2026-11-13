from app.ajudantes import inteiro, texto


def transformar(linha):
    codigo = inteiro(linha["fzdcod"], "FZDCOD")
    agente = texto(linha["agecod"])
    dinheiro = codigo == 1          # "VF - update_fzd_Dinheiro": a finalizadora 1 movimenta conta
    return {
        "fzdcod": codigo,
        "fzddes": texto(linha["fzddes"]),
        "agf_codigo": int(agente) if agente else None,
        "fzd_movimenta_conta": dinheiro,   # Add constants: false (exceto a 1, ver depois.sql)
        "fzd_cartao": False,               # Add constants
        "fzd_carga_geral": False,          # Add constants
    }
