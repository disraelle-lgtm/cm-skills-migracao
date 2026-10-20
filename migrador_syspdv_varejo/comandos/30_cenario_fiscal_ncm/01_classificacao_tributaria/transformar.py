from app.ajudantes import Pular, texto


def transformar(linha):
    codigo = texto(linha["clatrbcod"])
    if not codigo:
        raise Pular("classificacao sem codigo")
    return {
        "ct_codigo": codigo, "cic_codigo": texto(linha["cstcod"]), "ct_nome": texto(linha["clatrbapl"]),
        "ct_descricao": texto(linha["clatrbdescmp"]), "ct_lc_redacao": texto(linha["clatrbobs"]),
        "ct_lc_214_25": texto(linha["clatrbbaslgl"]),
        "ct_percentual_reducao_ibs": linha["clatrbpctredibs"], "ct_percentual_reducao_cbs": linha["clatrbpctredcbs"],
    }
