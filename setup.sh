#!/usr/bin/env bash
# Reproduz o ambiente REA (Reverse Engineer Anything) numa sessão nova (Ubuntu 24.04, root).
# Uso: bash setup.sh        (idempotente: pula o que já existe)
set -euo pipefail

GHIDRA_VER=12.1.4
GHIDRA_DATE=20260921
JADX_SHA=6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75
TOOLS=$HOME/tools
JADX_DIR=$HOME/.local/share/rea/android
mkdir -p "$TOOLS" "$JADX_DIR"

echo "[1/7] REA (npm)"
command -v rea >/dev/null || npm install --global rea-agents

echo "[2/7] pacotes do sistema"
export DEBIAN_FRONTEND=noninteractive
echo "wireshark-common wireshark-common/install-setuid boolean false" | debconf-set-selections
apt-get update -qq
apt-get install -y -qq adb apktool binwalk tshark sigrok-cli gdb binutils procps xvfb \
  python3-venv python3-pip openjdk-21-jdk-headless

echo "[3/7] JADX headless MCP 0.7.1"
JAR=$JADX_DIR/jadx-headless-mcp-0.7.1-all.jar
[ -f "$JAR" ] || curl -fsSL -o "$JAR" https://github.com/1013503897/jadx-headless-mcp/releases/download/v0.7.1/jadx-headless-mcp-0.7.1-all.jar
echo "$JADX_SHA  $JAR" | sha256sum -c -

echo "[4/7] WABT 1.0.42 e Wakaru 1.14.0"
if [ ! -d "$TOOLS/wabt-1.0.42" ]; then
  curl -fsSL -o /tmp/wabt.tgz https://github.com/WebAssembly/wabt/releases/download/1.0.42/wabt-1.0.42-linux-x64.tar.gz
  tar -xzf /tmp/wabt.tgz -C "$TOOLS"
fi
ln -sf "$TOOLS"/wabt-1.0.42/bin/* /usr/local/bin/
if [ ! -x "$TOOLS/wakaru" ]; then
  curl -fsSL https://github.com/pionxzh/wakaru/releases/download/v1.14.0/wakaru-linux-x64.tar.gz | tar -xz -C "$TOOLS" wakaru
fi

echo "[5/7] Ghidra $GHIDRA_VER"
if [ ! -d "$TOOLS/ghidra_${GHIDRA_VER}_PUBLIC" ]; then
  curl -fsSL -o /tmp/ghidra.zip "https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_${GHIDRA_VER}_build/ghidra_${GHIDRA_VER}_PUBLIC_${GHIDRA_DATE}.zip"
  unzip -q /tmp/ghidra.zip -d "$TOOLS"
fi

echo "[6/7] ferramentas Python (pwntools, mitmproxy, frida, unblob)"
[ -d "$TOOLS/pyenv" ] || python3 -m venv "$TOOLS/pyenv"
"$TOOLS/pyenv/bin/pip" install -q pwntools mitmproxy frida frida-tools unblob
for b in mitmdump frida unblob; do ln -sf "$TOOLS/pyenv/bin/$b" /usr/local/bin/$b; done

echo "[7/7] variáveis e registro do REA no Claude Code"
CHROME=$(ls /opt/pw-browsers/chromium-*/chrome-linux/chrome 2>/dev/null | head -1 || true)
cat > "$HOME/.rea-env.sh" <<ENV
export GHIDRA_INSTALL_DIR=$TOOLS/ghidra_${GHIDRA_VER}_PUBLIC
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export REA_JADX_MCP_JAR=$JAR
export REA_WAKARU_COMMAND=$TOOLS/wakaru
export REA_JAVASCRIPT_PRLIMIT_COMMAND=/usr/bin/prlimit
export REA_ADB_PATH=/usr/bin/adb
export REA_MITMDUMP_COMMAND=$TOOLS/pyenv/bin/mitmdump
export REA_GHIDRA_STARTUP_TIMEOUT_MS=900000
${CHROME:+export REA_BROWSER_EXECUTABLE=$CHROME}
ENV
grep -q rea-env "$HOME/.bashrc" || echo ". $HOME/.rea-env.sh" >> "$HOME/.bashrc"
. "$HOME/.rea-env.sh"
cd /tmp
rea setup --client claude_code --yes --json >/dev/null
python3 - <<PY
import json,os
p=os.path.expanduser('~/.claude.json'); d=json.load(open(p))
env=d['mcpServers']['rea'].setdefault('env',{})
for l in open(os.path.expanduser('~/.rea-env.sh')):
    if l.startswith('export '):
        k,v=l[7:].strip().split('=',1); env[k]=v
env['PATH']="$TOOLS/pyenv/bin:$TOOLS/wabt-1.0.42/bin:"+os.environ['PATH']
json.dump(d,open(p,'w'),indent=2)
PY
rea doctor --client claude_code --skill --json | python3 -c "import json,sys;print('healthy:',json.load(sys.stdin)['healthy'])"
echo "Pronto. Reinicie o Claude Code para carregar o MCP 'rea'."
