# PMD Payments: Partes IV a VI

Convenções da Parte 1 valem aqui. Em tabelas de provedores: **C** confirmado, **P** parcial, **Cd** condicional (depende de contrato, elegibilidade ou liberação), **N** não suportado, **NV** não verificado, **\*** afirmação de conhecimento prévio **não reconfirmada hoje** (tratar como NV até validar). Documentação existente **não comprova habilitação comercial** para qualquer lojista. Todas as células vêm de resumos de busca de páginas oficiais, não da leitura integral delas (ver limite de método na Parte 1). Fontes e URLs por célula estão em `evidencias/psp-*.md`.

---

# PARTE IV: Matriz de provedores financeiros

## 4.1 Capacidades

| Critério | Mercado Pago | InfinitePay | Asaas | Pagar.me v5 | PagBank | Efí | Iugu | Stripe (BR) | Adyen | Appmax |
|---|---|---|---|---|---|---|---|---|---|---|
| Checkout hospedado | C | C | C | NV | NV | C (boleto/cartão) | C | C\* | Cd | P |
| Checkout transparente (API) | C | Cd (API v2) | C (cartão passa pelo backend) | P | P | C | C | C\* | C\* | C |
| Componentes SDK | C (Bricks) | P (IPay.js) | NV | NV | NV | P | P | C\* | C\* | P (Appmax JS) |
| Cartão | C | C (até 12x) | C | P | P | C | C | P (Visa/Master; Elo não) | C\* | C |
| Pix | C | C | C | P | P | C | C | Cd (60 dias processando) | Cd (entidade BR) | C |
| Pix Automático | NV | NV | Cd (PJ, CNPJ ≥ 6 meses) | NV | NV | C na API Pix (PJ) | Cd (API sem motor de recorrência) | N/Cd (doc contraditória) | Cd (piloto) | NV |
| Boleto | C | NV | C | NV | NV | C | C | Cd | C\* | C |
| Apple Pay | Cd (docs de CO/MX) | NV | NV | NV | NV | NV | NV | P | C\* | C |
| Google Pay | NV | NV | NV | NV | NV | NV | NV | P | C\* | C |
| Assinaturas | C (`preapproval`) | NV | C | P | P | C (boleto/cartão) | C | P | Cd (merchant agenda) | P (seção não lida) |
| Tokenização p/ cobranças futuras | P | P | Cd (liberação) | NV | NV | C (`payment_token` reutilizável) | C | C\* | C\* | NV (token de uso único) |
| Split 1:1 | C (OAuth por vendedor) | NV | C (`walletId`) | Cd (cliente "PSP") | P | C | C | P | Cd | Cd (homologação API V4) |
| Split múltiplos recebedores | Cd (blog; contrato) | NV | C | Cd | P | C (até 20 no Pix; só entre contas Efí) | C | P (transfers) | Cd | Cd |
| Estorno parcial | C | N via API (só app/maquininha) | C (split: manual) | NV | NV | P | P (só cartão) | C\* | NV | P (sem split: só total) |
| Cancelar e capturar | C/P (conflito de doc) | NV | Cd (3 a 25 dias) | NV | NV | NV | C (7 dias) | C\* | C\* | NV |
| Antecipação | P (prazo D0/D14/D30 no painel) | P (embutida nas taxas) | Cd | NV | NV | NV | Cd | NV | NV | P |
| Webhook autenticado | C (HMAC-SHA256, `x-signature`) | NV (nenhuma assinatura documentada) | P (token estático) | NV | NV | C no Pix (mTLS) | P (Basic Auth) | C\* | C\* | NV (sem HMAC confirmado) |
| Idempotência | C (`X-Idempotency-Key`) | NV | NV (dedupe por id do evento) | NV | NV | P (`txid` no Pix) | NV | C\* | C\* | NV |
| Sandbox | P (Bricks sem conta de teste) | NV | C | NV | NV (relatos divergentes) | C | NV | C\* | C\* | C |
| OAuth de vendedor | C | N (identifica por `handle`) | NV (apiKey por subconta) | NV | P | P | P | C\* (Cd no BR) | Cd | P (token do merchant) |
| Limites de requisição | P (429 sem número) | NV | C (25.000/12 h; 50 GET simultâneos) | NV | NV | NV | NV | C\* | NV | P (números citados não achados) |
| Custos públicos | P (blogs: crédito ~3,98% a 4,98% conforme prazo; Pix ~0,99%; boleto R$ 3,49) | P (Pix grátis; crédito à vista 3,15% na faixa até R$ 20 mil) | P (Pix/boleto R$ 1,99; cartão 2,99% + R$ 0,49) | NV | NV | P (Pix 1,19%; boleto R$ 3,45; cartão 3,49%; Pix Aut. R$ 3,50) | P (tabela antiga) | NV | NV | P (Pix 0,99%; boleto R$ 3,49; cartão 3,49%) |
| Conta que recebe | Conta MP do vendedor | Conta do dono da InfiniteTag | Conta que emitiu a cobrança | Recebedor de cada parte | Recebedor primário/secundário | Conta Efí do emissor | Conta que emite a fatura | Cd (depende do modelo Connect) | NV | Conta Appmax do merchant |
| Quem controla a recorrência | PSP | n/a | PSP (cartão/boleto); híbrido no Pix Aut. | NV (provável PSP) | NV (provável PSP) | PSP (cartão/boleto, Pix fixo); integrador (Pix variável) | PSP (assinaturas); integrador (Pix Aut. por API) | PSP (Billing) | Merchant | NV |
| Dificuldade do adaptador (TS/Edge) | Média | Baixa | Baixa-média | Média | Média-alta | Média-alta (mTLS de saída no Pix) | Média | Baixa | Alta | Média-alta |

