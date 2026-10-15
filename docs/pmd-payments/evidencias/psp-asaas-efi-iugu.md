# PSPs Asaas, Efí e Iugu: matriz de capacidades (pesquisa de 2026-10-15)

## Método e limites

- Ferramenta: WebSearch (modo standard). WebFetch/curl indisponíveis. Os fatos vêm de **resumos de busca** das páginas oficiais, não de leitura integral das páginas.
- Datas: a busca raramente mostra "versão". Quando a página indicou idade, anotei. Caso contrário "data da página NÃO VERIFICADA"; todos os fatos foram coletados em 2026-10-15.
- Legenda: CONFIRMADO (documentação oficial diz), PARCIAL, CONDICIONAL (depende de elegibilidade/contrato/liberação), NÃO SUPORTADO, NÃO VERIFICADO.
- Documentação não prova habilitação comercial. Tudo que depende de contrato está marcado CONDICIONAL.
- Preços: tabelas públicas divergem entre páginas e blogs; o valor válido é o do contrato da conta.

---

## 1. ASAAS

### Matriz

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado / link de pagamento | CONFIRMADO | Asaas Checkout (via API): `chargeTypes` DETACHED/RECURRENT/INSTALLMENT, expiração 10 a 1440 min, split, pré-preenchimento. Link de pagamento `POST /v3/paymentLinks` com `chargeType` RECURRENT para assinatura. Meios no Checkout: Pix e cartão (boleto no Checkout NÃO VERIFICADO) | https://docs.asaas.com/docs/checkout-asaas ; https://docs.asaas.com/docs/criando-um-link-de-pagamentos ; https://docs.asaas.com/changelog/checkout-asaas-disponível-para-integrações-via-api |
| Checkout transparente (API cartão) | CONFIRMADO | Criar cobrança com dados do cartão; captura na criação; recomenda timeout mínimo 60 s; HTTPS obrigatório | https://docs.asaas.com/docs/cobrancas-via-cartao-de-credito ; https://docs.asaas.com/reference/criar-cobranca-com-cartao-de-credito |
| SDK components (iframe/JS de tokenização) | NÃO VERIFICADO | Não achei componente client-side oficial; dados de cartão trafegam pelo backend do integrador (implica escopo PCI para o integrador) | (busca sem resultado) |
| Cartão | CONFIRMADO | À vista e parcelado; sandbox cobre | https://docs.asaas.com/docs/o-que-pode-ser-testado |
| Pix | CONFIRMADO | Cobrança Pix dinâmica | https://asaas.com/precos-e-taxas |
| Pix Automático | CONDICIONAL | Ver seção 1.2 | https://docs.asaas.com/docs/pix-automatico |
| Boleto | CONFIRMADO | Sem taxa de emissão; paga ao liquidar | https://asaas.com/precos-e-taxas |
| Apple Pay | NÃO VERIFICADO | Nenhuma menção na documentação encontrada | https://docs.asaas.com/docs/asaas-checkout (lista só Pix e cartão) |
| Google Pay | NÃO VERIFICADO | idem | idem |
| Assinaturas nativas | CONFIRMADO | Ver seção 1.3 | https://docs.asaas.com/docs/assinaturas |
| Tokenização de cartão | CONDICIONAL | `creditCardToken` na 1ª cobrança ou `POST /v3/creditCard/tokenize`; sandbox habilitado, produção exige solicitação ao gerente + análise de risco; token preso ao cliente | https://docs.asaas.com/reference/tokenizacao-de-cartao-de-credito |
| Split 1:1 | CONFIRMADO | `splits[].walletId` + `fixedValue` ou `percentualValue` | https://docs.asaas.com/docs/split-de-pagamentos |
| Split múltiplos recebedores | CONFIRMADO | Array `splits`; soma fixa <= líquido; % <= 100; mistura permitida; erro se exceder | https://docs.asaas.com/reference/split-de-pagamento ; https://docs.asaas.com/docs/payment-split |
| Estorno parcial | CONFIRMADO (Pix e cartão) | Pix: vários parciais até o total; cartão: `value` parcial. Taxas de cobrança/notificação não são devolvidas. Pix integral logo após recebimento pode dar 400 se saldo não cobre a taxa | https://docs.asaas.com/reference/estornar-cobranca |
| Estorno parcial com split | PARCIAL | Estorno total reverte split automaticamente; **parcial NÃO reverte automaticamente**, exige `splitRefunds` (soma dos splits sai primeiro, resto da cobrança principal). Parcelamento tem endpoint próprio | https://docs.asaas.com/reference/estornar-cobranca ; https://docs.asaas.com/reference/estornar-parcelamento |
| Cancelar / capturar (pré-autorização) | CONDICIONAL | `authorizedOnly=true` gera AUTHORIZED; captura por endpoint dedicado; prazo padrão 3 dias, até 25 dias para contas elegíveis (MCC/bandeira); cancelar antes do prazo via estorno | https://docs.asaas.com/docs/duvidas-frequentes-cobrancas ; https://docs.asaas.com/changelog/criar-cobrança-do-cartão-de-crédito-com-pré-autorização |
| Antecipação | CONDICIONAL | Antecipação de cartão/boleto, configurável na criação, taxa própria, sujeita a análise de crédito. Detalhes de endpoint NÃO VERIFICADO (só blog) | https://blog.asaas.com/?p=265861 |
| Webhooks autenticados | CONFIRMADO (token estático) | Header `asaas-access-token` com `authToken` (32 a 255 caracteres, não pode ser API key); valor devolvido só na criação; até 10 webhooks/conta; HMAC de corpo NÃO VERIFICADO (provável que não exista); entrega at-least-once; eventos podem ser perdidos após 14 dias de falha | https://docs.asaas.com/docs/criar-novo-webhook-pela-api ; https://docs.asaas.com/docs/about-webhooks ; https://docs.asaas.com/docs/faq-sandbox |
| Idempotência | NÃO VERIFICADO | Nenhum header de idempotência encontrado. Docs mandam deduplicar webhook pelo id do evento e consultar antes de repetir estorno após timeout | https://docs.asaas.com/reference/estornar-parcelamento ; https://docs.asaas.com/docs/faq-sandbox |
| Sandbox | CONFIRMADO | `api-sandbox.asaas.com`; cartão, parcelado, split e estorno testáveis; cartões de teste definem resultado | https://docs.asaas.com/docs/o-que-pode-ser-testado ; https://docs.asaas.com/docs/testando-pagamento-com-cart%C3%A3o-de-cr%C3%A9dito |
| OAuth p/ autorização de vendedor | NÃO VERIFICADO | Só há sugestão em fórum (não é recurso). O modelo é apiKey por subconta devolvida na criação | https://docs.asaas.com/discuss/6aa758169108a1162a409303 |
| Subcontas via API | CONDICIONAL | `POST /v3/accounts` devolve `apiKey` (só uma vez) e `walletId`; só conta PJ pode criar; `incomeValue` obrigatório; período de avaliação regulatória com limites | https://docs.asaas.com/reference/criar-subconta ; https://docs.asaas.com/docs/criacao-de-subcontas |
| White label (BaaS) | CONDICIONAL | Liberação prévia pelo gerente de contas; subconta BaaS sem acesso à UI do Asaas, onboarding por API/`onboardingUrl`; exige divulgar Asaas como instituição prestadora | https://docs.asaas.com/docs/cria%C3%A7%C3%A3o-de-subcontas-baas |
| Rate limits | CONFIRMADO | HTTP 429; cota de 25.000 req/12 h por conta; 50 GET simultâneos; headers `RateLimit-Reset` | https://docs.asaas.com/docs/duvidas-frequentes-limites-da-api |
| Taxas públicas | PARCIAL | Página: Pix e boleto R$ 1,99; cartão à vista R$ 0,49 + 2,99%, 3,49% (2-6x), 3,99% (7-12x); débito R$ 0,35 + 1,89%. Blog cita promo Pix R$ 0,99 por 3 meses. Valor real é o do contrato | https://asaas.com/precos-e-taxas ; https://blog.asaas.com/taxas-asaas/ |
| Elegibilidade | CONDICIONAL | Pix Automático: PJ, CNPJ ativo >= 6 meses, sem restrição Pix, checagens CNAE/DICT; subcontas só PJ | https://docs.asaas.com/docs/faq-2 |
| Países/moedas | NÃO VERIFICADO | Presume-se BRL/Brasil; não confirmado em fonte | (nenhuma) |
| Quem recebe o dinheiro | CONFIRMADO | Conta Asaas que emitiu a cobrança; restante do líquido não repassado fica nela; recebedores de split precisam de walletId (conta Asaas) | https://docs.asaas.com/docs/split-faq |
| Restrições por canal/contrato | CONDICIONAL | Tokenização, BaaS, pré-autorização estendida, Pix Automático, antecipação: todos dependem de liberação | ver linhas acima |

