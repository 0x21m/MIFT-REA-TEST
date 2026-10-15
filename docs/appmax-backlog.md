# Backlog: plataforma de pagamentos equivalente (Caminho B)

> **Aviso (15/10/2026):** este backlog foi escrito sem acesso ao PMD Core. Para o PMD, valem a auditoria e o roadmap em [pmd-payments/](pmd-payments/README.md). As Etapas 6 e 7 (split, KYC, conta, antecipação etc.) contradizem `COMMERCIAL.md` L13 do PMD Core e foram descartadas no core; ver Anexo C da Parte 3.


Referência de escopo: `appmax-escopo.md`. Premissa: produto de software próprio + parceiros financeiros, com provedores substituíveis. Cada item só é "pronto" quando cumpre o critério listado. Estimativas de prazo/orçamento ficam em aberto até a Etapa 1 estar decidida.

Legenda: **[DEC]** decisão de negócio/jurídica, **[DEV]** desenvolvimento, **[OPS]** operação humana, **[PAR]** depende de parceiro/homologação.

## Etapa 1: Modelo operacional
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E1-1 | Definir o papel da empresa (Caminho A, B ou C) e o enquadramento regulatório com assessoria especializada | DEC | Parecer jurídico escrito e decisão registrada |
| E1-2 | Mapear fluxo do dinheiro: quem processa, mantém, liquida, assume perdas | DEC | Diagrama aprovado com responsável por etapa |
| E1-3 | Selecionar parceiros (adquirência/PSP, antifraude, conta/liquidação, WhatsApp) e levantar capacidades reais | PAR | Matriz de capacidades por parceiro (métodos, parcelas, recorrência, estorno, split, internacional, eventos, prazos) |
| E1-4 | Definir quem responde por risco, conciliação, disputas, suporte | OPS | Tabela RACI publicada |

## Etapa 2: Núcleo transacional
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E2-1 | Entidades: empresa, loja, usuário, permissão, recebedor, app integrado | DEV | Esquema PostgreSQL + migrações; recebedor distinto de usuário |
| E2-2 | Modelo comercial: cliente, produto, oferta/kit, sessão de checkout, pedido | DEV | Preço da oferta independente da soma dos produtos |
| E2-3 | Modelo de pagamento: intenção, tentativa, token referenciado, resultado do provedor | DEV | Um pedido com 3 tentativas de cartão + 1 Pix gera 1 pagamento concluído sem ambiguidade |
| E2-4 | Livro-razão com lançamentos compensados, moeda explícita, saldo derivado | DEV | Propriedades: toda movimentação tem origem, correção gera reversão, soma de distribuições fecha, estorno ≤ estornável |
| E2-5 | Máquinas de estado separadas (comercial, financeiro, integração) | DEV | Diagramas + testes de transição inválida |
| E2-6 | Idempotência em API, tentativas e eventos | DEV | Testes: clique duplo, resposta perdida, webhook repetido, eventos fora de ordem, estorno × saque concorrente |
| E2-7 | Fila durável e workers para processos assíncronos | DEV | Falha de worker não perde nem duplica efeito |
| E2-8 | Auditoria de alterações sensíveis (taxas, contas de destino, permissões, decisões) | DEV | Trilha consultável por ator, objeto e data |

## Etapa 3: Checkout e primeiro provedor
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E3-1 | Contrato de adaptador de provedor com declaração de capacidades | DEV | Interface: createPayment, getPayment, refundPayment, tokenize, createRecipient, createSplit, getReceivables, requestPayout; capacidades ausentes tratadas, não escondidas |
| E3-2 | Adaptador do primeiro provedor (cartão) com tokenização no navegador | PAR | Dados de cartão nunca passam pelo backend próprio; CVV nunca persistido |
| E3-3 | Pix (cobrança, validade, confirmação) e boleto (emissão, vencimento, confirmação) | DEV/PAR | Conciliados no livro-razão |
| E3-4 | Checkout: endereço, frete fixo, cupom, parcelamento, página de sucesso | DEV | Fluxo ponta a ponta em sandbox do provedor |
| E3-5 | Timeout resolvido antes de qualquer retentativa em outro provedor | DEV | Teste de simulação: timeout seguido de aprovação tardia não gera cobrança dupla |
| E3-6 | Estorno total/parcial conforme capacidade do provedor | DEV | Boleto exige dados bancários; restrições por modalidade expostas na UI |
| E3-7 | Links de pagamento como oferta com identidade própria (vendedor, origem, itens) | DEV | Relatório por vendedor e campanha |
| E3-8 | Webhooks de saída: assinados, persistidos antes da entrega, histórico e reenvio manual | DEV | HMAC, deduplicação por id, alertas de falha |
| E3-9 | Conciliação diária provedor × livro-razão | DEV/OPS | Divergências listadas e resolvidas em fila |

## Etapa 4: Conectores prioritários
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E4-1 | Plataforma de conectores: instalação/desinstalação, credenciais protegidas, mapeamento, versões, diagnóstico, fila de falhas, reprocesso | DEV | Conector de referência com testes ponta a ponta |
| E4-2 | Escolher 3 a 5 plataformas prioritárias com base na demanda | DEC | Lista justificada |
| E4-3 | Homologação em cada ecossistema (ex.: Shopify exige aprovação como parceiro de pagamentos) | PAR | Aprovação formal registrada |
| E4-4 | Matriz de capacidades publicada: conector × versão × meio × assinatura × split × estorno × carteira × recuperação × país | DEV | Matriz gerada dos adaptadores, não escrita à mão |
| E4-5 | Camada interna de eventos comerciais ("compra aprovada" com definição única) e adaptadores de destino (ads, analytics, CRM) | DEV | Conversão só dispara com pagamento confirmado |

