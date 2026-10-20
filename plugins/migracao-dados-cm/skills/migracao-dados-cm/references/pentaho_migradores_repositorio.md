# Repositório de Migradores Pentaho — Estrutura Real

> Fonte: `migracao-main/ferramentas/migrador/WebRoot/kettle-scripts/` (repositório interno).
> Este documento cataloga apenas a **estrutura organizacional** dos migradores (nomes de
> pastas e jobs) — nenhuma credencial de banco, IP interno ou dado de cliente foi copiado
> para este arquivo.

> ⚠️ **Nunca copie o conteúdo da pasta `.kettle/`** desse repositório (arquivos
> `kettle.properties`, `kettle_bkp.properties`, `db.cache-*`, `repositories.xml`,
> `shared.xml`) para nenhum lugar fora do ambiente de trabalho protegido — esses arquivos
> contêm credenciais reais de banco de dados (usuário/senha) e endereços IP internos.
> Os próprios arquivos `.kjb`/`.ktr` dos migradores **não** têm credenciais embutidas —
> eles usam variáveis (ex.: `${VAREJOFACIL_DATABASE_HOST}`, `${VAREJOFACIL_DATABASE_PASS}`)
> que são resolvidas a partir do `kettle.properties` local de cada máquina.

## Pastas de primeiro nível (migradores por par de sistemas)

| # | Pasta | Par de sistemas |
|---|---|---|
| 1 | `1 - Migrador Syspdv-Varejo(Firebird)` | SysPDV (Firebird) → VarejoFacil |
| 2 | `2 - Migrador Syspdv-Varejo(SQL Server)` | SysPDV (SQL Server) → VarejoFacil |
| 3 | `3 - Migrador Varejo-Varejo` | VarejoFacil → VarejoFacil (loja para loja / link para link) |
| 4 | `4 - Migrador Milenio-Milenio (SQL Server)` | Milênio → Milênio |
| 5 | `5 - Migrador Syspdv-Milenio(Firebird)` | SysPDV (Firebird) → Milênio |
| 7 | `7 - Migrador Milenio-Varejo` | Milênio → VarejoFacil |
| 8 | `8 - Migrador EasyAssist-Varejo` | EasyAssist → VarejoFacil |
| 9 | `9 - Migrador Syspdv - Syspdv (Firebird)` | SysPDV → SysPDV |
| 10 | `10 - Migrador Produto Valida Ean (Ajustavel)` | Utilitário de validação de EAN de produtos |
| 11 | `11 - Layout_outros-sistemas` | Layouts de referência para sistemas de terceiros |

Outras pastas de apoio no mesmo nível: `Ajustes`, `BaseModeloAtualizacao`, `Milenio-Milenio`,
`Milenio-Varejofacil`, `Sistema-ALFAMAQ`, `SysPDV-Firebird`,
`SysPDV-Firebird-AlterandoCodigoProduto`,
`SysPDV-Firebird-ViradaComTrocaDeCodigoProduto_e_Cliente`, `SysPDV-SQLServer`,
`SysPDV-SQLServer-AlterandoCodigoProduto`,
`SysPDV-SQLServer-ViradaComTrocaDeCodigoProduto_e_Cliente`, `Varejo-Syspdv`, `libs`,
`multi-loja`, `multi-lojaV2`, `multi-lojaV3`, `outros-sistemas` (subpastas: `AjusteNfe`,
`B2B`, `CSV`, `Grandcru`, `Syspdv`, `Varejofacil`, `WEBSIB`), `scprits_migracao`, `validador`.

Em uma revisão mais recente do mesmo repositório, também foram observadas as pastas:
`Layout-Milenio`, `Mobility`, `NCM`, `contas`, `varejofacil` (minúsculo, distinta de
`Varejo-Syspdv`), `Transformations Descontinuadas`, além de transformações (`.ktr`)
soltas na raiz como `atualiza_preco.ktr`, `T_EANsNoProcod_lista_Syspdv.ktr`,
`UpdateClicodibgeCliente_Syspdv.ktr`, `UpdateForcodibgeFornecedor_Syspdv.ktr` e alguns
arquivos de teste (`teste.ktr`, `teste_tratamento_clientes.ktr`,
`teste_tratamento_fornecedor.ktr`).

> O conteúdo completo desse repositório (>10.000 arquivos) não foi copiado para a
> skill — só o catálogo de nomes de pastas acima, que é seguro. Arquivos `.ktr`/`.kjb`
> individuais podem, em alguns casos, conter conexões com detalhes embutidos (diferente
> do padrão por variável visto nos `.kjb` já auditados), então qualquer arquivo
> específico desse repositório só deve ser trazido para a skill depois de conferido
> individualmente.

> É dentro de `outros-sistemas` e das pastas `SysPDV-*` / `Milenio-*` que ficam os
> migradores específicos de sistemas de terceiros (os "114 SysPDV / 156 VarejoFacil"
> mencionados no processo oficial).

