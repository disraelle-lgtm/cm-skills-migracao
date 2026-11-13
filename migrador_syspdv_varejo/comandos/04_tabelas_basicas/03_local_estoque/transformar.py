from app.ajudantes import inteiro


def transformar(linha):
    descricao = linha["locdes"]
    return {
        "loc_codigo": inteiro(linha["loccod"], "LOCCOD"),
        "loc_descricao": descricao,
        "loc_estoque": "PROPRIO",          # Add constants
        "loc_bloqueio": False,             # Add constants
        "loc_excluido": False,             # Add constants
        # Value Mapper 2: so a descricao 'AVARIA' vira local de avaria
        "loc_avaria": (descricao or "").strip() == "AVARIA",
    }
