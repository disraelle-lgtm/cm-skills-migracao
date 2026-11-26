"""T-ItemTabelaTributaria2: CST e CFOP com TRIM e como numero (vazios = 60 e 5102); classificacao
SAIDA_PARA_NAO_CONTRIBUINTE; agregado, carga liquida, aliquota interna, tributado ICMS e FECOP = 0."""
from app.ajudantes import texto


def _numero(valor, padrao):
    t = texto(valor)
    return int(t) if t else padrao


def transformar(linha):
    return {
        "trbid": linha["tributacao"],
        "itt_tributacao_nf": linha["tributada"],
        "itt_aliquota": linha["alicota"],
        "itt_outros_nf": linha["outros"],
        "itt_isento_nf": linha["isento"],
        "itt_cst": _numero(linha["cst"], 60),
        "itt_classificacao_pessoa": "SAIDA_PARA_NAO_CONTRIBUINTE",
        "itt_agregado": 0,
        "itt_carga_liquida": 0,
        "itt_aliquota_interna": 0,
        "itt_tributado_icms": 0,
        "itt_fecop": 0,
        "itt_cfop": _numero(linha["cfop"], 5102),
        "itt_uf": texto(linha["origem"]),
    }
