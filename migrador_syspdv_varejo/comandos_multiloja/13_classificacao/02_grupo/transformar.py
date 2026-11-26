from app.ajudantes import inteiro, texto


def _transformar_base(linha):
    return {
        "seccod": inteiro(linha["seccod"], "SECCOD"),
        "grpcod": inteiro(linha["grpcod"], "GRPCOD"),
        "grpdes": texto(linha["grpdes"], vazio="RENOMEAR"),  # so TRIM (o Pentaho nao poe em maiusculo)
    }


def transformar(linha):
    """Mesma traducao + o indicador da loja adicional (sem ele o vinculo com o que ja existe nao e gravado)."""
    dados = _transformar_base(linha)
    dados["vinculado_loja"] = True
    return dados
