# Auditoria somente-leitura do fluxo financeiro: PMD Core V1 (/home/user/pmd-core, main @4b91aec)

Metodo: analise estatica. `node_modules` NAO existe, entao NENHUM teste foi executado (vitest nao rodou). Toda afirmacao
"Coberto por teste existente" significa: o teste existe e, pelo titulo/corpo lido, afirma isso; nao foi visto passar.
Nenhum arquivo do repo foi alterado. Nenhuma chamada de rede.

Legenda: [V] Verificado no codigo | [T] Coberto por teste existente | [D] Documentado mas nao comprovado | [P] Proposta | [H] Hipotese.

Caminhos abreviados: MIG = supabase/migrations; DEF = supabase/definitions (snapshot dos corpos finais das funcoes; um teste
`tests/db/definitions.test.ts` os mantem iguais as migrations); SH = supabase/functions/_shared.
ATENCAO: as migrations reescrevem corpos por patch com guarda de md5; o corpo FINAL de cada funcao esta em DEF, nao na migration.

## 0. Veredito

O fluxo e um desenho de "porta unica de dinheiro": so o banco move centavos (`settle_provider_event`), so depois de uma
confirmacao feita DIRETAMENTE no provedor (nao pelo webhook). Ha um contrato de adaptador (`ProviderAdapter`/`PaymentAdapter`)
com `check` opcional, `cancel`/`refund` opcionais e `NOT_SUPPORTED`. Mas, na pratica, o produto hoje e MONO-PROVEDOR e
MONO-MODELO "link de redirecionamento": o contrato e a camada de Edge Functions ja aceitam varios provedores para
criar link / checar / reconciliar / reembolsar, mas a ENTRADA do webhook, o segredo do webhook, a funcao de borda do webhook, o
formato da tela do cliente (`{url}` e redirect) e varios nomes de campo do banco continuam amarrados a InfinitePay.
`refund`/`cancel` existem como contrato + porta de banco + testes com provedor simulado, mas NAO estao ligados a nenhuma Edge
Function, tela ou papel em producao, e a InfinitePay nao os oferece (NOT_SUPPORTED).

## 1. Onde pedidos sao criados  [V][T]

- `public.place_order(jsonb)`: DEF/pedidos/functions.sql L957-1139 (SECURITY DEFINER; grant a `anon` e `authenticated` L1140-1142).
  Insert em `orders` L~1092; itens em `order_items`; evento `placed` via `order_event`; token de acesso `issue_access('order', ...)`.
- Metodo de pagamento unico: `if method is distinct from 'card_online' then pmd_fail('PAYMENT_METHOD_INVALID')` (L~1078).
  Sem provedor pronto: `if not private.payment_provider_ready() then pmd_fail('PROVIDER_REQUIRED')` (L~989). Regra tambem em
  trigger/check `financeiro_order_check` ('rail') DEF/financeiro/functions.sql L76.
- Idempotencia de criacao: `idempotency_key`/`intent_id` (regex `^[A-Za-z0-9_-]{16,128}$`), `select ... where idempotency_key`,
  `on conflict (idempotency_key) ... do nothing` e re-chamada (L~960-975, L~1107-1110). Mesmo key com outro telefone =
  `IDEMPOTENCY_CONFLICT`. Testes: tests/db/order-idempotency.test.ts ("a repeat returns the first order and creates nothing",
  "a key reused by another customer is refused", "the key is unique in the table, and only where it is present").
- Ao nascer, `financeiro_order_changed` (INSERT) abre a linha `due` no ledger: DEF/financeiro/functions.sql L49-75, via o ponto
  `pedidos.order_changed`. Teste: tests/db/payments.test.ts "every order is born with its amount owed".
- Limites anti-abuso e human-check para pedido anonimo (hit_rate_limit, hit_client_limit, ORDERS_OPEN, HUMAN_CHECK_REQUIRED): L~992-1030.

## 2. Quem calcula o valor final  [V][T]

- Servidor (nao o cliente): `place_order` chama `quote_cart(p)` (L~1084; corpo DEF/pedidos/functions.sql L1145+). `quote_cart` le preco
  do banco (`variant_price(v.id)`, `price_delta_cents` das opcoes), soma subtotal, taxa de entrega pela zona do CEP, desconto de
  cupom via ponto de politica `pedidos.order_discount`/`order_reward`; `'total_cents', subtotal - discount + fee`.
- `place_order` grava `total_cents = q.total_cents`. O cliente pode mandar `expected_total_cents`; divergencia => `PRICE_CHANGED` (L~1087-1090).
- Invariante no schema: `orders_total_adds_up CHECK (total = subtotal - coupon_discount - manual_discount - pix_discount + delivery_fee)`
  DEF/pedidos/tables.sql L195.
- Valor cobrado no link = `outstanding = payment_ledger.due_cents - received_cents` (nao `orders.total_cents` direto):
  `checkout_link`, MIG 20261011005100 L296-299 (corpo final em DEF/financeiro/functions.sql L327+).
- Quando o total muda depois, `financeiro_order_changed` (UPDATE) insere nova linha `due` (L~62-72): o ledger e append-only.
- Taxa de cartao: o manual diz que "nao existe chave de taxa do cartao" (docs/manual-pagamentos.md §1), mas
  `card_fee_mode`/`card_surcharge_percent` continuam em settings (src/pmd/modules/financeiro.ts L~52 `settings`; DEF/casca/functions.sql L261-262
  ainda os expoe, ocultando o percentual quando ha provedor pronto). Nao ha uso no calculo de `quote_cart` (grep sem acerto em quote_cart). [V para ausencia no calculo; H de que sao legado morto]
- Testes: tests/db/financeiro-states.test.ts "160 generated sales: no disagreement" + "a planted defect ... one cent off turns the generator red";
  tests/unit/money-typing.test.ts, money-format.test.ts (nomes; conteudo nao lido).

## 3. Quem decide que um pedido esta pago  [V][T]

- Unica via de escrita de pagamento `paid` de entrada: `public.settle_provider_event(jsonb)` (service_role). Corpo final DEF/financeiro/functions.sql L813-1046
  (MIG 20261011005100 L483+). Unicos 2 `insert into payments` no schema final: `financeiro_order_changed` (linhas `due`) e `settle_provider_event`
  (L~1014) [V por grep em DEF].
