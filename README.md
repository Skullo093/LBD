# LeadForge — Projeto e Arquitetura de Banco de Dados 
Banco de dados do **LeadForge**, um copiloto comercial para freelancers de desenvolvimento web que prospectam negócios locais com apoio de inteligência artificial. O sistema descobre empresas por nicho e cidade, audita o site de cada uma, pontua a oportunidade e gera uma sugestão de abordagem revisada pelo usuário.
Projeto prático da disciplina de Banco de Dados — Tecnologia em Análise e
Desenvolvimento de Sistemas, FATEC Sorocaba.
| Integrante | Papel |
| --- | --- |
| Allan Batista | Líder do grupo, Scrum Master e desenvolvedor |
| Murillo Lourenço | Product Owner e desenvolvedor |
| Bruno Rocha | Desenvolvedor |
|Código da aplicação | [github.com/Skullo093/prjLeadForge](https://github.com/Skullo093/prjLeadForge) |
## Conteúdo do repositório
| Arquivo | O que contém |
| --- | --- |
| `DOCUMENTO_PROJETO_ARQUITETURA_BD.md` | Contexto, regras de negócio, dicionário de dados, normalização e justificativa de cada recurso avançado |
| `docs/diagrams/der/der_leadforge.png` | Diagrama Entidade-Relacionamento (fonte PlantUML em `der.plant`) |
| `Scripts SQL/01_ddl_estrutura.sql` | Schema `leadforge`, 10 tabelas, chaves, restrições e 4 índices compostos |
| `Scripts SQL/02_dml_carga_inicial.sql` | Carga inicial: usuários, perfis, habilidades, buscas, empresas, evidências e oportunidades |
| `Scripts SQL/03_programacao_avancada.sql` | Views, funções escalares, stored procedures e triggers |
| `Scripts SQL/04_testes_e_transacoes.sql` | Testes dos objetos, transações ACID (COMMIT e ROLLBACK com SAVEPOINT) e EXPLAIN ANALYZE |
| `LeadForge_Apresentacao_BancoDeDados.pptx` / `.pdf` | Slides da apresentação |
| Video de apresentação | https://youtu.be/FaYUZevUwNU |

## Como executar

**Requisito:** PostgreSQL 17 ou superior com pgAdmin 4. Os scripts devem ser executados rigorosamente nesta ordem:

1. `Scripts SQL/01_ddl_estrutura.sql`
2. `Scripts SQL/02_dml_carga_inicial.sql`
3. `Scripts SQL/03_programacao_avancada.sql`
4. `Scripts SQL/04_testes_e_transacoes.sql`

Siga os passos na ordem abaixo:

1. **Criar o banco de dados:**
   * Abra o **pgAdmin 4** e conecte-se ao seu servidor PostgreSQL no painel lateral esquerdo (**Servers**).
   * Clique com o botão direito em **Databases** $\rightarrow$ **Create** $\rightarrow$ **Database...**
   * Em **Database**, informe o nome `leadforge_db` e clique em **Save**.

2. **Abrir o Query Tool:**
   * Clique com o botão direito sobre o banco `leadforge_db` criado e selecione **Query Tool**.

3. **Executar os scripts de estrutura, carga e programação avançada:**
   * Clique no ícone de pasta (**Open File** / `Ctrl + O`) na barra superior do Query Tool.
   * Selecione `Scripts SQL/01_ddl_estrutura.sql` e clique em **Execute** (`F5`). *(O script cria automaticamente o schema `leadforge` do zero).*
   * Repita o mesmo processo para `Scripts SQL/02_dml_carga_inicial.sql` (`F5`).
   * Repita o mesmo processo para `Scripts SQL/03_programacao_avancada.sql` (`F5`).

4. **Executar o script de testes e transações (`04_testes_e_transacoes.sql`):**
   * Abra `Scripts SQL/04_testes_e_transacoes.sql` no Query Tool.
   * Como o pgAdmin interrompe a execução ao encontrar o erro proposital de chave estrangeira no **Cenário 2**, execute o arquivo em duas etapas:
     1. **Primeira parte:** Selecione do início do arquivo até a linha `VALUES (99999, 'Teste de falha', 'Teste de falha', CURRENT_TIMESTAMP);` (dentro do Cenário 2) e aperte **`F5`**. Será exibido o erro esperado de violação da constraint `fk_sugestao_oportunidade` (`SQL state: 23503`).
     2. **Segunda parte:** Selecione da linha `ROLLBACK TO SAVEPOINT antes_abordagem_ia;` até o final do arquivo e aperte **`F5`** para concluir o `ROLLBACK` e visualizar os planos de execução (`EXPLAIN ANALYZE`).
O script 01 recria o schema `leadforge` do zero. O cenário 2 do script 04 provoca um erro de chave estrangeira de propósito, para demonstrar o ROLLBACK.
## Modelo de dados
Dez tabelas normalizadas até a 3FN no schema `leadforge`:
- **Freelancer:** `usuario`, `perfil_freelancer` (1:1), `habilidade` e
`perfil_habilidade` (N:M com nível de proficiência).
- **Prospecção:** `busca`, `empresa` e `evidencia` (sinais técnicos do site,
cada um com grau de certeza).
- **Carteira:** `oportunidade` (N:M entre usuário e empresa),
`sugestao_abordagem` (1:1 com a oportunidade) e `auditoria_oportunidade_log`
(alimentada por trigger).
## Regras de negócio garantidas pelo banco
| Regra | Como o banco garante |
| --- | --- |
| LGPD (REG-01, REG-08) | Somente dados públicos de pessoa jurídica e `CHECK (aceite_lgpd = TRUE)` |
| Carteira sem duplicatas (REG-06) | `UNIQUE (usuario_id, empresa_id)` em `oportunidade` |
| Grau de certeza (REG-02, REG-03) | `CHECK` com domínio fechado: confirmado, sinal_forte, inferencia, desconhecido |
| Isolamento da carteira (REG-09) | `sp_avancar_status_e_registrar_abordagem` valida o dono antes de alterar |
| Revisão humana (RNF-05) | Flags `revisado_usuario` e `foi_editado` em `sugestao_abordagem` |
| Integridade referencial | `CASCADE` em dependentes; `RESTRICT` em `empresa` vinculada a carteiras |
## Programação avançada
| Objeto | Tipo | Função |
| --- | --- | --- |
| `vw_oportunidades_detalhadas` | View | Consolida oportunidade, usuário, empresa, evidências e sugestão em uma consulta (evita N+1) |
| `vw_resumo_prospeccao_nicho_cidade` | View | Métricas por nicho e cidade com `GROUP BY` e `HAVING` |
| `fn_calcular_pontuacao_empresa` | Função | Soma peso técnico × fator de certeza, com teto de 100 pontos |
| `fn_classificar_prioridade_lead` | Função | Classifica em CRÍTICA, ALTA, MÉDIA ou BAIXA |
| `sp_registrar_oportunidade_com_evidencia` | Procedure | Upsert da empresa, registro da evidência, cálculo e vínculo à carteira em uma chamada |
| `sp_avancar_status_e_registrar_abordagem` | Procedure | Valida o dono, avança o funil e grava a sugestão da IA |
| `trg_auditoria_oportunidade` | Trigger | `BEFORE UPDATE`: registra mudança de status e pontuação no log |
| `trg_recalcular_pontuacao_apos_evidencia` | Trigger | `AFTER INSERT/UPDATE/DELETE` em evidência: recalcula a pontuação |
### Fórmula de pontuação
| Evidência com problema | Peso |
| --- | --- |
| Site indisponível ou inexistente | 80 |
| Sem responsividade no celular | 35 |
| Sem HTTPS | 25 |
| Sem botão de WhatsApp | 20 |
| Sem formulário de contato | 15 |
| Sem chamada para ação | 10 |

Fator de certeza: confirmado 1,00 · sinal forte 0,85 · desconhecido 0,80 · inferência 0,60. A soma tem teto de 100 pontos.

Prioridade: **CRÍTICA** a partir de 75 pontos com ao menos um problema confirmado; **ALTA** a partir de 60; **MÉDIA** a partir de 35; **BAIXA** abaixo disso.
