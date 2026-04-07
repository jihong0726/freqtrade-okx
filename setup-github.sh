#!/bin/bash
# ============================================
# Freqtrade + OKX — GitHub 源码部署脚本 (Mac)
# ============================================
set -e

INSTALL_DIR="$HOME/freqtrade"
REPO_URL="https://github.com/freqtrade/freqtrade.git"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "============================================"
echo "  Freqtrade + OKX GitHub 源码部署"
echo "============================================"
echo ""

# ---- 1. 检查前置依赖 ----
echo "🔍 检查依赖..."

# 检查 git
if ! command -v git &> /dev/null; then
    echo "❌ Git 未安装。请运行: xcode-select --install"
    exit 1
fi
echo "  ✅ Git 已安装"

# 检查 Python
if command -v python3 &> /dev/null; then
    PY_VER=$(python3 --version 2>&1 | awk '{print $2}')
    PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
    PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
    if [ "$PY_MAJOR" -ge 3 ] && [ "$PY_MINOR" -ge 10 ]; then
        echo "  ✅ Python $PY_VER"
    else
        echo "❌ Python 版本过低 ($PY_VER)，需要 3.10+。"
        echo "   推荐: brew install python@3.12"
        exit 1
    fi
else
    echo "❌ Python3 未安装。请运行: brew install python@3.12"
    exit 1
fi

# 检查 brew（非必需但推荐）
if command -v brew &> /dev/null; then
    echo "  ✅ Homebrew 已安装"
else
    echo "  ⚠️  Homebrew 未安装（非必需，但安装 TA-Lib 会需要）"
fi

echo ""

# ---- 2. 克隆 Freqtrade ----
if [ -d "$INSTALL_DIR" ]; then
    echo "📂 $INSTALL_DIR 已存在，跳过克隆"
    cd "$INSTALL_DIR"
    echo "   正在拉取最新代码..."
    git pull --ff-only 2>/dev/null || echo "   ⚠️ 拉取失败，使用现有代码继续"
else
    echo "📥 克隆 Freqtrade 仓库..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

echo "  ✅ Freqtrade 源码就绪: $INSTALL_DIR"
echo ""

# ---- 3. 创建 Python 虚拟环境 ----
echo "🐍 创建虚拟环境..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    echo "  ✅ 虚拟环境创建完成"
else
    echo "  ✅ 虚拟环境已存在"
fi

source .venv/bin/activate
echo "  ✅ 已激活虚拟环境"
echo ""

# ---- 4. 安装依赖 ----
echo "📦 安装 Freqtrade 依赖（这一步可能需要几分钟）..."

# 升级 pip
pip install --upgrade pip setuptools wheel -q

# 安装 freqtrade
pip install -e . -q 2>&1 | tail -1

echo "  ✅ Freqtrade 核心已安装"

# 安装绘图依赖（可选但推荐）
pip install -e ".[plot]" -q 2>&1 | tail -1 || echo "  ⚠️ 绘图依赖安装失败（不影响核心功能）"

echo ""

# ---- 5. 安装 TA-Lib（技术分析库）----
echo "📊 安装 TA-Lib..."
if command -v brew &> /dev/null; then
    if ! brew list ta-lib &> /dev/null 2>&1; then
        brew install ta-lib 2>/dev/null || echo "  ⚠️ TA-Lib C 库安装失败"
    fi
    pip install ta-lib -q 2>&1 | tail -1 || echo "  ⚠️ TA-Lib Python 包安装失败（不影响基础功能）"
    echo "  ✅ TA-Lib 已安装"
else
    echo "  ⚠️ 跳过 TA-Lib（需要 Homebrew）。如需安装："
    echo "     /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "     brew install ta-lib && pip install ta-lib"
fi
echo ""

# ---- 6. 创建目录结构 ----
echo "📁 创建 user_data 目录..."
freqtrade create-userdir --userdir user_data 2>/dev/null || true

# ---- 7. 复制 OKX 配置文件 ----
echo "📋 复制 OKX 配置..."

# 复制 config.json
if [ -f "$SCRIPT_DIR/config.json" ]; then
    cp "$SCRIPT_DIR/config.json" "$INSTALL_DIR/config.json"
    echo "  ✅ config.json 已复制"
else
    echo "  ⚠️ 未找到 config.json，请手动复制"
fi

