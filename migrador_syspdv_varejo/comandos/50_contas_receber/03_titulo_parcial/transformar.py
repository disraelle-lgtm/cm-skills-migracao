from app.ajudantes import inteiro


def transformar(linha):
    return {"ctr_id": inteiro(linha["ctrid"], "CTRID"), "ttlr_status": "PARCIALMENTE_LIQUIDADO"}
