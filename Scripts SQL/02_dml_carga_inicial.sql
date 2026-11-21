SET search_path TO leadforge, public;

-- 1. USUÁRIOS (Freelancers cadastrados com aceite LGPD)
INSERT INTO leadforge.usuario (nome, email, senha_hash, aceite_lgpd, ativo) VALUES
('Lucas Almeida', 'lucas.almeida@devweb.com.br', 'scrypt:32768:8:1$hash_lucas_01', TRUE, TRUE),
('Mariana Costa', 'mariana.costa@uxstudio.com.br', 'scrypt:32768:8:1$hash_mariana_02', TRUE, TRUE),
('Rafael Mendes', 'rafael.mendes@fullstack.io', 'scrypt:32768:8:1$hash_rafael_03', TRUE, TRUE),
('Camila Ferreira', 'camila.ferreira@landingpro.com', 'scrypt:32768:8:1$hash_camila_04', TRUE, TRUE),
('Thiago Oliveira', 'thiago.oliveira@webcraft.dev', 'scrypt:32768:8:1$hash_thiago_05', TRUE, TRUE);

-- 2. PERFIS DE FREELANCER (1:1 com usuario)
INSERT INTO leadforge.perfil_freelancer (usuario_id, cidade, estado, tom_comunicacao) VALUES
(1, 'Sorocaba', 'SP', 'amigavel'),
(2, 'Sorocaba', 'SP', 'formal'),
(3, 'Campinas', 'SP', 'direto'),
(4, 'Votorantim', 'SP', 'amigavel'),
(5, 'Itu', 'SP', 'formal');

-- 3. CATÁLOGO DE HABILIDADES
INSERT INTO leadforge.habilidade (nome, categoria) VALUES
('React', 'frontend'),
('TypeScript', 'frontend'),
('WordPress', 'cms'),
('Python / FastAPI', 'backend'),
('UI/UX Design', 'design'),
('SEO Técnico', 'seo'),
('Landing Pages de Alta Conversão', 'frontend'),
('Otimização Core Web Vitals', 'seo');

-- 4. PERFIL_HABILIDADE (Relacionamento N:M)
INSERT INTO leadforge.perfil_habilidade (perfil_id, habilidade_id, nivel_proficiencia) VALUES
(1, 1, 'avancado'),
(1, 2, 'avancado'),
(1, 4, 'intermediario'),
(1, 7, 'avancado'),
(2, 3, 'avancado'),
(2, 5, 'avancado'),
(2, 6, 'intermediario'),
(3, 1, 'avancado'),
(3, 4, 'avancado'),
(3, 8, 'avancado'),
(4, 3, 'intermediario'),
(4, 7, 'avancado'),
(5, 1, 'intermediario'),
(5, 6, 'avancado');

-- 5. BUSCAS REALIZADAS (RF-02)
INSERT INTO leadforge.busca (usuario_id, nicho, cidade, estado, limite_resultados, status_busca, total_encontradas, total_duplicadas, finalizada_em) VALUES
(1, 'clínicas de estética', 'Sorocaba', 'SP', 10, 'concluida', 10, 2, CURRENT_TIMESTAMP - INTERVAL '2 days'),
(1, 'odontologia', 'Sorocaba', 'SP', 10, 'concluida', 6, 0, CURRENT_TIMESTAMP - INTERVAL '1 day'),
(1, 'academias', 'Sorocaba', 'SP', 10, 'concluida', 4, 1, CURRENT_TIMESTAMP - INTERVAL '12 hours'),
(2, 'clínicas de estética', 'Sorocaba', 'SP', 10, 'concluida', 5, 0, CURRENT_TIMESTAMP - INTERVAL '1 day'),
(3, 'restaurantes', 'Campinas', 'SP', 15, 'concluida', 8, 1, CURRENT_TIMESTAMP - INTERVAL '5 hours');

