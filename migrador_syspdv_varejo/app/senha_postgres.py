"""
Confere usuario e senha do PostgreSQL mesmo quando o servidor nao pede senha.

Quando o pg_hba.conf usa o metodo "trust" (comum em instalacao local), o PostgreSQL aceita a
conexao com QUALQUER senha (ate vazia) e o migrador nao fica sabendo. Por isso:
  1. se o servidor usou a senha para autenticar (con.pgconn.used_password), ela ja foi validada;
  2. senao, a senha informada e conferida contra a senha GRAVADA do usuario (pg_authid:
     hash SCRAM-SHA-256 ou MD5), do mesmo jeito que o PostgreSQL confere no login.
Senha vazia, errada, ou usuario sem senha definida = erro.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import unicodedata


class SenhaInvalida(Exception):
    pass


def _scram_confere(senha: str, verificador: str) -> bool:
    # formato: SCRAM-SHA-256$<iteracoes>:<salt>$<StoredKey>:<ServerKey>
    try:
        _, resto = verificador.split("$", 1)
        iter_salt, chaves = resto.split("$", 1)
        iteracoes, salt = iter_salt.split(":", 1)
        stored_key, _server_key = chaves.split(":", 1)
        salgada = hashlib.pbkdf2_hmac("sha256", unicodedata.normalize("NFKC", senha).encode("utf-8"),
                                      base64.b64decode(salt), int(iteracoes))
        client_key = hmac.new(salgada, b"Client Key", hashlib.sha256).digest()
        return hmac.compare_digest(hashlib.sha256(client_key).digest(), base64.b64decode(stored_key))
    except Exception:
        return False


def _md5_confere(senha: str, usuario: str, verificador: str) -> bool:
    return hmac.compare_digest("md5" + hashlib.md5((senha + usuario).encode("utf-8")).hexdigest(), verificador)


def validar(con, usuario: str, senha: str) -> None:
    """Levanta SenhaInvalida se a senha nao for a do usuario no PostgreSQL."""
    if not senha:
        raise SenhaInvalida("Informe a senha do PostgreSQL.")
    if getattr(con.pgconn, "used_password", False):
        return                                   # o proprio PostgreSQL conferiu a senha
    try:
        linha = con.execute("SELECT rolpassword FROM pg_authid WHERE rolname = current_user").fetchone()
        con.rollback()
    except Exception:
        con.rollback()
        raise SenhaInvalida(
            "Este PostgreSQL esta aceitando conexoes SEM conferir a senha (metodo 'trust' no pg_hba.conf) "
            "e o usuario nao tem permissao para o migrador conferir a senha. Use um usuario administrador "
            "(ex.: postgres) ou troque o metodo para scram-sha-256 no pg_hba.conf.")
    verificador = linha[0] if linha else None
    if not verificador:
        raise SenhaInvalida(f"O usuario '{usuario}' nao tem senha definida no PostgreSQL "
                            "(ALTER USER ... PASSWORD '...').")
    ok = (_scram_confere(senha, verificador) if verificador.startswith("SCRAM-SHA-256$")
          else _md5_confere(senha, usuario, verificador) if verificador.startswith("md5")
          else False)
    if not ok:
        raise SenhaInvalida("Senha do PostgreSQL incorreta.")