- Gatilho `payments_one_rail` (DEF/financeiro/functions.sql L297-309; tables.sql L245): `direction='in' and status in ('paid','to_check','proof_sent','refused') and provider is null` => `PROVIDER_ONLY`.
  Ou seja, nenhum papel humano consegue gravar pagamento recebido sem provedor.
- `record_payment`, `set_payment_status`, `refund_payment`, `confirm_courier_payment` foram removidos (MIG 20261005000200_one_rail.sql; 20260921004200_payment_final.sql;
  API.md L180, L428). Testes: tests/db/payment-final.test.ts criterion 1-3; tests/db/one-payment-rail.test.ts PP1.2 "leaves no door that writes a payment".
- `orders.payment_status`/`paid_at` e CACHE do ledger: trigger `payments_refresh_cache` (AFTER INSERT on payments) chama `private.order_payment_set`; guarda
  `payments_guard_cache` rejeita escrita divergente (`PAYMENT_CACHE_MISMATCH`, financeiro_order_check 'cache' L~85-98).
  Status do ledger: `payment_ledger()` DEF/financeiro/functions.sql L490: 'paid' se `any_paid and received >= due`.
- Regras de aceitacao: `settle_provider_event` so liquida o valor DEVIDO (`amount = min(amount_cents do provedor, outstanding)`), nunca `paid_amount`;
  pagamento menor que o devido => `PART_PAYMENT_REFUSED` (nada lancado, `refund_due_cents` += valor, nota para a loja); maior => lanca o devido e `refund_due` += excesso.
  Pedido cancelado/rejeitado/expirado ou ja pago => nao lanca, `refund_due` += valor, nota. Testes: tests/db/provider-events.test.ts P3-4
  ("one real against a R$ 150,00 order settles nothing"), "never settles more than the order still owes"; tests/db/block7c-refund-due.test.ts.
- Idempotencia de liquidacao: lock `for update` no evento E no pedido; `private.receipt('settle_provider_event', p)`; indice unico parcial
  `payments_provider_tx_once ON payments (provider, provider_tx_key(provider_ref)) WHERE status='paid' AND provider IS NOT NULL AND provider_ref IS NOT NULL` (MIG 005100 L179-180;
  DEF/financeiro/tables.sql ~L233). Teste: tests/db/provider-tx-unique.test.ts.

## 4. Como tentativas de pagamento sao registradas  [V][T]

Nao existe tabela de "tentativa" separada. Os registros sao:
- `private.checkout_links` (1 linha por pedido: `url`, `amount_cents`, `invoice_slug`, `provider`; PK `order_id`) — o link ATUAL.
- `private.checkout_link_mints` (PK `order_id, invoice_slug`: todo link ja emitido, com `provider`, `amount_cents`, `minted_at`) — historico de links; um pagamento so e aceito se o slug for um destes
  (`settle_provider_event`, regra PROVIDER_MISMATCH). MIG 20261011005000_link_antigo.sql L35; DEF/financeiro/tables.sql L5.
- `private.payment_events` (eventos brutos do provedor, unico por `(provider, external_id)`, com `attempts`, `next_try_at`, `processed_at`, `failed_at`, `error`): MIG 20261011004300 L47.
- `private.link_payments` (qual evento teve efeito por link; `from_check` distingue conciliacao de webhook): MIG 005000 L187.
- `private.provider_checks` (quantas vezes a conciliacao perguntou ao provedor por um pedido: `asks`, `next_at`): MIG 20261011001000 L94.
- `public.payments` (ledger append-only; ver §11).
- Limite: o `order_events` guarda `payment` (de/para, metodo, valor, provider, payment_id) quando liquida (`order_event(o.id,'payment',...)`, settle ~L1021).
- Lacuna [V]: uma tentativa de criar link que falha/da timeout NAO deixa registro algum (so o erro 502 PROVIDER_UNAVAILABLE ao cliente).

## 5. Como pagamentos de provedores diferentes sao identificados  [V]

- Coluna `provider` (texto, regex `^[a-z0-9_-]{2,30}$`) em `payments`, `payment_events`, `checkout_links`, `checkout_link_mints`, `link_payments`, `provider_refunds`.
- Registro de provedores: `private.payment_providers(provider PK, label, account, base_url, enabled, priority)`, RLS ligado, `revoke all` de todos os papeis (incl. service_role): MIG 005100 L82-93.
  Sem chave/segredo na tabela (comentario L92-99). Escrita so pelo SQL do instalador: `private.payment_provider_set(...)` (L102). 
- Selecao do provedor de um link NOVO: `private.payment_provider()` sem nome = habilitado, com conta, menor `priority` (L115-124). Tudo depois do link segue o provedor que o emitiu (guardado em `checkout_links.provider`).
- Chave de transacao canonica: `public.provider_tx_key(t)` (remove zeros a esquerda se numerico; trim+lower caso contrario): DEF/financeiro/functions.sql L693.
- Palavras do evento: `private.payment_fact(p, fact)` le palavras canonicas (`order_ref`, `provider_ref`, `link_ref`) OU as da InfinitePay (`order_nsu`, `transaction_nsu`, `invoice_slug`/`slug`) — MIG 005100 L147-154.
  A resposta do provedor passa por `private.payment_check_canonical` (L160-166): ja canonica (`answered` presente) passa; senao le `success/paid/amount/capture_method/order_nsu/transaction_nsu` da InfinitePay.
- Limite: `private.payment_event_record` aceita qualquer provedor REGISTRADO (L184-196), mas o unico caminho de entrada de webhook de pagamento e `record_infinitepay_event` (§6).

## 6. Como webhooks sao processados (autenticacao, assinatura, idempotencia)  [V][T]

- Edge Function `supabase/functions/infinitepay-webhook/index.ts` (verify_jwt=false, supabase/config.toml L31): chama `paymentAdapters().infinitepay.inbound.handle(req, deps)` — o nome do provedor esta CHUMBADO na funcao.
- `handleWebhook` (SH/infinitepay.ts L135-155): so POST (405); extrai o ultimo segmento da URL; se nao casa `^[0-9a-f]{64}$` => 404 sem consultar o banco; parse JSON (400 se ilegivel);
  `rpc('record_infinitepay_event', {secret, payload})`; sucesso ou duplicata => 200; `WEBHOOK_UNKNOWN` => 404; qualquer outra falha => 400 (para o provedor re-enviar).
