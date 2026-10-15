# PSPs: Pagar.me v5, PagBank, Stripe (BR), Adyen. Relatório de pesquisa (2026-10-15)

## Aviso de método (leia primeiro)
- WebFetch/curl indisponíveis. Só WebSearch, cujo retorno é resumo (não a página). Nenhuma página oficial foi lida integralmente; nenhuma data/versão de doc foi vista (datas só quando o resumo as citou).
- Legenda: CONFIRMADO / PARCIAL / CONDICIONAL / NÃO SUPORTADO / NÃO VERIFICADO. "(prévio)" = conhecimento de treino, NÃO reconfirmado nesta sessão; tratar como hipótese a validar.
- Documentação != habilitação comercial. Tudo que depende de contrato/elegibilidade está CONDICIONAL.
- Células sem evidência = NÃO VERIFICADO (muitas). Não preencher com suposição.

---
## 1. PAGAR.ME (Stone), API v5 (base https://api.pagar.me/core/v5, Basic auth; fonte secundária apievangelist)

| Item | Status | Nota / fonte |
|---|---|---|
| Checkout hospedado (links/checkout) | NÃO VERIFICADO | (prévio) existe "Checkout/Payment Link" na v5; não confirmado. |
| Checkout transparente (API orders/charges) | PARCIAL | Order-level create para Pix e cartão aparece em exemplo comunitário (glama.ai mcp-payments); não é doc oficial. |
| SDK components | NÃO VERIFICADO | |
| Cartão / Pix / boleto | PARCIAL | Cartão e Pix via orders (exemplo comunitário). Boleto NÃO VERIFICADO. |
| Pix Automático | NÃO VERIFICADO | Busca não retornou doc Pagar.me. |
| Apple Pay / Google Pay | NÃO VERIFICADO | |
| Assinaturas v5 (planos, subscriptions, invoices) | PARCIAL | Diretório de terceiros descreve Core v5 com subscriptions, plans, invoices, recipients, split, transfers, webhooks (https://providers.apievangelist.com/providers/pagarme/). Detalhes de ciclo/retry NÃO VERIFICADO. Quem controla recorrência: provável Pagar.me (agenda no PSP), NÃO VERIFICADO. |
| Tokenização p/ cobranças futuras (cartão salvo) | NÃO VERIFICADO | |
| Split 1:1 | CONDICIONAL | https://docs.pagar.me/reference/split-1: objeto split (amount, type flat/percentage, recipient_id `rp_...`, options). A página diz disponível apenas para clientes PSP. |
| Split múltiplos recebedores | CONDICIONAL | Idem; regras (docs v1 https://docs.pagar.me/v1/docs/split-rules, legado, usar só como indício): todos os recebedores declarados explicitamente inclusive o principal; amount OU percentage, nunca ambos; custo de gateway/antifraude fica com o principal; ao menos um recebedor assume chargeback (`liable`), taxas e "resto" dos recebíveis (referência atual); parcelas x recebedores geram recebíveis proporcionais. Campo `charge_processing_fee` citado só em artigo de suporte legado: NÃO VERIFICADO na v5. |
| Split em recorrência | PARCIAL/CONDICIONAL | Stone confirma a funcionalidade comercialmente (https://www.pagar.me/blog/split-de-pagamento-com-recorrencia/, blog, sem detalhes de API v5). Doc v4 "Split com assinatura" é legado. Regras v5 (cupom, taxa de adesão): NÃO VERIFICADO. |
| Reembolso parcial; cancel e capture; antecipação | NÃO VERIFICADO | |
| Webhooks autenticados | NÃO VERIFICADO | Nenhuma doc oficial encontrada (assinatura/Basic auth?). |
| Idempotência | NÃO VERIFICADO | |
| Sandbox | NÃO VERIFICADO | |
| Onboarding de recebedores (KYC) | PARCIAL | Existe API Recipients (https://docs.pagar.me/docs/recebedores-2, título só). Fluxo KYC/kyc_link, prazos, documentos: NÃO VERIFICADO. Não há OAuth/Connect tipo Stripe confirmado. |
| Rate limits; taxas públicas | NÃO VERIFICADO | |
| Elegibilidade ("produto PSP") | CONDICIONAL | Split só para clientes PSP (contrato com Stone/Pagar.me, análise comercial). Ativação do split em "Funcionalidades > Split" no dashboard citada por tutorial de terceiro (onprofit). Requisitos exatos: NÃO VERIFICADO. |
| Países/moedas | NÃO VERIFICADO | (prévio) BR/BRL. |
| Quem recebe o dinheiro | PARCIAL | Cada parte cai na conta do respectivo recebedor (Stone); recebedor principal (marketplace) arca gateway/antifraude. |

Adapter TS/Edge: MÉDIA. REST simples, mas split exige conta PSP, regras de liable/resto e recebíveis; webhooks e idempotência sem doc verificada. Risco: dependência de contrato PSP; docs com muitas versões (v1/v4/v5) misturadas. Encaixe PME BR: bom SE conseguir contrato PSP; senão split indisponível.

---
## 2. PAGBANK (developer.pagbank.com.br)

| Item | Status | Nota / fonte |
|---|---|---|
| Superfície de API | PARCIAL | Diretório de terceiros lista: Orders, Charges, Public Keys, Checkout, Recurring, Connect/OAuth, Account Registration, EDI, Webhooks, Pix API, Marketplace/Split (https://providers.apievangelist.com/providers/pagseguro/). Não oficial. |
| Checkout hospedado / links | NÃO VERIFICADO | Módulo "Checkout" listado por terceiro; detalhes não lidos. |
| Checkout transparente | PARCIAL | Blog oficial diz que checkout transparente combina com split (https://blog.pagbank.com.br/split-de-pagamento-pagbank). |
| SDK components; Apple/Google Pay; boleto; Pix Automático | NÃO VERIFICADO | |
| Cartão, Pix | PARCIAL | Módulos listados, doc não lida. |
| Recorrência | PARCIAL | Blog oficial (https://blog.pagbank.com.br/o-que-e-pagamento-recorrente): produto com planos, cupons de desconto, taxa de adesão, trial, e-mails. Quem controla: produto de assinatura do PagBank (PagBank agenda); NÃO VERIFICADO na API. |
| Split em recorrência e restrições (cupom, taxa de adesão) | NÃO VERIFICADO | Nenhuma doc encontrada confirmando ou negando. Blog não diz que combinam. Tratar como RISCO e perguntar ao PagBank/ler doc de Recurring+Split. (Asaas, outro PSP, bloqueia assinatura se split > líquido; é analogia, NÃO evidência PagBank.) |
| Split 1:1 / múltiplos | PARCIAL | Blog: regras definidas pelo marketplace na transação; dono do token é o recebedor primário, responsável por taxas e chargebacks; Split API divide cobrança entre vários recebedores com custódia opcional (terceiro). Modelo de Aplicações é exigido por Split e Connect (https://developer.pagbank.com.br/v1/docs/api-aplicacoes-dispositivos-suportados, página antiga >5 anos). |
| Onboarding de sellers (OAuth Connect) | PARCIAL | Connect/OAuth listado; fluxo não lido. |
| Webhooks autenticados | NÃO VERIFICADO | Mecanismo (x-authenticity-token ou outro) não confirmado. |
| Idempotência; rate limits; sandbox | NÃO VERIFICADO | Fórum relata sandbox funcionando com token e produção com erro de autorização, resposta não vista. Docs mostram v1.0 enquanto v4.1 citada como mais recente: confirmar versão. |
| Reembolso parcial, cancel/capture, antecipação, taxas, países | NÃO VERIFICADO | |
| Quem recebe | PARCIAL | Recebedor primário (token owner) e secundários conforme split. |

Adapter TS/Edge: MÉDIA-ALTA. Várias versões de doc, Modelo de Aplicações/OAuth, sandbox com comportamento divergente reportado, webhooks sem spec verificada. Risco: restrições de split+recorrência não documentadas nas fontes acessadas; produção exige aprovação de aplicação. Encaixe PME BR: alto (marca e base PagBank), integração mais incerta.

---
## 3. STRIPE (Brasil)

| Item | Status | Nota / fonte |
|---|---|---|
| Checkout hospedado, Elements/SDK, Payment Links | CONFIRMADO (prévio) | Produtos globais; disponibilidade por método no Brasil depende da conta. Não reconfirmado. |
| Cartão | PARCIAL | Suporte BR lista Visa e Mastercard; Elo, Amex, Hipercard aparecem como não suportados no resumo (tabela ilegível, confirmar) (https://support.stripe.com/questions/accepted-payment-methods-in-brazil). Parcelamento: NÃO VERIFICADO. |
| Pix (único) | CONDICIONAL | Contas BR aceitam Pix pontual com liquidação em BRL; habilitação exige boa situação e mínimo de 60 dias processando (https://docs.stripe.com/payments/pix; https://support.stripe.com/questions/how-to-enable-pix-as-a-payment-method-in-brazil). Estornos Pix até 90 dias. |
| Pix Automático | NÃO SUPORTADO/CONDICIONAL | Doc atual contraditória: diz suportar recorrência via Pix Automático mas também "não disponível no Brasil / invite only"; versão antiga e suporte BR: recorrência não suportada. Tratar como indisponível salvo convite. |
| Boleto | CONDICIONAL | Business location BR; contas Merchant e Platform/Connect; pode haver revisão pós-ativação (https://docs.stripe.com/payments/boleto). |
| Apple Pay / Google Pay | PARCIAL | Suporte BR lista wallets; detalhe por método NÃO VERIFICADO. |
| Billing (assinaturas) | PARCIAL | Billing global (prévio). Em BR, cartão recorrente ok (prévio); Pix/boleto recorrentes limitados (ver acima). Quem controla recorrência: Stripe Billing (agenda, retries, dunning). |
| Tokenização (SetupIntent/PaymentMethod) | CONFIRMADO (prévio) | |
| Connect: tipos de conta | PARCIAL | Standard/Express/Custom (prévio). Brasil na lista Express: não visto na lista parcial (https://docs.stripe.com/connect/accounts); Connect para contas BR NÃO VERIFICADO por completo. |
| Destination charge vs separate charges and transfers | PARCIAL | Pix doc: se conta conectada é merchant of record (direct / on_behalf_of) Pix depende do país da conectada e do pix_payments capability; se plataforma é MoR (destination / SCT sem on_behalf_of) depende do país da plataforma. SCT só se plataforma e conectada na mesma região (https://docs.stripe.com/payments/pix; https://docs.stripe.com/connect/separate-charges-and-transfers). Para plataforma US com conectada BR: só SCT sem on_behalf_of e top-ups (https://docs.stripe.com/connect/cross-border-payouts, página "US only"). |
| application_fee | CONFIRMADO (prévio) | Em direct e destination charges (https://docs.stripe.com/connect/application-fees). Em BR NÃO VERIFICADO. |
| Split múltiplos recebedores | PARCIAL | Via separate charges and transfers (vários transfers por charge) (prévio). |
| Reembolso parcial; cancel e capture | CONFIRMADO (prévio) | Cartão: auth e capture separados; Pix: refund até 90 dias. |
| Antecipação | NÃO VERIFICADO | Prazo de payout BR relatado ~30 dias corridos (terceiro, possivelmente desatualizado). |
| Webhooks assinados (Stripe-Signature HMAC, timestamp) | CONFIRMADO (prévio) | https://docs.stripe.com/webhooks; não reconfirmado hoje. |
| Idempotency-Key | CONFIRMADO (prévio) | https://docs.stripe.com/api/idempotent_requests; não reconfirmado hoje. |
| Sandbox / test mode | CONFIRMADO (prévio) | |
| OAuth/Connect onboarding | CONFIRMADO (prévio) | Account Links / OAuth (Standard); aplicabilidade a vendedores BR: CONDICIONAL. |
| Rate limits | CONFIRMADO (prévio) | ~100 req/s live; confirmar. |
| Taxas públicas BR | NÃO VERIFICADO | Terceiro cita 2,9% + 30 (centavos) com payout 30 dias; Pix via parceria EBANX (2025). Verificar stripe.com/br/pricing. |
| IOF | PARCIAL | 3,5% sobre pagamentos de compradores BR a empresa estrangeira (resumo da doc Pix). Relevante se plataforma não for BR. |
| Quem recebe | CONDICIONAL | Destination: conta conectada (país/moeda dela); direct: conectada; SCT: plataforma recebe e transfere. |

Adapter TS/Edge: BAIXA (API e SDK Deno/fetch maduros; webhooks com constructEventAsync, idempotência nativa). Complexidade real está em Connect+BR e métodos locais. Risco: habilitação de Pix (60 dias), Pix Automático indisponível, Elo não suportado, restrições cross-border, payout lento. Encaixe PME BR: bom para cartão/SaaS com cartão; fraco se negócio depende de Pix recorrente/Elo/split local.

---
## 4. ADYEN

| Item | Status | Nota / fonte |
|---|---|---|
| Plataformas | CONDICIONAL | Adyen for Platforms exige contato comercial: escopo, desenho, dashboard, build/test, conta live (https://docs.adyen.com/platforms/get-started, data resumo 2022). |
| Onboarding KYC | CONFIRMADO/CONDICIONAL | Hosted onboarding via convite ou link por API (https://docs.adyen.com/platforms/quickstart-guide/onboarding-and-kyc). Aplicação a sub-merchants BR pequenos: NÃO VERIFICADO. |
| Pix | CONDICIONAL | Requer entidade local no Brasil e pedir o método à Adyen (BigCommerce, terceiro); BR/BRL; redirect para página hospedada por padrão (Gr4vy, terceiro). |
| Pix Automático | CONDICIONAL | Piloto/ativação por MID BR pela Adyen (Gr4vy/Datalex, terceiros); participação no piloto do BCB abril 2025 (imprensa Adyen). Status 2026: NÃO VERIFICADO. |
| Cartão, SDK Drop-in/Components, hosted (Pay by Link), Apple/Google Pay | CONFIRMADO (prévio) | Produtos globais; BR por contrato. |
| Boleto | CONFIRMADO (prévio) | Método Adyen BR; habilitação por contrato. |
| Recorrência/tokenização | CONFIRMADO (prévio) | Tokens/stored payment methods; Adyen não agenda, merchant controla recorrência (CONDICIONAL). |
| Split | CONDICIONAL | Via Platforms (balance accounts / split config) (prévio); BR NÃO VERIFICADO. |
| Webhooks HMAC; idempotency key; sandbox (test account) | CONFIRMADO (prévio) | Não reconfirmado. |
| Volume mínimo/taxas públicas BR | NÃO VERIFICADO | Sem preços públicos; modelo interchange++ por contrato (prévio). |

Adapter TS/Edge: ALTA (modelo de contas/balance accounts, onboarding, sessões, contrato prévio). Quem controla recorrência: o merchant/plataforma (Adyen processa). Risco: acesso comercial, entidade BR, tempo de contratação. Encaixe PME BR pequena: baixo; mais realista para enterprise/orquestração.

---
## Pendências para validar com acesso direto à docs (prioridade)
1. Pagar.me: página "Regras do split" v5, assinaturas+split, KYC de recipient, webhook e idempotência, Pix Automático, condição "PSP".
2. PagBank: Recurring+Split (cupom/adesão), assinatura de webhook, Connect OAuth, versão atual da API.
3. Stripe: tabela atual de países Connect (BR conta plataforma/conectada), Pix em Billing, Elo/parcelamento, preços BR.
4. Adyen: Platforms disponível a sub-merchants BR, mínimos comerciais.