## 4.2 Pontos que alteram decisões (resumo)

- **Mercado Pago:** split 1:1 por OAuth é **confirmado**, com `application_fee` (Checkout Transparente e Bricks) ou `marketplace_fee` (Checkout Pro); um vendedor por pagamento; a comissão do MP sai antes da fee do marketplace; o reembolso é dividido proporcionalmente e depende de saldo do vendedor. O 1:N só aparece em blogs e exige contato comercial: **não tratar como capacidade aberta**. O `refresh_token` **rotaciona** a cada uso: perder o novo token quebra a conexão. A doc diverge em captura parcial (Orders × Payments) e em `preapproval_plan_id`. O briefing acertou o modelo 1:1 baseado em OAuth.
- **Pagar.me:** o split com múltiplos recebedores existe, mas a página oficial diz que vale só para clientes **PSP** (contrato com a Stone). Regras de liable/resto vêm de documentação v1 legada: usar só como indício. O briefing acertou.
- **PagBank:** o briefing menciona restrições de split com recorrência (cupons, taxa de adesão). **Não as encontrei em nenhuma fonte acessada**: é risco aberto a validar, não conclusão. Docs misturam v1.0 e v4.1.
- **Asaas:** o split calcula sobre o **líquido**; estorno total reverte o split, mas o **parcial não**: exige `splitRefunds`. Assinatura com split vira modelo fixo para as cobranças futuras; update com `splits: null` ou `[]` **desativa**; divergência de valor **bloqueia a assinatura**. Pix Automático: autorização via API, modo `SUBSCRIPTION` (PSP gera as cobranças) ou `MANUAL` (o integrador cria cada cobrança); **sem split na autorização inicial**. Não há componente client-side de cartão: pelo backend, o PMD passaria a ver dado de cartão (escopo PCI), então use checkout hospedado/link.
- **Efí:** a API Pix usa **mTLS também nas chamadas de saída**, o que é difícil em Edge Functions (Deno) [H]; a Efí afirmou que não pode ser "subadquirente de subadquirente", o que barra cartão em marketplace. "Pix Recorrente" (Open Finance) é **outro produto**.
- **Iugu:** a API de Pix Automático **não gerencia a recorrência**; o integrador precisa de motor próprio. Split por assinatura é confirmado. Estorno Pix só total; boleto sem estorno.
- **Stripe:** Pix Automático indisponível ou por convite; Elo não suportado; Pix exige 60 dias de processamento; Connect para contas brasileiras é NV. Forte tecnicamente (idempotência e webhook assinado nativos), fraco para Pix recorrente e split local.
- **Adyen:** exige contato comercial e entidade local; mais realista para enterprise.
- **InfinitePay:** a API pública de checkout só **cria link, notifica e consulta**. Sem reembolso por API, sem assinatura de webhook, sem split, sem sandbox documentado. O adaptador do PMD cobre exatamente isso.
- **Appmax como PSP integrável:** um terceiro com CNPJ pode criar app na App Store (público ou privado, com revisão técnica), mas é o modelo "integração para lojistas Appmax". O Bearer vem das credenciais do **merchant**. Split e recebedores exigem homologação (API V4) e credenciais da Appmax. "Payment as a Service" não foi verificado em fonte oficial.

