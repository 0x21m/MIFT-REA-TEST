# Pesquisa PSP: Mercado Pago, InfinitePay, Appmax (data: 2026-10-15)

Metodo e limites: so WebSearch (WebFetch/curl bloqueados). Os resultados chegam como resumos, nao como paginas completas. As datas/versoes das paginas quase nunca ficaram visiveis. Marcado NAO VERIFICADO tudo o que a busca nao confirmou. Doc publica nao prova habilitacao comercial: CONDICIONAL quando ha elegibilidade/contrato. Prefixo de URL MP = https://www.mercadopago.com.br/developers/pt/ (ou /en/).

Legenda: CONF = CONFIRMADO, PARC = PARCIAL, COND = CONDICIONAL, N/S = NAO SUPORTADO, N/V = NAO VERIFICADO.

---
## 1. MERCADO PAGO

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado (redirect) | CONF | Checkout Pro: comprador e redirecionado ao formulario MP e volta ao site; usa "preferences". Um artigo de blog 2026 diz "sem redirecionamentos visiveis" (contradiz; tratar como marketing) | docs/checkout-pro-preferences/overview |
| Checkout transparente | CONF | Duas APIs: Orders (`POST /v1/orders`, recomendada para novas integracoes) e Payments (`POST /v1/payments`, so correcoes de seguranca/estabilidade) | docs/checkout-api-orders/payment-integration ; docs/checkout-api-payments/overview |
| SDK components (Bricks) | CONF | Payment Brick (cartao, Pix, boleto, conta MP, parcelamento sem cartao; pode salvar cartao), Card Payment Brick, Wallet Brick, Status Screen Brick. Client-side (MercadoPago.js) | docs/checkout-bricks/introduction ; /payment-brick/introduction |
| Cartao | CONF | Credito/debito via token MercadoPago.js; Orders `websites/cards` | docs/checkout-api-orders/payment-integration/websites/cards |
| Pix | CONF | Orders: `payment_method.id=pix`, `type=bank_transfer`; retorna qr_code/qr_code_base64/ticket_url; expiracao padrao 24h, 30 min a 30 dias | docs/checkout-api-orders/payment-integration/pix |
| Pix Automatico | N/V | Nenhuma doc de API MP encontrada para Pix Automatico (so Pix avulso). Nao assumir | busca sem resultado |
| Boleto | CONF | Orders `POST /v1/orders`, `boleto`/`ticket`; endereco do pagador obrigatorio; vencimento padrao 3 dias uteis | docs/checkout-api-orders/payment-integration/websites/boleto |
| Apple Pay | COND | Doc existe (docs/apple-pay/overview) mas achada so em sites CO/MX; exige contato com time comercial; so Visa/Mastercard; Safari/iOS. Disponibilidade no Brasil N/V | mercadopago.com.co/developers/pt/docs/apple-pay/overview |
| Google Pay | N/V | Nenhuma doc oficial MP de Google Pay encontrada | busca sem resultado |
| Assinaturas/recorrente | CONF | `/preapproval_plan` (plano), `/preapproval` (assinatura com ou sem plano); retentativas em janela de 10 dias, cancela apos 3 recusas; gestao via `PUT /preapproval/{id}`, `/preapproval/search`. Doc diverge sobre obrigatoriedade de `preapproval_plan_id` (pagina diz obrigatorio, reference diz opcional). Alternativa: Orders `automatic_payments` com `payment_profile_id` (1 a 5 tentativas) | docs/subscriptions/integration-configuration/subscription-associated-plan ; reference/subscriptions/_preapproval/post ; docs/automatic-payments-orders/process-recurring-payments |
| Tokenizacao p/ cobrancas futuras | PARC | `POST /v1/customers/{id}/cards` salva cartao tokenizado; Orders cobra cartao existente via token. Regras (CVV/token por cobranca, MIT) N/V | reference checkout-api overview ; docs/checkout-api-orders/payment-integration/mobile/cards |
| Split 1:1 | CONF/COND | Documentado: vendedor vinculado por OAuth; `application_fee` (Checkout Transparente/Bricks, `/v1/payments`, Bearer = access_token do vendedor) ou `marketplace_fee` (Checkout Pro). Comissao MP sai primeiro do vendedor; fee do marketplace sobre o restante. So Checkout Pro, Transparente e Bricks. Pagamento so com saldo em conta MP entre contas (sem transferencia de banco externo) - citado no resumo da pagina, validar alcance. Um vendedor por pagamento (modelo "1:1") | docs/split-payments/split-1-1/overview ; .../integration-configuration/integrate-marketplace |
| Split multiplos recebedores (1:N) | COND | So em blogs MP: 1:N existe para "portfolios gerenciados" e exige contato comercial. Outro blog afirma multiplos recebedores sem citar contrato (conflito). Sem pagina tecnica 1:N na doc. Tratar como NAO disponivel via API aberta ate confirmar com comercial | blog mercadopago.com.br/blog/split-pagamento-marketplace-servicos-beleza |
| Reembolso parcial | CONF | Orders: `POST /v1/orders/{id}/refund` com `transactions[{id, amount}]` (uma transacao por chamada); sem amount = total; status `partially_refunded`; prazo 180 dias; precisa saldo. Payments: `POST /v1/payments/{id}/refunds` com `amount`. Split: reembolso dividido proporcionalmente entre vendedor e marketplace; em 1:1 marketplace nao pode reembolsar total se vendedor sem saldo | reference/orders/online-payments/refund/post ; docs/checkout-api-orders/payment-management/refunds-cancellations |
| Cancelar e capturar (auth/capture) | CONF/PARC | Payments: `capture:false` depois `PUT /v1/payments/{id}` `capture:true`; cancelar `status:cancelled`. Janela de captura 5 dias. Captura parcial: pagina Payments/Bricks diz que pode (`transaction_amount`), pagina Orders diz que so valor total (conflito) | docs/checkout-api-orders/payment-management/reserve-capture-cancel ; docs/checkout-api/payment-management/capture-authorized-payment |
| Antecipacao | PARC | Nao e API: vendedor escolhe prazo de liberacao D0/D14/D30 (taxas diferentes) no painel/conta. Controle por API N/V | blog mercadopago.com.br/blog/prazo-recebimento-link-de-pagamento |
| Webhooks autenticados | CONF | Header `x-signature` com `ts=...,v1=...`; manifest `id:[data.id da query];request-id:[x-request-id];ts:[ts];` ; HMAC-SHA256 hex com a chave secreta (painel: Suas integracoes > Webhooks); par ausente e omitido do manifest; comparar em tempo constante; responder 200/201. SDK tem WebhookSignatureValidator | docs/checkout-api-orders/notifications ; docs/checkout-pro-orders/notifications |
| Idempotencia | CONF | `X-Idempotency-Key` obrigatorio em Orders (criar, capturar, transactions, process, cancel, refund) e em Payments (criar e refund). UUID v4; limite citado 64 (alguns lugares 128) caracteres; reuso com corpo diferente em 24h = `idempotency_key_already_used` | docs/checkout-api-orders/resources/migrate-payments-to-orders |
| Sandbox | PARC | Contas de teste (comprador/vendedor, ate 15, nao deletaveis, mesmo pais), cartoes de teste, resultado definido pelo nome do titular (APRO, OTHE, FUND, CONT). Bricks nao aceita contas de teste; Pix "nao pode ser testado com credenciais de teste" segundo blog, mas ha pagina oficial de teste Pix Orders com `APRO` | docs/your-integrations/test/accounts ; /test/cards ; docs/checkout-api-orders/integration-test/pix |
| OAuth p/ autorizar vendedor | CONF | Authorization code (10 min, uso unico), access_token 180 dias, refresh_token (rotaciona a cada refresh; exige scope `offline_access`; doc diz 6 meses em uma pagina), PKCE opcional; `POST /oauth/token`. Um token por vendedor | reference/authentication/oauth/_oauth_token/post ; docs/.../security/oauth/introduction |
| Rate limits | PARC | Sem numero publicado. 429 `usage_quota_exceeded` (Orders, cabecalho `Retry-After`), `too_many_requests`, `local_rate_limited` (OAuth). Termos permitem limitar/cobrar chamadas | docs/checkout-api-orders/payment-management/integration-errors/api |
| Taxas publicas | PARC | Aproximado (blogs, variam por pagina): credito D0 ~4,98%, D14 ~4,49%, D30 ~3,98%; Pix ~0,99% no checkout; boleto R$3,49. Confirmar no painel | blog mercadopago.com.br/blog/prazo-recebimento-link-de-pagamento |
| Elegibilidade | PARC | Conta de vendedor MP, SSL, chaves Pix (para Pix). Split: conta ativa para marketplace e vendedores | docs/checkout-bricks/payment-brick/introduction |
| Paises/moedas | CONF | Docs multipais (AR, BR, CL, CO, MX, UY...); BRL no Brasil. Contas de teste so mesmo pais | varios |
| Conta que recebe | CONF | Conta MP do vendedor (OAuth) ou do proprio integrador; em split, vendedor recebe liquido e marketplace recebe a fee na sua conta MP | split overview |
| Restricoes de canal/contrato | COND | Apple Pay (comercial), 1:N (comercial), Pix Automatico N/V, liberacao D0/D14/D30 depende de conta/risco | acima |

