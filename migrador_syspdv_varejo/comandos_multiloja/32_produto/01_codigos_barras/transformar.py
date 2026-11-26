from app.ajudantes import Pular, inteiro, texto


def transformar(linha):
    """Codigo de barras so com digitos, sem zeros a esquerda (o mesmo EAN gravado com 13 ou 14 posicoes casa)."""
    ean = (texto(linha["ean"]) or "")
    if not ean.isdigit() or not ean.strip("0"):
        raise Pular("código não numérico (LITERAL) ou zerado: não serve para reconhecer o produto")
    return {"procod": inteiro(linha["procod"], "PROCOD"), "ean": ean.lstrip("0")}
