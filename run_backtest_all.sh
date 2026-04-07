#!/bin/bash
# ============================================
# Freqtrade 多策略批量回测 + 自动对比 + AI 推荐
# ============================================
# 参考项目：
#   - freqtrade 官方 --strategy-list（数据只加载一次）
#   - ErikKerkvliet/FreqtradeHyperOpt（多轮优化 + 过拟合检测）
#   - iterativv/NostalgiaForInfinity（社区最佳实践配置）
#
# 用法：
#   bash run_backtest_all.sh                        # 默认：最近 1 年多
#   bash run_backtest_all.sh 20240101 20260401      # 自定义时间范围
#   bash run_backtest_all.sh 20250101 20260401 -o   # 带 HyperOpt 优化
# ============================================
set -e

cd "$(dirname "$0")"

# ---- 参数解析 ----
START_DATE="${1:-20250101}"
END_DATE="${2:-20260401}"
TIMERANGE="${START_DATE}-${END_DATE}"
RUN_HYPEROPT=false
if [ "$3" = "-o" ] || [ "$3" = "--optimize" ]; then
    RUN_HYPEROPT=true
fi

CONFIG="config.json"
USERDIR="user_data"
RESULTS_DIR="user_data/backtest_results"

# 所有策略（按文件名自动发现）
STRATEGIES=()
for f in user_data/strategies/S*.py; do
    [ -f "$f" ] || continue
    basename="${f##*/}"
    name="${basename%.py}"
    STRATEGIES+=("$name")
done

