# Pesquisa: carteiras digitais, plataformas, seguranca e regulacao (Brasil)

Data da pesquisa: 2026-10-15. Metodo: WebSearch (resumos) + leitura direta apenas de developer.apple.com (JSON da documentacao). Todos os demais dominios oficiais (shopify.dev, developers.vtex.com, developers.google.com, bcb.gov.br, pcisecuritystandards.org, developer.woocommerce.com) NAO puderam ser abertos por curl (proxy bloqueou). Portanto, tudo exceto Apple e "resumo de busca": nivel de confianca MEDIO; confirmar na pagina oficial antes de decisao. Itens nao confirmados estao marcados NAO VERIFICADO.

Legenda de confianca: [LIDO] = pagina oficial lida integralmente por mim; [BUSCA-OFICIAL] = trecho de dominio oficial visto so em resumo de busca; [SECUNDARIA] = escritorio, imprensa, blog de fornecedor.

AVISO GERAL: nada neste documento e parecer juridico. Toda afirmacao regulatoria precisa de revisao por advogado especializado em regulacao de pagamentos/BCB.

---------------------------------------------------------------------------
## 1. Carteiras digitais

### 1.1 Apple Pay na web
Fontes oficiais [LIDO], consultadas em 2026-10-15 (JSON da documentacao Apple, sem numero de versao do documento):
- https://developer.apple.com/documentation/applepayontheweb/configuring-your-environment
- https://developer.apple.com/documentation/applepayontheweb/setting-up-your-server
- https://developer.apple.com/documentation/applepayontheweb/apple-pay-on-the-web-version-history (so confirma que a versao do Apple Pay e definida pelo SO do cliente e deve ser especificada ao criar a sessao)

Fatos verificados:
- Setup na conta de desenvolvedor: registrar Merchant ID + criar 2 certificados + verificar dominio. Requer conta Apple Developer Program e papel Team Agent/Admin (registro de dominio: Account Holder ou Admin).
- Merchant ID: nunca expira; pode ser usado em varios sites/apps.
- Payment processing certificate: Apple cifra os dados de pagamento com a chave publica; "voce, ou seu PSP" usa a chave privada para decifrar. Ou seja, o certificado pode ser mantido pelo PSP (o PSP gera o CSR/gerencia a chave) ou pelo comerciante/integrador (que entao precisa decifrar o token, o que traz escopo PCI). Expira.
- Merchant identity certificate (TLS): autentica a sessao do servidor do comerciante com os servidores Apple; so e necessario para a web (nao para apps). Expira.
- Dominio: todos os dominios/subdominios onde o botao aparece devem ser registrados e verificados; associados ao Team ID (nao se pode registrar o mesmo dominio em outro Team ID); dominio nao pode estar atras de proxy/redirect e deve ser acessivel aos servidores da Apple; verificacao expira (renovar).
- Servidor: paginas com Apple Pay somente HTTPS, certificado SSL valido, TLS 1.2+ com suites listadas, porta 443, SNI obrigatorio; allow list estrita dos IPs/dominios Apple (producao vs sandbox listados na pagina).
- Merchant validation: o servidor do comerciante chama a Apple com o merchant identity certificate para obter a sessao (a pagina de setup apenas referencia; detalhe em "Requesting an Apple Pay payment session" - NAO LIDO).
- Uso sujeito ao "Apple Pay Platform Web Merchant Terms and Conditions" (mencionado na pagina; texto NAO LIDO).

Quem faz o que (integrador vs PSP) - inferencia de fontes SECUNDARIAS (docs de PSPs, ex. docs.acquired.com, doc.begateway.com): alguns PSPs registram o comerciante e validam com os certificados do proprio PSP; outros exigem que o comerciante registre dominio na propria conta Apple. O modelo varia por PSP: NAO VERIFICADO de forma geral; confirmar na doc do PSP escolhido.

