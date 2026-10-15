# PMD Payments: Partes I a III

**O que é:** auditoria arquitetural e estudo de viabilidade para incorporar pagamentos, recorrência, split, recuperação e multi-PSP ao PMD Core, usando a Appmax como benchmark funcional.
**Base:** `pmd-workspace/pmd-core`, branch `main`, commit `4b91aec` (14/10/2026), lido em 15/10/2026. Nenhum arquivo do PMD Core foi alterado (`git status` limpo).
**Natureza:** somente leitura e planejamento. **Nenhum teste foi executado** (o clone não tem `node_modules`): onde este relatório diz "coberto por teste", significa que o teste existe e declara aquilo, não que foi visto passar. A avaliação é estática.

## Como ler as classificações

| Marca | Significado |
|---|---|
| [V] | Verificado no código (arquivo e linha) |
| [T] | Teste existente declara a garantia (não executado) |
| [D] | Documentado, não comprovado em execução |
| [F] | Documentado por fornecedor (via resumo de busca, ver limite abaixo) |
| [C] | Depende de contrato ou habilitação |
| [P] | Proposta arquitetural minha |
| [H] | Hipótese pendente de confirmação |

**Limite de método que afeta toda a pesquisa externa.** Neste ambiente, as páginas de documentação dos PSPs, do BCB, da Shopify, da VTEX e do PCI SSC estão bloqueadas (erro de DNS ou 403). A pesquisa usou busca web, que devolve **resumos** das páginas oficiais, não o texto delas, e quase nunca mostra data ou versão. Por isso muitas células da matriz de provedores são NÃO VERIFICADO, e itens baseados em conhecimento prévio estão marcados com `*` (não reconfirmados hoje). Antes de contratar ou codificar contra qualquer provedor, as páginas oficiais devem ser relidas por quem tem acesso direto. As evidências brutas estão em `evidencias/`.

---

# PARTE I: Veredito executivo

### 1. O PMD está arquiteturalmente preparado?

**Parcialmente.** O núcleo financeiro é sólido e bem testado para o que faz hoje, mas hoje é **mono-provedor (InfinitePay) e mono-modelo (link de redirecionamento)** [V]. O contrato de integração (`ProviderAdapter`/`PaymentAdapter`, `supabase/functions/_shared/integration.ts`) já aceita vários provedores para criar link, consultar, conciliar e reembolsar, mas quatro coisas continuam amarradas à InfinitePay: a **entrada do webhook** (função `infinitepay-webhook` e porta SQL `record_infinitepay_event`), o **segredo** do webhook, o formato `{url}` da resposta e o vocabulário de campos dos eventos pendentes [V]. `INSTALL.md` L1046 admite: "A provider other than InfinitePay needs its adapter in the functions and its own webhook function first, which this version does not ship".

Para **assinaturas, split, componentes embutidos, autorizar/capturar e boleto**, o modelo atual não serve sem evolução: o pedido é uma compra avulsa com uma conta recebedora única por instalação [V].

### 2. O que pode ser reaproveitado?

Quase tudo que importa para a correção financeira [V][T]:

- **Porta única de dinheiro:** só o banco move centavos, em `settle_provider_event`, e só depois de confirmar direto no provedor. O webhook é só "campainha".
- **Contrato de adaptador** com `verify` antes de armazenar, `check`, `cancel?`, `refund?` e `NOT_SUPPORTED`, mais provedor simulado e suíte de contrato (`tests/integrations/contract.test.ts`).
- **Livro-caixa imutável** `public.payments`, com cache em `orders` protegido por guarda.
- **Idempotência em camadas:** criação de pedido, índice único `payments_provider_tx_once`, locks, `link_payments`.
- **Reconciliação por minuto** com backoff, e valor liquidado sempre limitado ao **devido** (nunca `paid_amount`).
- **Modelo de módulos** (manifestos, portas tipadas, regra de ausência, SQL por dono) e **modelo de instalação** (um projeto Supabase por loja).
- **Reembolso no provedor** como contrato mais porta de banco (`provider_refund`), com chave de idempotência.

