#!/bin/bash
# ============================================
# Freqtrade + OKX 一键部署脚本 (Mac)
# ============================================
set -e

echo "============================================"
echo "  Freqtrade + OKX 部署脚本"
echo "============================================"
echo ""

# ---- 1. 检查 Docker ----
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装。请先安装 Docker Desktop for Mac："
    echo "   https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &> /dev/null 2>&1; then
    echo "❌ Docker 未运行。请先启动 Docker Desktop。"
    exit 1
fi

echo "✅ Docker 已就绪"

# ---- 2. 检查 config.json 中是否填写了 API Key ----
if grep -q '"key": ""' config.json; then
    echo ""
    echo "ℹ️  API Key 为空 — 这不影响以下功能："
    echo "   ✅ 下载历史行情数据（公开接口，不需要 Key）"
    echo "   ✅ 回测策略"
    echo "   ✅ dry_run 模拟盘"
    echo "   ❌ 实盘交易（需要 API Key）"
    echo ""
fi

# ---- 3. 修改 docker-compose 使用 DoNothing 策略 ----
# 如果用户选择了空策略模式
if [ "$1" = "--monitor" ] || [ "$1" = "-m" ]; then
    echo "📊 监控模式：使用 DoNothing 空策略（不自动交易）"
    STRATEGY="DoNothing"
else
    STRATEGY="${1:-DoNothing}"
    echo "📊 使用策略：$STRATEGY"
fi

# ---- 4. 生成 jwt_secret_key ----
JWT_SECRET=$(openssl rand -hex 32 2>/dev/null || cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | head -c 64)
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/CHANGE_ME_TO_RANDOM_STRING/$JWT_SECRET/" config.json
else
    sed -i "s/CHANGE_ME_TO_RANDOM_STRING/$JWT_SECRET/" config.json
fi
echo "✅ JWT Secret 已自动生成"

# ---- 5. 启动容器 ----
echo ""
echo "🚀 正在启动 Freqtrade..."
echo ""

# 替换策略名
export FREQTRADE_STRATEGY=$STRATEGY

docker compose up -d

echo ""
echo "============================================"
echo "  ✅ 部署完成！"
echo "============================================"
echo ""
echo "  📊 FreqUI 界面:  http://localhost:3000"
echo "  🔌 API 地址:     http://localhost:8080/api/v1"
echo "  👤 登录账号:     freqtrader / freqtrader"
echo ""
echo "  常用命令："
echo "  ─────────────────────────────────────────"
echo "  查看日志:    docker logs -f freqtrade-okx"
echo "  停止:        docker compose down"
echo "  重启:        docker compose restart"
echo "  进入容器:    docker exec -it freqtrade-okx /bin/bash"
echo ""
echo "  下载历史数据（在容器内执行）："
echo "  docker exec freqtrade-okx freqtrade download-data \\"
echo "    --config /freqtrade/config.json \\"
echo "    --timerange 20240101- \\"
echo "    --timeframe 5m 15m 1h 4h 1d"
echo ""
echo "============================================"