O que sobra ao integrador quando o PSP suporta: (a) hospedar o arquivo /.well-known/apple-developer-merchantid-domain-association no dominio de cada loja (ou delegar ao PSP/plataforma), (b) exibir botao Apple Pay conforme guidelines e checar disponibilidade (canMakePayments), (c) endpoint de merchant validation (se o PSP nao oferece), (d) repassar o token ao PSP, (e) renovar dominio/certificados antes de expirar, (f) em modelo multi-lojista (SaaS), automatizar registro de dominio de cada lojista - ponto de design critico para uma plataforma.

### 1.2 Google Pay (Web API)
Fonte oficial [BUSCA-OFICIAL]: https://developers.google.com/pay/api/web/guides/test-and-deploy/request-prod-access (e espelho developers.google.com/pay-wallet/...); troubleshooting developers.google.cn/pay/api/web/support/troubleshooting. Data/versao: nao exibida; consultado 2026-10-15.
- Pre-requisito: PSP suportado (integracao "Gateway") ou ambiente PCI DSS (integracao "Direct").
- Console "Google Pay & Wallet Console": criar Business Profile, habilitar a aba Google Pay API, aceitar termos; la aparece o merchant ID.
- Registrar o dominio de nivel superior, escolher tipo (Gateway/Direct), enviar screenshots do fluxo; revisao (Google menciona feedback de IA + revisao manual). Prazo de revisao "1-5 dias uteis" aparece so em pagina de terceiro: NAO VERIFICADO.
- Em producao: PaymentsClient com environment PRODUCTION + merchantId; HTTPS obrigatorio; valores "example" de gateway nao funcionam em producao; erro comum = dominio nao associado ao merchantId.
- Tokenizacao gateway: tokenizationSpecification com type PAYMENT_GATEWAY, gateway = identificador do PSP, gatewayMerchantId = fornecido pelo PSP; o token cifrado vai ao PSP. Metodos PAN_ONLY e CRYPTOGRAM_3DS [SECUNDARIA: docs Fractal].
- Tokenizacao DIRECT: exige registrar chave publica no Google e decifrar o payload (escopo PCI maior).
- Sobra ao integrador (com PSP suportado): ter perfil/merchant ID (um por negocio ou por lojista - decisao a validar com Google/PSP; NAO VERIFICADO), registrar cada dominio de producao, implementar botao/fluxo, passar gatewayMerchantId do PSP e enviar o token ao PSP.

---------------------------------------------------------------------------
## 2. Marketplaces / ecossistemas

Definicoes: "ENTRADA" = Plataforma/PMD consome APIs de PSPs (conector de saida para PSP). "SAIDA" = plataformas externas (Shopify, VTEX, etc.) consomem um conector de pagamento fornecido pela PMD (a PMD vira "payment provider" delas). Seguem requisitos de cada ecossistema para SAIDA.

### 2.1 Shopify (SAIDA)
Fontes oficiais [BUSCA-OFICIAL], consultadas 2026-10-15 (versao/data da pagina nao exibida):
- https://shopify.dev/docs/apps/build/payments
- https://shopify.dev/docs/apps/build/payments/payments-extension-review ("Get approved for payments")
- https://shopify.dev/docs/apps/build/payments/requirements
- https://shopify.dev/docs/apps/build/payments/considerations
- https://shopify.dev/docs/api/payments-apps/latest
Fatos:
- Somente Partners aprovados como Payments Partner podem construir payments apps/extensions; a Payments Apps API so esta disponivel a Payments Partners aprovados. Candidatura via "Payments Platform Application / Onboarding Form"; e preciso ser Shopify Partner. Shopify tem discricao exclusiva para aprovar/negar; nao ha prazo garantido.
- Contrato de revenue share assinado e necessario antes de processar pagamentos reais. Configuracao da extensao precisa de aprovacao antes da instalacao em lojas. Listagem publica na lista de gateways exige criterios + aprovacao.
- Requisitos tecnicos: lojista deve poder cobrar, estornar e processar transacoes de teste; SCA/3-D Secure onde aplicavel; idempotencia e politica de retry; mTLS nas chamadas em que a Shopify e cliente (pagamento, refund, capture, void), validando CA da Shopify e apresentando certificado de CA confiavel; regras de preco e de rescisao pelo lojista (ex.: aviso de 7 dias sem penalidade, segundo resumo). Descumprimento pode levar a remocao da lista ou suspensao.
- Suporte por pais/meios (Pix, boleto, parcelamento brasileiro): NAO VERIFICADO. Disponibilidade de payments apps para Brasil (Shopify Payments nao opera no Brasil historicamente): NAO VERIFICADO.
- Para fins regulatorios: ser "payments partner" na Shopify NAO substitui autorizacao do BCB; a Shopify tipicamente exige que o provider seja entidade regulada/processadora licenciada: NAO VERIFICADO.

