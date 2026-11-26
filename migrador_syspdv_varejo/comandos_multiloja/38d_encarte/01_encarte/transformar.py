"""T-Encarte_inicial: Switch/Case pelo tipo de preco do encarte (1, 2 ou 3) marca qual preco o
encarte atualiza; outro tipo segue sem marcar nenhum (como no Pentaho). Fora de linha = falso."""
from app.ajudantes import inteiro, texto


def transformar(linha):
    tipo = texto(linha["enctipprc"])
    tipo = int(tipo) if tipo and tipo.isdigit() else None
    marca = (lambda n: None if tipo not in (1, 2, 3) else tipo == n)
    return {
        "enccod": inteiro(linha["enccod"], "ENCCOD"),
        "loj_codigo": inteiro(linha["prpcod"], "PRPCOD"),
        "encdes": linha["encdes"],
        "encdatini": linha["encdatini"],
        "encdatfim": linha["encdatfim"],
        "encstatus": linha["encstatus"],
        "enc_atualiza_preco_1": marca(1),
        "enc_atualiza_preco_2": marca(2),
        "enc_atualiza_preco_3": marca(3),
        "enc_produto_fora_linha": False if tipo in (1, 2, 3) else None,
    }
