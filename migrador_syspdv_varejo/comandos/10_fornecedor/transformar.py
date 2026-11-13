from app.ajudantes import Pular, inteiro, so_digitos, texto

TIPO_PESSOA = {"F": "FISICA", "J": "JURIDICA", "E": "ESTRANGEIRO"}   # PARSE TIPO PESSOA (padrao JURIDICA)
TRANSPORTADORA = {"S": True, "N": False}                             # Value Mapper (FORTRANS)
REGIME = {"S": 4, "N": 1}                                            # Value Mapper 2 (FOROPTSIM), nulo = 1


def _inteiro_ou_nulo(valor):
    t = texto(valor)
    return int(t) if t else None


def transformar(linha):
    documento = so_digitos(linha["forcgc"])                           # limpa caracteres do CPF/CNPJ
    if not documento:
        raise Pular("CNPJ/CPF sem numeros (FORCGC)")
    return {
        # --- T-Fornecedor-Pessoa
        "pes_num_documento": documento,
        "pes_nome": linha["fordes"],
        "pes_logradouro": linha["forend"],
        "pes_bairro": linha["forbai"],
        "pes_descricao_cidade": linha["forcid"],
        "pes_uf": linha["forest"],
        "pes_telefone1": linha["fortel"],
        "pes_fax": (linha["forfax"] or "")[:14] or None,              # Strings cut 14
        "pes_cep": linha["forcep"],
        "pes_numero": texto(linha["fornum"]),                         # TRIM
        "pes_complemento": linha["forcmp"],
        "pes_fantasia": linha["forfan"],
        "pes_num_identificacao": linha["forcgf"],
        "pes_email": linha["foremail"],
        "mcp_codigo_ibge": _inteiro_ou_nulo(linha["forcodibge"]),
        "pes_pais": int(texto(linha["forpais"]) or "01058"),          # If null 01058 -> 1058
        "pes_tipo": TIPO_PESSOA.get(texto(linha["forpfpj"]) or "", "JURIDICA"),
        # --- T-Fornecedor-PessoaFornecedor
        "for_codigo": inteiro(linha["forcod"], "FORCOD"),
        "for_prazo_entrega": linha["forprzent"],
        "transportadora": TRANSPORTADORA.get(texto(linha["fortrans"]) or ""),
        "ret_codigo": REGIME.get(texto(linha["foroptsim"]) or "", 1),
    }
