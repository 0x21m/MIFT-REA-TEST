# Guia REA (Reverse Engineer Anything) — consolidado

Fonte: repo morluto/rea (commit 7054bbb, pacote npm `rea-agents` 6.5.0, MIT). O site rea.tools não pôde ser lido (bloqueado pela rede do ambiente); o README e `docs/` do repo foram lidos integralmente por agentes Haiku.

## 1. Instalação e verificação

```bash
npx rea-agents setup                     # registra MCP + skill nos agentes (mostra plano, pede aprovação)
npm install --global rea-agents          # opcional: comando `rea` no PATH
rea doctor --json                        # auditoria completa (somente leitura)
rea doctor --client claude_code --json   # só o registro no Claude Code
rea doctor --provider ghidra --json      # só o motor nativo
rea doctor --skill --json                # só a skill
claude mcp list                          # deve listar `rea`
rea mcp doctor --json                    # o servidor MCP sobe?
rea update                               # atualiza; depois: npx rea-agents@latest setup
```
Depois do setup: reiniciar o agente. Dentro do agente, a ferramenta `binary_session` com `{}` mostra `tool_availability`.
Requisitos: Node 22.19+/24.11+/26+, npm; Linux precisa de `ps` do procps. Motor nativo (Ghidra 12.1.x + JDK 21 completo, Hopper ou IDA) é instalado por você; JS/Electron/.NET/Flutter(APK) não precisam de motor.
Só skill: `npx skills add morluto/rea --skill reverse-engineer-anything` (não registra o MCP).

## 2. O que analisa (e o que precisa)
- Binários nativos (pseudocódigo, assembly, xrefs): Ghidra/Hopper/IDA.
- JS/Electron/ASAR: sem motor. Sites: Chrome com `--remote-debugging-port`. .NET: sem motor (estático). APK: JDK + jadx-headless-mcp 0.7.1. Android ao vivo: adb. Flutter, Go, Rust, WASM, SQLite, firmware (Binwalk/Unblob), pcap/HAR/SAZ, EVM, crashes.
- Runtime: Frida, captura de processo (`rea capture-process`), cenários de browser/Electron.

## 3. Fluxo recomendado (da skill)
1. Dê o alvo como caminho absoluto + pergunta concreta (não "analise o app").
2. Roteie pelo tipo de alvo; comece pelo resumo (`detail: "summary"`) e aprofunde com `inspect_analysis_view` + `parent_evidence_id`.
3. Separe observação / inferência / unknown; cite IDs de Evidence; estático nunca prova execução.
4. Confirme em runtime só quando a estática não basta.
5. Reconstrua → verifique: `build_reconstruction_obligation_ledger`, `evaluate_reconstruction_coverage`, `verify_reconstruction` (prompt guiado). Cobre só o que foi declarado, não equivalência global.
6. `close_binary` ao terminar.

Prompts MCP guiados: `investigate_feature`, `compare_application_versions`, `verify_reconstruction`, `trace_crash`, `audit_residual_unknowns`, `prepare_bounded_process_capture`.

## 4. Receitas por alvo
**Electron/JS**: `rea inspect-electron-fuses App.app` → `rea analyze app.asar --json` → `rea trace-application-feature trace-input.json` (seed: string/rota/IPC/export) → confirmar com `capture-electron-scenario` → `reconcile-javascript-runtime`.
**Site**: Chrome com porta de debug → `list-browser-targets` → `inspect-web-page ... --include-script-sources` → `export-web-scripts` → `analyze-javascript-application` → `recover-javascript-sources` (Wakaru) → `trace-web-source-location`; tráfego: `inspect-web-network-capture session.har har`.
**Nativo**: `rea inspect PATH --provider ghidra` → `search` → `function` / `decompile` / `instructions` / `xrefs` → `trace-native-values` → `observe-native-calls` (macOS/LLDB) → anotar com `annotate_native_function`.
**APK**: `inspect-android-package` → `search-android-classes` → `inspect-android-class/method` → `trace-android-references`; extrair do aparelho: `pull-adb-package`.
**.NET**: `inspect-managed-artifact` → `inspect-managed-members` → `compare_managed_members` entre builds.

## 5. Prompt modelo
"Entenda como funciona [FEATURE] no app [CAMINHO ABSOLUTO]. Comece pelo resumo, cite os IDs de Evidence, separe observado/inferido/desconhecido. Depois escreva uma implementação independente para o meu projeto e verifique-a com os mesmos cenários."

## 6. Limites e uso responsável
Pseudocódigo não é fonte; lista vazia não prova ausência; Ghidra headless pode levar minutos na 1ª consulta (`REA_GHIDRA_STARTUP_TIMEOUT_MS`). DISCLAIMER do projeto: não apoia burlar DRM/licença/anticheat, nem copiar software proprietário ou seus ativos/código protegido. Para "fazer sua própria versão": reimplemente o comportamento observado de forma independente (clean-room), em software que você possui/está autorizado a analisar ou para interoperabilidade; não copie código/ativos.
