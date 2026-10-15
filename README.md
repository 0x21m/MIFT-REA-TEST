# MIFT-REA-TEST

Ambiente e testes com o [REA](https://github.com/morluto/rea) (Reverse Engineer Anything).

- `setup.sh`: reinstala todo o ambiente numa sessão nova (REA 6.5.0, Ghidra 12.1.4, JADX 0.7.1, WABT 1.0.42, Wakaru 1.14.0, adb, apktool, binwalk, tshark, sigrok, gdb, pwntools, mitmproxy, frida, unblob) e registra o MCP no Claude Code.
- `docs/guia-rea.md`: guia de uso (instalação, fluxo, receitas por alvo, limites).
- `docs/appmax-escopo.md`: levantamento condensado do escopo público da Appmax.
- `docs/appmax-backlog.md`: backlog por etapa para uma plataforma equivalente (Caminho B).

```bash
bash setup.sh   # depois reinicie o Claude Code
```

Não incluídos (comerciais/opcionais): Hopper, IDA, JEB, Rizin, ILSpy.
Uso responsável: ver DISCLAIMER do projeto REA. Analise apenas software que você possui ou está autorizado a examinar.
