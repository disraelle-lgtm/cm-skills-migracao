from app.ajudantes import Pular, texto


def transformar(linha):
    if linha["id_num"] is None:
        raise Pular("classificacao do produto nao existe na CLASSIFICACAO_TRIBUTARIA do SysPDV")
    return {"cfp_codigo": int(linha["id_num"]), "ct_codigo": texto(linha["clatrbcodnfce"]),
            "cic_codigo": texto(linha["cstcod"]), "cfp_status": True, "cfp_funcionario_cadastrou": 1}