### 2.2 VTEX (SAIDA)
Fontes oficiais [BUSCA-OFICIAL], consultadas 2026-10-15:
- https://developers.vtex.com/docs/guides/payments-integration-payment-provider-homologation
- https://developers.vtex.com/docs/guides/integrating-a-new-payment-provider-on-vtex
- https://developers.vtex.com/docs/guides/payments-integration-implementing-a-payment-provider
- https://developers.vtex.com/docs/guides/payments-integration-purchase-flows
- https://developers.vtex.com/vtex-rest-api/reference/createpayment
- https://apps.vtex.com/vtex-payment-provider-test-suite/p
Fatos:
- Protocolo (Payment Provider Protocol): endpoints GET /manifest, POST /payments (Create Payment), cancelamento, settlement (captura, aceita parcial), refund, e "Inbound request" (BETA, /payments/{paymentId}/inbound/{action}). Request carrega paymentId e requestId (idempotencia). Para finalizacao assincrona, provider chama callbackUrl para mudar status para autorizado/negado; Create Payment pode ser re-tentado de forma assincrona por ate 7 dias; cancelamento re-tentado por ate 1 dia [BUSCA-OFICIAL, valores a reconferir].
- Transporte: HTTPS porta 443, TLS 1.2 exclusivamente.
- Homologacao: app gratuito "Payment Provider Test Suite" (App Store/Admin); informar Service URL, Connector Name (case-sensitive), AppKey/AppToken; valida URL, manifest e rotas; cabecalho X-VTEX-API-Is-TestSuite=true identifica requests de teste. Executar a suite e requisito de homologacao.
- Secure Proxy / PCI: indicacao de que o provider deve ser PCI-DSS certificado ou usar Secure Proxy, e tempos de resposta (5s homologacao / 20s producao): so em fonte de terceiros (skillselion): NAO VERIFICADO.
- Processo comercial de entrada no catalogo/parceria VTEX alem da homologacao tecnica: NAO VERIFICADO.

### 2.3 Outras plataformas do catalogo Appmax (nota curta; nenhuma doc oficial obtida)
- WooCommerce: gateway = plugin proprio que estende WC_Payment_Gateway e registra no filtro woocommerce_payment_gateways; tokens via Payment Token API (WC_Payment_Gateway_CC); checkout em blocos exige a Payment Method API separada. Fonte oficial [BUSCA-OFICIAL]: https://developer.woocommerce.com/docs/features/payments/payment-gateway-api/ ; .../payment-gateway-plugin-base/ ; .../payment-token-api/. Sem programa de aprovacao: qualquer um publica plugin (distribuicao via WordPress.org/marketplace Woo tem revisao propria: NAO VERIFICADO).
- Nuvemshop: apps de pagamento existentes (Mercado (Pago), Asaas) operam como modulos/app de meio de pagamento externo; docs de terceiros dizem que o app Asaas exige plano Nuvemshop que permita meios externos e nao suporta recorrencia nem sandbox [SECUNDARIA: docs.asaas.com]. Processo oficial para virar "payment provider" da Nuvemshop (dev.nuvemshop.com.br): NAO VERIFICADO.
- Tray, Loja Integrada, Yampi: ha integracoes com gateways (Yampi cita Mercado Pago, Pagar.me, PagBank, Appmax; Tray cita Vindi) [SECUNDARIA: blogs oficiais de marketing das plataformas]. Se o caminho e "app comum" ou "gateway homologado/ parceria comercial", NAO VERIFICADO para as tres: tende a ser parceria comercial + integracao propria, a confirmar diretamente com cada plataforma.
- Recomendacao: tratar SAIDA por plataforma como (i) apps genericos (OAuth/webhooks, sem aprovacao de pagamento) vs (ii) payment provider homologado (Shopify, VTEX: com contrato/aprovacao e requisitos PCI/mTLS). Confirmar caso a caso.