### Dificuldade (adapter TS em Edge Function): MEDIA
- Por que: REST + JSON, boa doc, SDK Node; webhook com HMAC verificavel facilmente com Web Crypto (HMAC-SHA256); idempotency header simples. Complica: duas APIs (Orders vs Payments) com semantica diferente; split exige OAuth por vendedor com refresh rotativo (guardar refresh_token novo a cada renovacao, concorrencia entre Edge Functions); notificacoes sao "ping" e exigem GET para estado atual; Bricks/MercadoPago.js sao client-side (device id, token do cartao); janelas e conflitos de doc (captura parcial, preapproval).
### Riscos
- Tokens de vendedor expiram (180 dias) e refresh rotaciona: perda do novo refresh_token quebra a conexao.
- Conflitos de doc (captura parcial Orders vs Payments; preapproval_plan_id) - testar em producao-sandbox.
- 1:N e Apple Pay dependem de contrato; Google Pay e Pix Automatico sem doc encontrada.
- Taxas e prazos variam por conta; reembolso depende de saldo do vendedor (em split).
- Rate limit sem numero publico; tratar 429 com Retry-After.
- Sandbox limitado (Bricks sem contas de teste).

---
## 2. INFINITEPAY

Existem DUAS superficies publicas distintas:
(A) Checkout Integrado (link de pagamento via API, sem chave): https://www.infinitepay.io/checkout-documentacao
(B) API v2 de adquirencia (IPay.js, client_credentials): https://docs.infinitepay.io

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado (redirect) | CONF | `POST https://api.checkout.infinitepay.io/links` com `handle` (InfiniteTag sem `$`), itens, opcionais `order_nsu`, `webhook_url`, redirect; cliente paga na pagina InfinitePay | infinitepay.io/checkout-documentacao ; ajuda.infinitepay.io/pt-BR/articles/10766888 |
| Checkout transparente | COND | Superficie (B): `POST api.infinitepay.io/v2/transactions` com `card.token` e `metadata.risk.session_id`; credenciais geradas no Dashboard, mas a busca nao confirmou se `transactions` e liberado a qualquer lojista (NAO VERIFICADO elegibilidade) | docs.infinitepay.io |
| SDK components | PARC | IPay.js (tokenizacao + fingerprint, atributos `data-ip`, eventos `result:success/error`). Nao e componente de pagamento pronto | docs.infinitepay.io |
| Cartao | CONF | Credito (ate 12x) e debito; no checkout capture_method `credit_card` | checkout-documentacao |
| Pix | CONF | capture_method `pix`; Pix sem taxa segundo pagina de taxas | checkout-documentacao ; infinitepay.io/taxas |
| Pix Automatico | N/V | Nao encontrado | - |
| Boleto | N/V | Nao encontrado na API de checkout | - |
| Apple Pay / Google Pay | PARC | Existe pagar link de pagamento com Google Pay (artigo de ajuda do consumidor); como recurso de API N/V | ajuda.infinitepay.io/pt-BR/articles/9741853 |
| Assinaturas/recorrente | N/V | Nao encontrado | - |
| Tokenizacao p/ cobrancas futuras | PARC | `POST /v2/cards/tokenize` (browser→servidores InfinitePay) gera token; se token e reutilizavel para cobrancas futuras N/V | docs.infinitepay.io |
| Split 1:1 / multiplos | N/V | Nenhuma evidencia publica | - |
| Reembolso parcial | N/S via API publica do checkout | So cancelamento pelo app/navegador/maquininha (credito 180 dias, debito Elo/Visa 90, Mastercard mesmo dia; exige saldo; irreversivel). Parcial e API de refund N/V | ajuda.infinitepay.io/pt-BR/articles/6097686 |
| Cancel/capture (auth/capture) | N/V | Nao encontrado | - |
| Antecipacao | PARC | Embutida nas taxas de cartao ("receba na hora ou em 1 dia util com antecipacao inclusa"); nao e endpoint | infinitepay.io/taxas |
| Webhook autenticado | NAO CONFIRMADO / provavel N/S | Webhook por `webhook_url` no link; payload com `invoice_slug`, `transaction_nsu`, `order_nsu`, `capture_method`, `receipt_url`; responder 200 (400 gera retry). Nenhuma assinatura/HMAC documentada. Mitigacao documentada: confirmar com `payment_check` | checkout-documentacao |
| Idempotencia | N/V | `order_nsu` (do lojista) funciona como chave natural de pedido; header de idempotencia N/V | - |
| Sandbox | N/V | Nada encontrado para o checkout | - |
| OAuth p/ seller | N/S (checkout) / PARC (v2) | Checkout identifica lojista so por `handle`; v2 usa `POST /v2/oauth/token` client_credentials, scopes `card_tokenization` e `transactions`, mas credenciais sao do proprio lojista (Dashboard), nao autorizacao de terceiro | docs.infinitepay.io |
| Rate limits | N/V | - | - |
| Taxas | PARC | Cartao a partir de 0,75%; faixa ate R$20 mil/mes: debito 1,37%, credito a vista 3,15%; "Na hora" mais caro; Pix gratis; numeros misturados na pagina | infinitepay.io/taxas |
| Elegibilidade | COND | Conta InfinitePay (InfiniteTag) do lojista | checkout-documentacao |
| Paises/moedas | PARC | Brasil/BRL (valores em centavos inteiros) | checkout-documentacao |
| Conta que recebe | CONF | Conta InfinitePay do dono da InfiniteTag (`handle`) | checkout-documentacao |
| Restricoes | COND | Checkout Integrado e Link de Pagamento: mesmas taxas; chargeback e descontado de recebimentos futuros | ajuda/blog chargeback |

