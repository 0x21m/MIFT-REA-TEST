# PMD Payments: Partes VII a XI e anexos

Convenções da Parte 1 valem aqui.

---

# PARTE VII: Gap analysis e riscos

Classificação pelo impacto real. **Bloqueante** = risco concreto de dinheiro incorreto ou perdido, exposição de dados, quebra de permissão ou impossibilidade de executar um fluxo essencial **do escopo pretendido**. Não incluí riscos abstratos sem ligação com o código.

## Bloqueantes

| ID | Achado | Impacto real | Evidência |
|---|---|---|---|
| **B1** | A monetização por comissão, o split e qualquer take rate **contradizem decisão vigente do dono**: o PMD nunca entra no fluxo de dinheiro | A frente estratégica de monetização do briefing não pode ser executada sem a decisão ser reaberta; planejar como se estivesse livre produziria trabalho descartável | `COMMERCIAL.md` L13 [V] |
| **B2** | A **entrada de webhook** é amarrada à InfinitePay: função `infinitepay-webhook` com o nome chumbado, porta SQL `record_infinitepay_event` e segredo `infinitepay_webhook_secret()` | Um segundo provedor não consegue entregar eventos; o `INSTALL.md` L1046 admite que a versão não traz a função de webhook de outro provedor | `infinitepay-webhook/index.ts`; `DEF/financeiro/functions.sql` L717-740 [V] |
| **B3** | **Criação de cobrança sem chave de idempotência e sem registro de tentativa.** `OperationInput.key` existe só para `cancel`/`refund`; `outbound.send` não a recebe. Uma criação que falha ou perde a resposta não deixa registro | Com um provedor que cobra na criação (Mercado Pago Orders exige `X-Idempotency-Key`), uma retentativa pode **cobrar duas vezes**; mesmo hoje, a perda da resposta gera **link órfão** (só é recusado se o pedido já tiver outro slug) | `integration.ts` L63; `payments.ts` L130; auditoria §8 [V]; nenhum teste cobre "primeira emissão perdida" [H] |

## Altos

| ID | Achado | Impacto real | Evidência |
|---|---|---|---|
| A1 | `Answer` só carrega `{id, ref}` e `id` é sempre uma URL https; `Backend.checkoutLink` devolve `string`; a tela abre uma URL | Impede componente embutido, Pix com QR/copia-e-cola e autenticação adicional | `integration.ts` L49; `payments.ts` L130-135; `src/backend/index.ts` L33 [V] |
| A2 | **Reembolso não está ligado a nada**: nenhuma Edge Function, tela ou papel chama `refundAtProvider`/`cancelAtProvider`; o poder `refund` está declarado mas nenhuma função o exige (`require_perm('refund')` só em migrations históricas); `refund_due_cents` **só cresce**; um reembolso `done` **não gera linha** no ledger | A loja vê "devido de volta" que o sistema nunca baixa; a InfinitePay não oferece reembolso por API (`NOT_SUPPORTED`), então hoje é devolução manual fora do sistema | `payments.ts` L224-254; grep de chamadores [V] |
| A3 | **ACT-037:** corrida expiração × pagamento tardio; o teste está marcado `it.fails` até o dono decidir | Pagamento confirmado pelo provedor para pedido já expirado vira dinheiro "devido de volta" em vez de ser aceito | `tests/db/expire-vs-reconcile.test.ts` (2 ocorrências de `it.fails`) [V] |
| A4 | Não há entidade de assinatura; um webhook de renovação chega **sem** `order_nsu`/link de um pedido existente e `settle` exige pedido pelo número e slug em `checkout_link_mints` | Recorrência não funciona sem criar o pedido de ciclo antes ou ao receber o evento | auditoria §16 [V][H] |
| A5 | Pix assíncrono e boleto conflitam com `hold_minutes` (≤ 24 h se agendado), com `expire_orders` e com a janela de reconciliação de 1 dia | Pedido expira e o dinheiro chega depois: cai em `refund_due` | `DEF/pedidos` expire_orders; `orders_to_reconcile` L453 [V][H] |
| A6 | O ledger não tem estado `authorized`; `payments_method_check` aceita só `pix\|cash\|card` | Autorizar/capturar e boleto exigem migration e cuidado: liquidar só na captura | `DEF/financeiro/tables.sql` [V] |
| A7 | Conflitos de **produto** que travam o Mercado Pago como segundo provedor: "trilho único", pagamento final, "PMD não registra reembolso" (D191), teste que proíbe a string `mercadopago` | Sem decisão do dono, o primeiro consumidor real do contrato não entra | `PRODUCT.md` §5; `single-card-rail.test.ts` L40-46 [V] |

## Moderados