## Fluxo real de execução — `1 - Migrador Syspdv-Varejo(Firebird)`

O job orquestrador `1 - Migrador_Syspdv-Varejo.kjb` executa, em sequência:

```
START → Migrador Inicial (job) → Migrador Virada (job) → Success
```

**`Migrador_Inicial.kjb`** (confirma e refina a ordem de módulos já documentada):

```
START → Cadastros → Estoque → Conta Receber → Conta Pagar
      → Success → (Insert Item Configuração Lançamento Financeiro) → Relatorio Padrão
```

Onde `Cadastros` (`JOB-Migracao_inicial-Cadastros.kjb`) engloba, internamente, os
sub-jobs de Loja, Pessoas (Cliente/Fornecedor/Funcionário/Agente Financeiro), Produto,
NCM/Tributação e Cenário Fiscal — antes de seguir para Estoque e Financeiro.

**Sub-jobs "_inicial" disponíveis** (carga inicial, executados dentro de `Cadastros`,
`Estoque` etc.):
`JOB-Loja_inicial`, `JOB-Cliente_inicial`, `JOB-Fornecedor_inicial`,
`JOB-Funcionario_inicial`, `JOB-Agente_inicial`, `JOB-Produto_inicial`,
`JOB-Produto_Fornecedor_inicial`, `JOB-Classificacao_Produtos_inicial`,
`JOB-NCM_inicial`, `JOB-Reforma_Tributaria_inicial`, `JOB-Pessoas_inicial`,
`JOB-Estoque_inicial`, `JOB-MovimentacaoEstoque_inicial`,
`JOB-Movimentacao_de_Custo_inicial`, `JOB-Encarte_inicial`, `JOB-TituloPagar_inicial`,
`JOB-TituloReceber_inicial`.

**Sub-jobs "_virada" disponíveis** (rodados na atualização final antes da virada de loja —
confirma exatamente quais entidades são reatualizadas nessa etapa):
`JOB-Cliente_virada`, `JOB-Encarte_virada`, `JOB-Estoque_virada`,
`JOB-MovimentacaoEstoque_virada`, `JOB-Pessoas_virada`, `JOB-Produto_virada`,
`JOB-Produto_fornecedor_virada`, `JOB-TituloReceber_virada`, além do orquestrador
`JOB-Migracao_Cadastros_virada`.

Outros jobs auxiliares na mesma pasta: `JOB-Cenario_Fiscal_NCM`,
`JOB-Cenario_Fiscal_Operacao`, `JOB-Cenario_Fiscal_Produto`, `JOB-NCM_Tributacao`,
`JOB-Loja` (variante sem sufixo, usada em alguns fluxos de atualização),
`JOB-Estoque` (idem), `JOB-Relatorio_Padrão` (gera o relatório padrão final da migração).

## Uso pela skill

Ao ajudar com um script ou dúvida técnica, use esta estrutura para:
- Confirmar se já existe um migrador pronto para o par de sistemas em questão (consulte a
  tabela de pastas de primeiro nível) antes de sugerir criar um do zero.
- Explicar a ordem real de execução (Cadastros → Estoque → Financeiro) citando os nomes
  reais dos jobs quando for útil para o usuário localizar o arquivo certo.
- Diferenciar claramente jobs "_inicial" (primeira carga) de jobs "_virada" (atualização
  final antes da loja virar para o sistema principal) — são fluxos e arquivos diferentes.


---

## Achados na revisão do migrador "1 - Migrador Syspdv-Varejo(Firebird)" (out/2026)

Encontrados ao converter os `.ktr`/`.kjb` para o migrador Python
(`references/migrador_python_syspdv_varejo.md`). Valem para quem ainda usa o Pentaho:

