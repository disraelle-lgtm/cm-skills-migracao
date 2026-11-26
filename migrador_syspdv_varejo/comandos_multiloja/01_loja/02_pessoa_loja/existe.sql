-- Loja que JA EXISTE no VarejoFacil com este codigo (ex.: lojas criadas e configuradas na implantacao) e MANTIDA como
-- esta: nenhuma coluna comparada = "sem alteracao" (a configuracao da implantacao nao e sobrescrita pelo SysPDV).
-- O validar.sql ja garantiu que o codigo e desta loja (mesmo CNPJ).
SELECT loj_codigo FROM pessoa_loja WHERE loj_codigo = %(loj_codigo)s