if [ ${#STRATEGIES[@]} -eq 0 ]; then
    echo "❌ 未在 user_data/strategies/ 中找到 S*.py 策略文件"
    exit 1
fi

echo "============================================"
echo "  Freqtrade 多策略批量回测"
echo "============================================"
echo "  时间范围:  $TIMERANGE"
echo "  策略数量:  ${#STRATEGIES[@]}"
echo "  策略列表:  ${STRATEGIES[*]}"
echo "  HyperOpt:  $RUN_HYPEROPT"
echo "============================================"
echo ""

# 激活虚拟环境
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi

mkdir -p "$RESULTS_DIR"

# ================================================================
# 阶段 1：数据下载
# ================================================================
echo "📥 [1/4] 检查历史数据..."
DATA_EXISTS=$(find "$USERDIR/data" -name "*.json" 2>/dev/null | head -1)
if [ -z "$DATA_EXISTS" ]; then
    echo "   正在从 OKX 下载历史数据..."
    freqtrade download-data \
        --config "$CONFIG" \
        --timerange "$TIMERANGE" \
        --timeframe 5m 15m 1h 4h \
        --userdir "$USERDIR" || {
        echo "❌ 数据下载失败。请检查网络连接。"
        echo "   （OKX 公开行情数据不需要 API Key）"
        exit 1
    }
    echo "   ✅ 数据下载完成"
else
    echo "   ✅ 历史数据已存在"
fi
echo ""

# ================================================================
# 阶段 2（可选）：HyperOpt 自动参数优化
# ================================================================
# 参考 ErikKerkvliet/FreqtradeHyperOpt 的三轮优化思路
if [ "$RUN_HYPEROPT" = true ]; then
    echo "🧬 [2/4] HyperOpt 参数优化（每策略 300 轮 × 3 次）..."
    echo ""

    for STRATEGY in "${STRATEGIES[@]}"; do
        echo "  ── 优化: $STRATEGY ──"
        BEST_PROFIT=-9999

        for ROUND in 1 2 3; do
            echo "     第 ${ROUND}/3 轮..."
            freqtrade hyperopt \
                --config "$CONFIG" \
                --strategy "$STRATEGY" \
                --hyperopt-loss SharpeHyperOptLossDaily \
                --timerange "$TIMERANGE" \
                --epochs 300 \
                --spaces buy sell \
                --userdir "$USERDIR" \
                --no-color 2>&1 | tail -3

            echo ""
        done
        echo "  ✅ $STRATEGY 优化完成（最优参数已自动应用）"
        echo ""
    done
else
    echo "⏭️  [2/4] 跳过 HyperOpt（加 -o 参数启用）"
fi
echo ""

# ================================================================
# 阶段 3：多策略同时回测（官方 --strategy-list，数据只加载一次）
# ================================================================
echo "🔬 [3/4] 批量回测（官方 --strategy-list 模式）..."
echo ""

RESULT_FILE="$RESULTS_DIR/multi_strategy_result.json"

freqtrade backtesting \
    --config "$CONFIG" \
    --strategy-list ${STRATEGIES[@]} \
    --timerange "$TIMERANGE" \
    --userdir "$USERDIR" \
    --export trades \
    --export-filename "$RESULT_FILE" \
    2>&1 | tee "$RESULTS_DIR/backtest_log.txt"

echo ""

# ================================================================
# 阶段 4：解析结果 + 生成对比报告
# ================================================================
echo "📊 [4/4] 解析结果..."
echo ""

python3 << 'PYEOF'
import json, glob, os, sys

results_dir = "user_data/backtest_results"
strategies = []

# 尝试解析 --strategy-list 输出的结果
result_files = sorted(glob.glob(f"{results_dir}/*result*.json"))

for f in result_files:
    try:
        with open(f) as fh:
            data = json.load(fh)

        # Freqtrade --strategy-list 输出格式
        if "strategy" in data:
            for strat_name, sd in data["strategy"].items():
                if strat_name in [s["name"] for s in strategies]:
                    continue  # 去重
                total = sd.get("total_trades", 0)
                wins = sd.get("wins", 0)
                losses = sd.get("losses", 0)
                draws = sd.get("draws", 0)
                wr = round((wins / total * 100), 1) if total > 0 else 0

                strategies.append({
                    "name": strat_name,
                    "total_trades": total,
                    "wins": wins,
                    "losses": losses,
                    "draws": draws,
                    "win_rate": wr,
                    "profit_pct": round(sd.get("profit_total", 0) * 100, 2),
                    "profit_total_abs": round(sd.get("profit_total_abs", 0), 2),
                    "avg_profit": round(sd.get("profit_mean", 0) * 100, 2),
                    "max_drawdown": round(sd.get("max_drawdown_abs", 0), 2),
                    "max_drawdown_pct": round(sd.get("max_drawdown", 0) * 100, 2),
                    "sharpe": round(sd.get("sharpe", 0), 2),
                    "sortino": round(sd.get("sortino", 0), 2),
                    "calmar": round(sd.get("calmar", 0), 2),
                    "profit_factor": round(sd.get("profit_factor", 0), 2),
                    "expectancy": round(sd.get("expectancy", 0), 4),
                    "avg_duration": str(sd.get("holding_avg", "N/A")),
                    "best_pair": sd.get("best_pair", "N/A"),
                    "worst_pair": sd.get("worst_pair", "N/A"),
                    "trading_volume": round(sd.get("trading_volume", 0), 2),
                })

        # strategy_comparison 快捷格式
        if "strategy_comparison" in data and not strategies:
            for row in data["strategy_comparison"]:
                trades = row.get("trades", 0)
                wins = row.get("wins", 0)
                strategies.append({
                    "name": row.get("key", "unknown"),
                    "total_trades": trades,
                    "wins": wins,
                    "losses": row.get("losses", 0),
                    "draws": row.get("draws", 0),
                    "win_rate": round(wins / max(trades, 1) * 100, 1),
                    "profit_pct": round(row.get("profit_total", 0), 2),
                    "profit_total_abs": round(row.get("profit_total_abs", 0), 2),
                    "avg_profit": round(row.get("profit_mean", 0), 2),
                    "max_drawdown": round(row.get("max_drawdown_abs", 0), 2),
                    "max_drawdown_pct": round(row.get("max_drawdown_account", 0) * 100, 2),
                    "sharpe": 0,
                    "sortino": 0,
                })

    except Exception as e:
        print(f"  ⚠️ 解析 {f}: {e}", file=sys.stderr)

if not strategies:
    print("⚠️ 未找到有效回测结果。")
    print("   确认 backtest 命令已成功执行。")
    sys.exit(0)

# ---- 排序：综合评分 ----
for s in strategies:
    wr = s.get("win_rate", 0)
    pf = s.get("profit_pct", 0)
    sh = s.get("sharpe", 0)
    md = s.get("max_drawdown_pct", s.get("max_drawdown", 0))
    # 综合分 = 胜率*0.25 + 收益*0.25 + Sharpe*10*0.25 + (100-回撤)*0.25
    s["composite_score"] = round(wr * 0.25 + pf * 0.25 + sh * 10 * 0.25 + (100 - abs(md)) * 0.25, 1)

strategies.sort(key=lambda x: x["composite_score"], reverse=True)

# 保存 JSON（供 HTML 报告）
with open(f"{results_dir}/comparison.json", "w") as f:
    json.dump(strategies, f, indent=2, ensure_ascii=False)

# ---- 打印终端表格 ----
print("")
print("=" * 105)
print(f"{'排名':>4} {'策略':<25} {'交易':>5} {'胜率':>7} {'总收益%':>8} {'最大回撤%':>9} {'Sharpe':>7} {'综合分':>7}")
print("=" * 105)

for i, s in enumerate(strategies):
    rank = i + 1
    name = s["name"]
    trades = s.get("total_trades", 0)
    wr = s.get("win_rate", 0)
    pf = s.get("profit_pct", 0)
    md = s.get("max_drawdown_pct", s.get("max_drawdown", 0))
    sh = s.get("sharpe", 0)
    cs = s.get("composite_score", 0)

    medal = "🏆" if rank == 1 else "🥈" if rank == 2 else "🥉" if rank == 3 else "  "
    wr_icon = "🟢" if wr >= 60 else "🟡" if wr >= 45 else "🔴"

    print(f" {medal}{rank:>2} {name:<25} {trades:>5} {wr:>5.1f}%{wr_icon} {pf:>+7.2f}% {md:>8.2f}% {sh:>7.2f} {cs:>7.1f}")

print("=" * 105)

best = strategies[0]
print(f"\n🏆 最优策略推荐: {best['name']}")
print(f"   胜率 {best.get('win_rate', 0)}% | 收益 {best.get('profit_pct', 0):+.2f}% | Sharpe {best.get('sharpe', 0)} | 综合分 {best.get('composite_score', 0)}")

if len(strategies) >= 2:
    runner = strategies[1]
    print(f"🥈 备选策略: {runner['name']}")
    print(f"   胜率 {runner.get('win_rate', 0)}% | 收益 {runner.get('profit_pct', 0):+.2f}% | Sharpe {runner.get('sharpe', 0)} | 综合分 {runner.get('composite_score', 0)}")

# ---- 过拟合风险检测（参考 ErikKerkvliet 的 Reality Gap 思路）----
print(f"\n⚠️  过拟合风险检测:")
for s in strategies:
    trades = s.get("total_trades", 0)
    wr = s.get("win_rate", 0)
    risks = []
    if trades < 30:
        risks.append("交易次数过少(<30)，统计意义不足")
    if wr > 80:
        risks.append("胜率异常高(>80%)，可能过拟合")
    if s.get("profit_pct", 0) > 100:
        risks.append("收益率异常高(>100%)，可能过拟合")
    if abs(s.get("max_drawdown_pct", s.get("max_drawdown", 0))) < 1 and trades > 20:
        risks.append("回撤异常低(<1%)，可能过拟合")

    if risks:
        print(f"   ⚠️ {s['name']}: {'; '.join(risks)}")
    else:
        print(f"   ✅ {s['name']}: 无明显过拟合信号")

print(f"\n📄 对比数据: {results_dir}/comparison.json")
print(f"🌐 打开 backtest_report.html 查看交互式报告")
print(f"💡 提示: 加 -o 参数可启用 HyperOpt 自动优化（bash run_backtest_all.sh {strategies[0].get('start', '20250101')} {strategies[0].get('end', '20260401')} -o）")

PYEOF

echo ""
echo "============================================"
echo "  ✅ 批量回测完成"
echo "============================================"
