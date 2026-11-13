from app.ajudantes import Pular, texto


def transformar(linha):
    if linha["id_num"] is None:
        raise Pular("classificacao do NCM nao existe na CLASSIFICACAO_TRIBUTARIA do SysPDV")
    funcionario = texto(linha["funcodatu"])
    return {
        "cfn_codigo": int(linha["id_num"]),
        "ct_codigo": texto(linha["clatrbcodnfce"]),
        "cic_codigo": texto(linha["cstcod"]),
        "cfn_descricao": texto((linha["clatrbapl"] or "")[:200]),      # Strings cut 200 + TRIM
        "cfn_funcionario_cadastrou": int(funcionario) if funcionario else 1,
    }