- NAO HA ASSINATURA: a InfinitePay nao assina nada (SH/infinitepay.ts L18-20, intent/pmd-integrations/infinitepay.md §3.2). A unica "autenticacao" e o segredo no caminho (64 hex).
  `checkedBy: 'door'` (L219): o banco compara `digest(secret) <> digest(infinitepay_webhook_secret())` e falha `WEBHOOK_UNKNOWN` (DEF/financeiro/functions.sql L717-740).
- Segredo: `infinitepay_webhook_secret() = hex(hmac('infinitepay-webhook', private.link_secret(), sha256))` (DEF/financeiro/functions.sql L419); `link_secret()` le o Vault `pmd_link_secret`, com FALLBACK para `private.secrets.link_secret` se nao houver Vault (DEF/autoridade/functions.sql L91-106).
  Para outros provedores: `private.payment_webhook_secret(provider) = hmac(provider||'-webhook', link_secret)` (MIG 005100 L134) — e injetado em `checkout_link` mint (so para servidor; a versao `authenticated` remove `webhook_secret` e `provider`: L333).
- Idempotencia: `external_id = provider_tx_key(transaction_nsu)`; `transaction_nsu` ausente => `EVENT_INVALID` (nao inventa chave); `record_provider_event` -> `private.payment_event_record` com `on conflict (provider, external_id) do nothing` => `{duplicate:true}`; mais `private.receipt('record_infinitepay_event', p)`.
  Evento de pedido ja apagado (LGPD, telefone '0000000000') e gravado so com fatos permitidos (`provider_payload_facts`).
- O webhook e "campainha": nada que ele diga move dinheiro (SH/infinitepay.ts L5-9; settle exige confirmacao do provedor, §7).
- Testes: tests/db/provider-events.test.ts ("writes the event down once, keyed on the transaction", "a second ring ... writes nothing new", "refuses an unknown path by name",
  "refuses a body with no transaction", "is the Edge Function door and nobody else"); tests/unit/infinitepay.test.ts ("the doorbell (P3-1)": 200/200-dup/400/404/400/405);
  tests/integrations/contract.test.ts (FIXTURES infinitepay: `verify` recusa entrega sem prova, entrega com prova errada nao grava nada; planted `verify` que acredita em tudo falha).
- [H] O segredo viaja dentro do `webhook_url` do payload do link; o proprio codigo admite que NAO foi provado se o link (`lenc=`) expoe esse caminho (MIG 20260923000100 comentario "What stays unproved"). Segredo e global (nao por pedido).
- Limite de ciclo de vida: nao ha rotacao/versionamento do segredo de webhook; trocar `pmd_link_secret` invalida os webhooks dos links ja emitidos [H, derivado do desenho; a conciliacao cobre].

## 7. Como a confirmacao e verificada direto no provedor  [V][T]

- Job de minuto `settleProviderPayments` (SH/payments.ts L158-189). Para cada adaptador com `check`: (a) `reconcile` (L191), (b) `rpc('unprocessed_provider_events', {provider, limit:50})`,
  (c) para cada evento `ask.event(payload, cfg, io)` e `rpc('settle_provider_event', {id, check})` (L~176-181). O codigo da borda NAO le a resposta; entrega inteira ao banco ("looking perfect is free for whoever forged it", L141-143).
- InfinitePay: `paymentCheck` (SH/infinitepay.ts L159-174) POST `${cfg.base_url}/payment_check` com `{handle, order_nsu, transaction_nsu, slug}`, timeout `io.timeoutMs ?? 10000`; `!res.ok` => throw (evento nao carimbado).
- O banco amarra a resposta: `PROVIDER_MISMATCH` se `order_ref`/`provider_ref` da resposta diferem do evento; slug do evento deve ser de um link emitido para AQUELE pedido; transacao ja usada => `TRANSACTION_ALREADY_SETTLED`. Valor = `amount` do provedor (nao `paid_amount`).
- Agendamento: pg_cron `pmd-settle-provider-payments` `* * * * *` -> `private.cron_post('settle-provider-payments')` (supabase/setup/after-migrations.sql L253; manifesto src/pmd/modules/financeiro.ts L48-51). `cron_post` so dispara se `cron_pending` (provedor pronto E (evento devido OU pedido a conciliar)); Authorization = Vault `pmd_dispatch_secret`; a funcao compara com `DISPATCH_SECRET` por `sameSecret` (tempo constante).
- Testes: tests/db/provider-events.test.ts P3-3 "a forged webhook moves nothing, because payment_check denies it", P3-3b, "never settles an order whose number was not the one the vendor was asked about";
  tests/unit/infinitepay.test.ts "asks the vendor about each unprocessed event and hands the answer to the database", "hands a denial through unchanged".

## 8. Resposta perdida / timeout: "desconhecido" nunca e tratado como recusa?  [V][T] (com ressalvas)

Ao CONFIRMAR (settle):
- Timeout/erro de rede/HTTP nao-ok/JSON invalido em `payment_check` => excecao => `failed++`, evento fica sem `processed_at` e volta por lease 1, 5, 15, 30, 60 min (`unprocessed_provider_events`, MIG 005100 ~L430; backoff `array[1,5,15,30,60]`).
- Resposta com `success != true` => `answered=false` => `{settled:false, retry:true}` e grava erro "payment_check did not answer success", SEM carimbar (settle ~(a)). Distincao explicita "not a denial: try again" vs `paid != true` com `success=true` = negacao FINAL (b).
- Apos 6 reivindicacoes sem resposta final: carimbado `processed_at/failed_at` com `error='PROVIDER_UNCONFIRMED ...'` — terminal, mas rotulado como NAO CONFIRMADO, nao como "nao pago"; o pedido nao e liquidado.
- `expire_orders` nao expira pedido com evento em voo (`payment_in_flight`), DEF/pedidos expire_orders; MAS depois que o evento e carimbado terminalmente (negado/UNCONFIRMED) ele expira.
- Testes: tests/db/provider-events.test.ts P3-3b ("an answer that is not a success is not a denial either: it is tried again"); tests/db/provider-queue.test.ts ("failed after six claims", "a claimed event is not handed out again inside its lease");
  tests/unit/infinitepay.test.ts ("leaves an event unstamped when the vendor could not be reached", "settleProviderPayments with one hanging payment_check counts one failure and still processes the next event", "a vendor that never answers makes handleCheckoutLink throw PROVIDER_UNAVAILABLE after its deadline").
