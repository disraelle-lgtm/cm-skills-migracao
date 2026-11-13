"""T-cenario_fiscal_produto_produto: grupo/subgrupo '000' = vazio; o produto entra no cenario pelo
nivel mais detalhado que tiver: so secao, secao + grupo ou secao + grupo + subgrupo."""
from app.ajudantes import inteiro, texto


def _cod(valor):
    t = texto(valor)
    return int(t) if t and t != "000" else None


def transformar(linha):
    grupo, subgrupo = _cod(linha["grpcod"]), _cod(linha["sgrcod"])
    dados = {"cfp_codigo": int(linha["id_num"]), "procod": inteiro(linha["procod"], "PROCOD"),
             "seccod": _cod(linha["seccod"]), "secdes": linha["secdes"],
             "grpcod": None, "grpdes": None, "sgpcod": None, "sgpdes": None}
    if grupo is not None:                                  # GRPCOD NULL -> so secao
        dados.update(grpcod=grupo, grpdes=linha["grpdes"])
        if subgrupo is not None:                           # SGRCOD NULL -> secao + grupo
            dados.update(sgpcod=subgrupo, sgpdes=linha["sgrdes"])
    return dados