| ID | Achado | Evidência |
|---|---|---|
| M1 | `audit_log` **não cobre** `payments`, `payment_events`, `provider_refunds`, `checkout_links` | auditoria §11 [V] |
| M2 | Sem rate limit específico em `checkout-link` nem em `infinitepay-webhook` (o `edge-gate` cobre CEP e human-check) | auditoria §13 [V] |
| M3 | `cron_pending` exige provedor pronto: com **todos** os provedores desligados o job não dispara, ao contrário do comentário do código | `payments.ts` L155; `after-migrations.sql` L253 [V] |
| M4 | Segredo de webhook global, sem rotação nem versionamento; fallback `private.secrets` quando não há Vault | `DEF/autoridade/functions.sql` L91-106 [V] |
| M5 | Conciliação interna cache × ledger (`reconcile_payments`) é sob demanda, sem cron; não há relatório de divergência PSP × ledger | `DEF/financeiro` L704 [V] |
| M6 | `meta.sim.ts` (prova das invariantes contra corrupção) roda fora do CI; `test:remote` nunca roda no CI e nunca alcança provedor real | `ARCHITECTURE.md` [V][D] |
| M7 | `card_fee_mode` e `card_surcharge_percent` ainda em settings sem efeito no cálculo | `DEF/casca/functions.sql` L261-262 [V ausência; H legado] |
| M8 | Divergência de fase sobre o Mercado Pago: "uma das primeiras novas etapas da Fase 2" (`F2-escala.md` L53-56) × "fica aqui" na Fase 3 (`F3-conformidade.md` L67, X0) | [V] |
| M9 | `paid=false` com `success=true` é negação final; se um Pix pendente responder assim de forma transitória, o evento daquele `transaction_nsu` fica negado e só a conciliação (limitada) pode reencontrá-lo | auditoria §8 [H] |

## Baixos / informativos

Documentos defasados (`material/roadmap.html`, `mercadopago-checkout-transparente.md` §3); contagem de portas anônimas 22 (teste) × 23 (`INSTALL.md`); o estudo `infinitepay.md` congelado; arquivos de estágios F2.E3 a E9 removidos; `PMD/relatorios/...` (lista do dono, `PMD-ACTION-BACKLOG.md`) fora do repositório e portanto **não lidos**.

---

# PARTE VIII: Roadmap de implementação

Princípios do roadmap: incrementos verticais; nada reescreve o que funciona; **a primeira entrega é invisível ao usuário** (compatível com a Fase 2); cada estágio é uma branch com critérios verificáveis escritos antes (CHARTER §3); dinheiro e migration exigem revisão cega (Opus só com motivo: dinheiro/arquitetura); credenciais são digitadas pelo dono, nunca lidas pelo agente.

## PAY-0: Decisões do dono (sem código)

| ID | Pergunta | Recomendação | Bloqueia |
|---|---|---|---|
| D1 | Reabrir `COMMERCIAL.md` L13 (comissão/split)? | **Não reabrir agora.** Adotar o Modelo 1; reavaliar com demanda e parecer jurídico | PAY-8, split, afiliados |
| D2 | Mercado Pago e InfinitePay coexistem na mesma instalação? Emendar `single-card-rail` e "um só caminho"? | Sim, uma conta ativa por loja escolhida na instalação (o plano do MP já recomenda manter as duas) | PAY-3 |
| D3 | Reabrir D191 (reembolso e devolução no sistema)? | Ligar reembolso **no provedor** com poder `refund` e segundo fator, sem pagamento parcial | PAY-2 (parte), PAY-3 fase 4 |
| D4 | Qual modelo de recorrência (A/B/C) e para quais negócios? | Híbrido (C), começando por academia/clínica | PAY-5 |
| D5 | Recuperação por WhatsApp contra `PRODUCT.md` L180? | Só após Meta/Tech Provider e WA2; decisão nova | PAY-7 |
| D6 | Reabrir a decisão 126 (cashback)? | Só na Fase 3 (H3) | PAY-7 |
| D7 | Em que fase entra o Mercado Pago (Fase 2 nova etapa × Fase 3)? | Fase 2, depois do portão F2.E12, como o próprio dono registrou em 12/10 | PAY-3 |
| D8 | ACT-037: pagamento confirmado após expirar é aceito ou devolvido? | **Aceitar** se o provedor confirma e o pedido ainda é atendível; senão devolver | PAY-4 |

## PAY-1: Contrato evoluído e invisível (Incremento 0/1)

- **Objetivo:** abrir o contrato para múltiplos modelos sem mudar nenhum comportamento visível.
- **Entrega:** `start` + chave de idempotência + `Next` tipada; `payment_attempts`; porta de webhook genérica; provedor simulado com três formas de `Next`.
- **Dependências:** nenhuma de dono além do congelamento da Fase 2 (não há tela, fluxo ou palavra novos).
- **Módulos:** `financeiro` (dono do código e das tabelas).
- **Arquivos prováveis:** `supabase/functions/_shared/integration.ts`, `payments.ts`, nova função de borda de webhook por provedor, `tests/integrations/simulated.ts`, `check-adapter.ts`, `contract.test.ts`, `supabase/definitions/financeiro/*`, `owners.csv`, `src/pmd/contracts/financeiro.ts`, `API.md`.
- **Migrações previstas:** uma por fatia: `private.payment_attempts` (com linha em `owners.csv`, classe `financial`, retenção declarada); porta `record_provider_event`.
- **Integrações externas:** nenhuma (simulado).
- **Aceite e testes:** ver Parte XI (critérios C1 a C8).
- **Complexidade:** média. **Risco técnico:** médio (toca dinheiro e migration; guarda de md5 obriga ler `pg_get_functiondef` antes de remendar).
- **Reversão:** `outbound.send` permanece; `start` é opcional por adaptador; tabela nova é aditiva; remover o uso volta ao comportamento atual.
- **Avançar quando:** suíte de contrato e testes de dinheiro verdes no CI nos 4 shards; revisão cega `Verdict: met`; nenhum arquivo de `src/screens`/`src/v2` alterado.

## PAY-2: Higiene financeira (corrige achados existentes)