- Reembolso: resposta perdida => claim fica `claimed`; repetir usa a MESMA chave de idempotencia `provider:refund:tx` e o provedor responde o primeiro reembolso (tests/integrations/contract.test.ts "an answer lost after the provider acted is asked again with the same key, and money moves once").

Ao CRIAR link (lacuna):
- `createLink` (SH/infinitepay.ts L99-120): fetch com `AbortSignal.timeout`; qualquer falha => `null` => `PROVIDER_UNAVAILABLE` (502). NAO ha chave de idempotencia na chamada `/links` (a API da InfinitePay nao tem). Se o provedor criou o link mas a resposta se perdeu, o link existe sem registro local (orfao).
  Mitigacao parcial [V]: o pagamento de um link orfao so e recusado quando o pedido ja tem outro slug gravado (PROVIDER_MISMATCH + nota para a loja, sem `refund_due`); se o pedido nao tem slug, a checagem e pulada e o pagamento (valor/pedido corretos, confirmado no provedor) e aceito. Teste mais proximo: tests/db/old-card-link-payment.test.ts "a slug never minted for this order is still refused". [H: nenhum teste cobre exatamente "primeira emissao perdida".]

Ao RECONCILIAR: `reconcileOrder` com `!res.ok` ou excecao => `null`/ignora; o banco devolve o pedido mais tarde (backoff 5/25/90 min).
Ressalva [H]: `paid=false` com `success=true` e FINAL; se o provedor responder "nao pago" por estado transitorio (Pix ainda em processamento) o evento daquele `transaction_nsu` fica negado; so a conciliacao (`check:<n>:<slug>`) pode reencontra-lo, e ela e limitada (ver §10).

## 9. Pagamento duplicado e reembolso duplicado

Pagamento duplicado [V][T]:
1. Um link por pedido/valor: `checkout_link` devolve o link guardado se `amount_cents = outstanding` (MIG 005100 L318-320). Teste: tests/db/checkout-link.test.ts "a second request returns the stored link"; tests/unit/infinitepay.test.ts P2-3.
2. `ALREADY_PAID`, `AMOUNT_INVALID` (nada devido), `PAYMENT_UNDER_REVIEW` (pagamento curto) no `checkout_link`; guarda de valor em `save_checkout_link` (AMOUNT_INVALID se o pedido mudou entre pedir e salvar).
3. Uma transacao paga um pedido uma vez: indice unico `payments_provider_tx_once` + checagem previa + captura de `unique_violation` (ACT-021). Teste: tests/db/provider-tx-unique.test.ts.
4. Link antigo (total mudou): todos os slugs emitidos continuam aceitos (`checkout_link_mints`); webhook + conciliacao do MESMO link contam uma vez via `link_payments`; duas transacoes distintas no mesmo link = dois pagamentos, cada um avisado. Testes: tests/db/old-card-link-payment.test.ts, provider-followups.test.ts.
5. Segundo pagamento num pedido ja pago => nao lanca; `refund_due_cents += valor`; nota ao time (settle "(d) outstanding <= 0"). tests/db/block7c-refund-due.test.ts.
6. Limitacao assumida em texto: a InfinitePay nao cancela link (SH/infinitepay.ts L232-233); por isso o link antigo continua pagavel (nota gerada em `save_checkout_link`).

Reembolso duplicado [V][T] (so no plano contrato/banco):
- `private.provider_refunds` PK `(provider, tx_key)`, `amount_cents>0`, `status in (claimed,done)`, `done_has_ref`; `public.provider_refund` (service_role) faz claim ANTES de perguntar ao provedor, recusa valor > pago (`AMOUNT_INVALID`), outro valor para a mesma tx (`AMOUNT_INVALID {claimed_cents}`), transacao sem pagamento `paid` no mesmo provedor (`NOT_FOUND`) — MIG 20261011005500 L25-91.
- `refundAtProvider` (SH/payments.ts L243-254): claim -> se `done` responde sem perguntar -> senao `adapter.refund({key: claim.key})` e so o "ok" do provedor fecha o claim (`answer`).
- Testes (provedor SIMULADO, PGlite): tests/integrations/contract.test.ts L228-296 ("money is returned once", "an answer lost...", "two at once move money once", "the database refuses a second refund..."), mais planted adapters sem chave/chave aleatoria reprovados em checkAdapter.
- Lacunas [V]: (i) nenhuma Edge Function, tela ou papel chama `refundAtProvider`/`cancelAtProvider` (grep: so SH/payments.ts e testes); (ii) `refund_due_cents` so cresce (`order_refund_due_add`, DEF/pedidos L310-318; nenhuma funcao decrementa), entao um reembolso `done` NAO baixa o saldo a devolver; (iii) um reembolso no provedor NAO gera linha `refunded` no ledger (comentario payments.ts L~236-241: "o que o livro-caixa registra e de refund_payment, por um colega (D149)" — mas `refund_payment` foi removido); (iv) o poder `refund` consta em `src/pmd/modules/financeiro.ts` L46 mas nenhum `require_perm('refund')` existe nas definicoes.

## 10. Conciliacao  [V][T]

- Automatica, por minuto, no mesmo job (`reconcile`, SH/payments.ts L191-203): `orders_to_reconcile` (DEF/financeiro/functions.sql L453; MIG 005100 L336) devolve ate 20 pedidos (por provedor) cujo link do provedor existe, nao pago, `hold_expires_at` vencido e < 1 dia atras, nao em voo, ate 4 perguntas por pedido (`provider_checks.asks`, backoff 5, 25, 90 min), considerando ate 4 slugs por pedido (atual + 3 do historico). Resposta "paga" e gravada via `record_provider_event` (mesmo caminho do webhook) e liquidada na mesma rodada, perguntando de novo ao provedor.
  Chave do evento de conciliacao: `transaction_nsu` do provedor, ou `check:<order>:<slug>` quando nao ha.