## 4.3 Ordem de integração recomendada [P]

| # | Provedor | Papel | Justificativa | Condição |
|---|---|---|---|---|
| 0 | **InfinitePay** | Manter | Implementado, com estudo e testes; limites conhecidos (sem estorno por API) | — |
| 1 | **Mercado Pago** | Primeiro consumidor do contrato evoluído (cartão por Brick + Pix) | Único com plano de integração escrito; HMAC assinado e `X-Idempotency-Key` documentados; Brick mantém o PMD fora do escopo de dados de cartão | Dono decide coexistência com InfinitePay (hoje o teste `single-card-rail` proíbe `mercadopago`) e o estágio entra na Fase 2 |
| 2 | **Asaas** | Billing recorrente de PME (academia, clínica, serviço) | Assinatura nativa, Pix Automático, boleto, sandbox completo, adaptador baixo-médio; usar **link/checkout hospedado** para não ver cartão | Elegibilidade do Pix Automático (CNPJ ≥ 6 meses); decisão sobre billing |
| 3 | Stripe | Opcional, para negócios com cartão e Billing | Adaptador mais simples; Pix recorrente e Elo fracos | Demanda concreta |
| — | Efí | Só para lojista que já tem conta Efí e quer Pix Automático | mTLS de saída | Só se Deno suportar |
| — | Iugu, Pagar.me, PagBank | Não priorizar agora | Dependem de contrato/versão de doc incerta | Demanda concreta; reler docs |
| — | Adyen | Não agora | Enterprise | — |
| — | Appmax | Apenas como PSP de lojistas que já a usam | App Store, CNPJ, homologação V4 | Demanda concreta |

Isso segue a regra do próprio PO (F3): *"catálogo de integrações é repertório, não fila"*.

---

# PARTE V: Arquitetura proposta

## 5.1 Princípios [P]

1. **Menor mudança que preserve a correção.** Estender o contrato existente por capacidades **opcionais** (o padrão `Operations` + `NOT_SUPPORTED` já existe), em vez de um contrato universal.
2. **Banco move o dinheiro; borda nunca decide.** Inalterado.
3. **Capacidade declarada, não presumida.** Split, recorrência e carteiras são capacidades por adaptador e por conta; ausência = `NOT_SUPPORTED`, nunca silêncio.
4. **Instalação independente.** Cada loja tem seus provedores e credenciais (digitadas pelo dono; o agente nunca as lê, CHARTER §9). Nada de `tenant_id`.
5. **Nenhum dado de cartão no PMD.** Hospedado ou componente do provedor (SAQ A).

## 5.2 Diagrama lógico

