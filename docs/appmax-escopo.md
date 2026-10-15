# Appmax: escopo público documentado (levantamento de 15/10/2026)

> Versão condensada do levantamento recebido, mantendo números, restrições e divergências. Fontes: appmax.com.br, help-center.appmax.com.br, docs.appmax.com.br. Não é auditoria do painel autenticado nem dos contratos privados. Itens "a confirmar" não devem virar requisito sem evidência.

## 1. Natureza
Subcredenciadora; também atua como correspondente bancária da Giro SCD (crédito contratado pela Giro). Não tratar como "banco próprio". Três camadas a construir: **produto de software**, **infraestrutura financeira integrada** (via parceiros), **operação do negócio** (cadastro/aprovação de lojistas, risco, conciliação, suporte, disputas, contratos).

## 2. Funcionalidades
| # | Módulo | Pontos-chave documentados |
|---|---|---|
| 2.1 | Cadastro | Empresa, loja, produtos físicos/digitais, SKUs, kits; termos permitem pedir documentos e consultar bases externas (qualificação, não só login). |
| 2.2 | Checkout (AppCheckout) | Hospedado no domínio Appmax; tema, produtos/kits, parcelamento, endereço, banners, cupom na intenção de saída. **Order bump**: até 2 kits sugeridos antes de concluir, com adicional de frete. **Upsell 1 clique**: pacote origem/destino, página de upsell e sucesso; guia restrito ao checkout Appmax; existe operação na API. **Frete fixo** múltiplo (sem transportadoras/etiquetas). Páginas de venda externas com parâmetros de campanha (não é construtor de landing). |
| 2.3 | Pagamentos | Cartão, Pix, boleto, carteiras; parcelamento online até 21x. Apple Pay por canal (Loja Integrada, Shopify, VTEX, AppCheckout). **Google Pay: divergência** (ajuda diz só Link de Pagamento; API descreve uso por apps). |
| 2.4 | Gateway | Multiadquirência, retentativas, tokenização. Lista de adquirentes e regras de roteamento: **não pública**. |
| 2.5 | Antifraude | Divulga 150+ sinais e IA. Decisão manual pelo lojista após 5 min para pedidos em análise; aprovação manual pode bloquear antecipação e perde cobertura de chargeback do serviço; exclui contas com CPF. |
| 2.6 | Recuperação (IA/WhatsApp) | Carrinho (até 30 min), Pix não pago (até 7 min), recusa do emissor (até 16 min). R$ 1,99 por disparo. API de recuperação em **beta** (`cart_link`). |
| 2.7 | AppCall | Televendas humano; cobrança por venda bem-sucedida. Exige operação de atendimento. |
| 2.8 | Links de pagamento | Personalizáveis, ilimitados, até 200 vendedores acompanhados. |
| 2.9 | Assinaturas | API: criar/consultar/listar/pausar/reativar/cancelar; dia e periodicidade; antecipar; pular ciclo; itens e quantidades (global e por ciclo); descontos; forma de pagamento/endereço. Até 3 tentativas a cada 24h (Shopify) e recuperação por WhatsApp; **recuperação de assinatura por IA: divergência (ajuda diz em desenvolvimento)**. Parcelamento ≠ assinatura; Pix inicial ≠ Pix Automático. |
| 2.10 | Split | % ou valor; cartão, Pix e boleto; recebedores com facematch, saldos, antecipação, saque. **Sem estorno parcial em pedidos com split**; estorno total proporcional. **Divergência**: ajuda diz rejeitar excesso; endpoint ajusta sobre o líquido. |
| 2.11 | Afiliados/coprodutores | Cookies, links, pixels, relatórios de comissão e ranking. |
| 2.12 | Estornos/chargebacks | Estorno total/parcial pela API; boleto exige dados bancários; relatórios de chargeback. |
| 2.13 | Compra Protegida | Não é seguro. Físico, até R$ 350, cartão, aprovado no antifraude. Exclui digitais, assinaturas, serviços. |
| 2.14 | Cashback Max | Crédito para próxima compra na mesma loja; não é saldo bancário. |
| 2.15 | Recebíveis | D+30 padrão; fluxo de parcelas; antecipação; liquidação automática por bandeira sem taxa de saque; reservas/compensações previstas nos termos. |
| 2.16 | Conta Max | Internet banking, Pix, boletos, extrato, DDA; operações web exigem autorização no app; multiusuário com perfis e limites. |
| 2.17 | Tap to Pay | Android/iPhone compatíveis, débito, crédito à vista e até 12x; D+0 com conta Max ativa. iPhone exige PSP compatível + entitlement Apple + revisão. |
| 2.18 | Internacional | Argentina, México, Chile (ajuda); site cita também Colômbia (**divergência**). Cartão crédito/débito, saldo em USD, saque em BRL, estorno integral, antifraude dLocal. |
| 2.19 | Relatórios | Pedidos, carrinhos, rastreamento, campanhas, comissões, chargebacks, não antecipáveis, ranking; exportação em planilha. |