### O que a API publica de checkout oferece vs. o que um adapter PMD precisaria
Oferece: gerar link (`/links`), webhook de pagamento aprovado, consulta `payment_check` (`handle`, `order_nsu`, `transaction_nsu`, `slug` → `paid`, `amount`, `paid_amount`, `installments`, `capture_method`).
Falta (ou N/V): assinatura de webhook, idempotency header, reembolso/cancelamento por API, parcial, captura, assinaturas, tokenizacao reutilizavel, split, OAuth de terceiros, sandbox, rate limits, boleto. Um adapter so de "criar cobranca + confirmar pagamento" e viavel; reembolso teria de ser manual no app InfinitePay.
Nota: PMD ja possui adapter InfinitePay (nao avaliado aqui).

### Dificuldade: BAIXA (checkout) / MEDIA-ALTA (v2)
- Checkout: 2 endpoints, sem segredo; trivial em Edge Function. Baixa porque o escopo e pequeno, mas a seguranca depende de `payment_check` e de validar `order_nsu`.
- v2: tokenizacao com IPay.js no browser, fingerprint, acesso a `transactions` provavelmente condicional.
### Riscos
- Webhook sem autenticacao: nunca confiar no corpo, sempre chamar `payment_check` e comparar valor/order_nsu.
- Sem refund/capture/split por API: PMD nao pode automatizar estornos.
- Escopo identificado so por `handle` (sem OAuth): cada lojista informa seu handle, sem prova de propriedade.
- Docs v2 tem exemplo `expires_in` incomum e um aviso antigo de dashboard desativado (2022) no login - confirmar acesso.
- Dependencia de contrato (acesso a v2) N/V.