### 3. Qual é o principal bloqueio?

**Há dois, de natureza diferente, e o primeiro é de decisão, não de código.**

1. **Decisão de negócio já tomada que contradiz o escopo de monetização do briefing.** `COMMERCIAL.md` §1, L13 (lido por mim): *"PMD never enters the shop's money flow: no commission, no split in PMD's name, no take rate, no PMD account holding a client's money or credentials."* O briefing pede "cobrança de taxas pela própria plataforma" e dá prioridade estratégica a split e monetização. **Não se pode planejar essa frente como se fosse livre.** Ela exige que o dono reabra essa decisão. Também conflitam: `PRODUCT.md` §5 (trilho único, pagamento final, "PMD não registra reembolso"), `PRODUCT.md` L180 (proíbe recuperação de carrinho e IA), `tests/unit/single-card-rail.test.ts` L40-46 (proíbe a string `mercadopago` no código do app) e a Fase 2 (CHARTER §8: nenhuma tela, fluxo ou palavra muda).
2. **Técnico:** o contrato não consegue hoje (a) devolver algo além de uma URL, (b) carregar chave de idempotência na **criação** (`OperationInput.key` só existe para cancel/refund, não para `outbound.send`), nem (c) receber webhook de um segundo provedor sem uma função de borda e uma porta SQL novas [V].

### 4. Qual arquitetura é recomendada? [P]

**Alternativa A: evolução modular interna ao PMD Core**, em incrementos verticais. Concretamente:

- Manter `PaymentAdapter` e **acrescentar capacidades opcionais** (`start` com próxima ação tipada, `capture`, `void`) em vez de um contrato gordo; **contratos especializados e separados** para billing/recorrência e para split, porque têm ciclo de vida e dados próprios.
- Generalizar a entrada de webhook por provedor, **mantendo** `infinitepay-webhook` e seu segredo (os links já emitidos embutem esse caminho).
- Uma entidade nova mínima, **tentativa de pagamento**, e um módulo opcional de **billing**. Nada de livro-razão de partidas dobradas agora.
- **Recorrência:** modelo híbrido (C): a assinatura comercial vive no PMD; a execução financeira é delegada ao PSP quando ele agenda bem (cartão), e o calendário fica no PMD quando o PSP não agenda (Pix Automático variável).
- **Monetização:** por padrão, **Modelo 1** (dinheiro direto na conta do lojista; o PMD cobra seu preço separado), que é o único coerente com `COMMERCIAL.md` hoje. Modelo 2 (split do PSP para o PMD) só se o dono reabrir a decisão. Modelo 3 (plataforma central) **não recomendado**.

Não há evidência de impossibilidade arquitetural que justifique B (pacote compartilhado) ou C (serviço independente).

### 5. Qual deve ser o primeiro incremento? [P]

**Incremento 0 + 1, invisível ao usuário, compatível com o congelamento da Fase 2:** endurecer o contrato com o **provedor simulado**, sem tocar tela, fluxo ou palavra.

1. Chave de idempotência obrigatória na criação (`start`/`outbound.send`).
2. Resposta tipada de próxima ação (`redirect` mapeia o fluxo atual).
3. Porta de entrada de webhook genérica por provedor, preservando o caminho e o segredo da InfinitePay.
4. Registro mínimo de tentativa (fecha o buraco do link órfão).
5. Corrigir pontos de dinheiro já encontrados (ver Parte VII).

Critério de pronto: o provedor simulado passa em `checkAdapter` com **três** formas de próxima ação; a InfinitePay segue passando sem alteração de comportamento; links e eventos históricos continuam sendo liquidados. O primeiro consumidor real (Mercado Pago, já planejado) fica para um estágio seguinte, quando o dono abrir a vaga na Fase 2.

---

# PARTE II: Estado atual do PMD

## 2.1 Mapa da arquitetura

