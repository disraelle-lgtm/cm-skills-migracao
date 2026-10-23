# Migração Virada

A aba **"Migração Virada"** roda **os mesmos itens da migração inicial** (pasta `comandos/`), com o
**de-para de códigos**. Esta pasta guarda só o que é exclusivo da virada.

## Como usar

1. Na seção **4. Consultar códigos**, depois da migração inicial, o ajuste gera as planilhas
   `cod_novo_cod_antigo_<cliente|produto>_todos_<banco>.csv` (botão Download).
2. Na aba **Migração Virada**, anexe em **Códigos de clientes** e/ou **Códigos de produtos** a planilha
   `..._todos_...csv` correspondente. Só o de produtos mudou? Anexe só ele: os clientes rodam como na
   migração inicial.
3. Marque os itens e inicie (a tela pede confirmação antes de gravar).

## O que o de-para faz

- Todo item que usa código de cliente ou de produto (declarado com `"depara"` no `modulo.json`)
  troca o código do SysPDV pelo código novo do VarejoFácil antes de gravar.
- **Cliente/Produto que não está na planilha** (cadastrado no SysPDV depois da inicial):
  - balança: mantém o código;
  - código válido (1 a 999998) que não é de outro registro pela planilha: mantém;
  - EAN (≥ 999999) ou código de outro registro: **próximo código vago e válido** (produtos a partir de
    10001; clientes a partir de 1) — nunca o EAN;
  - virada repetida: o produto reaproveita o código da troca anterior (alteração de produto do SPED)
    e o cliente o código do cliente com o mesmo CPF/CNPJ — rodar de novo não duplica.
- `20_virada_codigos_produto` (automático, logo depois do Produto): o EAN antigo dos produtos novos que
  ganharam código vira **código de barras** (como no ajuste do kit) e as trocas novas entram na
  alteração de produto do SPED com a **data de exportação de hoje**; as alterações anteriores (ex.: da
  primeira migração) são **mantidas com as datas delas** — mesmo padrão do ajuste de códigos do kit.
  (O "Insert SPED" do Pentaho apagava a tabela inteira e perdia essas datas.)
- A relação de códigos fica numa tabela temporária da conexão (`mapa_codigos`), que some no fim.
- No fim, a tela oferece as planilhas `virada_cod_novo_cod_antigo_<tipo>_todos|alterados_<banco>.csv`.

## Diferenças em relação ao migrador de virada do Pentaho

- Os caminhos dos CSV estavam fixos nos `.ktr` (pastas de técnicos e clientes diferentes): aqui o
  arquivo é anexado na tela.
- Produto novo recebia código de um contador fixo (38221340, acima de 999999 — quebra o VarejoFácil):
  aqui recebe o próximo código vago e válido.
- `proforlin = 'N'` fixo: aqui segue a opção "Incluir produtos fora de linha".
- Contas a Receber da virada não estava ligado ao `Migrador_virada.kjb`: aqui é o item normal, com
  de-para do cliente.
