from app.ajudantes import Pular, so_digitos, texto


def _inteiro_ou_nulo(valor):
    t = texto(valor)
    return int(t) if t else None


def transformar(linha):
    documento = so_digitos(linha["prpcgc"])                       # limpa caracteres do CPF/CNPJ
    if not documento:
        raise Pular("loja sem CNPJ (PRPCGC)")                     # e a chave da pessoa no Pentaho
    return {
        "pes_num_documento": documento,
        "pes_num_identificacao": linha["prpierg"],
        "pes_nome": linha["prpdes"],
        "pes_fantasia": linha["prpfan"],
        "pes_cep": linha["prpcep"],
        "pes_uf": linha["prpuf"],
        "pes_logradouro": linha["prpend"],
        "pes_numero": texto(linha["prpnum"]),                     # TRIM
        "pes_bairro": linha["prpbai"],
        "pes_complemento": linha["prpcmp"],
        "pes_descricao_cidade": linha["prpmun"],
        "pes_telefone1": linha["prptel"],
        "pes_fax": linha["prpfax"],
        "pes_email": texto(linha["prpemail"], vazio="cliente@cliente.com.br"),  # TRIM + If null
        "pes_insc_municipal": linha["prpincmun"],
        "mcp_codigo_ibge": _inteiro_ou_nulo(linha["prpcodibge"]),  # TRIM + Integer
        "pes_pais": _inteiro_ou_nulo(linha["prppais"]),            # TRIM + Integer
    }