**Stack real** [V]: TypeScript estrito; Astro 7 + Preact (ilhas `client:only`); Supabase (Postgres, RLS, Auth, Storage, Realtime), **um projeto por negócio**; regras transacionais em funções SQL `security definer`; Edge Functions (Deno) para integrações; PGlite nos testes (as mesmas migrations rodam no Vitest e no demo do navegador). **Divergências em relação ao briefing:** hospedagem estática Hostinger (loja e painel), e-mail Resend, WhatsApp Cloud API; sem Docker; plano Supabase Free (500 MB, 500 mil invocações); 279 migrations (última `20261014991000_saneamento_integracao.sql`).

**Módulos** [V]: manifesto tipado por módulo em `src/pmd/modules/<id>.ts` (`ModuleManifest`). Fixos (nunca desligam): pedidos, financeiro, catalogo, avisos, relatorios, packs. Opcionais: agenda, analytics, contatos, conversas, entrega, estoque, fidelidade, posvenda, promocoes, whatsapp. Menu, rotas e a tela Módulos são gerados dos manifestos (`manifests.gen.ts`).

**Núcleo mínimo e fronteiras** [V][T]: `src/pmd/core/manifest.ts`; portas tipadas em `src/pmd/contracts/*.ts` (171 portas, `tests/doors/inventory.ts`); `owners.csv` com 36 donos e 1.294 linhas; verificador de fronteira `scripts/boundary.py` (cinco regras, lista de exceções que só encolhe); regra de ausência `private.module_gate` com quatro estados provados (`tests/modules/conformance.test.ts`); efeitos duráveis via outbox (`notifications`, `private.domain_events`). O núcleo lê módulos opcionais só por **pontos de política** (`point_ask`, `point_tell`).

## 2.2 Inventário financeiro

| Componente | Onde | Papel |
|---|---|---|
| Módulo `financeiro` (fixo) | `src/pmd/modules/financeiro.ts` | Dono do ledger, links, eventos, reembolsos. Poderes `payment` e `refund` (L46). Cron `pmd-settle-provider-payments` (L48-51) |
| Contrato | `supabase/functions/_shared/integration.ts` L21-127 | `ProviderAdapter`, `PaymentAdapter`, `PaymentMint`, `PaymentCheck`, `Operations`, `NOT_SUPPORTED` |
| Registro/fluxos | `supabase/functions/_shared/payments.ts` | `paymentAdapters()` L18 (**uma entrada**), `linkFor` L123, `settleProviderPayments` L158, `reconcile` L191, `cancelAtProvider` L224, `refundAtProvider` L243 |
| Adaptador | `supabase/functions/_shared/infinitepay.ts` (235 linhas) | Cria link (`POST {base_url}/links`), `payment_check` |
| Edge Functions | `checkout-link`, `infinitepay-webhook`, `settle-provider-payments` | Borda; webhook com nome do provedor **chumbado** |
| Ledger | `public.payments` | Append-only (`payments_immutable`), imutável |
| Eventos/links | `private.payment_events`, `checkout_links`, `checkout_link_mints`, `link_payments`, `provider_checks`, `provider_refunds`, `payment_providers` | Ver 2.4 |

## 2.3 Respostas à auditoria (evidência abreviada)

Caminhos: `DEF` = `supabase/definitions` (corpo final das funções, mantido igual às migrations por `tests/db/definitions.test.ts`); `MIG` = `supabase/migrations`. **O corpo vivo de uma função está em `DEF`, não na migration** (as migrations reescrevem por patch com guarda de md5).