- **Objetivo:** fechar os pontos de dinheiro e segurança encontrados, que valem para qualquer provedor.
- **Entrega:** `audit_log` cobrindo `payments`, `payment_events`, `provider_refunds`; rate limit em `checkout-link` e no webhook; cron também com todos os provedores desligados; relatório de divergência PSP × ledger; **se D3**: `require_perm('refund')`, reembolso `done` baixa `refund_due_cents` e gera linha no ledger.
- **Dependências:** D3 (apenas a parte de reembolso).
- **Arquivos:** `DEF/financeiro/*`, `DEF/auditoria/*`, `after-migrations.sql`, `edge-gate.ts`, `src/pmd/modules/financeiro.ts`.
- **Migrações:** sim, com guarda de md5. **Complexidade:** média. **Risco:** médio-alto na parte de reembolso (dinheiro).
- **Reversão:** migrations aditivas; reembolso desligável pelo poder.
- **Avançar quando:** testes de `payment-final`, `provider-refund` e novos verdes; relatório de divergência vazio no ensaio.

## PAY-3: Mercado Pago como primeiro consumidor

- **Objetivo:** checkout transparente (cartão por Brick e Pix) e reembolso na API.
- **Entrega, em fases do plano existente:** (1) POC no sandbox; (2) adaptador `start`/`check`/`refund` com `X-Idempotency-Key`; (3) liberação por loja; (4) reembolso e contestação.
- **Dependências:** PAY-1, D2, D7; conta de teste; **credenciais digitadas pelo dono**; gasto real só com autorização expressa (CHARTER §9).
- **Pontos técnicos a resolver (lacunas do próprio plano):** modelo da `x-signature` no Brasil, Pix dentro de Orders, lista de status, campos do `onSubmit` do Brick, corpo de `/v1/orders`, captura parcial (conflito de doc).
- **Arquivos:** novo `_shared/mercadopago.ts` (paralelo, não misturar com `infinitepay.ts`), `provider_scan.py`, `paymentAdapters()`, fixture de contrato, `tests/unit/single-card-rail.test.ts` (emenda), `INSTALL.md`.
- **Migrações:** poucas (`provider` aceitar `mercadopago`; allowlist de fatos do payload).
- **Complexidade:** alta. **Risco:** alto (primeiro provedor real com componente no navegador; cartão nunca passa pelo backend).
- **Reversão:** desligar o provedor na instalação; os links/eventos seguem o provedor gravado.
- **Avançar quando:** `checkAdapter` verde, rodada `test:remote` + walk no sandbox, cartão recusado/cancelado testado pelo dono em seu aparelho.

## PAY-4: Pix pendente, expiração e ACT-037

- **Entrega:** alinhar `expire_orders` ao `expires_at` da tentativa; decisão D8 aplicada; teste `it.fails` convertido.
- **Dependências:** PAY-1, D8. **Migração:** sim (dinheiro). **Complexidade:** média. **Risco:** alto (decide dinheiro de pedido expirado).
- **Reversão:** voltar à função anterior pelo corpo vivo guardado (md5).

## PAY-5: Billing (módulo opcional)

- **Objetivo:** plano, assinatura e ciclo; cada ciclo gera um pedido que passa pelo mesmo `settle`.
- **Dependências:** PAY-1, PAY-3 ou PAY-6, D4.
- **Módulo novo:** `billing` (manifesto, portas tipadas, regra de ausência, eraser). **Tabelas:** planos, assinaturas, ciclos (com as quatro perguntas de risco do CHARTER §2 respondidas: segredo, dado pessoal por titular, crescimento anônimo, retenção).
- **Casos:** academia, clínica, serviço, B2B recorrente. **Complexidade:** alta. **Risco:** alto (cobrança recorrente: duplicidade por ciclo).
- **Reversão:** módulo removível; remover nunca apaga dado financeiro (D241).
- **Avançar quando:** propriedade gerada "um ciclo, uma cobrança", testes de data (fim de mês, fuso), cancelamento durante tentativa.

## PAY-6: Asaas (hospedado, assinatura, Pix Automático)

- **Entrega:** adaptador usando **link/checkout hospedado** (para não ver cartão), assinatura nativa e Pix Automático; webhook com token estático + reconsulta; chave própria + consulta antes de repetir (sem idempotência nativa).
- **Dependências:** PAY-1, PAY-5, elegibilidade do Pix Automático (CNPJ ≥ 6 meses, PJ). **Complexidade:** média. **Risco:** médio-alto (split em assinatura bloqueia por divergência; só relevante se D1 mudar).

## PAY-7: Recuperação e conversão (condicionado)

