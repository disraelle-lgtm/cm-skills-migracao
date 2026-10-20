from app.ajudantes import texto


def transformar(linha):
    return {"ncm_codigo": linha["ncmcod"], "ct_codigo": texto(linha["clatrbcodnfce"]), "cic_codigo": texto(linha["cstcod"])}