| Pergunta | Resposta | Evidência |
|---|---|---|
| Onde pedidos são criados? | `public.place_order(jsonb)`, `security definer`, concedida a anon e authenticated. Método único `card_online`; sem provedor pronto falha `PROVIDER_REQUIRED` | `DEF/pedidos/functions.sql` L957-1139 [V] |
| Quem calcula o valor final? | O servidor: `quote_cart` lê preço do banco, taxa por zona, desconto por ponto de política. O cliente só pode mandar `expected_total_cents` (divergência = `PRICE_CHANGED`). Invariante `orders_total_adds_up` | `DEF/pedidos/functions.sql` L1084-1090, `tables.sql` L195 [V][T] |
| Quem decide que está pago? | Só `settle_provider_event`; trigger `payments_one_rail` barra pagamento de entrada sem provedor (`PROVIDER_ONLY`). Pagamento é cache do ledger com guarda `PAYMENT_CACHE_MISMATCH` | `DEF/financeiro/functions.sql` L813-1046, L297-309 [V][T] |
| Como tentativas são registradas? | **Não há entidade de tentativa.** Há o link atual (`checkout_links`), o histórico de links (`checkout_link_mints`) e eventos brutos (`payment_events`). Uma criação de link que falha deixa **nenhum registro** | [V] lacuna |
| Como identificar provedores? | Coluna `provider` em todas as tabelas; `private.payment_providers(provider, account, base_url, enabled, priority)` sem chaves; chave de transação canônica `provider_tx_key` | `MIG 20261011005100` L82-124 [V] |
| Como webhooks são processados? | Função faz `verify` do caminho (`^[0-9a-f]{64}$`), chama `record_infinitepay_event`; **a InfinitePay não assina nada**: a única prova é o segredo no caminho, comparado no banco. Idempotência por `(provider, external_id)` | `infinitepay.ts` L135-155; `DEF/financeiro/functions.sql` L717-740 [V][T] |
| Como confirma no provedor? | Job de minuto pergunta ao provedor (`/payment_check`) sobre **todo** evento, mesmo "perfeito"; o banco amarra a resposta (`PROVIDER_MISMATCH`) | `payments.ts` L158-188 [V][T] |
| Perda de resposta? | Timeout/erro deixa o evento sem carimbo, nova tentativa em 1, 5, 15, 30 e 60 min; `success != true` = tentar de novo; só `success=true, paid=false` é negação final; após 6 tentativas, `PROVIDER_UNCONFIRMED` (não é "não pago"). **Lacuna:** criação de link sem chave de idempotência pode gerar link órfão | [V][T] |
| Duplicidade de pagamento? | Índice único `payments_provider_tx_once`; lock no evento e no pedido; um link por pedido e valor; `link_payments` conta webhook e conciliação uma vez | `MIG 20261011005100` L179-180 [V][T] |
| Duplicidade de estorno? | PK `(provider, tx_key)` em `provider_refunds`; claim antes de perguntar ao provedor; mesma chave de idempotência em repetição | `MIG 20261011005500` L25-91 [V][T] |
| Reconciliação? | Automática por minuto: até 20 pedidos, **1 dia** após o hold, **4** perguntas por pedido, só pedidos com slug. A conciliação interna cache × ledger (`reconcile_payments`) é **sob demanda, sem cron** | `payments.ts` L191; `DEF/financeiro` L453, L704 [V][T] |
| Histórico financeiro? | `payments` imutável; **`audit_log` não cobre** `payments`, `payment_events`, `provider_refunds` | [V] |
| Configuração de provedores? | `store_settings.infinitepay_handle` (lacrado: `RECEIVER_SEALED`); chaves nunca em tabela (segredos da Edge Function por nome, ou Vault) | [V][T] |
| Permissões? | `payments`: RLS + `staff_read`; portas financeiras só `service_role`, exceto `checkout_link` (exige poder `orders`) e `place_order`. **O poder `refund` está declarado mas nenhuma função o exige** | `financeiro.ts` L46; grep sem acerto em `DEF` [V] |
| Como módulos opcionais conversam com o núcleo? | Só por pontos de política, pontes e registro | `ARCHITECTURE.md` [V] |
| E se um módulo é desativado? | Portas de escrita recusam `MODULE_UNAVAILABLE`; a venda continua (provado por teste de composição e propriedade gerada) | `tests/compositions/sale.property.test.ts` [T] |
| Invariantes protegidas por teste? | Ver Parte IX | — |

## 2.4 Segurança e limitações observadas