## Etapa 5: Conversão e recorrência
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E5-1 | Order bump (até 2 ofertas) com recálculo de preço, frete, desconto, itens | DEV | Testes de totais |
| E5-2 | Upsell de 1 clique com origem, destino e páginas | DEV | Reuso de token autorizado; efeito financeiro conciliado |
| E5-3 | Assinaturas: contrato, ciclo, cobrança do ciclo; pausar, reativar, cancelar, pular, antecipar, mudar itens/desconto/pagamento | DEV | Parcelamento e assinatura em modelos distintos; 3 tentativas/24h configuráveis |
| E5-4 | Recuperação por mensagens: elegibilidade, agenda, limite de contato, orçamento, atribuição | DEV | Para ao pagar; sem contato duplicado; separa receita recuperada de venda orgânica |
| E5-5 | Consentimento e preferências de comunicação | DEV | Opt-out respeitado em todos os canais |
| E5-6 | Cashback: concessão, validade, reserva, consumo, expiração, reversão | DEV | Contabilidade promocional separada de dinheiro real; reserva desfeita se pagamento falhar |
| E5-7 | Afiliados/coprodutores: atribuição, comissão e split como mecanismos separados | DEV | Vendedor com atribuição sem ser recebedor de split |

## Etapa 6: Distribuição e risco
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E6-1 | Cadastro e verificação de recebedores (KYC) | PAR | Só recebedores aprovados entram em split |
| E6-2 | Split determinístico por % ou valor; quem arca taxas, descontos, estornos e perdas | DEV | Regra incompatível é recusada, nunca ajustada em silêncio |
| E6-3 | Estorno em pedido com split (parcial vedado, total proporcional) | DEV | Reversões no livro-razão por participante |
| E6-4 | Antifraude: coleta de sinais, motor do parceiro, fila de revisão, mensuração | DEV/OPS | Métricas: fraude, chargeback, falso positivo, aprovação após perdas |
| E6-5 | Disputas: motivo, evidências, prazos, decisão, efeito financeiro, sincronização de acesso | DEV/OPS | Prazos alertados; decisões auditáveis |
| E6-6 | Reservas, bloqueios e valor antecipável | DEV | Painel distingue: venda aprovada, recebível, antecipável, reserva, disponível, liquidado, repassado |
| E6-7 | Relatórios: comercial, financeiro, operacional | DEV | Exportação em planilha |

## Etapa 7: Serviços ampliados
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E7-1 | Conta integrada: experiência no painel sobre instituição parceira, multiusuário, limites, aprovações | PAR | Instituição mantém os recursos; painel não finge ser conta |
| E7-2 | Antecipação e liquidação automática | PAR | Condições comerciais e elegibilidade documentadas |
| E7-3 | Internacional: moeda da compra x liquidação, taxas, câmbio, estorno | PAR | Países habilitados só após validação |
| E7-4 | Tap to Pay | PAR | PSP compatível, entitlement Apple, app homologado |
| E7-5 | Compra Protegida | DEC/OPS | Elegibilidade, evidências, responsabilidade financeira definidas |
| E7-6 | Carteiras digitais (Apple Pay, Google Pay) | PAR | Habilitação confirmada por conta e canal |
| E7-7 | Televendas (AppCall equivalente) | OPS | Filas, distribuição, comissão e qualidade |

## Etapa 8: Expansão do catálogo
| ID | Item | Tipo | Critério de pronto |
|---|---|---|---|
| E8-1 | Demais conectores e versões | DEV/PAR | Cada um com testes e homologação |
| E8-2 | Fiscal e ERP (Bling, Notazz): itens, descontos, parcelas, frete, retorno de nota | DEV | Latência documentada (Notazz roda em lote diário) |
| E8-3 | Infoprodutos/membros: criar, suspender, renovar, cancelar e revogar no estorno | DEV | Ciclo completo coberto |
| E8-4 | Portal de desenvolvedores, SDKs, sandbox, limites de uso | DEV | Documentação e exemplos versionados |

## Transversais (todas as etapas)
- Segurança: tokenização do parceiro, controle de scripts na página de pagamento, cofre de segredos, autenticação reforçada em ações financeiras, backups testados.
- LGPD: inventário de dados, finalidade, retenção, atendimento ao titular.
- Testes de contrato com cada provedor e simulação de falhas (provedor fora, resposta perdida, evento duplicado).
- Observabilidade: alertas de divergência de conciliação e fila de eventos presos.

## Questões em aberto (confirmar antes de assumir)
1. Google Pay: habilitação real por conta e canal.
2. Países da operação internacional (Colômbia).
3. Comportamento do split acima do líquido disponível.
4. Recuperação de assinatura por IA: disponibilidade real.
5. Lista de adquirentes e regras de roteamento (não pública).
6. Pix Automático, Samsung Pay web, ERP/logística nativos: não confirmados.
