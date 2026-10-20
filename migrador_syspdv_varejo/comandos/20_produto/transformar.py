"""
Regras do T-Produto_inicial (Pentaho), na ordem dos passos:
  String operations (TRIM; MAIUSCULO nas unidades) -> Null if -> Select values (tipos)
  -> Replace in string (NCM sem ponto) -> Add constants -> 11 Value Mappers -> If null
  -> String operations 2 (NCM com zeros a esquerda ate 8) -> Insert/Update.
Tambem aplica aqui as correcoes do "Ajusta Produto" e do "Produto higieniza Loccod" que mexem
nos mesmos campos, para que rodar de novo nao fique "atualizando" o que os ajustes ja corrigiram.
"""
from datetime import date

from app.ajudantes import inteiro, texto

# ---- "Null if" do Pentaho: estes valores viram vazio (NULL).
# ATENCAO: marca 3/6 e local 1/2/97 podem ser sobra de outro cliente - confirmar.
MARCA_VIRA_NULO = {"0", "3", "6"}
LOCAL_VIRA_NULO = {"0", "1", "2", "97"}


def _s(v):
    """Valor como texto sem tratamento (None continua None)."""
    return None if v is None else str(v)


def _mapear(valor, mapa, padrao=None):
    """Value Mapper do Kettle: vazio usa a entrada '' do mapa (se houver); valor sem
    correspondencia vira o padrao (se houver) ou continua como esta."""
    if valor is None or valor == "":
        return mapa.get("", None)
    if valor in mapa:
        return mapa[valor]
    return padrao if padrao is not None else valor


def _int_ou_nulo(valor):
    t = texto(valor)
    return int(t) if t else None


def _nulo_se(valor, proibidos):
    t = texto(valor)
    return None if t is None or t in proibidos else t


