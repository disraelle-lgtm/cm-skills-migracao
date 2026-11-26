"""T-CriaSituacaoFiscalProduto: descricao = simbologia por extenso + '-' + TRBID (Concat Fields).
Simbologia = 1o caractere do TRBID: T = Tributado, F = Fonte, I = Isento (outros ficam como estao)."""

SIMBOLOGIA = {"T": "Tributado", "F": "Fonte", "I": "Isento"}


def transformar(linha):
    trbid = linha["trbid"]                      # sem TRIM, igual ao que o item Produto grava em produto.trbid
    letra = str(trbid)[:1]
    descricao = f"{SIMBOLOGIA.get(letra, letra)}-{trbid}"
    return {"trbid": trbid, "stf_descricao_reduzida": descricao, "stf_descricao_completa": descricao}