-- 6. EMPRESAS PROSPECTADAS (20 registros públicos em Sorocaba, Votorantim e Campinas)
INSERT INTO leadforge.empresa (external_place_id, nome, nicho, cidade, estado, endereco, telefone, url_site) VALUES
('geo_sor_001', 'Clínica Bela Forma', 'Clínica de estética', 'Sorocaba', 'SP', 'Av. Barão de Tatuí, 1120 - Campolim', '(15) 3211-4401', 'http://clinicabelaforma.com.br'),
('geo_sor_002', 'Studio Corpo & Alma', 'Clínica de estética', 'Sorocaba', 'SP', 'Rua Professora Zélia Dulce, 340 - Jardim dos Estados', '(15) 3222-8890', 'http://studiocorpoealma.com.br'),
('geo_sor_003', 'Odonto Sorriso Integrado', 'Dentista', 'Sorocaba', 'SP', 'Rua da Penha, 815 - Centro', '(15) 3233-1020', 'https://odontosorrisosorocaba.com.br'),
('geo_sor_004', 'Academia Ritmo Vital', 'Academia', 'Sorocaba', 'SP', 'Av. General Carneiro, 1450 - Cerrado', '(15) 3202-7741', 'https://academiaritmovital.com.br'),
('geo_sor_005', 'Espaço Vita Estética', 'Clínica de estética', 'Sorocaba', 'SP', 'Rua XV de Novembro, 412 - Centro', '(15) 99112-3344', NULL),
('geo_sor_006', 'Dermacare Estética Avançada', 'Clínica de estética', 'Sorocaba', 'SP', 'Av. Washington Luiz, 920 - Trujillo', '(15) 3218-5510', 'https://dermacaresorocaba.com.br'),
('geo_sor_007', 'Instituto Oral Campolim', 'Dentista', 'Sorocaba', 'SP', 'Av. Antônio Carlos Comitre, 510 - Campolim', '(15) 3217-9000', 'http://institutooralcampolim.com.br'),
('geo_sor_008', 'Clínica Harmonize Face & Corpo', 'Clínica de estética', 'Sorocaba', 'SP', 'Rua Miranda Azevedo, 290 - Centro', '(15) 99744-1122', NULL),
('geo_sor_009', 'Fit Center Sorocaba', 'Academia', 'Sorocaba', 'SP', 'Av. Itavuvu, 2300 - Jardim Santa Cecília', '(15) 3226-4090', 'https://fitcentersorocaba.com.br'),
('geo_sor_010', 'Sorocaba Implantes & Estética Dental', 'Dentista', 'Sorocaba', 'SP', 'Rua Santa Clara, 198 - Centro', '(15) 3231-6677', 'https://sorocabaimplantes.com.br'),
('geo_sor_011', 'Estética Renova Pele', 'Clínica de estética', 'Sorocaba', 'SP', 'Av. Doutor Eugênio Salerno, 615 - Santa Terezinha', '(15) 98123-7788', 'http://renovapeleestetica.com.br'),
('geo_sor_012', 'CrossTraining Force Box', 'Academia', 'Sorocaba', 'SP', 'Av. Ipanema, 1890 - Vila Helena', '(15) 3223-9191', NULL),
('geo_sor_013', 'Clínica Odontológica Sorriso Real', 'Dentista', 'Sorocaba', 'SP', 'Rua Coronel Nogueira Padilha, 1040 - Vila Hortência', '(15) 3234-5050', 'https://sorrisorealodontologia.com.br'),
('geo_sor_014', 'BelleVie Bem-Estar & Spa', 'Clínica de estética', 'Sorocaba', 'SP', 'Rua Pedro Lombardi, 145 - Mangal', '(15) 3211-9876', 'https://belleviespa.com.br'),
('geo_sor_015', 'BioForma Pilates e Fisioterapia', 'Clínica de estética', 'Sorocaba', 'SP', 'Av. Moreira César, 480 - Centro', '(15) 3232-4141', 'http://bioformapilates.com.br'),
('geo_vot_016', 'Estética Bella Votorantim', 'Clínica de estética', 'Votorantim', 'SP', 'Av. 31 de Março, 780 - Centro', '(15) 3243-2210', NULL),
('geo_vot_017', 'OdontoVoto Clínica Popular', 'Dentista', 'Votorantim', 'SP', 'Av. São João, 410 - Jardim Icatu', '(15) 3247-8900', 'http://odontovoto.com.br'),
('geo_cam_018', 'Cantina Bella Napoli', 'Restaurante', 'Campinas', 'SP', 'Rua Conceição, 620 - Cambuí', '(19) 3251-4433', 'http://cantinabellanapoli.com.br'),
('geo_cam_019', 'Bistrô Jardim Cambuí', 'Restaurante', 'Campinas', 'SP', 'Rua Coronel Quirino, 1120 - Cambuí', '(19) 3254-7890', 'https://bistrojardimcambui.com.br'),
('geo_cam_020', 'Pizzaria Forno a Lenha Express', 'Restaurante', 'Campinas', 'SP', 'Av. Brasil, 1540 - Guanabara', '(19) 3241-1100', NULL);