### 2.4 ENTRADA (PMD usando APIs de PSP)
Nao ha aprovacao de plataforma; a PMD e cliente do PSP. Pontos a cobrir contratualmente: quem e o contratante regulatorio (PMD como software/orquestrador usando contas do lojista no PSP, vs PMD como intermediaria de fundos - ver secao 4), tokenizacao no PSP, webhooks do PSP, SLAs, e responsabilidade por chargeback/fraude.

---------------------------------------------------------------------------
## 3. Seguranca

### 3.1 PCI DSS e-commerce (SAQ A vs A-EP)
Fontes oficiais [BUSCA-OFICIAL]:
- https://www.pcisecuritystandards.org/faqs/1292/ ; https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants ; SAQ A v4.0: https://listings.pcisecuritystandards.org/documents/PCI-DSS-v4-0-SAQ-A.pdf ; SAQ A-EP v4.0.1: https://docs-prv.pcisecuritystandards.org/SAQ%20(Assessment)/SAQ/PCI-DSS-v4-0-1-SAQ-A-EP.pdf
- SAQ A: todos os elementos da pagina de pagamento vem de provedor validado PCI (redirect ou iframe do PSP); comerciante nao recebe dados de cartao.
- SAQ A-EP: comerciante controla elementos da pagina (ex. direct post / JavaScript do comerciante) mesmo que dados nao passem pelo servidor dele; escopo maior (inclui, p.ex., 6.4.3 e 11.6.1 como itens do questionario).
- Hosted fields/iframes de PSP: geralmente tratados como modelo iframe (SAQ A sujeito ao criterio de elegibilidade); a classificacao exata depende do PSP/adquirente: NAO VERIFICADO caso a caso.
- 6.4.3 (autorizar, garantir integridade e inventariar scripts da pagina de pagamento) e 11.6.1 (mecanismo de deteccao de adulteracao da pagina/headers, cadencia ao menos semanal ou conforme analise de risco [SECUNDARIA]): em v4.0.1 deixaram de constar como itens de SAQ A, mas foram substituidos por criterio de elegibilidade de que o comerciante confirma que sua pagina (que embute o iframe) e protegida contra ataques de script; aplica-se a iframe, nao a redirect puro; interpretacao de escopo (pagina vs site inteiro) varia entre QSAs [SECUNDARIA: TrustedSec, Compass IT]. Eram "best practice" ate 31/03/2025 e obrigatorios depois [SECUNDARIA; confirmar no PCI DSS v4.0.1].
- Implicacao para uma PMD: se a PMD hospeda a pagina de checkout propria do lojista e embute iframe/hosted field de PSP, a PMD/lojista herda a obrigacao de proteger a pagina; se a PMD processa/transmite dados de cartao, pode ser Service Provider (SAQ D-SP/ROC): decisao de arquitetura e de adquirente/bandeira: NAO VERIFICADO.

### 3.2 Armazenamento de CVV
Fonte oficial [BUSCA-OFICIAL]: FAQ PCI SSC "Can card verification codes/values be stored for card-on-file or recurring transactions?" https://pcisecuritystandards.org/faq/articles/Frequently_Asked_Question/can-card-verification-codes-values-be-stored-for-card-on-file-or-recurring-transactions (sem data exibida). Req. 3.3.1 / 3.3.1.2 do PCI DSS v4.x.
- Codigo de verificacao NAO pode ser retido apos a autorizacao, nem para card-on-file/recorrencia, mesmo cifrado, mesmo com consentimento do portador. Coletar antes da autorizacao de uma compra especifica e permitido.
- Pratica: guardar apenas token do PSP/network token e PAN truncado; recorrencia sem CVV (MIT), com indicadores de credencial armazenada conforme regras da bandeira/PSP (detalhe NAO VERIFICADO).