```mermaid
flowchart LR
  classDef exist fill:#e8f1ff,stroke:#2b5fbf,color:#0b2a5b
  classDef prop fill:#fff4d6,stroke:#b8860b,color:#5b3d00,stroke-dasharray: 5 3
  classDef cond fill:#f3e8ff,stroke:#7a3fb0,color:#3b1a5c,stroke-dasharray: 2 4

  subgraph Cliente
    L[Loja/checkout\nplace_order]:::exist
    T[Tela /acompanhar\nredirect para URL]:::exist
    NX[Tela: próxima ação tipada\nredirect · pix · componente]:::prop
  end

  subgraph Nucleo[Núcleo PMD - Supabase da instalação]
    PO[pedidos\nquote_cart]:::exist
    FIN[financeiro\nledger payments imutável\nsettle_provider_event]:::exist
    ATT[(payment_attempts\ntentativa + chave)]:::prop
    EVT[(payment_events\nprovider_events)]:::exist
    HOOK[porta de webhook genérica\nrecord_provider_event]:::prop
    HOOKI[record_infinitepay_event\nmantida]:::exist
    REC[reconcile\njob por minuto]:::exist
    REF[provider_refund\nclaim + chave]:::exist
    BILL[módulo billing\nplano · assinatura · ciclo]:::prop
    SPL[módulo split/comissão]:::cond
  end

  subgraph Borda[Edge Functions]
    CL[checkout-link]:::exist
    WH1[infinitepay-webhook]:::exist
    WHN[webhook por provedor]:::prop
    ST[settle-provider-payments]:::exist
    START[start: próxima ação]:::prop
  end

  subgraph Adaptadores
    IP[InfinitePay\nsend · check]:::exist
    MP[Mercado Pago\nstart · check · refund]:::prop
    AS[Asaas\nstart · check · billing]:::prop
    SIM[provedor simulado\ntestes de contrato]:::exist
  end

  L --> PO --> FIN
  T --> CL --> IP
  NX --> START --> MP
  START --> AS
  START --> ATT
  IP -. webhook campainha .-> WH1 --> HOOKI --> EVT
  MP -. webhook .-> WHN --> HOOK --> EVT
  AS -. webhook .-> WHN
  ST --> EVT
  ST --> REC
  ST -->|"confirma no provedor"| IP
  ST --> MP
  EVT --> FIN
  REC --> FIN
  REF --> FIN
  BILL -->|"cada ciclo = pedido"| PO
  SPL -. só se COMMERCIAL.md L13 for reaberta .-> FIN
```

Azul sólido = existe (verificado no código). Amarelo tracejado = proposto. Roxo pontilhado = condicionado a decisão do dono.

## 5.3 Contratos [P]

**Preservar** `PaymentAdapter` como está (`outbound.send` → `{ok,id,ref}`), para a InfinitePay e para links históricos. **Acrescentar**, em `Operations`, capacidades opcionais:

| Capacidade nova | Assinatura (conceitual) | Por quê |
|---|---|---|
| `start?(input, io)` | `input = {mint, key, functionsUrl}`; resposta `{ok:true, ref, next: Next}` ou `{ok:false, code}` | Resolve (a) **chave de idempotência na criação**, que hoje não existe; (b) resposta que não é URL |
| `Next` (união tipada) | `redirect{url}` · `pix{qr_code, copy_paste, expires_at}` · `component{kind, public_key, session}` · `authenticate{...}` · `pending{poll_after}` · `paid` | O briefing pede exatamente este modelo; `redirect` mapeia o fluxo atual sem quebrar nada |
| `capture?`, `void?` | como `cancel`/`refund`, com `key` | Só se algum provedor adotado precisar de autorizar/capturar |
| Contrato `BillingAdapter` (separado) | `createPlan`, `createSubscription`, `changeSubscription`, `cancelSubscription`, `listCharges` | Ciclo de vida e dados diferentes: não deve engordar `PaymentAdapter` |
| Contrato `SplitAdapter` (separado, condicionado) | `createRecipient`, `applySplit`, `refundSplit` | Idem; só existe se a decisão do dono permitir |
| Declaração de capacidades | `capabilities: {hosted, embedded, pix, boleto, wallets, recurring, split, refund:'none'|'total'|'partial', capture}` publicada pelo adaptador | A matriz da Parte IV vira dado verificável por `checkAdapter`; a UI mostra só o habilitado |

Regras herdadas, que valem para todo adaptador novo: `verify` antes de qualquer parse; segredos só por nome; hosts declarados; deadline ≤ 15 s; nenhuma string de provedor fora do adaptador (`scripts/provider_scan.py`); registro em `paymentAdapters()`; fixture em `tests/integrations/contract.test.ts`.

