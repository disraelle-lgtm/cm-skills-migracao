from app.ajudantes import inteiro


def transformar(linha):
    preco = lambda v: 0 if v is None else v          # If null: precos = 0
    return {
        "procod": inteiro(linha["procod"], "PROCOD"),   # produto "pai" (composicao)
        "cc_procod": inteiro(linha["cntcod"], "CNTCOD"),
        "cc_quantidade": linha["cntqtd"],
        "cc_preco1": preco(linha["cntprcvda1"]),
        "cc_preco2": preco(linha["cntprcvda2"]),
        "cc_preco3": preco(linha["cntprcvda3"]),
    }