---
## 3. APPMAX (como merchant app e como PSP integravel pela PMD)

Doc oficial: https://docs.appmax.com.br ; help: https://help-center.appmax.com.br ; developers: https://appmax.com.br/en-US/developers/ ; App Store: appstore.appmax.com.br. Base: producao `api.appmax.com.br`, sandbox `https://api.sandboxappmax.com.br` (scripts sandbox `scripts.sandboxappmax.com.br/appmax.min.js`).

| Item | Status | Nota | Fonte |
|---|---|---|---|
| Checkout hospedado | PARC | Link de pagamento Appmax existe (produto); via API N/V | appmax.com.br/en-US/payment-link/ |
| Checkout transparente | CONF | Fluxo: cliente → pedido → pagamento (`POST /v1/payments/tokenize` + `POST /v1/payments/credit-card` com `order_id`, `customer_id`) | docs.appmax.com.br/api-reference/payments/cartao-credito |
| SDK components | PARC | Appmax JS (tokenizacao, botao Google Pay); SDK npm `@appmax-api/sdk` (nao oficial confirmado) | docs.appmax.com.br/api-reference/payments/google-pay-appmax-js |
| Cartao | CONF | Ver acima | idem |
| Pix | CONF | Pagamento Pix via API; liquidacao imediata | docs.appmax.com.br ; help-center (taxas) |
| Pix Automatico | N/V | - | - |
| Boleto | CONF | Pagamento boleto via API; R$3,49 | docs.appmax.com.br ; appmax.com.br/en-US/fees/ |
| Apple Pay | CONF | Pagina "Pagamento com Apple Pay" na API (inclui VTEX) | docs.appmax.com.br/api-reference/payments/apple-pay |
| Google Pay | CONF | "Implementando o botao Google Pay com o Appmax JS" | docs.appmax.com.br/api-reference/payments/google-pay-appmax-js |
| Assinaturas/recorrente | PARC | Secao "Recorrencia" na API e menu Assinaturas no painel (semanal/mensal/anual); endpoints nao lidos. Webhook tem categoria Subscription | docs.appmax.com.br ; help-center.appmax.com.br/artigos/pagamento-recorrente-na-shopify |
| Tokenizacao p/ cobrancas futuras | N/V | Token do fluxo de cartao descrito como uso unico; recorrencia usa mecanismo proprio N/V | docs cartao-credito |
| Split 1:1 / multiplos | COND | Split por percentual ou valor fixo na criacao do pedido (`POST /orders/{orderId}/split-order`, `recipient_hash`), cartao/boleto/Pix, soma > 100% e rejeitada, imutavel apos pagamento. Disponivel so para parceiros da API V4 apos homologacao do conector e credenciais fornecidas pela Appmax. Quantidade maxima de recebedores N/V | help-center.appmax.com.br/artigos/split-de-pagamentos-na-appmax ; docs/guides/split-status |
| Recebedores/saques | CONF | Onboarding com facematch + KYC (estados: aguardando facematch, em verificacao, concluido); so concluido recebe split e saca; sem webhook de transicao (polling `GET /status`); `GET /balances` 404 antes de provisionar; saque retorna pending e tambem sem webhook (polling); `withdrawal_blocked` retorna 403. Recebedor nao usa painel | split-status |
| Reembolso parcial | PARC | API: estorno total ou parcial ("Criar estorno"; endpoint exato nao lido). Pedidos com split aceitam SO estorno total (parcial retorna erro de validacao) | docs.appmax.com.br ; docs/guides/split-status |
| Cancel/capture | N/V | Nao encontrado | - |
| Antecipacao | PARC | Padrao cartao D+30; antecipacao D+1 por 1,49% sobre o liquido; taxa fixa R$3,67 por saque/antecipacao < R$10 mil; no contrato a taxa de antecipacao e negociada. Controle via API N/V | appmax.com.br/en-US/fees/ ; help-center.appmax.com.br/artigos/taxas-aplicadas-no-saque-ou-antecipacao |
| Webhooks | CONF existencia / assinatura N/V | 29 eventos em 4 categorias (Order, Customer, Payment, Subscription); config por app/painel; "retry automatico" citado so em pagina de marketing. NENHUMA assinatura/HMAC confirmada; integracoes de terceiros usam um "token" que nao e validacao | docs/guides/criar-aplicativo ; appmax.com.br/en-US/developers/ |
| Idempotencia | N/V | - | - |
| Sandbox | CONF | `api.sandboxappmax.com.br` | docs.appmax.com.br |
| OAuth | PARC | Bearer do MERCHANT via `POST /oauth2/token` com credenciais do merchant (nao do app); `client_id/client_secret` emitidos na instalacao do app; fluxo de instalacao `/app/authorize` → redirect → `/app/client/generate`; URL de validacao deve responder 200 `{external_id: UUID}`. `grant_type=client_credentials` NAO confirmado pela busca | docs/guides/criar-aplicativo ; docs/guides/validar-url |
| Rate limits | PARC | Por credencial, na reference; guia de split recomenda nao pollar >1 req/s; tetos "5 rps / 100 mil mes" NAO VERIFICADOS (nao encontrados) | appmax.com.br/en-US/developers/ ; docs/guides/split-status |
| Taxas publicas | CONF/PARC | Pix 0,99%; boleto R$3,49; cartao 3,49% (+ possivel R$0,99 por transacao segundo blog); sem mensalidade segundo pagina de taxas, mas termos de uso citam taxa de manutencao (conflito); >R$100k TPV mensal negociavel | appmax.com.br/en-US/fees/ ; blog.appmax.com.br/taxas-da-appmax/ ; appmax.com.br/termos-de-uso/ |
| Elegibilidade | COND | Terceiro pode criar app na App Store: exige CNPJ ativo, app publico (qualquer merchant instala) ou privado, revisao tecnica antes de ficar visivel. Split exige homologacao de conector (API V4) | docs/guides/criar-aplicativo |
| Paises/moedas | PARC | Brasil/BRL | - |
| Conta que recebe | CONF | Conta Appmax do merchant; em split, recebedores tem saldo proprio na Appmax | split help |
| Restricoes | COND | "Payment as a Service": NAO VERIFICADO (nenhuma doc oficial encontrada). Contexto publico: Appmax e subadquirente com autorizacao do BC como Instituicao de Pagamento e planeja abrir conta para vendedores de marketplaces (finsidersbrasil / latamfintech - imprensa, nao oficial). Implicacao provavel (hipotese): modelo de plataforma/marketplace com recebedores, ligado a homologacao V4; confirmar com Appmax | finsidersbrasil.com.br ; latamfintech.co |