**Webhook.** Uma porta SQL genérica `record_provider_event(provider, secret, payload)` (já existe `private.payment_event_record` por baixo) e uma função de borda parametrizada por provedor para os novos. **`infinitepay-webhook` e `record_infinitepay_event` permanecem**, porque os links já emitidos embutem `/infinitepay-webhook/<segredo>` e trocar o nome ou rotacionar `pmd_link_secret` deixaria de aceitar webhooks de links pendentes [V]. Para provedores com assinatura (Mercado Pago `x-signature`), `verify` valida o HMAC no adaptador (`checkedBy: 'adapter'`).

**Por que não um contrato universal:** pelo menos cinco provedores da matriz não documentam webhook assinado, três não documentam idempotência e nenhum oferece o mesmo conjunto de operações. Um contrato gordo seria preenchido com `NOT_SUPPORTED` em metade das linhas; capacidades opcionais refletem isso sem custo.

## 5.4 Modelo de domínio: o que criar e o que não criar

Para cada entidade: problema que resolve, cobertura existente, dono, fonte de verdade, invariantes e teste.

| Entidade | Decisão | Problema / cobertura existente | Dono e fonte de verdade | Invariantes a provar |
|---|---|---|---|---|
| Payment Intent | **Não criar** | Já coberto por `orders` + linha `due` do ledger (`financeiro_order_changed`) | `financeiro` / ledger | — |
| **Payment Attempt** | **Criar (mínima)** | Hoje uma criação de link que falha ou perde a resposta não deixa registro e pode gerar **link órfão**; Pix emitido não tem estado pendente/expirado; MP exige chave de idempotência na criação | `financeiro`; tabela `private.payment_attempts(order_id, provider, key, status, expires_at, next)` guarda só dados não sensíveis | Uma tentativa por (pedido, provedor, chave); repetir com a mesma chave devolve a mesma `next`; tentativa expirada não impede nova; nunca guarda token de cartão |
| Payment Method | **Não criar agora** | `payments.method` já é `pix\|card` (`payments_method_check`); só ampliar se adotar boleto | `financeiro` | Constraint ampliada por migration nova, preservando `payments_provider_tx_once` |
| Provider Configuration | **Existe** | `private.payment_providers` + `store_settings.infinitepay_handle` lacrada | `financeiro` | `RECEIVER_SEALED` |
| Provider Transaction | **Existe** | `payment_events` + `payments.provider_ref` | `financeiro` | Índice único por transação |
| Authorization/Capture | **Adiar** | Ledger não tem estado `authorized`; só se um provedor adotado exigir | — | Liquidar como `paid` **somente na captura** |
| Refund | **Existe, incompleto** | Contrato + `provider_refunds` mas sem tela/papel e sem linha no ledger | `financeiro` | Reembolso `done` baixa `refund_due_cents` e gera linha; `REFUND_EXCEEDS_RECEIVED` preservado |
| Checkout Session | **Não criar** | `checkout_links` + `checkout_link_mints` + tentativa | `financeiro` | — |
| Subscription / Subscription Cycle | **Criar, em módulo opcional `billing`** | Não há nada hoje | `billing`; cada ciclo gera um **pedido** que passa pelo mesmo `settle` | Ciclo único por (assinatura, período); datas de fim de mês/fuso determinísticas; cancelar durante tentativa não duplica |
| Billing Invoice | **Não criar** | Ciclo + pedido já cumprem esse papel | — | — |
| Recipient / Split Allocation / Settlement / Receivable | **Condicionado** | Vetado por `COMMERCIAL.md` L13 | só existiria em módulo `split` | Soma das partes + taxas = valor liquidado; reversão proporcional |
| Fee Rule / Fee Assessment | **Condicionado** | Só necessário se o PMD cobrar por transação | idem | Taxa calculada no servidor; estorno reverte comissão conforme regra explícita |
| Dispute | **Não criar** | Delegar ao PSP; ingerir o evento e marcar o pedido | `pedidos`/`financeiro` | Chargeback nunca reabre acesso já concedido sem regra |
| Reconciliation Run | **Complementar** | Conciliação por minuto existe; falta relatório de divergência PSP × ledger | `relatorios` | Divergência listada, nunca corrigida em silêncio |

