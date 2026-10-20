"""
Funcoes de apoio para os arquivos transformar.py dos modulos.

Uso dentro de comandos/<modulo>/transformar.py:

    from app.ajudantes import inteiro, texto, Pular

    def transformar(linha):
        return {"seccod": inteiro(linha["seccod"], "SECCOD"), ...}
"""
from __future__ import annotations

import re
from decimal import Decimal
from typing import Any


class Pular(Exception):
    """Levante Pular("motivo") para nao migrar uma linha (fica como 'pulado' no relatorio)."""


def inteiro(valor: Any, campo: str = "codigo") -> int:
    """'001 ' -> 1. Vazio ou nao numerico vira erro daquela linha no relatorio."""
    t = valor.strip() if isinstance(valor, str) else valor
    if t in (None, ""):
        raise ValueError(f"{campo} vazio")
    try:
        return int(t)
    except (TypeError, ValueError):
        raise ValueError(f"{campo} nao numerico: {valor!r}") from None


def texto(valor: Any, maiusculo: bool = False, vazio: str | None = None,
          tamanho: int | None = None) -> str | None:
    """TRIM; opcionalmente MAIUSCULO; se ficar vazio usa `vazio`; corta em `tamanho`."""
    t = "" if valor is None else str(valor).strip()
    if maiusculo:
        t = t.upper()
    if not t:
        return vazio
    return t[:tamanho] if tamanho else t


def numero(valor: Any, padrao: float | None = None) -> Decimal | None:
    """Valores monetarios/quantidades: '1.234,50' ou 1234.5 -> Decimal('1234.50')."""
    if valor in (None, ""):
        return None if padrao is None else Decimal(str(padrao))
    if isinstance(valor, (int, float, Decimal)):
        return Decimal(str(valor))
    t = str(valor).strip().replace(".", "").replace(",", ".") if "," in str(valor) else str(valor).strip()
    return Decimal(t)


def so_digitos(valor: Any) -> str | None:
    """CPF/CNPJ/CEP/telefone: mantem so os numeros."""
    if valor is None:
        return None
    d = re.sub(r"\D", "", str(valor))
    return d or None