- Testes: tests/db/provider-reconcile.test.ts ("finds a payment whose webhook never came, records and settles it once, and a second run records nothing new", "a late webhook ... settles nothing twice", "stops asking after four times", "asks nothing about an order whose hold has not run out, or that has no link", "only the service role may ask"); tests/db/expire-vs-reconcile.test.ts (ACT-015: "today: the order expires first, and the payment the provider confirms becomes money owed back").
- Limites [V]: janela de apenas 1 dia apos o hold; 4 tentativas; so pedidos COM slug; sem relatorio periodico de divergencia provedor x ledger alem disso.
- Conciliacao interna cache x ledger: `public.reconcile_payments()` (DEF/financeiro L704) e as verificacoes `supabase/verify/checks.sql` (tests/db/checks-reconcile.test.ts "an order whose payment status drifted ... turns the payments row red"). Rodam sob demanda (verify), nao ha cron para elas [V: cron list em after-migrations.sql so tem 8 jobs, nenhum de conciliacao interna].
- Inconsistencia pequena [V]: o comentario de `settleProviderPayments` diz que "um provedor desligado ainda liquida os pagamentos de seus links", mas `cron_pending('settle-provider-payments')` exige `payment_provider_ready()` (algum provedor ligado e com conta); com TODOS desligados o cron nao dispara. [H de impacto: so no cenario "todos desligados".]

## 11. Historico financeiro / trilha de auditoria  [V][T]