## 5.5 Consistência financeira e livro-razão

O ledger atual `public.payments` é um **livro-caixa por pedido**, append-only e imutável (`payments_immutable`), com estorno por linha `cancelled` que referencia a original (`payments_undo_names_entry`, `payments_voids_key`) [V]. Para o escopo recomendado (Modelo 1, sem split) ele é **suficiente**, com três correções: ampliar o `method`/status só quando um método novo for adotado; registrar reembolso `done` como linha; baixar `refund_due_cents`.

**Livro-razão de partidas dobradas: não recomendado agora.** Ele só se justifica quando o PMD (ou um módulo) passar a ter **saldos a pagar entre partes** (recebedores, comissões a repassar). Isso não acontece no Modelo 1, e criar um segundo livro duplicaria a fonte de verdade dos pagamentos. Gatilho para reavaliar: aprovação do Modelo 2 pelo dono. Nesse caso, introduzir `fee_assessments` e `split_allocations` **derivados** de linhas de `payments` (referenciando `payment_id`), não um razão geral independente.

Fatos sobre a separação pedido/pagamento/estorno que o ledger atual já resolve [V]: pagamento menor que o devido é recusado e vira `refund_due`; excedente vira `refund_due`; pagamento num pedido morto vira `refund_due` com nota; link antigo continua aceito pelo histórico de mints; duplicidade de transação é barrada por índice único.

## 5.6 Reconciliação, falhas e versionamento

- **Reconciliação:** manter o job por minuto; acrescentar (a) janela maior para métodos de confirmação lenta, se algum for adotado; (b) relatório periódico de divergência; (c) cron também com **todos** os provedores desligados (hoje `cron_pending` exige provedor pronto, contra o comentário do código) [V].
- **Política de falhas:** desconhecido nunca vira recusa (já vale). Acrescentar à tentativa o estado `unknown` e reconsultar por chave antes de qualquer nova cobrança em outro provedor.
- **Versionamento/instalação:** migrations novas sempre (guarda de md5 impede editar as antigas); atualizar `supabase/definitions`; módulo `billing` entra via `module.py` e a receita da instalação (`scripts/recipe.py`); uma loja sem o módulo continua vendendo (regra de ausência, provada por `sale.property.test.ts`).

---

# PARTE VI: Fluxos técnicos de ponta a ponta

"Existe" = verificado no código; "Proposto" = depende do que a Parte V propõe. Em todos, o dinheiro só se move em `settle_provider_event` após confirmação direta no provedor.

**1. Pagamento com checkout externo (existe).** Ator: cliente. Inicial: pedido `new` com linha `due`. Passos: `checkout_link` devolve o link guardado ou um `mint`; adaptador cria link (`POST /links`); `save_checkout_link`; cliente é redirecionado; paga; provedor toca o webhook; banco grava evento; job pergunta `payment_check`; `settle_provider_event` lança o devido. Final: pedido `paid`, `order_events.payment`. Falhas: criação falha → 502 `PROVIDER_UNAVAILABLE` (**sem registro**, lacuna); resposta perdida → link órfão. Recuperação: reconsulta/backoff; órfão só aceito se o pedido não tiver outro slug.

**2. Pagamento com checkout transparente (proposto).** Cliente, no navegador, tokeniza o cartão com o SDK do provedor (Brick/Appmax JS); o token vai à Edge `start` com chave de idempotência; o adaptador cria a cobrança; resposta `Next=paid|authenticate|pending`; a tentativa é gravada **antes** da chamada. Final: confirmação síncrona **não** liquida: ainda passa por `check` (evento `reaction` único). Falhas: timeout após o provedor agir → tentativa `unknown`, reconsulta pela mesma chave, nunca nova cobrança. PCI: o PMD nunca vê o PAN.