### 3.3 Tokenizacao
Cartao: preferir token do PSP (vault) ou network token; PAN nunca no banco da PMD, salvo certificacao. Tokens de carteira (Apple Pay/Google Pay) chegam cifrados e vao direto ao PSP (secoes 1.1 e 1.2).

### 3.4 Autenticidade de webhooks (boas praticas) [SECUNDARIA: elastic.io, basiq.io, inventivehq, botoi; nenhuma norma]
- Verificar assinatura HMAC-SHA256 sobre o corpo bruto com segredo compartilhado, comparacao em tempo constante.
- Incluir/validar timestamp com janela (ex. 5 min; relogio sincronizado por NTP) contra replay; nem todo provedor assina timestamp (ex. GitHub e Shopify, segundo fonte).
- Idempotencia: deduplicar por ID estavel do evento; processar de forma assincrona e responder 2xx rapido.
- Alem disso (pratica geral, nao verificada em fonte): confirmar o estado consultando a API do PSP, allow list/mTLS quando disponivel, rotacao de segredos, nao confiar em payload para autorizar liberacao de pedido.

---------------------------------------------------------------------------
## 4. Regulacao (Brasil) - NAO E PARECER JURIDICO

IMPORTANTE: Os textos primarios (normativos.bcb.gov.br) nao puderam ser abertos; as afirmacoes abaixo vem de resumos de busca e escritorios. Todas precisam ser confirmadas no texto vigente e por especialista.

### 4.1 Fontes normativas identificadas
- Resolucao BCB 150/2021 (consolida arranjos de pagamento e instituicoes de pagamento participantes do SPB): resumida por okai.com.br https://okai.com.br/documento/2021-10-06/resolucao-bcb-n-150 [SECUNDARIA]. Alterada pela Resolucao BCB 522, de 10/11/2025 (gestao centralizada de riscos nos arranjos; origem: Consulta Publica 104/2024; vigencia imediata, bandeiras com ate 180 dias para adequar) [SECUNDARIA: legisweb.com.br/legislacao/?id=486238; finsidersbrasil.com.br; okai.com.br].
- Resolucao BCB 80/2021 (constituicao/funcionamento de instituicoes de pagamento; modalidades: emissor de moeda eletronica, emissor de instrumento pos-pago, credenciador, iniciador de transacao de pagamento). Alteracoes: Resolucao BCB 494 (05/09/2025) e 495 (05/09/2025, altera a Res. BCB 81/2021 com requisitos de capital/patrimonio minimo, capacitacao de administradores e sede exclusiva) [SECUNDARIA: legisweb.com.br ids 483156/483157; capitalaberto.com.br; demarest.com.br; lefosse.com]. Segundo essas fontes: novas IPs nao podem operar sem autorizacao previa; IPs em operacao deveriam protocolar pedido de autorizacao entre 1 e 31/05/2026 (art. 9-A da Res. 80), e quem nao o fizesse adequadamente teria de encerrar atividades em 30 dias. Situacao atual (out/2026) de cada requerente: NAO VERIFICADO. Valores de capital minimo: NAO VERIFICADO.
- Resolucao CMN 4.935/2021 (correspondentes no Pais; vigor 01/02/2022, substitui a Res. CMN 4.145/2012) [SECUNDARIA: finsidersbrasil.com.br; felsberg.com.br; normativos.bcb.gov.br/.../Res_4145_v2_L.pdf].
- Registro de recebiveis de cartao: Resolucao CMN 4.734/2019 e Resolucao BCB 264/2022 (que substituiu a Circular 3.952), alterada pela Res. BCB 514/2025 e 562/2026 (cancelamento de antecipacao pre-contratada; prazo divergente entre fontes: NAO VERIFICADO) [SECUNDARIA: b3.com.br manual; legisweb ids 485366 e 495271]. Registradoras citadas: CERC, CIP, TAG (lista oficial: NAO VERIFICADO).
- Circulares anteriores (3.682/2013, 3.886/2018) tratavam de credenciamento/subcredenciamento; estao no historico mencionado por fontes [SECUNDARIA: legisweb.com.br/legislacao/?id=358077]; status de revogacao: NAO VERIFICADO.
- Citei "Instrucao Normativa BCB 513": NAO VERIFICADA (nao localizei). Para o Pix Automatico a norma verificada e a Resolucao BCB 402/2024 (ver secao 5).