- Segredos: Vault (`pmd_link_secret`, `pmd_dispatch_secret`), com **fallback para `private.secrets`** quando não há Vault (risco menor, relevante em dev) [V]. Sem rotação/versionamento do segredo de webhook; trocar `pmd_link_secret` invalida os webhooks dos links já emitidos (a reconciliação é a rede de segurança, limitada a 1 dia) [H derivado do desenho].
- Rate limit: nenhum específico em `checkout-link` nem em `infinitepay-webhook` (o `edge-gate` cobre só CEP e human-check) [V].
- `card_fee_mode` e `card_surcharge_percent` continuam em settings mas não entram em `quote_cart` (provável legado) [V ausência; H legado].
- **Provado só em PGlite.** Concorrência real, Storage, Realtime, `pg_cron` e superfície anônima sob JWT real só se provam por `npm run test:remote`, que nunca roda no CI e nunca alcança o provedor de pagamento real (CHARTER §4). Para qualquer provedor novo, o provedor real fica "escrito, não provado" até a rodada do integrador.
- `meta.sim.ts` (prova das 14 invariantes contra corrupção, o mais próximo de mutação no repositório) **roda fora do CI** [V].

## 2.5 Documentos defasados (não usar como fonte)

`material/roadmap.html` ainda cita "Pix manual construído" e Asaas; `intent/pmd-integrations/mercadopago-checkout-transparente.md` assume Pix próprio da loja e a coexistência de dois provedores, ambos anteriores a F1.E33 (05/10/2026), quando só sobrou provedor [V][D]. O estudo `infinitepay.md` está congelado ("não é mais atualizado", L354).

---

# PARTE III: Matriz de aderência Appmax × PMD

Não atribuo percentuais de conclusão (sem método objetivo). "Próxima ação" é recomendação; decisões marcadas **[DONO]** dependem do dono.