**3. Pix pendente até confirmação (proposto).** `start` devolve `Next=pix{qr_code, copy_paste, expires_at}`; tentativa `pending`; pedido mantém o hold até `expires_at`; webhook/reconsulta confirma. Falhas: o hold atual e a janela de reconciliação de 1 dia podem expirar o pedido com Pix ainda válido [H] → alinhar `expire_orders` ao `expires_at` da tentativa; pagamento tardio vira `refund_due` (comportamento atual, ACT-015/037).

**4. Pagamento recusado e nova tentativa (proposto).** Recusa conhecida do emissor (`success=true, paid=false`) → tentativa `failed`; cliente tenta de novo com **nova chave** (nova tentativa), nunca reutiliza a chave com corpo diferente (MP rejeita `idempotency_key_already_used`). Recusa **desconhecida** (timeout) → `unknown`, reconsulta; só depois permite nova.

**5. Assinatura criada e primeira cobrança (proposto, módulo `billing`).** Atores: lojista (plano) e cliente. Cria-se contrato/assinatura; o primeiro ciclo gera um **pedido** de ciclo, que segue o fluxo 1 ou 2; ao pagar, o direito de acesso é concedido por ponto de política. Falha na primeira cobrança → assinatura `aguardando ativação`; não concede acesso.

**6. Renovação automática (proposto).** Modelo híbrido: com cartão, o PSP agenda (MP `preapproval`, Asaas assinatura) e o webhook de renovação chega **sem `order_nsu` de um pedido existente** → o `billing` cria o pedido de ciclo ao receber o evento e vincula pela referência da assinatura; com Pix Automático MANUAL, o PMD cria a cobrança de cada ciclo no calendário. Datas: ciclo único por período; dias inexistentes (31 em mês curto) e fim de semana com regra explícita; fuso Brasília.

**7. Falha na renovação (proposto).** Retentativa conforme o PSP (MP: janela de 10 dias, cancela após 3 recusas) ou do PMD; status `em atraso`; avisos pelo WhatsApp **somente reativo**/ e-mail (recuperação por WhatsApp depende de decisão do dono, `PRODUCT.md` L180); acesso suspenso conforme política do negócio; nunca cobrança duplicada num mesmo ciclo.

**8. Cancelamento da assinatura (proposto).** Imediato ou ao fim do período (`cancelamento agendado`); cancela no PSP com chave de idempotência; **cancelar durante uma tentativa em curso** espera o resultado da tentativa antes de aplicar, para não gerar cobrança órfã.

**9. Venda com split (condicionado a decisão do dono).** Só no Modelo 2 ou em split entre lojista e terceiros (marketplace). O split é **do PSP**; o PMD registra a alocação derivada. Limitações por provedor: MP 1:1 com OAuth; Asaas sobre o líquido; Pagar.me só cliente PSP; Appmax só homologado. Regra incompatível com o provedor é **recusada**, nunca ajustada em silêncio.

**10. Estorno em operação com split (condicionado).** Appmax: só estorno total em pedido com split. Asaas: total reverte o split sozinho; parcial exige `splitRefunds`. MP: reembolso rateado entre vendedor e marketplace, dependente de saldo do vendedor. O modelo precisa de política explícita para quem arca com a taxa do PSP e com a comissão.

**11. Cobrança com comissão do PMD (condicionado).** Modelo 1: o PMD cobra por fora (assinatura do software), sem tocar o fluxo. Modelo 2: `application_fee`/split do PSP; a comissão é revertida no estorno conforme regra escrita (decisão de negócio). Modelo 3: não recomendado.

**12. Webhook perdido e reconciliação (existe).** Pedido pago no provedor sem toque; `orders_to_reconcile` devolve o pedido (hold vencido, < 1 dia, ≤ 4 perguntas); `check.order` pergunta ao provedor; resposta "paga" é gravada via `record_provider_event` e liquidada na mesma rodada, perguntando de novo. Limite: janela de 1 dia; só pedidos com slug.

**13. Provedor desabilitado com operações pendentes (existe, com lacuna).** Eventos e links seguem o provedor gravado no link, não a configuração atual [V]. **Lacuna:** `cron_pending` exige um provedor pronto, então com **todos** os provedores desligados o job não dispara e os pendentes ficam sem liquidar, contra o comentário do código [V].
