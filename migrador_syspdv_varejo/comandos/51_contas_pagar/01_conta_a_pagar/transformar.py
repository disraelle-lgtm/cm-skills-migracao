"""T-ContaPagar_inicial: categoria financeira 32 fixa (a constante "cfnc_codigo = 32" do Add constants
do .ktr; antes vinha do PLCRED - pedido do usuario);
a vista, 1 titulo, modalidade S, AVULSO, especie 1, agente 0, juros/multa 0; observacao cortada em 100.
Documento vazio = o proprio id (o "VF - Atualiza Sequence" fazia isso DEPOIS de gravar)."""
from app.ajudantes import inteiro, so_digitos, texto


def transformar(linha):
    ctp_id = inteiro(linha["ctpid"], "CTPID")
    valor = linha["ctpvlrnom"]
    return {
        "ctp_id": ctp_id,
        "for_codigo": inteiro(linha["forcod"], "FORCOD"),
        "forcgc": so_digitos(linha["forcgc"]),
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "ctp_num_documento": texto(linha["ctpnum"]) or str(ctp_id),
        "ctp_observacao": None if linha["ctpobs"] is None else str(linha["ctpobs"])[:100],
        "ctp_data_emissao": linha["ctpdatemi"],
        "ctp_primeiro_vencimento": linha["ctpdatvnc"],
        "ctp_valor_nominal": valor,
        "ctp_valor_bruto": valor,
        "cfnc_codigo": 32,
    }
