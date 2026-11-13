"""Aprovação HUMANA dos pedidos do MCP (migração, simulação e ajuste de códigos).

Rode num terminal interativo, pelo usuário:   aprovar.bat [CODIGO]

O Claude não tem como executar isto: o script exige um terminal interativo (teclado de verdade)
e uma frase de confirmação digitada por você. Cada aprovação vale para UM pedido, UMA execução.
"""
from __future__ import annotations

import argparse
import getpass
import sys

import aprovacoes


def mostrar(p: dict, saida=print) -> None:
    r = p["resumo"]
    barra = "=" * 72
    saida(barra)
    saida(f" PEDIDO {p['id']}  —  {r['titulo']}")
    if r.get("real"):
        saida(" >>> ESTE PEDIDO GRAVA NO BANCO DE DESTINO <<<")
    saida(barra)
    saida(f" Criado : {aprovacoes.iso(p['criado_em'])}    Vale até: {aprovacoes.iso(p['expira_em'])}")
    if "origem" in r:
        o = r["origem"]
        saida(f" ORIGEM : {o['nome']} ({o['tipo']})  {o['servidor']}  banco {o['banco']}")
    d = r["destino"]
    saida(f" DESTINO: {d['nome']}  {d['servidor']}  banco {d['banco']}  (usuário {d['usuario']})")
    saida("")
    saida(" Itens pedidos:")
    for i in r["itens_escolhidos"]:
        saida(f"   - {i['id']}  {i['nome']}")
        if i.get("descricao"):
            saida(f"       {i['descricao']}")
    if r.get("itens_automaticos"):
        saida("")
        saida(" Itens AUTOMÁTICOS que entram junto (não foram escolhidos, o migrador os inclui):")
        for i in r["itens_automaticos"]:
            saida(f"   - {i['id']}  {i['nome']}")
            if i.get("descricao"):
                saida(f"       {i['descricao'][:400]}")
    saida("")
    saida(f" Etapas no total: {r.get('etapas_total')}")
    if r.get("opcoes"):
        saida(" Opções: " + ", ".join(f"{k}={'sim' if v else 'não'}" for k, v in r["opcoes"].items()))
    if r.get("arquivos_de_codigos"):
        for k, v in r["arquivos_de_codigos"].items():
            saida(f" Arquivo ({k}): {v}")
    if r.get("previa"):
        saida(f" Prévia: {r['previa']}")
    if r.get("avisos"):
        saida("")
        saida(" ATENÇÃO:")
        for a in r["avisos"]:
            saida(f"   * {a}")
    saida(barra)


def aprovar_interativo(pedido_id: str, entrada=input, saida=print) -> int:
    p = aprovacoes.carregar(pedido_id)
    if p["estado"] != aprovacoes.PENDENTE:
        saida(f"O pedido {p['id']} está '{p['estado']}': não há o que aprovar.")
        return 1
    mostrar(p, saida)
    frase = p["resumo"]["frase_confirmacao"]
    resposta = entrada(f'Para APROVAR digite exatamente  {frase}  (ENTER para cancelar): ').strip()
    if not resposta:
        saida("Cancelado. Nada foi aprovado.")
        return 1
    if resposta != frase:
        saida("A frase não confere. Nada foi aprovado.")
        return 1
    aprovacoes.aprovar(p["id"], getpass.getuser())
    saida(f"APROVADO. Avise o Claude para executar o pedido {p['id']} (vale uma única vez, até {aprovacoes.iso(p['expira_em'])}).")
    return 0


def listar_pendentes(saida=print) -> list[dict]:
    pend = aprovacoes.listar((aprovacoes.PENDENTE,))
    if not pend:
        saida("Nenhum pedido pendente.")
    for p in pend:
        saida(f"  {p['id']}  {p['resumo']['titulo']}  (vale até {aprovacoes.iso(p['expira_em'])})")
    return pend


def main(argv: list[str] | None = None, entrada=input, saida=print, interativo: bool | None = None) -> int:
    ap = argparse.ArgumentParser(description="Aprova ou recusa pedidos do MCP do migrador.")
    ap.add_argument("pedido", nargs="?", help="código do pedido (ex.: A3F09C); sem ele, lista os pendentes")
    ap.add_argument("--recusar", action="store_true", help="recusa o pedido em vez de aprovar")
    args = ap.parse_args(argv)
    try:
        if args.recusar and args.pedido:
            aprovacoes.recusar(args.pedido, getpass.getuser())
            saida(f"Pedido {args.pedido.upper()} recusado.")
            return 0
        if interativo is None:
            interativo = sys.stdin.isatty() and sys.stdout.isatty()
        if not args.pedido:
            pend = listar_pendentes(saida)
            if not pend or not interativo:
                return 0
            args.pedido = entrada("Código do pedido a analisar (ENTER para sair): ").strip()
            if not args.pedido:
                return 0
        if not interativo:
            saida("Aprovar só funciona num terminal interativo, digitado por uma pessoa. Abra o terminal e rode aprovar.bat.")
            return 2
        return aprovar_interativo(args.pedido, entrada, saida)
    except aprovacoes.ErroAprovacao as e:
        saida(f"Erro: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