| Onde | Achado | Impacto |
|---|---|---|
| `T-Funcionario-Loja_inicial` | filtro fixo `loj_codigo = 3` (comentário "estava inserindo os funcionários da loja 03") | sobra de outro cliente: pode pular funcionários sem motivo |
| `JOB-Pessoas_inicial` → "VF - Corrige IE Duplicada" | `pes_codigo != 21` fixo | sobra de outro cliente (a pessoa da loja dele) |
| `JOB-Funcionario_inicial` | insert usa `sq_funcionario_loja`; o ajuste final usa `sq_pessoa_funcionario_loja` | dois nomes de sequence no mesmo fluxo — conferir no banco |
| Funcionário, Cliente, Agente | pessoa localizada por coluna temporária (`*_codigo_syspdv`) apagada no fim do job | rodar o job de novo cria pessoas duplicadas |
| `T-Cliente-*` | clientes com o mesmo CPF/CNPJ: só o último fica ligado à pessoa | o primeiro cliente se perde sem aviso |
| Impostos Federais | o Insert/Update gera os 4 IDs (geral/atacado/simples/varejo) de novo a cada execução e o SQL "VF - Imposto Federal Geral" não tem NOT EXISTS | segunda execução desencontra IDs / erro de chave duplicada |
| SQLs "FB - Ajuste ..." | fazem UPDATE no banco do SysPDV | alteram a origem do cliente (rodar sempre numa cópia do .fdb) |
| `T-Produto_inicial` | filtro `proforlin = 'N'` comentado | produtos fora de linha são migrados |
| `JOB-Produto_inicial` → "Ajusta Produto" | `update pesquisa_satisfacao ... where id = 3` no meio dos ajustes de produto | sobra de outro cliente |
| "Ajusta Produto" | `WHERE itt_icms_desonerado = NULL` | nunca é verdadeiro no PostgreSQL: a linha não faz nada |
| `T-Produto_inicial` → Null if | marca 0/3/6 e local 0/1/2/97 viram NULL | possível sobra de cliente (a confirmar) |
| `T-ProdutoAuxiliar_inicial` | `proauxcodigoean` = 13 primeiros caracteres do código completado até 14 | corta o último dígito de um EAN-13 (a confirmar) |
| "VF - Limpeza nos EAN's" | `CAST(procodaux AS BIGINT)` em todos os códigos | pode dar erro com código LITERAL com letras |
| `T-ProdutoFornecedor_inicial` | Merge Join do `FORCGC` (com máscara) com `pes_num_documento` (só dígitos) | com máscara nada liga: as referências do fornecedor somem |
| "Imp fed duplicidade", "VF - Limpa Duplicidade" (fornecedor) | só SELECT dentro de Execute SQL | não fazem nada |
| `T-ItemTabelaTributaria2_inicial` | chave do Insert/Update `itt_id IS NULL` | duplica os itens a cada execução |
| `T-Produto_Kit_inicial` | `comp_id` com Update = Y (nova sequence a cada execução) | componentes já gravados ficam sem composição |
| "FB - Ajuste Seção / Unidade", "FB - Ajustes campos estourados" | UPDATE no banco do SysPDV | alteram a origem do cliente |
| `JOB-Encarte_inicial` → "Insert Programação de Preço" | `id NOT IN (SELECT id_produto_encarte FROM programacao_preco)` | com um `id_produto_encarte` nulo na tabela, não cria nenhuma programação |
| `T-Encarte-Produto`, `T-MovimentacaoEstoque_*`, `T-Movimentacao_de_Custo`, `T-Custo_Dia`, `T-Auditoria_Custo` | `proforlin = 'N'` fixo | produtos fora de linha nunca entram (sem opção) |
| `T-Cenario_fiscal_ncm_loja`, `T-cenario_fiscal_produto_loja` | loja = constante 1 | errado se a loja matriz não for a 1 |
| "VF - Zerar todo o estoque" | `loj_codigo = 1` fixo; gera ajuste de 0 para produto sem saldo | errado se a matriz não for a 1; histórico cresce a cada execução |
| `T-Cadastro-de-operacoes_inicial` | 24 INSERTs com código fixo, sem verificação | 2ª execução: chave duplicada |
| `T-Movimentacao_de_Custo`, `T-Custo_Dia` | chave do Insert/Update = próprio id da sequence | duplica a cada execução |
| `T-Movimentacao_de_Custo` | `moc_custo_medio` ← CUSTO_FISCAL (no custo_dia vai o médio) | usuário confirmou manter assim |
| `JOB-Reforma_Tributaria_inicial` → "Cenario Fiscal Operação" | job sem entradas | não faz nada |
| `T-ContaReceber_inicial` (versão nova do usuário) | Merge Join trocado para CLICOD = cli_codigo, mas os Sort rows continuam ordenando pelo documento | o Merge Join exige a mesma ordenação: pode perder títulos sem aviso |
| `T-TituloReceber_Parcial_inicial` | título parcial ligado à conta pelo número do documento (Join Rows CTRNUM = ctr_num_documento) | título aberto de outro cliente com o mesmo número vira "parcialmente liquidado" |
| `T-MovimentacaoTituloReceber_Parcial_inicial`, `T-MovimentacaoTituloPagar_inicial` | chave com o mov_id da sequence | duplica as liquidações a cada execução (e o Panamá recebe pagamentos em dobro) |
| `T-MovimentacaoTituloPagar_inicial` | título ligado à conta por `ttlp_valor = ctp_valor_nominal` | contas de mesmo valor trocam a data de emissão |
| `T-ContaPagar_inicial` | constante `cfnc_codigo = 32` não usada (categoria vinha do PLCRED); FORCGC convertido em número | usuário passou a usar o 32; CNPJ com máscara dá erro |
| JOBs de título → "VF - Ajusta Sequence" / "Atualiza Sequence" | documento vazio = id preenchido depois de gravar | uma 2ª execução não acha a conta pelo documento e duplica |
| "VF - Insert Panama" (receber e pagar) | enfileira os títulos a cada execução | substituído pelo `InsertFilaPanama.sql` do usuário no fim da migração |
| `T-CriaEspecieDocumentoPadrao_TituloPagar_inicial` | SQL todo comentado | não faz nada |