- `public.payments` e um LIVRO-CAIXA append-only: trigger `payments_immutable BEFORE DELETE OR UPDATE ... forbid_change()` (DEF/auditoria/tables.sql L160) — excecao so em apagamento LGPD (`pmd.erasure`, `financeiro_on_erase`). Constraints: `payments_out_is_refund`, `payments_paid_has_collector`, `payments_undo_names_entry` (estorno por linha `cancelled` com `voids`), `payments_voids_key UNIQUE`. Teste: tests/db/payments.test.ts "the ledger never changes an entry".
- Reembolsos antigos (`refunded`, `direction='out'`) permanecem lidos; regra `payments_refund_covered` => `REFUND_EXCEEDS_RECEIVED` (tests/db/payment-final.test.ts criterion 4).
- `order_events` (timeline do pedido) recebe 'payment'; `private.order_note_add` grava notas internas automaticas (excesso, parcial, pedido morto, link antigo).
- `public.audit_log` (imutavel) audita configuracoes (`store_settings_audit`, modulos etc.); NAO audita `payments`, `payment_events`, `provider_refunds` nem `checkout_links` (grep `audit_row` em DEF/*/tables.sql) [V]. A troca da InfiniteTag e registrada em audit_log (INSTALL.md L1039).
- `payment_events` e atualizado no lugar (`processed_at`, `error`, `attempts`): o motivo de cada decisao fica em `error` (strings `TRANSACTION_ALREADY_SETTLED...`, `PARTIAL...`). Nao ha tabela separada de decisoes por tentativa; `provider_refunds` muda `claimed -> done` no lugar.
- Relatorios: `public.report_payments` (poder `payment`), tests/db/finance-page.test.ts, explain-finance.test.ts, money-on-screen.test.ts (nomes; conteudo nao lido).

## 12. Onde ficam config/credenciais do provedor e como segredos sao protegidos  [V]

- Conta da loja InfinitePay ("InfiniteTag" = identificador, nao credencial): `store_settings.infinitepay_handle` (regex `^[A-Za-z0-9][A-Za-z0-9._-]{1,63}$`, DEF/configuracao/tables.sql L110) e `infinitepay_base_url` (default `https://api.checkout.infinitepay.io`, L81). Lacrada: so o roteiro de instalacao altera (`RECEIVER_SEALED`; tests/db/one-payment-rail.test.ts PP1.3). Evita desvio por sessao roubada.
- Outros provedores: `private.payment_providers.account/base_url`, escritos so por `private.payment_provider_set` (SQL do instalador).
- Chaves de API de provedor: NAO ha em tabela; "Edge Function secrets lidos por NOME" (campo `secrets` do adaptador) ou Vault. InfinitePay nao tem chave (`secrets: ['pmd_link_secret']`, SH/infinitepay.ts L210 — e o nome do segredo do Vault que o BANCO le).
- Vault: `pmd_link_secret`, `pmd_project_url`, `pmd_dispatch_secret`; Edge: `DISPATCH_SECRET` (>=32 chars), `SUPABASE_SERVICE_ROLE_KEY`. Fallback `private.secrets` quando nao ha Vault (DEF/autoridade L91-106) [V; risco menor em PGlite/dev].
- Protecao: tabelas `private.*` com RLS ligado e `revoke all` de public/anon/authenticated/service_role (acesso so via funcoes SECURITY DEFINER); `webhook_secret` removido da resposta de `checkout_link` para `authenticated` (L333); testes de que o segredo nao vaza em resposta nem em log: tests/unit/checkout-link-colleague.test.ts P12b-3; tests/db/payments.test.ts ("never the webhook secret"); tests/unit/baseline-secrets.test.ts (nome apenas).
- Varredura de hosts/campos de provedor fora do adaptador: scripts/provider_scan.py + tests/integrations/provider-scan.test.ts.
- Adaptador declara `hosts`: InfinitePay = hostname de `mint.base_url` (configuracao, nunca constante), SH/infinitepay.ts L211.

## 13. Permissoes das acoes financeiras (RLS, papeis)  [V][T]

- `public.payments`: RLS ligado, `revoke all` de todos os papeis, policy unica `staff_read` (SELECT para `authenticated` com `is_staff()`) — DEF/financeiro/tables.sql L257. Nenhuma policy de INSERT/UPDATE/DELETE.
- Todas as portas financeiras sao `SECURITY DEFINER` com `grant execute` explicito: `settle_provider_event`, `record_infinitepay_event`, `unprocessed_provider_events`, `orders_to_reconcile`, `save_checkout_link`, `provider_refund`, `payment_provider_config` => SO `service_role`. `checkout_link` => `authenticated` + `service_role`; para `authenticated` exige `require_perm('orders')`, nao aceita `token`, e antes da aceitacao falha `STEP_SKIPPED`; papel desconhecido e recusado antes de qualquer leitura (L263-265). `place_order`/`quote_cart` => anon+authenticated.
- Poderes (powers) declarados: `payment`, `refund` (financeiro.ts L46). `payment` e usado em `report_payments` (DEF/relatorios L228) e na UI; `refund` nao tem `require_perm` em nenhuma funcao [V por grep].
- Edge Functions publicas (verify_jwt=false): `checkout-link` (cliente por token do pedido; colega por JWT, ver `handleColleagueCheckoutLink`: primeiro pergunta ao banco com o JWT do colega, so entao ao servidor), `infinitepay-webhook` (segredo no caminho), `settle-provider-payments` (bearer DISPATCH_SECRET).
- Testes: tests/db/payments.test.ts (anon/outsider/colega, "fails closed"); tests/db/checkout-link.test.ts "is the Edge Function door and nobody else"; tests/db/financeiro-states.test.ts "no door of finance is open to an anonymous caller"; tests/db/aal2-doors.test.ts, roles.test.ts, tests/scenarios/permissions.test.ts (nomes; conteudo nao lido a fundo); tests/doors/inventory.ts (inventario de portas); tests/integrations/contract.test.ts L293-295 (`provider_refund` recusa anon e OWNER).
- [H] `checkout_link` do cliente depende so do token do pedido (capacidade); o rate-limit especifico dessa funcao nao foi encontrado (o `edge-gate` cobre cep-area, cep-lookup e human-check apenas).

## 14. Invariantes protegidos por testes (arquivos)  [T — existem; NAO executados]

| Arquivo | O que prova (pelos titulos/corpo lido) |
|---|---|
| tests/integrations/contract.test.ts | Todo adaptador (InfinitePay, WhatsApp, Resend, simulado) cumpre o contrato; `verify` ruim e detectado; `check`/`cancel`/`refund` no provedor simulado via fluxo real em PGlite; reembolso uma vez, resposta perdida, concorrencia, recusas do banco; `NOT_SUPPORTED` sem chamar ninguem e sem claim; provedor sem `check` nunca liquida |
| tests/integrations/check-adapter.ts, simulated.ts | verificador de promessas do contrato e o provedor simulado (oraculo) |
| tests/integrations/provider-scan.test.ts | nenhum host/cabecalho/campo de provedor fora do adaptador; so payments.ts importa adaptadores |
| tests/db/provider-events.test.ts | campainha idempotente, segredo errado, sem transacao; forjado nada move (P3-3); 1 real vs R$150 (P3-4); nunca mais que o devido |
| tests/db/provider-tx-unique.test.ts | 1 transacao paga 1 pedido (ACT-021) + migration 005100 idempotente (rodar 2x) |
| tests/db/provider-reconcile.test.ts, expire-vs-reconcile.test.ts, provider-queue.test.ts | conciliacao; lease/backoff; 6 reivindicacoes; pedido expira antes (ACT-015) |
| tests/db/old-card-link-payment.test.ts, provider-followups.test.ts, block7c-refund-due.test.ts | links antigos, webhook+conciliacao contam uma vez, saldo a devolver, apagamento LGPD de payload |
| tests/db/payment-final.test.ts, one-payment-rail.test.ts, one-payment.test.ts, payments.test.ts | pagamento confirmado e final; sem porta humana de pagar/reembolsar; ledger imutavel; cache = ledger; trilho unico; InfiniteTag lacrada |
| tests/db/checkout-link.test.ts, tests/unit/checkout-link-colleague.test.ts, checkout-link-refusals.test.ts | um link por pedido/valor; recusas; segredo nunca no navegador/log; host por configuracao |
| tests/db/order-idempotency.test.ts | idempotencia da criacao do pedido |
| tests/db/financeiro-states.test.ts | 160 vendas geradas: quote = pedido = linha de pagamento; modulo fixo; erase; sem porta anonima |
| tests/db/checks-reconcile.test.ts | cache x ledger |
| tests/unit/infinitepay.test.ts | payload do provedor (1 linha, centavos inteiros, sem token), campainha 200/400/404/405, timeouts de 10 s, job de minuto |
| tests/unit/cron-jobs.test.ts | cron do manifesto = cron gerado em setup/after-migrations.sql |
| tests/unit/manual-pagamentos.test.ts | rotulos do manual existem nas telas |
| tests/db/definitions.test.ts, tests/db/contracts/contracts.json, tests/doors/inventory.ts | definicoes = migrations; contratos de portas; inventario de portas |

## 15. Formas exatas dos contratos  [V]

SH/integration.ts (linhas):
- L21 `Env = (name) => string`. L25-32 `InboundDeps {env, rpc, fetch, upload, remove, defer}`. L34-45 `Inbound {records, checkedBy:'adapter'|'door', verify(req, raw, env), handle(req, deps)}`.
- L49 `Answer = {ok:true; id; ref?; simulated?} | {ok:false; code}`. L51 `OutboundIo {fetch, env, timeoutMs?}`.
- L55-57 `NOT_SUPPORTED = 'NOT_SUPPORTED'`, `type Unsupported = {ok:false; code:'NOT_SUPPORTED'}`, `unsupported()`.
- L63 `OperationInput {ref; key; amount_cents?; cfg?: PaymentConfig}`. L69-73 `Operations<C> {check?: C; cancel?(input, io): Promise<Answer>; refund?(input, io): Promise<Answer>}`.
- L75-87 `ProviderAdapter<I, C> extends Operations<C> {provider; kind:'payment'|'messaging'|'email'; secrets: readonly string[]; hosts: readonly string[] | ((input:I)=>readonly string[]); timeoutMs; retry:'queue'|'job'|'provider'|'caller'; keeps:{table,retention}|null; inbound: Inbound|null; outbound:{send(input, io): Promise<Answer>}}`.
- L92-102 `PaymentMint {order_id; order_number; amount_cents; provider?; handle; domain|null; base_url; webhook_secret}`. L106 `PaymentConfig {handle; base_url}`.
- L110-119 `PaymentCheck {event(payload, cfg, io): Promise<unknown>; order(order, cfg, io): Promise<{external_id; payload}|null>}`.
- L125-127 `PaymentAdapter extends ProviderAdapter<{mint: PaymentMint; functionsUrl: string}, PaymentCheck> {kind:'payment'}`.

SH/payments.ts: L18 `paymentAdapters = (): Record<string, PaymentAdapter> => ({ infinitepay: INFINITEPAY })` (UMA entrada; funcao e nao constante por ciclo de import). L21 `DEFAULT_PROVIDER='infinitepay'`.
Operacoes expostas: `handleCheckoutLink(token, deps)` L88 e `handleColleagueCheckoutLink(orderId, authorization, deps)` L109 (-> `linkFor` L123: rpc `checkout_link` -> `adapter.outbound.send` -> rpc `save_checkout_link`); `settleProviderPayments(deps)` L158; `reconcile` L191 (interna); `cancelAtProvider(deps,{provider,ref})` L224; `refundAtProvider(deps,{provider,transaction,amount_cents})` L243.
Mecanismo NOT_SUPPORTED: `if (!adapter.cancel) return unsupported()` (L~229) e `if (!adapter.refund) return unsupported()` (L~246), antes de qualquer rpc/claim/fetch. Provedor desconhecido => `{ok:false, code:'PROVIDER_UNAVAILABLE'}`. `check` ausente => provedor e pulado em `settleProviderPayments` (`if (!ask) continue`, L~163).
Operacoes existentes por provedor: criar link (`outbound.send`), `check.event`, `check.order`, `cancel?`, `refund?`; NAO existem: criar cobranca Pix/QR retornando dados (so `{ok,id,ref}` onde `id` e URL https), capturar, obter status por consulta avulsa, assinatura, split.
InfinitePay declara apenas `outbound.send` + `check:{event, order}` (SH/infinitepay.ts L226-234); sem `cancel`/`refund`.

Amarrado a URL/forma externa [V]:
- `POST ${base_url}/links` (SH/infinitepay.ts L100), `POST ${base_url}/payment_check` (L160, L181). `base_url` vem de `store_settings.infinitepay_base_url` (configuracao), mas os CAMINHOS e os campos (`handle`, `order_nsu`, `items[{description,price,quantity}]`, `redirect_url`, `webhook_url`, `transaction_nsu`, `slug`, `success`, `paid`, `capture_method`) sao do adaptador.
- `linkOf()` exige `url` https: o resultado de `outbound.send` e SEMPRE uma URL (`Answer.id`), gravada em `private.checkout_links.url` (`url ~ '^https://'`, length<=2000, em `save_checkout_link`).
- `redirect_url = https://<domain>/acompanhar/` (sem token); a pagina de acompanhamento le `order_nsu` de `location.search` (src/pmd/infinitepay.ts `returnNsu`; src/screens/Track.tsx L16, L518).
- Edge Function de webhook: uma por provedor, `paymentAdapters().infinitepay` literal (infinitepay-webhook/index.ts). Porta de gravacao do webhook: `record_infinitepay_event` (nome e `provider:'infinitepay'` chumbados no SQL; DEF/financeiro/functions.sql L717-740). `INSTALL.md` L1046: "A provider other than InfinitePay needs its adapter in the functions and its own webhook function first, which this version does not ship."
- Tabelas/colunas com nome InfinitePay: `store_settings.infinitepay_handle/base_url`, `infinitepay_webhook_secret()`, `DEFAULT 'infinitepay'` em `checkout_links.provider`, `payment_event_record`/`payment_events` alinhados ao provedor registrado; funcoes `orders_to_reconcile` emitem `order_nsu/slug` para InfinitePay e `order_ref/link_ref` para os demais (MIG 005100 L357-360).
- Frontend: `Backend.checkoutLink(token): Promise<string>` (src/backend/index.ts L33) -> redireciona ao URL.

## 16. Premissas que quebram com cada modelo  [P/H — analise; nada implementado]

Premissas centrais hoje: (A) pagar = abrir uma URL hospedada pelo provedor; (B) 1 link por pedido+valor; (C) pagamento a vista, valor integral, quitado de uma vez (PART_PAYMENT_REFUSED); (D) confirmacao so por consulta a `payment_check` de "pago/nao pago"; (E) cada pagamento tem `transaction_nsu` e um `slug` de link que prova pertencer ao pedido; (F) um webhook por provedor com segredo no caminho e porta SQL propria; (G) metodo guardado so como `pix|card` (check `payments_method_check` aceita `pix|cash|card`); (H) o cliente nunca informa dados de pagamento ao servidor.

- Componentes embutidos / token de cartao (ex.: Mercado Pago Brick, docs: intent/pmd-integrations/mercadopago-checkout-transparente.md §2.2, §3): QUEBRA (A) e a forma de `outbound.send` (devolve `{ok,id:URL,ref}`; precisaria devolver client_secret/chave publica/dados do componente e receber token de volta num novo canal de entrada autenticado). `Backend.checkoutLink: Promise<string>`, `checkout-link` `{url}` (contrato `plataforma.ts` L23), `save_checkout_link` (exige `https://` e `invoice_slug` proprios), `Track.tsx` (botao que abre URL) e a premissa (E) de `slug` (Orders/Payments do MP usam `external_reference` e id da order, sem "slug de link"). A resposta do cartao ja vem sincrona com status final (mp §2.2): nao ha etapa "campainha -> check" natural; precisaria de um caminho de settle sincrono ou reaproveitar o evento. Idempotencia na criacao e obrigatoria no MP (`X-Idempotency-Key`), e `OperationInput.key` so existe para cancel/refund, NAO para `outbound.send` (lacuna do contrato). Escopo de PCI: o desenho atual e favoravel (nunca ve cartao); o token teria de passar por `place_order`/Edge e nao pode ir a `payment_events` (allowlist `provider_payload_facts` ajuda).
- Pix QR / copia-e-cola: QUEBRA (A) e (D) parcialmente: precisa expor `qr_code` + expiracao (24 h padrao no MP, mp §2.3) na pagina, e `Answer`/`checkout_links` so guardam uma URL. Aceita status `pending` ate expirar: hoje nao existe estado "emitido/pendente/expirado" por tentativa (so link + hold do pedido). `hold_expires_at` e a janela de conciliacao de 1 dia (orders_to_ask) interagem com expiracao do Pix; `expire_orders` poderia expirar um pedido com Pix ainda valido [H]. `payment_check_canonical` ja mapeia `capture_method='pix'` -> `method:'pix'` (bom). A pagina atual ja menciona Pix dentro do link do provedor; o Pix proprio da loja (chave Pix, comprovante) foi REMOVIDO (docs/manual-pagamentos.md §topo) e `payments_one_rail` bloqueia pagamento sem provedor.
- Boleto: QUEBRA (C) e o relogio: confirmacao em 1-3 dias uteis; `orders_to_ask` so olha 1 dia apos o hold; `expire_orders` expira pedido `new` apos `hold_minutes` (<=24 h se agendado) e o dinheiro chega depois => cai em `refund_due` (ACT-015). Tambem `payments_method_check` nao tem `boleto`; `payment_method_of`, relatorios e `settle` mapeiam so `pix|card`. O mp doc sugere deixar boleto de fora (§5.2).
- Autorizar/capturar: QUEBRA (D) e o vocabulario do ledger: so ha `due/proof_sent/paid/refused/refunded/cancelled/to_check`; sem estado `authorized`/`captured`/`voided auth`. `check` devolve `answered/paid`; precisaria de `authorized`, e `capture`/`void` como novas operacoes opcionais (hoje so `cancel`, que no contrato e "retirar algo ainda nao pago"). Liquidar na autorizacao seria dar dinheiro sem captura [P: manter 'paid' apenas na captura]. Expiracao de autorizacao e reserva de estoque (`hold`) precisariam alinhar.
- Assinaturas/recorrencia: QUEBRA (B), (C) e o modelo de pedido: `orders` e uma compra avulsa com `due` unico; nao ha entidade de contrato/assinatura, cobranca recorrente nem dunning; `payments_provider_tx_once` e `link_payments` pressupoem 1 pagamento por transacao por link; webhooks de renovacao chegariam sem `order_nsu`/link do pedido (settle exige pedido pelo numero e slug em `checkout_link_mints`).
- Recebedores / split: QUEBRA (G) e a conta unica: `private.payment_providers.account` e a `infinitepay_handle` sao UMA conta por instalacao; o ledger registra um unico valor `amount_cents` sem partes por recebedor; sem taxa/comissao no `payments`; reembolso parcial por recebedor nao tem modelo. Acerto de entregadores e declarado FORA do PMD (D191). `provider_refund` tem 1 linha por (provider, tx) com 1 valor.

Geral: o contrato `Answer` nao carrega dados estruturados (so `id`/`ref`); `PaymentMint` e `PaymentCheck.event` retornam `unknown` e dependem de `payment_check_canonical` no SQL; adicionar campos ao evento exige tocar `payment_fact` e `provider_payload_facts` (allowlist LGPD, so strings/numeros).

## 17. Pedidos historicos, eventos pendentes e links emitidos se o contrato mudar  [V]

Restricoes de compatibilidade encontradas:
1. Links ja emitidos continuam pagaveis no provedor (a InfinitePay nao cancela) e sao reconhecidos por `private.checkout_links` (atual) e `private.checkout_link_mints` (historico). Mudar a forma de `slug`/`invoice_slug` ou apagar essas tabelas faz pagamentos legitimos virarem `PROVIDER_MISMATCH` (ficam sem lancar; o banco so avisa a loja por nota em alguns casos).
2. Eventos pendentes em `private.payment_events` guardam o payload NO VOCABULARIO DA INFINITEPAY (`order_nsu`, `transaction_nsu`, `invoice_slug`...). `payment_fact` le canonico OU InfinitePay; o indice `payment_events_order_ref` e funcional sobre `payment_fact(payload,'order_ref')`; `payment_in_flight`/`payment_short` e o apagamento LGPD usam as mesmas palavras. Trocar o vocabulario sem manter essa leitura dupla quebra expiracao, pagina de acompanhamento ('online_short'), conciliacao e eraser.
3. `payments` e imutavel: linhas historicas (inclusive `refunded`/`cancelled` anteriores a 2026-10-05, `provider_ref` com forma `check:<n>:<slug>`) nao podem ser migradas por UPDATE; qualquer nova coluna precisa de default/nullable e as constraints (`payments_method_check`, `payments_status_check`) ampliadas por migration, preservando `payments_provider_tx_once` e `provider_tx_key`.
4. `orders.checkout_url/amount/invoice_slug` foram retiradas e preservadas em `private.orders_checkout_*_retired` (MIG 20261014990500); `provider_owns_payment()` ainda trata pedido antigo com link como do provedor; `checkout_link` recusa `payment_method <> 'card_online'` (pedidos antigos Pix/dinheiro nao ganham link; tests/db/checkout-link-old-pix-order.test.ts).
5. `private.checkout_links.provider` default `'infinitepay'`: toda linha antiga e InfinitePay; `orders_to_reconcile` e `settle` decidem pelo provedor gravado, nao pela configuracao atual.
6. Contratos externos fixados em teste: `Backend.checkoutLink` (string URL), porta `checkout-link` `{url}` (src/pmd/contracts/plataforma.ts L23), formas das portas em tests/db/contracts/contracts.json e src/pmd/contracts/financeiro.ts; `API.md` L294, L691-694; tests/doors/inventory.ts. Mudar a forma sem atualizar esses quebra testes de contrato.
7. Migrations: corpos de funcoes sao reescritos por patch com guarda de md5 ("is not the body this migration was written against"); portanto nao se edita migration antiga: toda mudanca e migration NOVA, mais atualizar DEF (tests/db/definitions.test.ts). tests/db/provider-tx-unique.test.ts exige que a migration 005100 seja idempotente.
8. Webhooks em voo: o `webhook_url` ja foi embutido nos links emitidos (`/infinitepay-webhook/<segredo>`); renomear a Edge Function ou rotacionar `pmd_link_secret` deixa de aceitar webhooks de links pendentes (a conciliacao e a rede de seguranca, limitada a 1 dia/4 tentativas).
9. Retencao/LGPD: `payment_events` (classe personal, eraser `financeiro_on_erase`), `checkout_links`/`link_payments`/`provider_refunds` (financial, mantidos como fatos financeiros), allowlist `provider_payload_facts` (strings/numeros). Novo dado de pagador (CPF, e-mail do pagador exigidos pelo Pix MP) precisa de classe/eraser novos (tests/unit/ ... manifest, financeiro-states "criterion 5").

## 18. Lacunas / nao verificado

- Nenhum teste foi executado (sem node_modules). Nao foi lido o corpo completo de tests/scenarios/*, tests/db/roles.test.ts, aal2-doors.test.ts, money-*.test.ts, nem o texto completo de intent/pmd-integrations/infinitepay.md (616 linhas; so referencias).
- Nao foi confirmado em ambiente real: se `payment_check` ecoa `order_nsu`/`transaction_nsu`; se o link da InfinitePay expoe o caminho do webhook; o comportamento da InfinitePay para Pix pendente (`paid:false` transitorio).
- Nao encontrado rate-limit proprio na Edge Function `checkout-link` nem em `infinitepay-webhook` (alem do limite de 50 eventos/minuto do job) [H de risco de fila por spam do webhook so se o segredo vazar].
- Nao auditado: src/ do painel (v2) alem de referencias; `supabase/verify/checks.sql` so por grep; scripts/provider_scan.py nao lido; PGlite vs Postgres real (as portas foram testadas em PGlite).
- `card_fee_mode`/`card_surcharge_percent`: ainda em settings e em `casca` mas aparentemente sem efeito no calculo (confirmar se e legado a retirar).