def transformar(linha):
    hoje = date.today()
    procod = inteiro(linha["procod"], "PROCOD")
    prodes = texto(linha["prodes"]) or "SEM DESCRICAO"
    prounid = (texto(linha["prounid"]) or "UN").upper()
    ncm = (_s(linha["proncm"]) or "").replace(".", "").strip()
    ncm = ncm.rjust(8, "0") if ncm else None

    propesvar = texto(linha["propesvar"]) or "N"
    if propesvar == "0":                                   # higieniza: '0' = 'N'
        propesvar = "N"
    if prounid == "KG":                                    # Ajusta Produto: KG e pesavel
        propesvar = "S"

    proenvbal = _mapear(texto(linha["proenvbal"]), {" ": "N", "": "N"}) or "N"
    if propesvar == "S":                                   # Ajusta Produto
        proenvbal = "S"

    proiteemb = linha["proiteemb"] if linha["proiteemb"] not in (None, 0) else 1      # If null + higieniza
    proiteembvda = linha["proiteembvda"] if linha["proiteembvda"] not in (None, 0) else 1
    propesbrt = linha["propesbrt"] if linha["propesbrt"] not in (None, 0) else 1      # Ajusta Produto
    propesliq = linha["propesliq"] if linha["propesliq"] not in (None, 0) else 1
    proestmin = linha["proestmin"] if linha["proestmin"] != 0 else None              # Ajusta: 0 = NULL
    proestmax = linha["proestmax"] if linha["proestmax"] != 0 else None

    proctrest = _mapear(_s(linha["proctrest"]), {" ": "N", "": "N"})
    if proctrest in (None, "N"):                           # Ajusta Produto: nulo ou N = S
        proctrest = "S"

    proesp = texto(linha["proesp"]) or "N"
    proesp = "N" if proesp == "0" else proesp              # higieniza
    procomp = _mapear(texto(linha["procomp"]), {"S": "C"}) or "N"
    natcodigo = _int_ou_nulo(linha["natcodigo"])
    proforlin = _s(linha["proforlin"]) or "N"
    proundfun = _s(linha["proundfun"])
    proprcvar = _s(linha["proprcvar"])
    proprcvar = "N" if proprcvar in (None, "0") else proprcvar
    protipagr = _s(linha["protipagr"])
    procodanp = _s(linha["procodanp"])
    prodesvar = _s(linha["prodesvar"])
    provld = texto(linha["provld"])

    return {
        "procod": procod,
        "procodint": linha["procodint"],
        "prodes": prodes,
        "prodesrdz": linha["prodesrdz"] if linha["prodesrdz"] is not None else prodes[:20],   # Ajusta
        "seccod": _int_ou_nulo(_nulo_se(linha["seccod"], {"00"})),
        "trbid": _s(linha["trbid"]) or "F00",
        "prounid": prounid,
        "propesvar": propesvar,
        "procomtip": texto(linha["procomtip"]) or "N",
        "procomcap": linha["procomcap"],
        "procompro": linha["procompro"],
        "procomven": linha["procomven"],
        "provld": provld if provld else 0,                                        # Ajusta: nulo = 0
        "profrtloj": _mapear(_s(linha["profrtloj"]), {" ": "N"}) or "N",          # Ajusta: nulo = N
        "proestmin": proestmin,
        "proestmax": proestmax,
        "proqtdetq": linha["proqtdetq"],
        "pronumser": _s(linha["pronumser"]) or "N",                               # Ajusta
        "proflgalt": linha["proflgalt"],
        "protaba": _mapear(_s(linha["protaba"]), {" ": "0", "": "0"}) or 0,       # Ajusta: nulo = 0
        "probontip": texto(linha["probontip"]) or "P",
        "probonfat": linha["probonfat"],
        "proctrest": proctrest,
        "proesp": proesp,
        "procomp": procomp,
        "proctrvld": _mapear(_s(linha["proctrvld"]), {" ": "N", "": "N"}) or "N",
        "proenvbal": proenvbal,
        "prodatcadinc": linha["prodatcadinc"] or hoje,                              # Ajusta: nulo = hoje
        "prodatcadalt": hoje,                                                       # Ajusta: sempre hoje
        "funcod": 1,                                                                # Add constants
        "prodesvar": "N" if prodesvar in (None, " ") else prodesvar,               # Ajusta
        "proend": linha["proend"],
        "grpcod": _int_ou_nulo(_nulo_se(linha["grpcod"], {"000"})),
        "sgpcod": _int_ou_nulo(_nulo_se(linha["sgrcod"], {"000"})),                # no VarejoFacil e sgpcod
        "proiteemb": proiteemb,
        "procstmed": linha["procstmed"],
        "proqtdmaxvda": linha["proqtdmaxvda"],
        "propesbrt": propesbrt,
        "propesliq": propesliq,
        "proforlin": proforlin,
        "prodatforlin": hoje if proforlin == "S" else linha["prodatforlin"],       # Ajusta
        "proundcmp": (texto(linha["proundcmp"]) or "UN").upper(),
        "loccod": _int_ou_nulo(_nulo_se(linha["loccod"], LOCAL_VIRA_NULO)) or 0,  # Null if + higieniza
        "proundref": proundfun if proundfun is not None else prounid,             # o Pentaho grava PROUNDFUN
        "promedref": linha["promedfun"] if linha["promedfun"] is not None else 1,  # Ajusta: nulo = 1.00
        "protipipi": _mapear(_s(linha["protipipi"]), {" ": "P", "": "P"}) or "P",
        "provlragr": linha["provlragr"],
        "protipagr": None if protipagr == " " else protipagr,                      # Ajusta
        "proprcvar": proprcvar,
        "proiat": _mapear(texto(linha["proiat"]), {"A": "A", "T": "T"}) or "A",
        "proippt": _mapear(texto(linha["proippt"]), {"P": "P", "T": "T"}, padrao="T") or "P",
        "proncm": ncm,
        "profin": texto(linha["profin"]) or "1",
        "pro_modelo": linha["pro_modelo"],
        "mar_codigo": _int_ou_nulo(_nulo_se(linha["pro_mar_codigo"], MARCA_VIRA_NULO)),
        "proipi": linha["proipi"],
        "proinczf": _mapear(_s(linha["proinczf"]), {" ": "N", "": "N"}) or "N",
        "properpda": linha["properpda"],
        "proncmexc": _nulo_se(linha["proncmexc"], {"00"}),
        "proiteembvda": proiteembvda,
        "procodanp": None if procodanp == " " else procodanp,                      # Ajusta
        "gencodigo": int(ncm[:2]) if ncm else None,                               # Ajusta: 2 primeiros do NCM
        "natcodigo": natcodigo if natcodigo != 0 else None,                       # Ajusta: 0 = NULL
        "pro_compoe_total_nota_fiscal": True,
        "procest": _int_ou_nulo(_nulo_se(linha["procest"], {"Escolha"})),
        "prod_bloqueado_compra": False,
        "pro_permite_desconto": texto(linha["properdcn"]) == "S",                  # S = true, resto false
        "procodorigem": linha["procodorigem"],
        "proiteembtrs": 1,
        "prod_dias_seguranca": 0,
    }