-- 7. EVIDÊNCIAS TÉCNICAS COLETADAS NOS SITES (34 registros)
INSERT INTO leadforge.evidencia (empresa_id, tipo_evidencia, indica_problema, valor_detectado, nivel_certeza, origem_fonte) VALUES
-- Empresa 1: Clínica Bela Forma (Sem mobile + Sem HTTPS + Sem WhatsApp -> Pontuação alta)
(1, 'RESPONSIVIDADE_CELULAR', TRUE, 'Meta tag viewport ausente no HTML', 'confirmado', 'HTML Parser (http://clinicabelaforma.com.br)'),
(1, 'HTTPS', TRUE, 'Site servido exclusivamente via HTTP inseguro', 'confirmado', 'HTTP Header Check'),
(1, 'BOTAO_WHATSAPP', TRUE, 'Nenhum link api.whatsapp.com ou wa.me detectado', 'sinal_forte', 'HTML Link Scan'),
(1, 'FORMULARIO_CONTATO', TRUE, 'Nenhuma tag <form> de agendamento encontrada', 'sinal_forte', 'HTML DOM Scan'),

-- Empresa 2: Studio Corpo & Alma (Sem HTTPS + Sem WhatsApp + Sem mobile)
(2, 'HTTPS', TRUE, 'Certificado SSL ausente (protocolo HTTP)', 'confirmado', 'HTTP Header Check'),
(2, 'BOTAO_WHATSAPP', TRUE, 'Ausência de botão flutuante ou link de WhatsApp', 'sinal_forte', 'HTML Link Scan'),
(2, 'RESPONSIVIDADE_CELULAR', TRUE, 'Layout largura fixa 980px sem viewport', 'confirmado', 'HTML Parser'),

-- Empresa 3: Odonto Sorriso Integrado (Sem mobile + Sem formulário)
(3, 'RESPONSIVIDADE_CELULAR', TRUE, 'Viewport não configurado para dispositivos móveis', 'confirmado', 'HTML Parser'),
(3, 'FORMULARIO_CONTATO', TRUE, 'Página de contato possui apenas texto estático', 'sinal_forte', 'HTML DOM Scan'),
(3, 'HTTPS', FALSE, 'Certificado SSL ativo e válido', 'confirmado', 'TLS Handshake'),

-- Empresa 4: Academia Ritmo Vital (Sem WhatsApp + Sem CTA)
(4, 'BOTAO_WHATSAPP', TRUE, 'Nenhum canal direto de WhatsApp no HTML', 'sinal_forte', 'HTML Link Scan'),
(4, 'CHAMADA_PARA_ACAO', TRUE, 'Ausência de botões de conversão/agendamento acima da dobra', 'inferencia', 'CTA Keyword Analyzer'),

-- Empresa 5: Espaço Vita Estética (Sem site encontrado -> Desconhecido = 80 * 0.8 = 64)
(5, 'DISPONIBILIDADE_SITE', TRUE, 'Nenhum website próprio registrado na fonte pública', 'desconhecido', 'Geoapify Place Details'),

-- Empresa 6: Dermacare Estética Avançada (Sem formulário + Sem CTA)
(6, 'FORMULARIO_CONTATO', TRUE, 'Formulário de avaliação ausente', 'sinal_forte', 'HTML DOM Scan'),
(6, 'CHAMADA_PARA_ACAO', TRUE, 'Sem chamada explícita para agendamento', 'inferencia', 'CTA Keyword Analyzer'),

-- Empresa 7: Instituto Oral Campolim (Sem HTTPS + Sem mobile + Sem WhatsApp)
(7, 'HTTPS', TRUE, 'Redirecionamento HTTPS inexistente', 'confirmado', 'HTTP Header Check'),
(7, 'RESPONSIVIDADE_CELULAR', TRUE, 'Ausência de meta viewport', 'confirmado', 'HTML Parser'),
(7, 'BOTAO_WHATSAPP', TRUE, 'Sem link direto para WhatsApp', 'sinal_forte', 'HTML Link Scan'),

