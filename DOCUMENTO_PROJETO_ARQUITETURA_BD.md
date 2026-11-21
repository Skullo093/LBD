# Documento de Projeto e Arquitetura de Banco de Dados — LeadForge

**Projeto / TG:** LeadForge: copiloto comercial para freelancers com prospecção assistida por inteligência artificial  
**Curso:** Tecnologia em Análise e Desenvolvimento de Sistemas — FATEC Sorocaba  
**Equipe:**  
* **Allan Batista** (Líder do Grupo / Scrum Master / Desenvolvedor)  
* **Murillo Lourenço** (Product Owner / Desenvolvedor)  
* **Bruno Rocha** (Desenvolvedor)  

**Repositório Oficial:** `https://github.com/Skullo093/prjLeadForge`  

---

## 1. Contextualização do Projeto

### 1.1. Resumo do Problema de Negócio
Freelancers e pequenos prestadores de serviços digitais (desenvolvedores web, designers, especialistas em SEO) investem uma parcela significativa de horas não faturáveis na prospecção manual de clientes. O processo tradicional envolve pesquisar estabelecimentos em mapas, avaliar sites subjetivamente, manter planilhas desorganizadas e enviar mensagens genéricas com baixa taxa de conversão. As ferramentas convencionais apenas entregam listas de contatos, sem responder à pergunta central: **"Por que esta empresa precisa do meu serviço agora?"**.

### 1.2. Escopo da Aplicação e Público-Alvo
* **Público-alvo:** Freelancers e pequenos estúdios digitais focados inicialmente no módulo de **desenvolvimento web** (criação e reformulação de sites e landing pages) voltados a negócios locais (clínicas, academias, escritórios, restaurantes) em cidades brasileiras.
* **Escopo Funcional:** Cadastro e configuração do perfil técnico do freelancer (`RF-01`), descoberta automatizada de empresas por nicho e cidade via API externa Geoapify (`RF-02`), deduplicação automática (`RF-03`), varredura técnica de evidências públicas em websites (`RF-04`), classificação por grau de certeza (`RF-05`), pontuação e ranqueamento de oportunidades (`RF-06`), geração assistida de explicações e rascunhos de abordagem por IA (`RF-07`, `RF-08`), consulta conversacional à carteira (`RF-09`), gestão de status do funil (`RF-10`) e exportação em CSV/JSON (`RF-11`).

### 1.3. Regras de Negócio Críticas que Impactam Diretamente os Dados
1. **REG-01 e REG-08 (Dados Públicos e LGPD):** O banco armazena exclusivamente dados públicos de pessoas jurídicas (`empresa`) e exige aceite explícito dos termos de uso (`aceite_lgpd = TRUE`) no cadastro do freelancer (`usuario`).
2. **REG-02 e REG-03 (Níveis de Certeza e Ausência de Evidência):** Toda evidência coletada precisa registrar explicitamente um dos quatro graus de certeza (`confirmado`, `sinal_forte`, `inferencia`, `desconhecido`). A ausência de site ou impossibilidade de leitura não é tratada como falha confirmada, mas classificada como `desconhecido`.
3. **REG-04 e RNF-01 (Integridade e Rastreabilidade da IA):** Toda sugestão gerada por IA (`sugestao_abordagem`) deve estar vinculada a uma `oportunidade` concreta e suas respectivas `evidencias`, impedindo alucinações ou dados inventados.
4. **REG-05 e RNF-05 (Intervenção Humana Obrigatória):** O sistema nunca dispara mensagens automaticamente; o banco mantém o controle booleano (`revisado_usuario` e `foi_editado`) antes da utilização pelo freelancer.
5. **REG-06 (Deduplicação na Carteira):** Uma mesma empresa (`empresa_id`) jamais pode aparecer duplicada na carteira de um mesmo freelancer (`usuario_id`), imposto por restrição `UNIQUE (usuario_id, empresa_id)`.
6. **REG-09 e RNF-02 (Isolamento de Carteira por Usuário):** Cada freelancer visualiza e manipula apenas as oportunidades vinculadas ao seu próprio `usuario_id`.