- **Entrega:** gatilhos determinísticos (Pix gerado e não pago, assinatura vencida) reaproveitando o módulo `whatsapp` (janela de 24 h, consentimento, limite de frequência) e `avisos`; IA só sugere texto.
- **Dependências:** D5, Meta (método de pagamento, Tech Provider até 22/11, ROADMAP #1-5), WA2. **Custo:** por mensagem Meta, não "R$ 1,99 por disparo". **Complexidade:** média. **Risco:** médio (consentimento e custo).
- Order bump/upsell/cross-sell: **fora** (mexem em UI e preço; D240).

## PAY-8: Monetização (condicionado a D1)

- **Modelo 1 (padrão):** cobrança do software fora do fluxo (assinatura/manutenção); sem código de dinheiro no core.
- **Modelo 2 (só com D1 reaberta + parecer jurídico):** módulo `split` + `fee_assessments`, derivados do ledger, PSP executa o split.
- **Modelo 3:** não planejar.

## PAY-9 e PAY-10

PAY-9 Carteiras (Apple/Google Pay): depende do PSP escolhido; verificar o que fica a cargo do integrador (arquivo de verificação de domínio por loja, validação de comerciante, renovação de certificados). PAY-10 Conectores de saída (Shopify/VTEX/outros): **por demanda real**, cada um é um produto com homologação própria.

---

# PARTE IX: Plano de testes e homologação

Relacionado ao que já existe. Princípios do projeto: teste direto da regra; **geradores e defeito plantado só para dinheiro, dados pessoais, permissões e segurança**; um teste vale quando o resultado muda uma decisão.

| Área | O que provar | Mecanismo existente a estender |
|---|---|---|
| Contratos de adaptador | `start` com mesma chave devolve a mesma `next` e move dinheiro uma vez; adaptador que ignora a chave é reprovado; `capabilities` coerentes com as operações | `tests/integrations/check-adapter.ts` + `simulated.ts` + `contract.test.ts` |
| Operações financeiras | Valor liquidado = menor entre o do provedor e o devido; nunca `paid_amount`; pago é final | `provider-events.test.ts`, `payment-final.test.ts`, geração de 160 vendas em `financeiro-states.test.ts` |
| Idempotência | Criação, webhook, refund, ciclo de assinatura | `order-idempotency`, `provider-tx-unique`, `contract.test.ts` L228-296 |
| Concorrência | Duas tentativas simultâneas; refund e pagamento tardio | `tests/db/concurrency/*` + `tests/remote/suites/concurrency.mjs` (**PGlite roda uma consulta por vez; concorrência real só no remoto**) |
| Falhas e timeouts | Desconhecido ≠ recusa; criação perdida não duplica; reconsulta por chave | `provider-queue`, `infinitepay.test.ts`; **teste novo** para "primeira emissão perdida" |
| Duplicidade/fora de ordem | Evento repetido; evento antes do pedido; renovação sem pedido | `provider-events`; novos testes para billing |
| Reconciliação | Pedido pago sem webhook; relatório de divergência; janela maior para métodos lentos | `provider-reconcile`, `expire-vs-reconcile` (converter `it.fails`) |
| Assinaturas | Um ciclo, uma cobrança; fim de mês; fuso; pausa/reativa; cancelamento durante tentativa; upgrade com pró-rata | propriedade gerada nova (como `sale.property.test.ts`) com defeito plantado |
| Split (se D1) | Soma das partes + taxas = líquido; estorno parcial/total por provedor; regra incompatível é recusada | verificador gerado + defeito plantado |
| Reversões | Reembolso baixa `refund_due_cents`; gera linha; `REFUND_EXCEEDS_RECEIVED` | `block7c-refund-due`, `payment-final` |
| Segurança | Segredo nunca no navegador/log; HMAC do webhook antes do parse; PAN/CVV nunca persistidos; rate limit | `tests/db/security/*`, `provider-scan`, `baseline-secrets`; **teste novo** de rate limit em `checkout-link` e webhook |
| RLS e permissões | `refund` exige poder + segundo fator; portas financeiras só `service_role` | `aal2-doors`, `financeiro-states` ("no door open to anonymous") |
| Módulo ausente | Sem `billing`, a venda continua; remover não apaga financeiro | `tests/compositions/sale.property.test.ts`, `conformance.test.ts` |
| Compatibilidade histórica | Link emitido antes do upgrade continua sendo liquidado; evento pendente no vocabulário antigo é lido | `upgrade-rehearsal.test.ts`, `old-card-link-payment.test.ts`; **estender** com eventos pendentes |
| Sandbox dos provedores | Fluxo completo por provedor, com cartões de teste (Mercado Pago: contas de teste, até 15; Bricks não aceita conta de teste) | `test:remote` (alvo manual, projeto de teste do dono); **nunca produção** |
| Jornadas completas | Cliente, colega com poucos poderes, lojista; cartão recusado/cancelado | Playwright do portão F2.E12 + teste do dono no próprio aparelho |
| Mutação das invariantes | `meta.sim.ts` hoje fora do CI | Propor rodá-lo nos estágios que tocam dinheiro |

**Lacuna que não se fecha por teste:** o provedor real só é provado pela rodada remota do integrador; até lá, "escrito mas não provado" (`ARCHITECTURE.md` L688-689).

---

# PARTE X: Plano comercial e operacional

**Premissa:** `COMMERCIAL.md`: software vendido por instalação; o cliente é dono da instalação, dos dados e das contas de todos os provedores; onde o provedor exige integrador, a empresa do PMD se cadastra como desenvolvedor de software **sem guardar credencial nem dado do cliente**. Os tetos de custo por loja são "go/no-go" para cada integração.

## 10.1 Modelos de cobrança (os nove do briefing)

| # | Modelo | Compatível com `COMMERCIAL.md` L13? | Observação |
|---|---|---|---|
| 1 | Taxa fixa por transação | Não, se arrecadada pelo PMD no fluxo | Receita ligada a volume |
| 2 | Percentual sobre a transação | Não (take rate) | Idem |
| 3 | Percentual com mínimo | Não | Idem |
| 4 | Taxa por pedido concluído | Não, se via fluxo; sim se faturada por fora | Medição no ledger, cobrança fora |
| 5 | Assinatura pelo uso do PMD | **Sim** | É o modelo vigente (manutenção/licença) |
| 6 | Híbrido assinatura + taxa | Parcial (a parte "taxa" depende de D1) | — |
| 7 | Split executado pelo PSP | Não | Depende de recebedor habilitado e parecer jurídico |
| 8 | Cobrança independente da tarifa do PMD | **Sim** | O lojista paga o PSP à parte |
| 9 | Receita compartilhada com parceiro financeiro | Depende de contrato | Hipótese; não verificada em fonte oficial |

## 10.2 Destino do dinheiro (perguntas obrigatórias)

| Pergunta | Modelo 1: direto ao lojista, PMD cobra por fora | Modelo 2: PSP divide entre lojista e PMD | Modelo 3: plataforma centralizada |
|---|---|---|---|
| O comprador paga a quem? | Ao lojista (conta dele no PSP) | Ao lojista, com a fatia do PMD separada pelo PSP | À plataforma |
| Qual conta recebe primeiro? | Conta do lojista | Conta do emissor/lojista; o PSP reparte | Conta da plataforma |
| Quem mantém os recursos? | O PSP do lojista | O PSP | A plataforma/IP parceira |
| A taxa do PSP sai de quem? | Do lojista | Do emissor; varia por PSP (ex.: Pagar.me: o recebedor principal arca gateway/antifraude) | Da plataforma |
| O PMD recebe comissão diretamente? | Não | Sim, via split | Sim |
| Há repasse posterior? | Não | Não, o PSP repassa | Sim |
| Como ocorre estorno? | Pelo PSP, contra o lojista | Proporcional entre as partes (MP, Iugu); parcial exige tratamento próprio (Asaas); só total em Appmax com split | Pela plataforma |
| Quem suporta o chargeback? | O lojista | Depende do PSP (um recebedor assume `liable`) | A plataforma |
| Comissão após venda cancelada? | n/a | **Regra de negócio a definir** (reverter ou reter) | idem |
| Recebedor sem saldo? | n/a | Reembolso depende de saldo do vendedor (MP) | idem |
| Conciliação do lojista? | Extrato do PSP × ledger do PMD | Extrato + alocação derivada | Relatório da plataforma |
| Recomendação | **Adotar** | Só se D1 reabrir + parecer jurídico | **Não recomendado** sem base jurídica, parceiro habilitado e necessidade de negócio |

## 10.3 Simulações parametrizadas

**Todos os números abaixo são hipotéticos e arbitrários, escolhidos para ilustrar a mecânica. Não são tarifas reais de nenhum parceiro nem projeção de receita.** Parâmetros: taxa de cartão do PSP 4,00% + R$ 0,50; Pix 1,00%; comissão hipotética do PMD no Modelo 2: 1,00% do bruto; antecipação 2,00% do valor antecipado; mensagem paga de recuperação R$ 0,35; taxa de chargeback R$ 15,00.

Cadeia: **bruto → taxas do PSP → comissão do PMD → outros descontos → recebível líquido → liquidado → repasse.** "Liquidado/repasse" depende do prazo contratual do PSP (não calculado aqui).

| Caso | Bruto | Taxas PSP | Comissão PMD (M2) | Outros | Recebível líquido | Observação |
|---|---:|---:|---:|---:|---:|---|
| Venda única, cartão à vista | 100,00 | 4,50 | 1,00 | 0 | **94,50** | Em M1 a comissão é 0 e o líquido seria 95,50 |
| Parcelada 3x (R$ 300), sem antecipar | 300,00 | 12,50 | 3,00 | 0 | **284,50** | Recebe em 3 parcelas no prazo do PSP |
| Parcelada 3x, antecipada | 300,00 | 12,50 | 3,00 | 6,00 (antecipação) | **278,50** | Custo financeiro explícito |
| Assinatura mensal R$ 99, Pix | 99,00 | 0,99 | 0,99 | 0 | **97,02** | Por ciclo |
| Venda com comissão de afiliado de 10% | 200,00 | 8,50 | 2,00 | 20,00 (afiliado) | **169,50** | Comissão contábil do software ≠ split do PSP ≠ repasse posterior |
| Estorno total da venda de R$ 100 | 100,00 devolvidos | 4,50 (hipótese: não devolvida) | 1,00 (política: revertida ou não) | 0 | **-4,50** para o lojista (-5,50 se a comissão não for revertida) | Quem arca com a taxa do PSP precisa estar escrito |
| Chargeback de R$ 100 | 100,00 debitados | 4,50 | 1,00 (revertida) | 15,00 (taxa de chargeback) | **-19,50** sobre os 94,50 originalmente recebidos | Sem contar custo do produto |
| Venda recuperada por 2 mensagens | 100,00 | 4,50 | 1,00 | 0,70 (mensagens) | **93,80** | Só se a decisão D5 permitir recuperação |

Contas conferidas: `100 − 4,50 − 1,00 = 94,50`; `300 − (4% de 300 + 0,50 = 12,50) − 3,00 = 284,50`; `284,50 − 6,00 = 278,50`; `99 − 0,99 − 0,99 = 97,02`; `200 − 8,50 − 20 − 2 = 169,50`; `94,50 − 100 − 15 + 1,00 = −19,50`; `94,50 − 0,70 = 93,80`.

## 10.4 Requisitos de onboarding e habilitações externas (resumo)

| Provedor | Requisitos conhecidos [F][C] |
|---|---|
| InfinitePay | Conta e InfiniteTag do lojista |
| Mercado Pago | Conta de vendedor; OAuth por vendedor só se houver split; Apple Pay e 1:N por contato comercial |
| Asaas | Pix Automático: PJ, CNPJ ≥ 6 meses, sem restrição Pix; subcontas só PJ; BaaS/white label por liberação do gerente |
| Pagar.me | Split só para cliente "PSP" (contrato com a Stone) |
| PagBank | Aplicação aprovada para produção |
| Efí | PJ para Pix Automático; subcontas só via parceria |
| Iugu | Marketplace, Pix Automático e captura tardia dependem de habilitação; KYC das subcontas |
| Stripe | Pix exige 60 dias processando; Connect no Brasil não verificado |
| Appmax | CNPJ ativo e revisão técnica para app; split por homologação V4 |
| Shopify | Programa de parceiros de pagamento, aprovação a critério da Shopify e contrato de revenue share |
| VTEX | Homologação pelo Payment Provider Test Suite |

## 10.5 Custos, suporte e operação

Custos operacionais variáveis: mensagens Meta (a partir de 01/10/2026, serviço acima de 1.000/mês cobrado; sem método de pagamento nada é entregue, ROADMAP #1); Edge Functions e cron (Free: 500 mil invocações, job por minuto ≈ 44 mil/mês); taxas do PSP pagas pelo lojista. Suporte: quem opera as integrações é a **pergunta aberta nº 9 do ROADMAP**; cada conector precisa de mantenedor nomeado. Sem projeções de faturamento.

## 10.6 Matriz regulatória (conceitual, **não é parecer jurídico**)

| Atividade | O que costuma significar | Quando o PMD entraria | Exige consulta especializada? |
|---|---|---|---|
| Software de gestão | Sistema do lojista que usa PSP de terceiro | **Hoje** (Modelo 1) | Baixa, LGPD e contratos |
| Gateway | Camada técnica que encaminha transações | Se o PMD intermediasse credenciais de vários lojistas | Sim |
| Orquestração | Escolha de PSP por transação | Só dentro da instalação do lojista (cada um com seus PSPs) | Sim se centralizada |
| Subcredenciamento | Intermediar a liquidação perante o credenciador | Não no escopo recomendado | **Sim** |
| Marketplace / facilitador | Plataforma que reparte pagamentos entre vendedores | Somente se o lojista for um marketplace | **Sim** |
| Split operado por parceiro | O PSP divide, a plataforma configura | Modelo 2 | **Sim** (fluxo de fundos e contratante) |
| Conta de pagamento | Manter saldo de terceiros | Não | **Sim** (instituição de pagamento) |
| Antecipação de recebíveis | Cessão e registro de recebíveis | Não | **Sim** |
| Correspondente bancário | Encaminhar propostas | Não | **Sim** |

Fontes secundárias (nenhum texto normativo foi lido diretamente neste ambiente): Res. BCB 150/2021 (alterada pela 522/2025), Res. BCB 80/2021 (alteradas pelas 494 e 495 de 2025: autorização prévia, capital mínimo), Res. CMN 4.734 e Res. BCB 264/2022 (antecipação), Res. CMN 4.935/2021 (correspondente), **Res. BCB 402/2024** (Pix Automático; go-live 16/06/2025), Res. CD/ANPD 15/2024 (incidente em 3 dias úteis). Não encontrei definição normativa de "facilitador", de gateway ou de orquestração; fontes de mercado divergem sobre marketplace com split. **Itens para especialista:** (1) enquadramento do PMD; (2) fluxo de fundos e contratante do lojista no split; (3) antecipação; (4) eventual autorização como instituição de pagamento; (5) uso de correspondente; (6) Pix Automático como recebedor/iniciador; (7) contratos com Shopify/VTEX; (8) LGPD: papéis, DPA, transferência internacional.

## 10.7 Condições para um eventual produto financeiro independente

Só considerar um serviço separado (Alternativa C) se: (a) houver demanda comprovada de vários lojistas pelo mesmo serviço central; (b) o dono reabrir `COMMERCIAL.md` L13 por decisão registrada; (c) existir parceiro financeiro habilitado e parecer jurídico; (d) houver operação para risco, conciliação, disputas e suporte; (e) uma métrica medida (não expectativa de escala) justificar a infraestrutura.

---

# PARTE XI: Plano de ação imediato

**O que já está pronto.** Núcleo de dinheiro de porta única; contrato `ProviderAdapter` com `check`/`cancel`/`refund` opcionais e `NOT_SUPPORTED`; provedor simulado e suíte de contrato; livro-caixa imutável; reconciliação por minuto; módulo `financeiro` fixo; modelo de módulos e de instalação; WhatsApp reativo; cupons/promoções; entrega por zona.

**O que precisa ser validado.**
1. Rodar a suíte de testes do PMD e o CI (**nada foi executado nesta auditoria**).
2. Reler as páginas oficiais dos provedores com acesso direto (as células NV e `*` da Parte IV).
3. Confirmar com a InfinitePay: `payment_check` ecoa `order_nsu`/`transaction_nsu`? o link expõe o caminho do webhook? como trata Pix pendente?
4. O que Mercado Pago aplica ao Brasil: Pix Automático, Google Pay, Apple Pay, 1:N.
5. Se Deno suporta mTLS de saída (Efí).
6. O parecer jurídico sobre os itens da seção 10.6.

**O que precisa ser definido (dono).** D1 a D8 (PAY-0). A mais determinante é **D1**, porque decide se a frente de monetização existe.

**O que deve ser construído primeiro.** PAY-1 (contrato evoluído, invisível), seguido de PAY-2 (higiene financeira).

**O que pode esperar.** Billing (PAY-5) até D4; Asaas (PAY-6); recuperação (PAY-7); monetização (PAY-8); carteiras; conectores de saída; tudo que dependa de Meta, contratos ou decisões do dono.

## Primeira etapa de desenvolvimento proposta: PAY-1

**Escopo delimitado.** Só `financeiro` e seus testes. **Fora do escopo:** qualquer tela, fluxo ou palavra; qualquer provedor real; billing; split.

**Critérios de aceite, cada um com um verificador que outra pessoa pode reexecutar** (nenhum será enfraquecido para passar):

| # | Critério | Verificador |
|---|---|---|
| C1 | `start` com a mesma chave duas vezes devolve a mesma `next` e o provedor simulado registra **uma** cobrança | `contract.test.ts` + `simulated.ts` |
| C2 | O provedor simulado emite as três formas (`redirect`, `pix`, `component`) e passa em `checkAdapter` | `check-adapter.ts` |
| C3 | Um adaptador plantado que ignora a chave **falha** | defeito plantado em `contract.test.ts` |
| C4 | O comportamento da InfinitePay não muda: os testes existentes continuam verdes **sem edição** | `provider-events`, `checkout-link`, `unit/infinitepay`, `old-card-link-payment` |
| C5 | Webhook genérico: evento forjado de um provedor não move nada; o segredo de um provedor não grava evento de outro | novo teste ao lado de `provider-events.test.ts` |
| C6 | Primeira emissão perdida: não há segunda cobrança e a tentativa fica `unknown` até reconsulta | novo teste |
| C7 | Histórico preservado: link e evento pendente emitidos antes continuam liquidando | `upgrade-rehearsal.test.ts` estendido |
| C8 | Nada de interface mudou | `git diff --stat` sem `src/screens` nem `src/v2`; exposure gate; `single-card-rail` intacto |

**Ritual do projeto.** Branch de estágio; critérios no arquivo do estágio antes de construir; `pmd-banco` (Opus, motivo: dinheiro/arquitetura) para a migration; teste da parte tocada via `scripts/run.py`; CI verde nos 4 shards; **revisão cega** `Verdict: met`; `node scripts/land.mjs`.

---

# Anexo A: Alternativas arquiteturais (briefing, etapa 10)

| Critério | A. Evolução modular interna | B. Pacote compartilhado | C. Serviço independente |
|---|---|---|---|
| Complexidade | Baixa-média | Média | Alta |
| Reutilização | Alta (usa o que existe) | Alta entre instalações | Alta |
| Custo | Baixo (mesmo Supabase) | Médio | Alto (infra e operação próprias) |
| Segurança | Boa (porta única, isolamento por instalação) | Boa | Concentra credenciais de todos os lojistas |
| Consistência | Mesma transação do banco da loja | Idem | Consistência eventual entre sistemas |
| Acoplamento | Dentro das fronteiras do módulo | Contrato do pacote | API entre serviços |
| Replicabilidade | Total (recipe por instalação) | Boa (dependência versionada) | Cria dependência central |
| Manutenção | Uma base | Duas | Duas, mais infra |
| Testabilidade | Suíte e harness existentes | Boa | Exige ambientes novos |
| Dependência de terceiros | Só PSPs | PSPs | PSPs + operação própria |
| Risco de migração | Baixo (aditivo, com expand→migrate→contract) | Médio | Alto |

**Recomendação: A.** Nenhuma evidência concreta de que B ou C resolva melhor uma restrição relevante. C contradiz `COMMERCIAL.md` ("not a platform"; dados não cruzam instalações) e exigiria a decisão D1.

# Anexo B: Aderência por tipo de negócio

| Negócio | Cenário financeiro | Atendido pelas mesmas capacidades? | Exige |
|---|---|---|---|
| Restaurante e delivery | Pagamento imediato, Pix, cartão, cancelamento e estorno | **Sim, hoje** (primeiro cliente do PMD) | Estorno ligado (PAY-2) |
| Loja física | Links, QR Code, conciliação, pagamento presencial | Parcial (link/QR do provedor; sem maquininha própria) | Presencial é produto do PSP |
| E-commerce | Checkout transparente, ofertas, recuperação | Parcial | PAY-3; order bump fora; recuperação depende de D5 |
| Profissional liberal | Cobranças pontuais e links | Sim | — |
| Clínica e agenda | Sinal, pagamento antecipado, cobrança por serviço | Parcial (agenda existe; pagar para reservar não verificado) | Pagamento ligado ao `claim_slot` |
| Academia | Mensalidade e renovação | **Não** | PAY-5 + PAY-6 |
| Software por assinatura | Billing e controle de acesso | **Não** | PAY-5 |
| Infoproduto | Checkout, recorrência, afiliados, liberação de conteúdo | **Não** | Fora do público atual |
| Marketplace | Comissão, recebedores, split | **Não** | D1 |
| Serviço B2B | Faturas, vencimentos, recorrência contratual | **Não** | PAY-5 |

As lacunas se resolvem com **uma** abstração de domínio (contrato + ciclo + cobrança), não com um módulo por nicho.

# Anexo C: Consolidação do backlog

**Fontes encontradas.** (1) O backlog preliminar de 8 etapas deste repositório (`docs/appmax-backlog.md`); (2) o plano de integrações antigo do PMD, recuperado da tag `pre-saneamento-2026-09-30` (`intent/pmd-integrations/roadmap.md`, `catalog.md`, `backlog-review.md`, `contract.md`), que previa **Asaas como primeiro PSP candidato** (I2, `PaymentPort`) e dizia "Split / commissions: business model and legal question before technical"; (3) `intent/pmd-integrations/mercadopago-checkout-transparente.md` e `infinitepay.md`. **O `pmd-core` não tem backlog próprio de pagamentos e não menciona "Appmax"** (zero ocorrências). Não acessíveis: `PMD/relatorios/F2.E12/auditoria-bos/PMD-ACTION-BACKLOG.md` e `lista-do-dono.md` (fora do repositório). O roadmap antigo está marcado como rascunho, superado onde discorda de documentos posteriores.

| Item | Decisão | Justificativa |
|---|---|---|
| `infinitepay.md` e adaptador | **Preservar** | Implementado; as lições (campainha, valor devido, sem assinatura) viram requisitos transversais |
| Contrato M10 | **Preservar e estender** | Cobre E3-1; estender por capacidades |
| Plano do Mercado Pago | **Complementar** | Único plano real de segundo PSP; reescrever pós-F1.E33 com critérios de aceite; resolver as 5 perguntas do dono |
| Reembolso no provedor | **Complementar** | Falta ligar (D3) e registrar no ledger |
| WhatsApp (I0, I0b, I0c, WA1 a WA4) | **Preservar** | Já tem dono e prazos Meta |
| Recuperação de vendas | **Dividir** | (a) acesso por e-mail fica; (b) carrinho/Pix/recusa por WhatsApp = decisão nova contra `PRODUCT.md` L180 |
| Fidelidade (selos) e cupons | **Preservar** | Implementados |
| Cashback | **Reorganizar** | Fase 3 H3; reabrir decisão 126 |
| Assinaturas | **Reorganizar** | Só intenção em HTML antigo; criar item próprio (PAY-5) |
| Asaas como primeiro PSP (plano antigo I2) | **Reorganizar** | Mercado Pago passou à frente por decisão do dono em 12/10; Asaas vira o provedor de recorrência (PAY-6) |
| Split, afiliados, recebedores, KYC, conta, antecipação, Tap to Pay, internacional, Compra Protegida, AppCall (Etapas 6-7 do backlog Appmax) | **Descartar no core** | Violam `COMMERCIAL.md` L13; só voltariam como produto separado após D1 |
| Antifraude, disputas, chargeback | **Reorganizar** | Delegar ao PSP; ingerir evento |
| Conciliação diária | **Complementar** | Já reconcilia por consulta; falta relatório de divergência |
| Webhooks de saída | **Preservar** | = F3 I1; complementar com HMAC e reenvio |
| Plataforma de conectores (E4) | **Reorganizar** | Reaproveitar registro de módulos e manifestos; escolher conectores pela regra F3 ("repertório, não fila") |
| Order bump/upsell, boleto, infoprodutos, portal de desenvolvedores | **Descartar por ora** | Sem base; mexem em UI/preço; fora do público |
| Fiscal/ERP | **Preservar** | = F3 I2, via gateway |
| Etapas 1 e 2 do backlog Appmax | **Dividir** | E1 já decidida por `COMMERCIAL.md`; E2 em boa parte existe (idempotência, ledger por pedido, estados); faltam máquinas de estado separadas e fila durável |

**Lacunas do backlog Appmax frente ao PMD:** não tratava o modelo de posse por instalação, as fases e o congelamento (D240), módulos e regra de ausência, custos e prazos da Meta, nem a regra de reconsulta e valor liquidado = devido. Estão incorporadas acima.

# Anexo D: O que não foi possível verificar / correções ao briefing

- **Nenhum teste, build ou `test:remote` foi executado.** O estado verde do CI e a cobertura (≥ 60% é critério do portão) não foram vistos.
- A **auditoria de arquitetura** foi feita por agente somente leitura e entregue na conversa; o texto integral não está em `evidencias/` (apenas as demais seis).
- Não li as skills `implantacao-pmd`, `pmd-modulo`, `supabase-pmd`, nem `intent/overhaul/**`, `docs/legal/`, `packs/*`, `src/v2/*.tsx`. Como cada loja recebe o core "como dependência versionada" (`COMMERCIAL.md` L13-14) não tem automação encontrada no código.
- **Pesquisa externa só por resumos de busca**; domínios oficiais bloqueados. As células NV e `*` precisam de releitura.
- **Correções ao briefing:** (1) a "Instrução Normativa BCB 513" não foi localizada; a norma verificada do Pix Automático é a **Resolução BCB 402/2024**; (2) as restrições do PagBank para split com recorrência (cupons, taxa de adesão) **não foram encontradas** em nenhuma fonte acessada; (3) o split do Mercado Pago 1:1 por OAuth e o do Pagar.me para clientes PSP **foram confirmados**; (4) a documentação de Asaas sobre Pix Automático foi confirmada (autorização + instrução de cobrança), com elegibilidade condicional.
- O briefing assume que split e monetização são livres; o código mostra o contrário (B1). Este é o ponto que mais muda o plano.