### 4.2 Quadro comparativo (conceitual; enquadramento depende de analise juridica)
Obs.: as definicoes abaixo combinam texto normativo citado em fonte secundaria (marcado) com conhecimento geral; onde nao ha fonte, esta indicado.
- Software de gestao (ERP/SaaS): nao toca em fundos nem em dados de pagamento como participante de arranjo; nao regulado pelo BCB nessa funcao (premissa de mercado; NAO VERIFICADO em norma). Pode ainda ser operador/controlador sob a LGPD.
- Gateway: tecnologia que transmite dados de transacao ao adquirente/PSP, sem liquidar fundos; geralmente nao e IP, mas pode tornar-se Service Provider PCI. Nao ha definicao normativa unica localizada: NAO VERIFICADO.
- Orquestracao de pagamentos: roteamento entre varios PSPs/adquirentes; mesmo ponto: sem definicao normativa localizada; o enquadramento depende de quem custodia fundos e de quem contrata com o lojista.
- Credenciador: participante com relacionamento contratual com o lojista que assume posicao de credor perante o emissor na liquidacao [SECUNDARIA: okai.com.br "novas regras dos arranjos... credenciadoras"]; e modalidade de IP (Res. BCB 80) ou instituicao financeira.
- Subcredenciador: participante do arranjo que habilita usuario final recebedor a aceitar instrumento de pagamento, sem participar da liquidacao como credor perante o emissor (Res. BCB 150, art. 2, IX, conforme alteracao pela 522/2025, segundo resumo [SECUNDARIA]; definicao ja existia na Circular 3.886/2018). Art. 11: IPs e outras entidades autorizadas, inclusive como subcredenciador, tornam-se participantes ao aderir ao arranjo [SECUNDARIA, via documento de licitacao; conferir no texto]. Pela Res. 522/2025, segundo resumo, subcredenciadores devem participar da liquidacao centralizada quando recebem/pagam fluxos, e bandeiras nao podem delegar aos credenciadores a gestao de risco de transacoes de subcredenciadores [SECUNDARIA: finsidersbrasil.com.br; okai.com.br]. Se o subcredenciador precisa ele proprio de autorizacao do BCB como IP: ponto que exige consulta especializada (NAO VERIFICADO).
- Marketplace / facilitador de pagamento: nao encontrei definicao normativa de "facilitador". Fontes de mercado divergem: fornecedores (Zoop, NDM) dizem que o split afasta a regulacao; outras (Celcoin, Aurum Legacy) dizem que reter fundos de terceiros antes do repasse pode configurar atuacao como participante de arranjo/IP [SECUNDARIA]. Nenhuma posicao oficial do BCB obtida. REQUER CONSULTA ESPECIALIZADA.
- Split operado por PSP parceiro: modelo em que o PSP autorizado recebe, divide e repassa, e a PMD apenas configura regras via API. Tende a manter a PMD fora da custodia de fundos, mas o enquadramento depende de contrato, fluxo de fundos e de quem e o contratante do lojista: NAO VERIFICADO; REQUER CONSULTA ESPECIALIZADA.
- Instituicao de pagamento / conta de pagamento: IP e a pessoa juridica nao financeira autorizada pelo BCB para modalidades da Res. BCB 80 (emissor de moeda eletronica, pos-pago, credenciador, iniciador); conta de pagamento e a conta mantida por IP emissora de moeda eletronica (conceito da Lei 12.865/2013 - NAO LIDA; citada por conhecimento geral).
- Antecipacao de recebiveis: operacao financeira/cessao sobre agenda de recebiveis registrada em registradora (Res. CMN 4.734/2019 e Res. BCB 264/2022, com alteracoes) [SECUNDARIA]; antecipar com recursos proprios ou de terceiros tem implicacoes de funding/instituicao financeira, securitizacao ou parceiro regulado: REQUER CONSULTA ESPECIALIZADA. Observacao: para registro, lojista pode ter oferta de outro financiador; transferencia de agenda em ate 2 dias uteis [SECUNDARIA: Finsiders/blog; confirmar no texto].
- Correspondente bancario: pessoa contratada por instituicao financeira/IP autorizada para prestar servicos em seu nome, sob a Res. CMN 4.935/2021, incluindo atuacao digital; exige politica de contratacao aprovada pelo conselho/diretoria da contratante [SECUNDARIA: finsidersbrasil.com.br]. Usar parceiro regulado como "correspondente" para distribuir conta/credito e diferente de ser o PSP: REQUER CONSULTA ESPECIALIZADA sobre limites de atuacao.