### 1.4. Decisão Arquitetural de SGBD (SQLite em Dev $\to$ PostgreSQL em Produção)
Conforme definido na arquitetura do sistema (Seção 7.6 do Planejamento), a camada de persistência da aplicação utiliza **SQLAlchemy ORM** e migrações via **Alembic**, permitindo utilizar **SQLite** para prototipação rápida local sem servidor e migrar diretamente para **PostgreSQL** sem reescrever o código da aplicação. Como o SQLite não suporta nativamente *Stored Procedures*, funções procedurais em *PL/pgSQL* e *Schemas* isolados, os scripts SQL desta entrega foram implementados no dialeto **PostgreSQL 15+**, garantindo aderência total aos padrões ACID e aos recursos avançados exigidos.

---

## 2. Modelagem Conceitual e Lógica

### 2.1. Diagrama Entidade-Relacionamento (DER)
O modelo lógico foi estruturado no schema `leadforge` com **10 tabelas normalizadas**, contemplando relacionamentos `1:1`, `1:N` e `N:M` resolvidos por entidades associativas (`perfil_habilidade` e `oportunidade`). *(A versão gráfica em alta resolução encontra-se aqui: 👉 [(Der)](docs/der.png)*



### 2.2. Dicionário de Dados Completo

#### Tabela 1: `leadforge.usuario`
Armazena as credenciais de autenticação e consentimento LGPD do freelancer.

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único sequencial do usuário. |
| `nome` | `VARCHAR(120)` | `NOT NULL` | Nome completo do freelancer. |
| `email` | `VARCHAR(150)` | `NOT NULL`, `UNIQUE`, `CHECK` | Endereço de e-mail corporativo ou pessoal usado no login. |
| `senha_hash` | `VARCHAR(255)` | `NOT NULL` | Hash criptográfico da senha (algoritmo `scrypt`). |
| `aceite_lgpd` | `BOOLEAN` | `NOT NULL`, `DEFAULT FALSE`, `CHECK (aceite_lgpd = TRUE)` | Confirmação obrigatória de aceite das diretrizes LGPD. |
| `ativo` | `BOOLEAN` | `NOT NULL`, `DEFAULT TRUE` | Indica se a conta está ativa na plataforma. |
| `criado_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data e hora de criação da conta. |
| `atualizado_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data e hora da última atualização cadastral. |

#### Tabela 2: `leadforge.perfil_freelancer`
Armazena as preferências regionais e de abordagem comercial do profissional (`1:1` com `usuario`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único do perfil profissional. |
| `usuario_id` | `INT` | `NOT NULL`, `UNIQUE`, `FK -> usuario(id)` (`ON DELETE CASCADE`) | Chave estrangeira exclusiva vinculando o perfil ao usuário. |
| `cidade` | `VARCHAR(100)` | `NOT NULL` | Cidade base de atuação do freelancer (ex.: Sorocaba). |
| `estado` | `CHAR(2)` | `NOT NULL`, `CHECK (CHAR_LENGTH(TRIM(estado)) = 2)` | Sigla da Unidade Federativa (UF). |
| `tom_comunicacao` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'amigavel'`, `CHECK` | Estilo de texto da IA (`formal`, `amigavel`, `direto`). |
| `atualizado_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Timestamp da última edição do perfil. |

#### Tabela 3: `leadforge.habilidade`
Catálogo normalizado de competências técnicas disponíveis no sistema.

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único da habilidade. |
| `nome` | `VARCHAR(60)` | `NOT NULL`, `UNIQUE` | Nome da tecnologia ou competência (ex.: React, WordPress). |
| `categoria` | `VARCHAR(30)` | `NOT NULL`, `DEFAULT 'frontend'`, `CHECK` | Área técnica (`frontend`, `backend`, `design`, `seo`, `cms`, `outros`). |

#### Tabela 4: `leadforge.perfil_habilidade`
Entidade associativa que resolve o relacionamento `N:M` entre `perfil_freelancer` e `habilidade`.

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `perfil_id` | `INT` | `PK`, `FK -> perfil_freelancer(id)` (`ON DELETE CASCADE`) | Referência ao perfil do freelancer. |
| `habilidade_id` | `INT` | `PK`, `FK -> habilidade(id)` (`ON DELETE RESTRICT`) | Referência à habilidade do catálogo. |
| `nivel_proficiencia` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'intermediario'`, `CHECK` | Grau de domínio (`basico`, `intermediario`, `avancado`). |

#### Tabela 5: `leadforge.busca`
Registra as execuções de descoberta de empresas parametrizadas pelo usuário (`RF-02`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único da execução de busca. |
| `usuario_id` | `INT` | `NOT NULL`, `FK -> usuario(id)` (`ON DELETE CASCADE`) | Freelancer que disparou a varredura. |
| `nicho` | `VARCHAR(100)` | `NOT NULL` | Segmento de mercado pesquisado (ex.: clínicas de estética). |
| `cidade` | `VARCHAR(100)` | `NOT NULL` | Município alvo da prospecção. |
| `estado` | `CHAR(2)` | `NOT NULL` | UF do município pesquisado. |
| `limite_resultados` | `INT` | `NOT NULL`, `DEFAULT 10`, `CHECK (1..50)` | Quantidade máxima de estabelecimentos solicitados. |
| `status_busca` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'pendente'`, `CHECK` | Estado do pipeline (`pendente`, `buscando`, `deduplicando`, `analisando`, `concluida`, `erro`, `cancelada`). |
| `total_encontradas` | `INT` | `NOT NULL`, `DEFAULT 0`, `CHECK (>= 0)` | Total de empresas retornadas pela fonte externa. |
| `total_duplicadas` | `INT` | `NOT NULL`, `DEFAULT 0`, `CHECK (>= 0)` | Quantidade de registros ignorados por já constarem na carteira. |
| `mensagem_erro` | `VARCHAR(255)` | `NULL` | Detalhe técnico caso ocorra falha de rede ou rate limit (`RNF-04`). |
| `criada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Início da execução da busca. |
| `finalizada_em` | `TIMESTAMP` | `NULL` | Conclusão do processamento assíncrono. |

#### Tabela 6: `leadforge.empresa`
Cadastro centralizado de pessoas jurídicas públicas identificadas (`REG-01`, `REG-08`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador interno da empresa. |
| `external_place_id` | `VARCHAR(120)` | `NOT NULL`, `UNIQUE` | Identificador único na API externa (Geoapify/OSM) para deduplicação global. |
| `nome` | `VARCHAR(160)` | `NOT NULL` | Razão social ou nome fantasia público do estabelecimento. |
| `nicho` | `VARCHAR(100)` | `NOT NULL` | Categoria comercial do negócio. |
| `cidade` | `VARCHAR(100)` | `NOT NULL` | Cidade onde o estabelecimento está localizado. |
| `estado` | `CHAR(2)` | `NOT NULL`, `CHECK (CHAR_LENGTH(TRIM(estado)) = 2)` | Sigla da UF. |
| `endereco` | `VARCHAR(255)` | `NULL` | Endereço comercial público. |
| `telefone` | `VARCHAR(30)` | `NULL` | Telefone comercial público. |
| `url_site` | `VARCHAR(255)` | `NULL` | Endereço web público analisado (nulo quando a empresa não possui site). |
| `criada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data de inclusão na base. |
| `atualizada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data da última atualização cadastral. |

#### Tabela 7: `leadforge.evidencia`
Armazena cada sinal técnico objetivo extraído do site público da empresa (`RF-04`, `RF-05`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único da evidência. |
| `empresa_id` | `INT` | `NOT NULL`, `FK -> empresa(id)` (`ON DELETE CASCADE`) | Empresa à qual a evidência pertence. |
| `tipo_evidencia` | `VARCHAR(35)` | `NOT NULL`, `CHECK` | Critério avaliado (`HTTPS`, `RESPONSIVIDADE_CELULAR`, `BOTAO_WHATSAPP`, `FORMULARIO_CONTATO`, `CHAMADA_PARA_ACAO`, `DISPONIBILIDADE_SITE`). |
| `indica_problema` | `BOOLEAN` | `NOT NULL`, `DEFAULT TRUE` | Diferencia falhas/oportunidades (`TRUE`) de conformidades (`FALSE`). |
| `valor_detectado` | `VARCHAR(255)` | `NOT NULL` | Descrição factual observada na análise técnica. |
| `nivel_certeza` | `VARCHAR(20)` | `NOT NULL`, `CHECK` | Grau de confiabilidade (`confirmado`, `sinal_forte`, `inferencia`, `desconhecido`). |
| `origem_fonte` | `VARCHAR(120)` | `NOT NULL` | Rastreabilidade da fonte (ex.: `HTML Parser`, `HTTP Header Check`). |
| `coletada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data e hora da varredura. |

#### Tabela 8: `leadforge.oportunidade`
Entidade associativa (`N:M` entre `usuario` e `empresa`) que representa o lead na carteira isolada do freelancer (`RF-06`, `RF-10`, `REG-06`, `REG-09`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único da oportunidade na carteira. |
| `usuario_id` | `INT` | `NOT NULL`, `UNIQUE(usuario_id, empresa_id)`, `FK -> usuario(id)` (`ON DELETE CASCADE`) | Dono da carteira de prospecção. |
| `empresa_id` | `INT` | `NOT NULL`, `UNIQUE(usuario_id, empresa_id)`, `FK -> empresa(id)` (`ON DELETE RESTRICT`) | Empresa prospectada (impede exclusão se houver oportunidades ativas). |
| `busca_id` | `INT` | `NULL`, `FK -> busca(id)` (`ON DELETE SET NULL`) | Busca que originou o lead (preserva o lead mesmo se o histórico da busca for limpo). |
| `pontuacao` | `NUMERIC(5,2)` | `NOT NULL`, `DEFAULT 0.00`, `CHECK (0..100)` | Score calculado de 0 a 100 que define o ranqueamento. |
| `status_contato` | `VARCHAR(20)` | `NOT NULL`, `DEFAULT 'novo'`, `CHECK` | Estágio no funil (`novo`, `contatado`, `respondeu`, `descartado`). |
| `observacoes` | `TEXT` | `NULL` | Anotações comerciais livres do freelancer. |
| `criada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data de entrada na carteira. |
| `atualizada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data da última movimentação. |

#### Tabela 9: `leadforge.sugestao_abordagem`
Armazena a síntese explicativa e o rascunho de abordagem gerados pelo modelo de IA (`RF-07`, `RF-08`, `RNF-05`).

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador único da sugestão. |
| `oportunidade_id` | `INT` | `NOT NULL`, `UNIQUE`, `FK -> oportunidade(id)` (`ON DELETE CASCADE`) | Oportunidade associada (`1:1`). |
| `texto_explicacao` | `TEXT` | `NOT NULL` | Tradução em linguagem natural dos problemas técnicos encontrados. |
| `rascunho_mensagem` | `TEXT` | `NOT NULL` | Proposta de primeira mensagem editável pelo usuário. |
| `modelo_ia` | `VARCHAR(50)` | `NOT NULL`, `DEFAULT 'gpt-4o-mini'` | Identificação do LLM utilizado na geração. |
| `foi_editado` | `BOOLEAN` | `NOT NULL`, `DEFAULT FALSE` | Indica se o freelancer personalizou o rascunho sugerido. |
| `revisado_usuario` | `BOOLEAN` | `NOT NULL`, `DEFAULT FALSE` | Confirmação de revisão humana (`RNF-05`). |
| `gerada_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Data/hora da geração pela IA. |
| `editada_em` | `TIMESTAMP` | `NULL` | Data/hora da última edição manual. |

#### Tabela 10: `leadforge.auditoria_oportunidade_log`
Tabela de auditoria alimentada exclusivamente por trigger para rastrear mudanças de status e pontuação.

| Coluna | Tipo de Dados | Restrições | Descrição Semântica |
| :--- | :--- | :--- | :--- |
| `id` | `SERIAL` | `PK` | Identificador sequencial do evento de auditoria. |
| `oportunidade_id` | `INT` | `NOT NULL` | ID da oportunidade alterada. |
| `usuario_id` | `INT` | `NOT NULL` | ID do usuário proprietário da carteira. |
| `acao` | `VARCHAR(20)` | `NOT NULL` | Tipo da operação DML (`UPDATE`). |
| `status_anterior` | `VARCHAR(20)` | `NULL` | Status do contato antes da alteração. |
| `status_novo` | `VARCHAR(20)` | `NULL` | Status do contato após a alteração. |
| `pontuacao_anterior` | `NUMERIC(5,2)` | `NULL` | Pontuação anterior da oportunidade. |
| `pontuacao_nova` | `NUMERIC(5,2)` | `NULL` | Nova pontuação após recálculo. |
| `registrado_em` | `TIMESTAMP` | `NOT NULL`, `DEFAULT CURRENT_TIMESTAMP` | Carimbo de tempo exato da ocorrência. |

### 2.3. Justificativa de Normalização (Até a 3ª Forma Normal — 3FN)
* **1ª Forma Normal (1FN):** Todos os atributos são atômicos e monovalorados. No diagrama de classes UML original, `PerfilFreelancer` possuía listas multivaloradas (`List<String> habilidades` e `List<String> servicos`). Na modelagem relacional, esses grupos repetitivos foram eliminados criando-se a tabela `habilidade` e a tabela associativa `perfil_habilidade`, bem como isolando cada achado técnico em linhas distintas na tabela `evidencia`.
* **2ª Forma Normal (2FN):** Todas as tabelas com chave primária simples (`SERIAL`) já satisfazem automaticamente a 2FN. Na única tabela com chave primária composta (`perfil_habilidade`, PK `(perfil_id, habilidade_id)`), o único atributo não-chave (`nivel_proficiencia`) depende integralmente de toda a chave composta (o nível pertence àquela habilidade específica daquele freelancer específico), eliminando dependências parciais.
* **3ª Forma Normal (3FN):** Não existem dependências transitivas entre atributos não-chave. Os dados cadastrais da empresa (`nome`, `nicho`, `cidade`, `estado`, `url_site`) residem exclusivamente na tabela `empresa`, evitando que sejam repetidos em cada registro de `oportunidade` ou `evidencia`. Da mesma forma, o nome e a categoria da habilidade residem apenas em `habilidade`, e as credenciais de acesso ficam separadas em `usuario` em relação aos parâmetros regionais de `perfil_freelancer`.

---

## 3. Justificativa Técnica dos Recursos Avançados

### 3.1. Índices Customizados
1. **`idx_oportunidade_usuario_pontuacao` (`usuario_id, pontuacao DESC`):**
   * **Gargalo resolvido:** A tela principal `/oportunidades` (`RF-06`, `REG-09`) sempre filtra pelo `usuario_id` logado e ordena pela `pontuacao` decrescente. Sem este índice composto, o SGBD executaria um *Sequential Scan* seguido de ordenação em memória (*Sort*). Com o índice, o PostgreSQL realiza um *Index Scan* já ordenado.
2. **`idx_oportunidade_usuario_status` (`usuario_id, status_contato`):**
   * **Gargalo resolvido:** Acelera os filtros rápidos por estágio do funil (`novo`, `contatado`, `respondeu`, `descartado`) na listagem e no quadro Kanban (`RF-10`).
3. **`idx_empresa_estado_cidade_nicho` (`estado, cidade, nicho`):**
   * **Gargalo resolvido:** Otimiza tanto a deduplicação territorial nas buscas (`RF-02`) quanto as consultas analíticas do Assistente Virtual por município e segmento (ex.: *"empresas de Sorocaba"*).
4. **`idx_evidencia_empresa_problema_certeza` (`empresa_id, indica_problema, nivel_certeza`):**
   * **Gargalo resolvido:** Acelera o cálculo agregado de pontuação por empresa e a filtragem por nível de certeza (`confirmado`, `sinal_forte`, etc.).

### 3.2. Views (Visões)
1. **`vw_oportunidades_detalhadas`:** Consolida `oportunidade`, `usuario`, `empresa`, `evidencia` e `sugestao_abordagem` em uma única consulta padronizada para o dashboard e exportação (`RF-11`), encapsulando `LEFT JOIN`s e agregações de texto (`STRING_AGG`) no banco em vez de múltiplas consultas N+1 no backend Python.
2. **`vw_resumo_prospeccao_nicho_cidade`:** Consolida 4 tabelas com `GROUP BY` e `HAVING COUNT(DISTINCT o.id) >= 2 AND AVG(o.pontuacao) >= 50.00`, entregando ao Assistente Virtual (`RF-09`) métricas pré-agregadas confiáveis para responder perguntas gerenciais sem risco de alucinação de números pela IA.

### 3.3. Scalar Functions (Funções)
1. **`fn_calcular_pontuacao_empresa(p_empresa_id)`:** Centraliza a fórmula oficial de pesos e multiplicadores de certeza (Seção 5) diretamente no banco. Isso garante que qualquer inserção de evidência (seja pela API FastAPI, por script de carga ou por migração) produza rigorosamente a mesma pontuação, eliminando divergências entre regras de negócio na aplicação e no banco.
2. **`fn_classificar_prioridade_lead(p_pontuacao, p_empresa_id)`:** Padroniza a categorização comercial (`CRITICA (Imediata)`, `ALTA`, `MEDIA`, `BAIXA`) para relatórios, views e consultas do assistente.

### 3.4. Stored Procedures (Procedimentos Armazenados)
1. **`sp_registrar_oportunidade_com_evidencia`:** Executa em uma única rotina no servidor o *upsert* da empresa (`ON CONFLICT`), a inserção da evidência, o cálculo da pontuação e a vinculação deduplicada na carteira do freelancer (`REG-06`). Reduz drasticamente a latência de rede (round-trips HTTP/TCP) durante o processamento de lotes de buscas (`busca_runner.py`).
2. **`sp_avancar_status_e_registrar_abordagem`:** Valida a propriedade da carteira (`REG-09`) antes de atualizar o status do contato e registrar a sugestão gerada pela OpenAI (`RF-07`, `RF-08`), garantindo que a regra de segurança (`RNF-02`) seja respeitada mesmo que a rotina seja chamada fora da camada FastAPI.

### 3.5. Triggers (Gatilhos)
1. **`trg_auditoria_oportunidade` (`BEFORE UPDATE` em `oportunidade`):** Garante rastreabilidade imutável de toda movimentação de funil (`status_contato`) e alteração de `pontuacao` na tabela `auditoria_oportunidade_log`. Fazer isso via trigger impede que atualizações manuais ou rotinas administrativas contornem o log de auditoria da aplicação.
2. **`trg_recalcular_pontuacao_apos_evidencia` (`AFTER INSERT OR UPDATE OR DELETE` em `evidencia`):** Garante consistência forte entre evidências técnicas e o ranking da carteira. Sempre que uma evidência é adicionada ou corrigida, todas as oportunidades vinculadas àquela empresa têm sua pontuação recalculada automaticamente sem depender de esquecimento no código Python.

### 3.6. Controle Transacional (ACID)
* **Cenário 1 (`BEGIN` ... `COMMIT`):** Garante atomicidade no onboarding do freelancer (`usuario` + `perfil_freelancer` + `perfil_habilidade`), impedindo a existência de contas sem perfil configurado.
* **Cenário 2 (`BEGIN` ... `SAVEPOINT` ... `ROLLBACK`):** Demonstra a reversão completa diante de falhas de integridade durante o registro combinado de movimentação de funil e abordagem de IA, preservando a consistência da carteira.