## 3. Integrações
- **Catálogo oficial (30)**: 25 e-commerce (Bagy, FacilZap, Irroba, Jet, Linx Commerce, Loja Integrada, LPQV, Macro E-commerce, Magazord, Magento, Moovin, Nuvemshop, Olist, Rits, Shopify, Shoppub, Tray, Uappi, Visual E-commerce, VTEX, Wake, wBuy, WooCommerce, WX3, Yampi); checkout (Adoorei); checkout/infoprodutos (Digital Manager Guru); infoprodutos (Astron Members, Memberkit, The Members).
- **Só na ajuda (6)**: Cartpanda, Corvex Checkout, Luna Checkout, Vnda, Well.Commerce, Zedy Checkout (confirmar versão/disponibilidade).
- **Complementares**: RD Station, ActiveCampaign, Infusion, LeadLovers, Hotzapp, SAK, Notificações Inteligentes, Apollo (plataforma de ensino, não o CRM Apollo.io), EAD Plataforma, OptimizePress/OptimizeMember, Bling (itens, descontos, parcelas, frete, destinatário; fiscal depende do Bling), Notazz (busca pedidos do dia anterior + webhook).
- **Ads/analytics**: Meta Pixel, Google Ads, Bing Ads, Criteo, Taboola, Outbrain, Google Analytics, GTM.
- **Financeiro/ecossistema**: Apple Pay, Google Pay, WhatsApp, Max, Giro SCD, dLocal, bancos elegíveis p/ liquidação. Termos citam consultas a idwall/SPC/Serasa (autorização contratual, não lista confirmada).
- **Suporte por recurso varia por plataforma**: recuperação de carrinho (Yampi, Shopify, Nuvemshop, Bagy, Uappi, VTEX); cartão recusado (Yampi, Cartpanda, Nuvemshop, Checkout Appmax). Exigir matriz conector × versão × meio × assinatura × split × estorno × carteira × recuperação × país.

## 4. API e desenvolvedores
- Sandbox e produção; OAuth `client_credentials`, token de 1h; credenciais do app vs. do lojista autorizado.
- Fluxo: instalar/autorizar app → credenciais da loja → cliente → pedido → pagamento → eventos.
- Recursos: clientes, produtos, pedidos (cálculo, upsell, rastreio), pagamentos (cartão, Pix, boleto, carteiras, parcelas), assinaturas, estornos, links, recebedores/split.
- **Appmax JS**: coleta de IP do comprador (obrigatória mesmo com PCI próprio), tokenização, carteiras.
- **Webhooks/Apphooks**: sem HMAC; ordem não garantida; resposta em 5 s; descarte após 4 falhas.
- **Rate limit** por credencial de lojista: 5 req/s, pico 50, 100 mil/mês, limites por rota.
- Apps públicos/privados; MCP oficial apenas de apoio ao desenvolvimento.

## 5. Preços divulgados (sujeitos a negociação)
Crédito à vista 3,49%; até 12x 3,49% + 2,49% por parcela; 21x sob consulta; Pix 0,99%; boleto R$ 3,49; internacional 9,90% + US$ 0,50; tarifa fixa gateway+antifraude R$ 0,99; saque R$ 3,67 (conforme modalidade); antecipação D+1 +2,49%; D+30 padrão; sem mensalidade anunciada.

## 6. Não confirmado publicamente
ERP/logística própria, Pix Automático, Samsung Pay web, portabilidade irrestrita de tokens, lista completa de adquirentes.

## 7. Caminhos e arquitetura recomendados
- **A** Marca própria sobre infra pronta (Payment as a Service da própria Appmax). **B (recomendado)** produto próprio + parceiros financeiros com adaptadores substituíveis. **C** operação própria profunda (decisão empresarial e jurídica separada; enquadramento BCB credenciador/subcredenciador).
- Módulos: identidade/estabelecimentos, catálogo/ofertas, checkout, pedidos, pagamentos, risco, assinaturas, recebedores/split, financeiro (livro-razão), disputas, conversão, comunicação, integrações, observabilidade.
- Regras: livro-razão com lançamentos compensados; estados comercial/financeiro/integração separados; idempotência; timeout ≠ recusa; sem CVV armazenado (PCI SSC); adaptadores declaram capacidades; webhooks próprios assinados, persistidos e reprocessáveis.
- No contexto PMD: plataforma de pagamentos separada do PMD Core; checkout determinístico por WhatsApp distinto da recuperação conversacional por IA.