-- Empresa 8: Clínica Harmonize Face & Corpo (Sem site)
(8, 'DISPONIBILIDADE_SITE', TRUE, 'Estabelecimento sem domínio web cadastrado', 'desconhecido', 'Geoapify Place Details'),

-- Empresa 9: Fit Center Sorocaba (Sem WhatsApp)
(9, 'BOTAO_WHATSAPP', TRUE, 'Sem integração com WhatsApp Web/API', 'sinal_forte', 'HTML Link Scan'),

-- Empresa 10: Sorocaba Implantes & Estética Dental (Sem mobile)
(10, 'RESPONSIVIDADE_CELULAR', TRUE, 'Site legado não responsivo', 'confirmado', 'HTML Parser'),

-- Empresa 11: Estética Renova Pele (Sem HTTPS + Sem formulário)
(11, 'HTTPS', TRUE, 'Conexão não criptografada (HTTP)', 'confirmado', 'HTTP Header Check'),
(11, 'FORMULARIO_CONTATO', TRUE, 'Sem formulário de captação de leads', 'sinal_forte', 'HTML DOM Scan'),

-- Empresa 12: CrossTraining Force Box (Sem site)
(12, 'DISPONIBILIDADE_SITE', TRUE, 'Apenas perfil social, sem site próprio', 'desconhecido', 'Geoapify Place Details'),

-- Empresa 13: Clínica Odontológica Sorriso Real (Site bem estruturado - baixa pontuação)
(13, 'HTTPS', FALSE, 'HTTPS ativo', 'confirmado', 'TLS Handshake'),
(13, 'CHAMADA_PARA_ACAO', TRUE, 'CTA pouco visível no rodapé', 'inferencia', 'CTA Keyword Analyzer'),

-- Empresa 14: BelleVie Bem-Estar & Spa (Sem WhatsApp + Sem CTA)
(14, 'BOTAO_WHATSAPP', TRUE, 'Sem botão de WhatsApp', 'sinal_forte', 'HTML Link Scan'),
(14, 'CHAMADA_PARA_ACAO', TRUE, 'Sem botão de agendamento online', 'inferencia', 'CTA Keyword Analyzer'),

-- Empresa 15: BioForma Pilates e Fisioterapia (Sem HTTPS + Sem mobile)
(15, 'HTTPS', TRUE, 'Sem SSL/HTTPS', 'confirmado', 'HTTP Header Check'),
(15, 'RESPONSIVIDADE_CELULAR', TRUE, 'Sem meta viewport mobile', 'confirmado', 'HTML Parser'),

-- Empresas 16 a 20 (Votorantim e Campinas)
(16, 'DISPONIBILIDADE_SITE', TRUE, 'Sem website próprio encontrado', 'desconhecido', 'Geoapify Place Details'),
(17, 'HTTPS', TRUE, 'Sem HTTPS', 'confirmado', 'HTTP Header Check'),
(17, 'BOTAO_WHATSAPP', TRUE, 'Sem WhatsApp', 'sinal_forte', 'HTML Link Scan'),
(18, 'HTTPS', TRUE, 'Cardápio em HTTP sem SSL', 'confirmado', 'HTTP Header Check'),
(18, 'RESPONSIVIDADE_CELULAR', TRUE, 'Tabela HTML fixa sem suporte mobile', 'confirmado', 'HTML Parser'),
(19, 'FORMULARIO_CONTATO', TRUE, 'Sem formulário de reserva de mesas', 'sinal_forte', 'HTML DOM Scan'),
(20, 'DISPONIBILIDADE_SITE', TRUE, 'Sem site próprio cadastrado', 'desconhecido', 'Geoapify Place Details');