### PMD pode integrar como "merchant app" comum? 
CONDICIONAL/provavel sim: App Store aceita desenvolvedores com CNPJ, app publico ou privado, com revisao tecnica; o merchant instala o app e gera credenciais. Mas isso e modelo "integracao para lojistas Appmax", nao modelo marketplace da PMD cobrando em nome de terceiros. Split/recebedores exigem homologacao e credenciais da Appmax (contrato).

### Dificuldade: MEDIA-ALTA
- Fluxo de instalacao do app (authorize/redirect/generate + URL de validacao), token de merchant (nao do app) a renovar, pedido→cliente→pagamento em 3 chamadas, tokenizacao via Appmax JS no front.
- Webhooks sem assinatura documentada: exige reconsulta do pedido.
- Split: onboarding KYC assincrono com polling (sem webhooks), saques por polling, estorno so total em split.
- Limites de taxa nao claros; reference completa nao lida (varios endpoints so inferidos).
### Riscos
- Webhook nao autenticavel (se confirmado) → sempre `GET` do pedido antes de liberar.
- Rate limit baixo (polling de split 1 req/s) pode estrangular Edge Functions concorrentes.
- Dependencia contratual/homologacao para split e "PaaS".
- Conflitos de taxa (mensalidade) e de prazos (boleto).
- Estorno parcial bloqueado em pedidos com split.

---
## 4. Comparativo rapido (para decisao)
- Webhook assinado: MP sim (HMAC-SHA256, `x-signature`); InfinitePay nao documentado; Appmax nao documentado.
- Split API aberto: MP 1:1 sim via OAuth (so Checkout Pro/Transparente/Bricks); InfinitePay nada; Appmax split por contrato/homologacao V4.
- Reembolso parcial via API: MP sim; InfinitePay nao (so painel); Appmax sim exceto pedidos com split.
- Assinaturas: MP sim (preapproval); Appmax parcial (secao Recorrencia nao lida); InfinitePay nao encontrado.
- Wallets: Appmax Apple Pay + Google Pay documentados; MP Apple Pay condicional (docs CO/MX), Google Pay nao encontrado; InfinitePay N/V em API.
- Lacunas para validar com acesso direto as paginas: Appmax webhooks reference, Appmax endpoint de estorno e recorrencia, rate limits numericos, "Payment as a Service", MP Pix Automatico/Google Pay no Brasil, elegibilidade InfinitePay v2 `transactions`.
