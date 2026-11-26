from app.ajudantes import Pular


def transformar(linha):
    ncm = (linha["proncm"] or "").replace(".", "").strip()   # Replace in string: tira os pontos + TRIM
    if not ncm:
        raise Pular("produto sem NCM")                         # AND p.proncm IS NOT NULL
    return {"ncm_codigo": ncm.rjust(8, "0")}                   # completa com zeros a esquerda ate 8