| Capacidade | Appmax (benchmark) | PMD atual | Evidência | Lacuna | Próxima ação |
|---|---|---|---|---|---|
| Checkout hospedado | AppCheckout no domínio Appmax [F] | Link do provedor (redirect), único caminho | `payments.ts` L123-136 [V] | Nenhuma de modelo; é decisão de produto | Preservar |
| Checkout transparente/embutido | Tokenize + `credit-card` via API [F] | Inexistente. Plano do Mercado Pago só em papel ("Nenhum código foi escrito") | `intent/pmd-integrations/mercadopago-checkout-transparente.md` L3 [V] | Contrato devolve só URL; sem chave de idempotência na criação | Parte V; Incremento 0/1 |
| Links de pagamento | Ilimitados, com vendedores/campanhas [F] | Um link por pedido e valor | `checkout_link` [V] | Sem vendedor/campanha | Fora de escopo agora |
| Cartão, Pix | Sim [F] | Dentro da página do provedor (InfinitePay) | `infinitepay.md` [D] | Controle de parcelas inexistente | Preservar |
| Boleto | Sim [F] | Inexistente; excluído do plano MP | MP plan §5.2 [D] | Relógio de confirmação conflita com hold e janela de 1 dia | Descartar por ora |
| Apple/Google Pay | Apple e Google Pay via Appmax JS [F] | Só o que a página do provedor oferecer | — | Não controlável pelo PMD | Depende do PSP; validar |
| Parcelamento | Até 21x online [F] | Parcelas definidas pelo provedor; não configuráveis | `infinitepay.md` §8.4 [D] | — | Aceitar |
| Cupom | Cupom + intenção de saída [F] | Cupom e promoções implementados | módulo `promocoes` [V][T] | Cupom de intenção de saída não existe | Pedido novo, só se houver demanda |
| Order bump / upsell | Sim [F] | Inexistente e não planejado | grep nos docs [V] | Mexe em UI (D240) e em preço | Descartar por ora |
| Frete | Frete fixo configurável [F] | Entrega por zona de CEP/raio com taxa por zona | módulo `entrega` [V][T] | Sem transportadora/etiqueta | Preservar |
| Cashback | Crédito para próxima compra [F] | Cartão de selos que gera cupom; **cashback foi rejeitado** | decisão autônoma 126 (marcada "não verificada"); `F3 H3` sketch | Passivo contábil | Reabrir decisão 126 só na Fase 3 **[DONO]** |
| Recuperação de vendas | Carrinho, Pix, recusa por WhatsApp [F] | **Proibida**: "no cart recovery, no AI answer" | `PRODUCT.md` L180-181 [V] | Decisão de produto | **[DONO]** |
| WhatsApp | Canal de recuperação [F] | Módulo reativo completo (janela 24 h, regras PARAR/VOLTAR, 7 mensagens/pedido) | módulo `whatsapp` [V][T] | Envio real nunca provado; Meta pendente (prazo 22/11) | Preservar; ver ROADMAP #1-5 |
| Assinaturas | Ciclo de vida completo na API [F] | **Inexistente** (só intenção em HTML antigo) | `material/roadmap.html` L254, L280 [D] | Tudo | Parte V/VI; Fase 3 |
| Split | Percentual/valor, KYC de recebedor [F][C] | **Inexistente e vetado** | `COMMERCIAL.md` L13 [V] | Decisão de negócio | **[DONO]** |
| Afiliados/comissões | Cookies, relatórios, coprodutores [F] | Inexistente | grep [V] | — | Condicionado ao split |
| Estorno | Total/parcial; só total em split [F] | Contrato + porta de banco; **não ligado a nenhuma tela ou função**; InfinitePay não oferece | `payments.ts` L224-254; busca de chamadores [V] | Sem tela (D191 veda); `refund_due_cents` só cresce; reembolso feito não gera linha | Parte VII, itens A3-A5 |
| Chargeback/disputas | Relatórios e acompanhamento [F] | Inexistente | — | Delegável ao PSP | Reorganizar: ingerir evento do PSP, sem fila própria |
| Antifraude | 150+ sinais, decisão do lojista [F] | Rate limit anti-abuso e human-check (Turnstile) no pedido anônimo; sem antifraude de pagamento | `SECURITY.md` L71-78 [V] | Delegado ao PSP | Delegar |
| Conciliação | Relatórios, recebíveis [F] | Reconcilia pedido pago no provedor, 1 dia, 4 tentativas | `provider-reconcile.test.ts` [T] | Sem relatório de divergência periódico | Complementar |
| Recebíveis, antecipação, conta, saque | Conta Max, D+30, antecipação [F][C] | **Fora**: PMD nunca guarda dinheiro | `COMMERCIAL.md` L13 [V] | — | Descartar no core |
| Papéis/multiusuário | Perfis e aprovações [F] | `autoridade`: 11 poderes + `*`, segundo fator em ações sensíveis | `tests/db/aal2-doors.test.ts` [T] | `refund` sem `require_perm` | Corrigir ao ligar reembolso |
| Webhooks de saída/API | 29 eventos; sem HMAC [F] | Webhook de saída é só esboço (F3 I1) | `F3-conformidade.md` L71 [D] | Assinatura, reenvio, persistência | Preservar para Fase 3 |
| Conectores de plataformas | 30 + 6 [F] | Campo `channel` existe; nada cria pedidos | `API.md` L228-230 [V] | Cada conector é produto | Por demanda (regra F3 do PO: "repertório, não fila") |
| Internacional, Tap to Pay, Compra Protegida, AppCall | Sim [F][C] | Fora | — | Operação humana/regulatória | Descartar no core |
| Relatórios | Exportação, comissão, chargeback [F] | `report_payments`, exportação CSV com segundo fator | `finance-page.test.ts` [T] | Sem divergência PSP × ledger | Complementar |

**Leitura da matriz:** o PMD já tem o que a Appmax chama de "base" (checkout, cupom, frete, papéis, WhatsApp reativo, conciliação). Os vazios reais são **assinatura, componentes embutidos, split, estorno ligado e recuperação**. Destes, só os dois primeiros e o estorno cabem sem reabrir decisões do dono.