# 复制策略文件
if [ -f "$SCRIPT_DIR/user_data/strategies/DoNothing.py" ]; then
    cp "$SCRIPT_DIR/user_data/strategies/DoNothing.py" "$INSTALL_DIR/user_data/strategies/DoNothing.py"
    echo "  ✅ DoNothing.py 策略已复制"
fi

# ---- 8. 生成 jwt_secret_key ----
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/CHANGE_ME_TO_RANDOM_STRING/$JWT_SECRET/" "$INSTALL_DIR/config.json" 2>/dev/null || true
else
    sed -i "s/CHANGE_ME_TO_RANDOM_STRING/$JWT_SECRET/" "$INSTALL_DIR/config.json" 2>/dev/null || true
fi
echo "  ✅ JWT Secret 已生成"
echo ""

# ---- 9. 验证安装 ----
echo "🔍 验证安装..."
FT_VER=$(freqtrade --version 2>&1 || echo "unknown")
echo "  ✅ $FT_VER"
echo ""

# ---- 10. 创建快捷启动脚本 ----
cat > "$INSTALL_DIR/start.sh" << 'STARTEOF'
#!/bin/bash
# Freqtrade 快捷启动脚本
cd "$(dirname "$0")"
source .venv/bin/activate

STRATEGY="${1:-DoNothing}"

echo "🚀 启动 Freqtrade (策略: $STRATEGY)"
echo "   API: http://localhost:8080/api/v1"
echo "   用户: freqtrader / freqtrader"
echo "   按 Ctrl+C 停止"
echo ""

freqtrade trade \
    --config config.json \
    --strategy "$STRATEGY" \
    --userdir user_data
STARTEOF
chmod +x "$INSTALL_DIR/start.sh"

# 创建数据下载脚本
cat > "$INSTALL_DIR/download-data.sh" << 'DLEOF'
#!/bin/bash
# 下载 OKX 历史 K 线数据
cd "$(dirname "$0")"
source .venv/bin/activate

echo "📥 下载 OKX 历史数据..."
freqtrade download-data \
    --config config.json \
    --timerange 20240101- \
    --timeframe 5m 15m 1h 4h 1d \
    --userdir user_data

echo "✅ 数据下载完成"
echo "   数据目录: user_data/data/"
DLEOF
chmod +x "$INSTALL_DIR/download-data.sh"

# 创建回测脚本
cat > "$INSTALL_DIR/backtest.sh" << 'BTEOF'
#!/bin/bash
# 回测策略
cd "$(dirname "$0")"
source .venv/bin/activate

STRATEGY="${1:-DoNothing}"
TIMERANGE="${2:-20240101-20260401}"

echo "🔬 回测策略: $STRATEGY (时间范围: $TIMERANGE)"
freqtrade backtesting \
    --config config.json \
    --strategy "$STRATEGY" \
    --timerange "$TIMERANGE" \
    --timeframe 5m \
    --userdir user_data

echo "✅ 回测完成"
BTEOF
chmod +x "$INSTALL_DIR/backtest.sh"

echo ""
echo "============================================"
echo "  ✅ 部署完成！"
echo "============================================"
echo ""
echo "  📂 安装目录: $INSTALL_DIR"
echo ""
echo "  🚀 启动命令："
echo "  ─────────────────────────────────────────"
echo "  cd $INSTALL_DIR"
echo ""
echo "  # 监控模式（不自动交易）"
echo "  bash start.sh"
echo ""
echo "  # 指定策略"
echo "  bash start.sh SampleStrategy"
echo ""
echo "  # 下载历史数据"
echo "  bash download-data.sh"
echo ""
echo "  # 回测"
echo "  bash backtest.sh DoNothing 20240101-20260401"
echo ""
echo "  📊 Web UI："
echo "  ─────────────────────────────────────────"
echo "  需要安装 FreqUI 才有 Web 界面。"
echo "  启动后直接访问: http://localhost:8080"
echo "  或安装独立 FreqUI："
echo "  freqtrade install-ui"
echo ""
echo "  👤 API 登录: freqtrader / freqtrader"
echo ""
echo "  💡 下一步："
echo "     回测/下载行情数据 → 不需要 API Key，直接可用"
echo "     实盘交易 → 需要填入 OKX API Key（参见 README.md）"
echo ""
echo "============================================"