### 4.3 LGPD (pontos de contato)
- Papeis: a PMD tende a ser operadora para dados do lojista e controladora para seus proprios dados (classificacao concreta: NAO VERIFICADO; analise juridica).
- Incidente de seguranca: Resolucao CD/ANPD 15/2024 (26/04/2024): controlador comunica ANPD e titulares em 3 dias uteis do conhecimento de incidente com risco/dano relevante, salvo prazo previsto em legislacao especifica [SECUNDARIA: mattosfilho.com.br, lefosse.com, okai.com.br]; fonte primaria nao aberta. Interacao com prazos do BCB/Resolucao CMN-BCB de seguranca cibernetica: NAO VERIFICADO.
- Outros pontos (base legal para dados financeiros, transferencia internacional se PSP/carteiras fora do pais, retencao, direitos dos titulares, DPA com PSPs): listados para analise; sem fonte coletada.

### 4.4 O que exige consulta especializada (lista)
1. Enquadramento da PMD (gateway/orquestracao/marketplace/facilitador) e se atinge definicao de participante de arranjo ou IP.
2. Modelo de split e fluxo de fundos (quem custodia, quem e contratante do lojista).
3. Antecipacao de recebiveis (como intermediaria/originadora, cessao, registro).
4. Eventual autorizacao como IP e requisitos de capital, e transicao dado o regime das Res. 494/495.
5. Uso de correspondente e limites.
6. Pix Automatico como recebedor/iniciador (ver 5) e requisitos de participante.
7. Contratos com Shopify/VTEX etc. (garantias regulatorias exigidas).
8. LGPD: papeis, DPA, incidente, transferencia internacional.

---------------------------------------------------------------------------
## 5. Pix Automatico

