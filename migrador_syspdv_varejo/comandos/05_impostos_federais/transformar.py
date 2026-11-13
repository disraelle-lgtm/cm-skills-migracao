"""Pentaho: Value Mapper em IMPFEDTIP (P/C/I/S/O -> nome do imposto).
O nome IPMFEDOBS (com 'PM') e assim mesmo no SysPDV e no VarejoFacil."""

TIPOS = {"P": "PIS", "C": "COFINS", "I": "IRPJ", "S": "CSLL", "O": "OUTROS"}


def transformar(linha):
    dados = dict(linha)                         # demais campos vao como vieram do SysPDV
    tipo = (linha["impfedtip"] or "").strip()
    dados["impfedtip"] = TIPOS.get(tipo, linha["impfedtip"])   # sem correspondencia: mantem
    return dados