### 1.1 Split (must-check)

- Base de cálculo: **valor líquido** (após taxas), não o bruto. Ex.: boleto R$100 com taxa R$2 = base R$98. Fonte: https://docs.asaas.com/docs/split-faq
- `fixedValue` (2 casas) e `percentualValue` (4 casas); mistura permitida sem regra de prioridade; excesso gera exceção. Fonte: https://docs.asaas.com/reference/split-de-pagamento
- Não incluir o walletId da própria conta emissora. Sobra fica na emissora.
- Parcelado: `fixedValue` por parcela ou `totalFixedValue` dividido pelas parcelas. Fonte: https://docs.asaas.com/docs/duvidas-frequentes-split
- Split em Pix Automático: **não pode** na autorização/QR inicial. Fonte: https://docs.asaas.com/docs/faq-2
- Recebedor precisa ter conta Asaas (walletId). Subconta via API devolve walletId.
- Estorno parcial: ver tabela (não reverte split sozinho).

### 1.2 Pix Automático (must-check)

- **Distinção**: Pix Automático é a funcionalidade do BCB (autorização do pagador no banco, débito agendado pelo recebedor). Não é transferência Pix agendada nem "Pix Recorrente" por Open Finance (há página separada https://docs.asaas.com/docs/pix-recorrente, conteúdo NÃO VERIFICADO).
- Fluxo API: `POST /v3/pix/automatic/authorizations` cria a autorização ligada a um cliente e gera QR do primeiro pagamento; só passa a ACTIVE quando o pagador conclui pagamento e autorização no banco. Depois, cobranças referenciam `pixAutomaticAuthorizationId` (só aceita ACTIVE). Fontes: https://docs.asaas.com/reference/criar-uma-autorizacao-pix-automatico ; https://docs.asaas.com/docs/pix-automatico-implementacao
- `paymentCreationMode`: **SUBSCRIPTION** (cobranças geradas por assinatura Asaas, exige `value`) ou **MANUAL** (aplicação cria cada cobrança). FAQ afirma que o Asaas não gera recorrência sozinho fora da assinatura: a aplicação cria a cobrança de cada ciclo com o id da autorização. Pagamento antecipado até D-1 cancela a instrução automática daquele ciclo.
- Jornadas Asaas: adesão automática por API (jornada 3) e adesão após primeiro pagamento (jornada 4).
- Eventos próprios existem (https://docs.asaas.com/docs/eventos-para-pix-autom%C3%A1tico), incluindo `PIX_AUTOMATIC_RECURRING_ELIGIBILITY_UPDATED` para subcontas.
- Elegibilidade: CONDICIONAL (PJ, aprovada, sem pendência, CNPJ >= 6 meses, sem restrição Pix, CNAE, liberação gradual). Fonte: https://docs.asaas.com/docs/faq-2 ; https://blog.asaas.com/release/pix-automatico/
- Existe página "Diferença entre Pix Automático e Assinaturas" (https://docs.asaas.com/docs/diferen%C3%A7a-entre-pix-autom%C3%A1tico-e-assinaturas-1); conteúdo NÃO VERIFICADO.
- Split com Pix Automático nas cobranças subsequentes: NÃO VERIFICADO (só a autorização inicial é vedada).

### 1.3 Assinaturas (must-check)

- Assinatura = agendador: gera cobranças no ciclo; padrão gerar cada cobrança 40 dias antes do vencimento (opções 14 ou 7). Fonte: https://docs.asaas.com/docs/assinaturas
- Cartão: endpoint próprio, valida o cartão na criação (não garante cobranças futuras). Fonte: https://docs.asaas.com/docs/criando-assinatura-com-cartao-de-credito
- Split em assinatura: array `splits` na criação vira modelo para cada cobrança futura. Atualizar: enviar novo `splits`; **omitir** mantém, **`null` ou `[]` desativa**. Cobranças já geradas não mudam automaticamente. Fonte: https://docs.asaas.com/docs/split-em-assinaturas
- Bloqueio: se o split ultrapassar o líquido, a assinatura é bloqueada, split desabilitado e novas cobranças param até regularizar; webhooks avisam. Fonte: https://docs.asaas.com/docs/fluxo-de-bloqueio-de-assinatura-por-divergência-de-split
- Ciclos disponíveis e endpoint de atualização completo: NÃO VERIFICADO.

### 1.4 Quem controla a recorrência e implicação nos modelos

- Cartão e boleto: **PSP** (assinatura Asaas gera as cobranças). Pix Automático: **híbrido**, calendário no PSP se modo SUBSCRIPTION, no integrador se MANUAL.
- Modelo A (PSP controla): viável com assinaturas Asaas e Pix Automático SUBSCRIPTION. Sincronizar estado por webhook; dedupe pelo id do evento.
- Modelo B (PMD controla calendário): viável com cartão tokenizado (cobrança avulsa com `creditCardToken`, depende de liberação) e Pix Automático MANUAL.
- Modelo C (híbrido): natural no Asaas (escolher por método).
- Atenção: split em assinatura é por modelo fixo; mudança de regra exige update explícito, e bloqueio por divergência é risco operacional.

### 1.5 Dificuldade do adaptador (TypeScript Edge Functions)

- Baixa a média. REST simples, header `access_token` (formato do header de autenticação NÃO VERIFICADO nesta busca), sem mTLS. Webhook com token estático é trivial de validar, porém fraco (sem assinatura de corpo): tratar token como segredo e comparar em tempo constante; deduplicar por id do evento.
- Sem header de idempotência: o adaptador precisa de chave própria + consulta antes de repetir (cobrança, estorno).
- Cartão trafega pelo backend (escopo PCI) a menos que se use Checkout hospedado.
- Armazenar `apiKey` de subconta (devolvida uma única vez) cifrada.

### 1.6 Riscos e fit

- Riscos: BaaS exige liberação e divulgação de marca; período de avaliação regulatória limita subcontas; cota 25k req/12 h (evitar polling); estorno parcial com split manual; tokenização e pré-autorização dependem de liberação.
- Fit PME (restaurantes, academias, clínicas): **alto**. Boleto/Pix/cartão, assinatura nativa, link de pagamento, Pix Automático para mensalidade (academia, clínica). Academia: assinatura + Pix Automático. Restaurante: Pix/link e split para marketplace/delivery. Clínica: cobrança avulsa/assinatura.

---

## 2. EFÍ (Efí Pay / Gerencianet)

### Matriz

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado / link de pagamento | CONFIRMADO (boleto, cartão) | Link de pagamento via API Cobranças, cartão até 12x e boleto. Pix no link: PARCIAL (blog atual diz que aceita; post de comunidade antigo diz que não) | https://dev.efipay.com.br/en/docs/api-cobrancas/link-de-pagamento/ ; https://sejaefi.com.br/efi-pay/link-de-pagamento |
| Checkout transparente (API cartão) | CONFIRMADO | Fluxo em duas etapas: gerar `payment_token` no cliente (biblioteca JS) e cobrar. Token de uso único ou reutilizável (`reuse`). Token de homologação não vale em produção | https://dev.efipay.com.br/en/docs/api-cobrancas/cartao/ ; https://comunidade.sejaefi.com.br/discussao/armazenamento-reutilizacao-payment-token-5 |
| SDK components | PARCIAL | JS de geração de `payment_token` (evita dados de cartão no servidor) e SDKs de servidor (PHP etc.). Componentes de UI prontos NÃO VERIFICADO | https://github.com/efipay/sdk-php-apis-efi |
| Cartão | CONFIRMADO | via API Cobranças | idem |
| Pix | CONFIRMADO | API Pix com mTLS, `cob`, `cobv` | https://dev.efipay.com.br/en/docs/api-pix/webhooks/ |
| Pix Automático | CONFIRMADO (API) / CONDICIONAL (PJ) | Ver 2.1 | https://dev.efipay.com.br/en/docs/api-pix/pix-automatico/ |
| Boleto | CONFIRMADO | tarifa por boleto pago | https://sejaefi.com.br/tarifas |
| Apple Pay / Google Pay | NÃO VERIFICADO | Nenhum resultado na documentação | (busca sem resultado) |
| Assinaturas nativas | CONFIRMADO (boleto e cartão) | Plano `POST /v1/plan` (nome, intervalo em meses, `repeats`; null = indefinido); assinatura `POST /v1/plan/:id/subscription/one-step` ou duas etapas. Intervalo só em meses. Idade da página ~532 dias | https://dev.efipay.com.br/en/docs/api-cobrancas/assinatura/ |
| Tokenização p/ cobranças futuras | CONFIRMADO | `payment_token` com reuso; também vincula a plano | https://comunidade.sejaefi.com.br/discussao/geracao-payment-token-vincular-cliente-plano-22 |
| Split 1:1 | CONFIRMADO | | https://dev.efipay.com.br/en/docs/api-cobrancas/split-de-pagamento/ |
| Split múltiplos | CONFIRMADO | Cobranças: bloco `marketplace.repasses[]` (`payee_code` + `percentage`). Pix: `POST /v2/gn/split/config`, escopo `gn.split.write`, máximo 20 contas, só entre contas Efí, não divide para a própria conta; tarifa `assumir_total` ou `proporcional`. Fixo vs percentual: Pix tem ambos; cobranças só percentual vi nos exemplos (PARCIAL) | https://dev.efipay.com.br/en/docs/api-pix/split-de-pagamento-pix/ |
| Estorno parcial | PARCIAL | Pix: devolução existe (parcial NÃO VERIFICADO). Cartão: devolução pelo painel em até 90 dias (página antiga ~1.200 dias); API de devolução parcial de cartão NÃO VERIFICADO | https://sejaefi.com.br/central-de-ajuda/gestao-de-cobrancas/fazer-devolucao-de-pagamento-cartao-de-credito |
| Cancelar e capturar | NÃO VERIFICADO | Sem evidência de pré-autorização | (nenhuma) |
| Antecipação | NÃO VERIFICADO | | (nenhuma) |
| Webhooks autenticados | CONFIRMADO (Pix) | **mTLS** (Efí envia certificado; integrador valida a cadeia). Alternativa `x-skip-mtls-checking: true` (hospedagem sem mTLS): exige validar IP de origem (docs citam 34.193.116.226, confirmar) e **"hmac" na query da URL** (segredo fixo, não assinatura do corpo). Cobranças (boleto/cartão): notificação por POST com token `notification` e consulta posterior por `getNotification` (fonte de fórum, 2023, NÃO oficial); URL em `metadata` | https://dev.efipay.com.br/en/docs/api-pix/webhooks/ ; https://comunidade.sejaefi.com.br/discussao/criacao-cobrancas-efipay-notification-url-41 |
| Idempotência | NÃO VERIFICADO | txid definido pelo integrador em Pix (`PUT /v2/cob/:txid`) dá idempotência natural no Pix; em cartão NÃO VERIFICADO | https://dev.efipay.com.br/en/docs/api-pix/pix-automatico/ |
| Sandbox | CONFIRMADO | hosts `pix-h.api.efipay.com.br`, `cobrancas-h.api.efipay.com.br`; credenciais e tokens separados | https://dev.efipay.com.br/en/docs/api-pix/credenciais/ |
| OAuth p/ autorização de vendedor | PARCIAL | OAuth 2.0 client credentials para a própria aplicação (Pix exige certificado P12/PEM; API Cobranças não). Não há fluxo de consentimento de terceiro (estilo "Connect") encontrado | https://dev.efipay.com.br/en/docs/api-pix/credenciais/ |
| Subcontas via API | CONDICIONAL | "API Abertura de contas" exclusiva para parceiros, com liberação por formulário. Posts de comunidade antigos (620 a 760 dias) dizem que subconta não existe, só conta | https://dev.efipay.com.br/en/docs/api-abertura-de-contas/credenciais/ ; https://comunidade.sejaefi.com.br/discussao/split-pix-criacao-subcontas-59 |
| Rate limits | NÃO VERIFICADO | | (nenhuma) |
| Taxas públicas | PARCIAL | Pix API 1,19%; boleto R$ 3,45 por pago; cartão 3,49% (possível "a partir de"); Pix Automático R$ 3,50 por liquidado (criar, cancelar e agendar sem custo) | https://sejaefi.com.br/tarifas ; https://sejaefi.com.br/central-de-ajuda/tarifas-e-prazos |
| Elegibilidade | CONDICIONAL | Pix Automático restrito a PJ; módulos de API precisam ser ativados na aplicação | https://sejaefi.com.br/efi-pay/pix-recorrente |
| Países/moedas | NÃO VERIFICADO | | |
| Quem recebe | CONFIRMADO | Conta Efí do emissor; split só para contas Efí | acima |
| Restrições canal/contrato | CONDICIONAL | Em caso de e-commerce multi-lojista, Efí respondeu que cartão não pode ser oferecido porque atua como subadquirente ("não pode ser subadquirente de subadquirente"); marketplace exige integração com contas dos próprios usuários | https://comunidade.sejaefi.com.br/discussao/integracao-gateway-whitelabel-ecommerce-2 ; https://comunidade.sejaefi.com.br/discussao/split-pix-criacao-subcontas-59 |

### 2.1 Pix Automático e "Pix Recorrente" (must-check)

- **Pix Automático** (API Pix, doc atualizada 2025-11-18): `POST /v2/rec` (cria recorrência; txid atribuído pela Efí), `GET/PATCH /v2/rec/:idRec`, `GET /v2/rec` (filtros `inicio`/`fim` obrigatórios), `GET /v2/solicrec/:idSolicRec`, cobranças `PUT/POST /v2/cobr`, webhooks `PUT/GET/DELETE /v2/webhookrec`, locations `POST /v2/locrec`. Escopos `rec.read`, `rec.write`, `solicrec.read`. Estados: CRIADA, APROVADA, REJEITADA, EXPIRADA, CANCELADA. Fonte: https://dev.efipay.com.br/en/docs/api-pix/pix-automatico/
- Jornada 3: `POST /v2/locrec` -> `POST /v2/cob` ou `PUT /v2/cob/:txid` -> `POST /v2/rec`. Jornada 4: `PUT /v2/cobv/:txid` com opção de Pix Automático. Fonte: https://sejaefi.com.br/blog/pix-automatico-guia-tecnico (blog; um trecho dele cita rotas `/v2/recurrence/...` que divergem da doc atual: **prevalece a doc oficial**).
- Valor fixo: Efí automatiza as cobranças; valor variável: integrador cria cada `cobr`. Periodicidade: semanal, mensal, trimestral, semestral, anual (FAQ comercial, NÃO é doc técnica).
- **Pix Recorrente** é outro produto: Open Finance, `POST /v1/pagamentos-recorrentes/pix`, API Open Finance; não confundir. Fonte: https://dev.efipay.com.br/en/docs/api-open-finance/pagamentos-recorrentes/ ; https://sejaefi.com.br/efi-pay/pix-recorrente
- Split em Pix Automático: NÃO VERIFICADO.

### 2.2 Quem controla a recorrência

- Boleto/cartão (assinatura): **PSP** (plano + assinatura, intervalo em meses). Pix Automático: **PSP** para valor fixo, **integrador** para valor variável (cria `cobr`). Modelo A para cartão/boleto e Pix fixo; B (PMD) para Pix variável ou cartão com `payment_token` reutilizável (cobrança avulsa); C quando misturar.
- Limitação: plano só em intervalo de meses (semanas/dias em plano NÃO VERIFICADO).

### 2.3 Dificuldade do adaptador (TypeScript Edge Functions)

- **Média a alta.** API Pix e Open Finance exigem **certificado P12/PEM (mTLS) também nas chamadas de saída**. Em Edge Functions (Deno), mTLS de cliente depende de `Deno.createHttpClient` com cert/key; verificar suporte no runtime alvo (NÃO VERIFICADO aqui). Webhook Pix com mTLS exige terminação TLS que a Edge Function normalmente não controla: na prática usar `x-skip-mtls-checking` + validação de IP + `hmac` na URL, ou um proxy mTLS (o próprio fórum cita proxy de terceiro; risco).
- API Cobranças (cartão/boleto/assinatura) não usa certificado: mais simples.
- Três bases de URL diferentes (pix, cobranças, abertura de contas), credenciais por ambiente, escopos separados.
- Notificação de cobranças em dois passos (token + consulta): requer chamada extra e estado.

### 2.4 Riscos e fit

- Riscos: split limitado a contas Efí; "sem subadquirência de subadquirente" bloqueia cartão em marketplace; subcontas só via parceria; docs com idade mista e blogs divergentes das rotas; ausência de evidência de pré-autorização, Apple/Google Pay, antecipação; segredo HMAC na query vaza em logs.
- Fit PME: **alto para negócio que recebe na própria conta Efí** (academias e clínicas com boleto/cartão/Pix Automático, tarifas públicas baixas e sem mensalidade). **Baixo para plataforma multi-estabelecimento** com cartão e white label.

---

## 3. IUGU

### Matriz

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado / link | CONFIRMADO | Checkout iugu (fatura com `secure_url`), link de pagamento (Pix, cartão, boleto), assinatura com Checkout iugu | https://dev.iugu.com/docs/checkout ; https://www.iugu.com/link-pagamentos ; https://dev.iugu.com/reference/assinatura-com-checkout-iugu |
| Checkout transparente (API cartão) | CONFIRMADO | `iugu.js` tokeniza no cliente (token de uso único) e `POST /v1/charge`; qualquer resposta da cobrança invalida o token | https://dev.iugu.com/docs/realizar-uma-cobran%C3%A7a-simples-no-cart%C3%A3o-de-cr%C3%A9dito-por-api |
| SDK components | PARCIAL | `iugu.js` (tokenização, não UI completa); componentes de UI NÃO VERIFICADO | idem |
| Cartão / Pix / Boleto | CONFIRMADO | "Aceitamos 3 métodos": cartão, boleto, Pix (também Bolepix) | https://dev.iugu.com/docs/habilitar-m%C3%A9todos-de-pagamento-via-api |
| Pix Automático | CONDICIONAL | Dois caminhos: (1) produto iugu Recorrência compatível; (2) API: **a API não gerencia a recorrência**, exige motor do próprio lojista. Jornada 3 (QR com 1º pagamento imediato) e 4 (QR com proposta de recorrência) | https://dev.iugu.com/docs/cobrar-com-pix-automatico-por-api ; https://www.iugu.com/pix-automatico |
| Apple Pay / Google Pay | NÃO SUPORTADO nas fontes (docs listam só 3 métodos) -> classificar NÃO VERIFICADO comercialmente | | https://dev.iugu.com/docs/habilitar-m%C3%A9todos-de-pagamento-via-api |
| Assinaturas nativas | CONFIRMADO | `POST /v1/plans` (identificador, intervalo, tipo meses/semanas, valor em centavos, limite de ciclos) e `POST /v1/subscriptions` (`plan_identifier`, `customer_id`, `expires_at` = 1ª cobrança) | https://dev.iugu.com/reference/criar-plano ; https://dev.iugu.com/docs/realizar-cobran%C3%A7as-recorrentes-por-api |
| Tokenização p/ cobranças futuras | CONFIRMADO | Forma de pagamento do cliente (`Criar Forma de Pagamento`) e tokenização | https://dev.iugu.com/docs/tokenizacao-de-cartao-de-credito ; https://dev.iugu.com/reference/criar-forma-de-pagamento |
| Split 1:1 / múltiplos | CONFIRMADO | `splits[]` com `recipient_account_id` + `cents` ou `percent`; sem limite de contas na API; conta criadora da fatura não deve ser destinatária; soma nunca chega a 100% | https://dev.iugu.com/docs/split-de-pagamentos |
| **Split por assinatura** | CONFIRMADO | `splits` enviados na criação da assinatura valem para todas as faturas geradas | https://dev.iugu.com/reference/criar-assinatura |
| Estorno parcial | PARCIAL | Só **cartão** (`partial_value_refund_cents` em `POST /v1/invoices/{id}/refund`, até 180 dias); Pix só total (90 dias); boleto sem estorno pela plataforma. Com split, reembolso é rateado proporcionalmente entre contas | https://dev.iugu.com/docs/estorno ; https://dev.iugu.com/reference/reembolso-cartao-de-credito ; https://dev.iugu.com/reference/reembolso-pix |
| Cancelar e capturar | CONFIRMADO | Cobrança em duas etapas (captura tardia): reserva, captura ou cancela (`PUT` cancelar fatura); cancelamento automático em 7 dias | https://dev.iugu.com/docs/cobran%C3%A7a-em-duas-etapas |
| Antecipação | CONDICIONAL | Contrato: pedido via painel, iugu analisa e define preço; **não antecipa recebíveis futuros** (transações ainda não ocorridas); lojista responde por estornos. Contrato ~1.941 dias | https://www.iugu.com/juridico/contrato |
| Webhooks ("gatilhos") autenticados | PARCIAL | `POST /v1/web_hooks` com campo `authorization` -> usado como **Basic Auth** no recebimento; payload `application/x-www-form-urlencoded`; até 20 gatilhos; reenvio por `web_hook_logs/{id}/retry` e `web_hooks/resend`. HMAC de corpo: NÃO VERIFICADO (não achado) | https://dev.iugu.com/reference/criar-gatilho ; https://dev.iugu.com/docs/gatilhos ; https://dev.iugu.com/docs/reenviar-gatilhos-para-o-webhook |
| Idempotência | NÃO VERIFICADO | | |
| Sandbox | NÃO VERIFICADO | Iugu usa modo de teste por token de conta; não confirmado nesta busca | |
| OAuth / autorização de vendedor | PARCIAL | Existe fluxo OAuth Authorization Code em `developer.iugu.com/identity/oauth` (produto Identity, possivelmente outra plataforma); relação com a API de pagamentos NÃO VERIFICADO. Subcontas usam `live_api_token` da subconta | https://developer.iugu.com/identity/oauth/authorization-code/ |
| Subcontas via API | CONDICIONAL | `POST /v1/marketplace/create_account` (1 por requisição, conta mestre precisa do recurso Marketplace); verificação obrigatória via `POST /v1/accounts/{id}/request_verification` com `user_token` (documento, selfie, comprovante); saque mínimo R$5; saque no dia útil seguinte; desativar cancela faturas/assinaturas pendentes | https://dev.iugu.com/docs/configurar-subconta-por-api ; https://dev.iugu.com/docs/fluxo-marketplace |
| White label | CONDICIONAL | Fluxo whitelabel documentado: etapas na conta mestre, depois usa `live_api_token` da subconta; exige **assinatura RSA** das requisições; verificação opcional de assinatura incompatível com whitelabel | https://dev.iugu.com/docs/fluxo-marketplace ; https://dev.iugu.com/reference/autentica%C3%A7%C3%A3o |
| Rate limits | NÃO VERIFICADO | | |
| Taxas públicas | PARCIAL | Variam por plano (consultar painel). Tabela antiga (~5 anos): Pix 0,99%, boleto R$ 2,19, cartão 3,34% + R$ 0,40. Valor mínimo R$1 (parcelado R$5/parcela). Recebimento de cartão padrão 30 dias | https://support.iugu.com/hc/pt-br/articles/360056021752 ; https://support.iugu.com/hc/pt-br/articles/201727467 |
| Elegibilidade | CONDICIONAL | Marketplace/split e Pix Automático dependem de contratação; verificação KYC das subcontas | acima |
| Países/moedas | NÃO VERIFICADO | | |
| Quem recebe | CONFIRMADO | Conta que emite a fatura (mestre ou subconta); splits repartem para outras contas iugu | https://dev.iugu.com/docs/split-de-pagamentos |
| Restrições canal/contrato | CONDICIONAL | Marketplace, Pix Automático, captura tardia e antecipação dependem de habilitação; split em assinatura sobrescrito se o "multi split" for recriado (fonte: SDK comunitário, não oficial) | |

### 3.1 Quem controla a recorrência

- Cartão/boleto/Pix via **assinatura**: **PSP** (iugu gera as faturas). Pix Automático via API: **integrador** (a API não gerencia a recorrência), ou **PSP** se usar o produto iugu Recorrência. Modelo A com assinaturas; B com Pix Automático por API ou cartão tokenizado + `POST /v1/charge`; C misturando.
- Atenção: não achei na busca o endpoint de atualização de assinatura nem política de retentativas (NÃO VERIFICADO).

### 3.2 Dificuldade do adaptador (TypeScript Edge Functions)

- **Média.** REST com Basic Auth de token, payload e gatilhos em form-urlencoded (parse diferente de JSON). Conceitos: fatura (invoice) como entidade central, planos, assinaturas, subcontas com 3 tipos de token (`api_token`, `user_token`, `live_api_token`).
- White label exige assinatura RSA de requisições: implementar com WebCrypto (viável em Deno).
- Webhook: Basic Auth estático + reconciliação por consulta; sem HMAC, tratar como entrada não confiável e revalidar a fatura via API antes de agir.
- Split por assinatura bem alinhado a SaaS multi-estabelecimento.

### 3.3 Riscos e fit

- Riscos: marketing/docs de datas muito diferentes (algumas ~348 dias, contrato ~1.941 dias); Pix estorno só total; boleto sem estorno; taxas só no contrato; Apple/Google Pay ausentes; verificação KYC de subcontas pode levar 24 h; sem informação de sandbox e rate limit.
- Fit PME: **bom, especialmente para plataformas/SaaS que cobram assinatura das PMEs e dividem receita** (split por assinatura, subcontas). Para o estabelecimento isolado, é aceitável, mas depende de plano contratado.

---

## 4. Comparação resumida

| Critério | Asaas | Efí | Iugu |
|---|---|---|---|
| Split cartão | Sim, por walletId (conta Asaas) | Sim (percentual em `marketplace.repasses`), restrições de subadquirência | Sim (`splits`, centavos ou %) |
| Split em assinatura | Sim, modelo nas cobranças futuras; update explícito | NÃO VERIFICADO | Sim, na criação da assinatura |
| Estorno parcial | Cartão e Pix (split manual) | Parcial/NÃO VERIFICADO | Só cartão |
| Pré-autorização/captura | Condicional (3 a 25 dias) | NÃO VERIFICADO | Sim (7 dias) |
| Webhook | Token estático em header | mTLS (ou skip + IP + hmac na URL) | Basic Auth estático, form-urlencoded |
| Pix Automático | Condicional, PJ >= 6 meses | Sim (API Pix, `rec`/`cobr`) | Condicional, API sem motor |
| Subconta/white label | Condicional (BaaS via gerente) | Condicional (parceiro, abertura em lote) | Condicional (Marketplace + KYC + RSA) |
| Idempotência | Sem header; dedupe webhook por id | txid no Pix; resto NÃO VERIFICADO | NÃO VERIFICADO |
| Dificuldade adapter Edge | Baixa-média | Média-alta (mTLS) | Média |

## 5. Lacunas a validar com suporte/contrato

1. Apple Pay e Google Pay: nenhum dos três documentou suporte.
2. Idempotência (header) nos três; rate limits de Efí e Iugu; sandbox de Iugu.
3. Efí: split de cobrança em assinatura, fixo vs percentual em cartão, estorno parcial de cartão por API, pré-autorização, antecipação.
4. Asaas: ciclos aceitos e update de assinatura; split nas cobranças de Pix Automático; formato do header de autenticação.
5. Iugu: update/cancelamento de assinatura e retentativas; OAuth do Identity versus API de pagamentos.
6. Países/moedas dos três (presumido BRL, não confirmado).
7. Taxas efetivas e liberações (tokenização, BaaS, Pix Automático, antecipação, marketplace): somente em contrato.