Fontes: Resolucao BCB 402, 22/07/2024 (e 403 de seguranca) [SECUNDARIA: btlaw.com.br; Agencia Brasil via acionista.com.br; comunicado BCB pdf em static.poder360.com.br]; documentos oficiais [BUSCA-OFICIAL]: Guia de implementacao v1.3 https://www.bcb.gov.br/content/estabilidadefinanceira/pix/automatico/guia_pix_automatico.pdf ; FAQ participantes https://www.bcb.gov.br/content/estabilidadefinanceira/pix/pix-automatico-FAQ-participantes.pdf ; Voto BCB 113/2024 https://normativos.bcb.gov.br/Votos/BCB/2024113/Voto_do_BC_113_2024.pdf ; Forum Pix.
- Go-live: 16/06/2025 (fixado pela Res. BCB 402/2024; confirmado por multiplas fontes). Nota de divergencia: Qitech atribui o assunto a 403, BT Law a 402; adotar 402 para Pix Automatico e 403 para seguranca (Pix com dispositivo nao cadastrado: R$200 por transacao/R$1.000 por dia, vigor 01/11/2024) [SECUNDARIA].
- Obrigacao (FAQ BCB / Voto 113/2024 [BUSCA-OFICIAL]): instituicoes que mantem contas transacionais, quando PSP do pagador, devem ofertar o Pix Automatico (pagador PJ pode pedir dispensa, art. 11-S par.1); oferta do lado recebedor e facultativa e restrita a recebedor PJ com CNPJ ativo. Multa por dia de atraso, limitada a 60 dias, para quem nao cumprisse a oferta ate 16/06/2025 (art. 120 da norma). Datas de 13/10/2025 e janeiro/2026 citadas por blogs como "obrigatoriedade" e adequacao de contratos: NAO VERIFICADO; nao encontrei nas fontes oficiais.
- Como funciona: autorizacao unica pelo pagador no app do seu PSP; 4 jornadas (1 sem QR Code com notificacao no app do pagador; 2 a 4 com QR Code, sendo 3 com primeiro pagamento imediato e 4 combinando pagamento/agendamento com oferta de recorrencia); cada contrato liga-se a uma unica recorrencia; vigencia definida entre recebedor e pagador; sem transferencia automatica de recorrencias entre PSPs; QR do Pix Automatico deve ser lido por qualquer leitor Pix e funcionar por Copia e Cola; PSP recebedor pode cobrar tarifa do recebedor, vedada tarifa do pagador [BUSCA-OFICIAL, guia v1.3]. Pagador pode definir regras (ex. valor maximo) [SECUNDARIA].
- Mudancas posteriores (SECUNDARIAS e de 2026, precisam checagem): noticias indicam Resolucao BCB 587 (publicada em 18/09/2026) que (i) permite dispensa pelo BCB de instituicoes com mais de 500 mil contas da participacao obrigatoria no Pix e (ii) autoriza Pix Automatico em contas-salario a partir de 01/07/2027; tambem regras novas para cobranca hibrida (boleto com QR Pix) a partir de fevereiro de 2027 (fontes: tecnoblog, istoedinheiro, mixvale, jb.com.br, brasil247). NAO VERIFICADO no texto oficial.
- Adocao: dados do Itau (+281% de volume no 1S26; +185% de pagadores com recorrencia) e "R$ 1,2 bi/mes" e "2,8 milhoes de pagamentos em maio" (Let's Money) sao SECUNDARIOS; nao confirmados no painel do BCB.
- Efeito em assinaturas: reduz custo e friccao de cobranca recorrente frente a cartao/debito em conta (segundo BCB, via Agencia Brasil) e compete com cartao recorrente; impacto na taxa de aprovacao/ churn ainda sem dado oficial. Implicacao de produto para a PMD: suporte a Pix Automatico depende do PSP (recebedor) oferecer a jornada; a PMD como integrador usa a API do PSP: modelos de ENTRADA. Se a PMD vira participante direta, entra a analise regulatoria da secao 4.
- Exigencias de seguranca do Pix Automatico em 01/01/2026 mencionadas em slide do Forum Pix: detalhe NAO VERIFICADO.

---------------------------------------------------------------------------
## Lacunas principais para a proxima rodada (com acesso a dominios oficiais)
1. Texto primario das Res. BCB 80, 150, 402, 403, 494, 495, 522, 587 e IN referente (IN BCB 513 nao localizada).
2. Paginas Shopify/VTEX completas (SLA, PCI, requisitos de pais/meios).
3. Apple: pagina "Requesting an Apple Pay payment session" e Merchant Terms.
4. Documentacao de Nuvemshop, Tray, Loja Integrada, Yampi sobre virar provider.
5. PCI DSS v4.0.1 texto oficial (6.4.3, 11.6.1, 3.3.1) e SAQ A atual.
6. Posicao do BCB sobre marketplace/split/facilitador.
