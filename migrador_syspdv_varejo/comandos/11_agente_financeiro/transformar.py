from app.ajudantes import inteiro, so_digitos, texto

TIPO_PESSOA = {"F": "FISICA", "J": "JURIDICA", "E": "ESTRANGEIRO"}   # padrao FISICA


def transformar(linha):
    documento = so_digitos(linha["id"])                  # limpa caracteres do CPF/CNPJ + TRIM
    nome = texto(linha["agenom"])
    dados = {
        "agf_codigo": inteiro(linha["agecod"], "AGECOD"),
        "pes_num_documento": documento,
        "pes_tipo": TIPO_PESSOA.get(texto(linha["agepfpj"]) or "", "FISICA"),
        "pes_nome": nome,
        "pes_fantasia": nome,                            # o Pentaho grava o nome nos dois campos
        "pes_uf": texto(linha["ageuf"]),
        "pes_logradouro": texto(linha["ageend"]),
        "pes_numero": texto(linha["agenum"]),
        "pes_bairro": texto(linha["agebair"]),
        "pes_descricao_cidade": texto(linha["agecid"]),
        "pes_telefone1": texto(linha["agefon"]),
        "pes_fax": texto(linha["agefax"]),
        "pes_email": texto(linha["ageemail"]),
        "agf_codigo_banco": 0,                           # Add constants: banco = 0
    }
    if documento is None:
        dados["_aviso"] = "agente sem CNPJ/CPF: pessoa criada sem documento"
    return dados
