"""T-MovimentacaoTituloReceber_Parcial_inicial: LIQUIDADO_PARCIALMENTE, valor recebido, data da
liquidacao, dias em atraso 0, finalizadora 1, conta corrente (CRLCTCCOD, vazio = 1), juros/multa/
desconto da liquidacao, usuario 1.

No Pentaho a chave era o mov_id da sequence (sempre inseria: a 2a rodada DOBRAVA os pagamentos, e o
"Insert Panama" mandava os pagamentos em dobro). Aqui cada liquidacao recebe um numero de ordem
entre as liquidacoes IGUAIS do mesmo titulo (mesma data, valor, juros, multa e desconto) e so e
gravada se o titulo ainda nao tiver essa quantidade de movimentos iguais."""
from app.ajudantes import inteiro, texto

_vistas = {}


def transformar(linha):
    conta = texto(linha["crlctccod"])
    dados = {
        "ctr_id": inteiro(linha["ctrid"], "CTRID"),
        "mov_valor": linha["crlvlrrec"],
        "mov_data": linha["crldat"],
        "mov_juros": linha["crlvlrjur"],
        "mov_multa": linha["crlvlrmul"],
        "mov_desconto": linha["crlvlrdcn"],
        "cct_codigo": int(conta) if conta else 1,
    }
    chave = tuple(dados[c] for c in ("ctr_id", "mov_valor", "mov_data", "mov_juros", "mov_multa", "mov_desconto"))
    _vistas[chave] = _vistas.get(chave, 0) + 1
    dados["ordem"] = _vistas[chave]
    return dados