-- 8. OPORTUNIDADES NA CARTEIRA DOS USUÁRIOS (22 registros)
INSERT INTO leadforge.oportunidade (usuario_id, empresa_id, busca_id, pontuacao, status_contato, observacoes) VALUES
(1, 1, 1, 89.75, 'novo', 'Alta prioridade: clínica no Campolim sem HTTPS e sem mobile.'),
(1, 2, 1, 77.00, 'contatado', 'Enviada abordagem inicial via WhatsApp comercial.'),
(1, 3, 2, 47.75, 'novo', 'Bom potencial para redesign responsivo.'),
(1, 4, 3, 23.00, 'respondeu', 'Gerente pediu orçamento para landing page de planos.'),
(1, 5, 1, 64.00, 'novo', 'Não possui site, apenas Instagram.'),
(1, 6, 1, 18.75, 'descartado', 'Site já possui HTTPS e versão mobile recente.'),
(1, 7, 2, 77.00, 'novo', 'Clínica odontológica no Campolim com site HTTP antigo.'),
(1, 8, 1, 64.00, 'novo', 'Oportunidade de criação de site institucional do zero.'),
(1, 9, 3, 17.00, 'novo', 'Adicionar botão flutuante de WhatsApp.'),
(1, 10, 2, 35.00, 'contatado', 'Aguardando retorno da recepção.'),
(1, 11, 1, 37.75, 'novo', 'Site sem certificado SSL.'),
(1, 12, 3, 64.00, 'novo', 'Box de crossfit sem site institucional.'),
(1, 13, 2, 6.00, 'descartado', 'Site atualizado recentemente.'),
(1, 14, 1, 23.00, 'novo', 'Spa urbano com potencial para agendamento online.'),
(1, 15, 1, 60.00, 'novo', 'Clínica de pilates sem HTTPS e sem suporte mobile.'),
-- Carteira da Usuária 2 (Mariana Costa - Sorocaba)
(2, 1, 4, 89.75, 'novo', 'Foco em UX/UI mobile-first.'),
(2, 2, 4, 77.00, 'novo', 'Propor reformulação visual e certificado SSL.'),
(2, 5, 4, 64.00, 'contatado', 'Primeiro contato realizado.'),
-- Carteira do Usuário 3 (Rafael Mendes - Campinas)
(3, 18, 5, 60.00, 'novo', 'Restaurante tradicional no Cambuí sem site responsivo.'),
(3, 19, 5, 12.75, 'novo', 'Implementar formulário de reserva.'),
(3, 20, 5, 64.00, 'contatado', 'Oferecer landing page com cardápio digital.'),
-- Carteira da Usuária 4 (Camila Ferreira - Votorantim)
(4, 16, NULL, 64.00, 'novo', 'Prospecção local em Votorantim.');

-- 9. SUGESTÕES DE ABORDAGEM GERADAS POR IA (RF-07, RF-08, RNF-05)
INSERT INTO leadforge.sugestao_abordagem (oportunidade_id, texto_explicacao, rascunho_mensagem, modelo_ia, foi_editado, revisado_usuario) VALUES
(1, 'A Clínica Bela Forma possui site ativo em HTTP (sem certificado de segurança) e não possui adaptação para celulares (meta viewport ausente), além de não oferecer link direto para WhatsApp.',
    'Olá, equipe da Clínica Bela Forma! Notei que o site de vocês ainda não está adaptado para celulares e aparece como "não seguro" nos navegadores por falta de HTTPS. Trabalho com desenvolvimento web em Sorocaba e posso ajudar a modernizar o site para atrair mais agendamentos pelo celular. Podemos conversar rapidamente?',
    'gpt-4o-mini', FALSE, TRUE),
(2, 'O Studio Corpo & Alma opera sem HTTPS, sem responsividade mobile e sem botão direto de WhatsApp no site institucional.',
    'Oi! Tudo bem? Vi o site do Studio Corpo & Alma e percebi que pacientes que acessam pelo celular têm dificuldade de navegação e não encontram um botão direto para o WhatsApp. Ajudo clínicas de estética em Sorocaba a corrigir exatamente esses pontos. Teria 5 minutos esta semana para eu te mostrar como melhorar isso?',
    'gpt-4o-mini', TRUE, TRUE),
(7, 'O Instituto Oral Campolim apresenta protocolo HTTP inseguro e layout não responsivo para smartphones.',
    'Olá, tudo bem? Acompanho clínicas odontológicas no Campolim e notei que o site do Instituto Oral ainda não possui certificado HTTPS nem versão otimizada para celular. Posso preparar uma proposta objetiva para atualizar a presença digital da clínica?',
    'gpt-4o-mini', FALSE, FALSE);
