# Freqtrade + OKX 多策略回测系统

> 不需要 API Key，不需要装软件，纯 GitHub 运行。

## 这是什么

一个基于 Freqtrade 的多策略回测工具，连接 OKX 公开行情数据，内置 6 个交易策略，自动对比胜率、收益、风险，推荐最优策略。

## 纯 GitHub 使用（推荐，不用装任何东西）

### 第 1 步：上传文件到 GitHub 仓库

在 GitHub 创建仓库，把所有文件按目录结构上传。

### 第 2 步：开启 GitHub Pages

仓库 → Settings → Pages → Source 选 **GitHub Actions**

### 第 3 步：运行回测

仓库 → Actions → 选 **多策略回测对比** → Run workflow：

- **回测开始日期**：填 `20250101`（或任意起始）
- **回测结束日期**：填 `20260401`
- **是否 HyperOpt**：选 `false`（首次建议 false，跑快一些）

点 **Run workflow**，等 10-15 分钟。

### 第 4 步：查看结果

两种方式看报告：

1. **GitHub Actions Summary**：点进运行完的 workflow，页面底部直接看排名表
2. **GitHub Pages 报告**：打开 `https://你的用户名.github.io/freqtrade-okx/` 查看交互式报告

### 自动触发

除了手动触发，以下情况也会自动回测：
- 你修改了策略文件（`S*.py`）或 `config.json` 并 push
- 每周一凌晨 2 点自动跑一次

---

## 不需要 API Key 能做什么

| 功能 | 需要 API Key？ |
|------|:---:|
| 下载 OKX 历史 K 线数据 | 不需要 |
| 6 策略批量回测 | 不需要 |
| 查看胜率/收益/风险对比报告 | 不需要 |
| HyperOpt 参数自动优化 | 不需要 |
| 实盘交易 | 需要 |

## 目录结构

```
freqtrade-okx/
├── config.json                     # OKX 交易所配置
├── setup-github.sh                 # 一键部署脚本（GitHub 源码方式）
├── run_backtest_all.sh             # 多策略批量回测
├── backtest_report.html            # 回测结果对比报告（浏览器打开）
├── docker-compose.yml              # Docker 部署（备选方案）
├── setup.sh                        # Docker 启动脚本（备选方案）
├── README.md
└── user_data/
    ├── strategies/
    │   ├── DoNothing.py            # 空策略（纯监控）
    │   ├── S01_RSI_Reversal.py     # RSI 反转
    │   ├── S02_MACD_Cross.py       # MACD 金叉死叉
    │   ├── S03_BollingerBand.py    # 布林带均值回归
    │   ├── S04_EMA_Trend.py        # EMA 多头排列
    │   ├── S05_Stoch_RSI.py        # 随机 RSI + 放量
    │   └── S06_Combined_Multi.py   # 多指标综合
    ├── data/                       # 历史数据（自动下载）
    └── logs/
```

---

## 快速开始（3 步）

### 第 1 步：部署

Mac 上需要 Python 3.10+ 和 Git（通常自带）。

```bash
git clone https://github.com/你的用户名/freqtrade-okx.git
cd freqtrade-okx
bash setup-github.sh
```

脚本自动完成：克隆 Freqtrade → 创建虚拟环境 → 安装依赖 → 复制配置和策略。

### 第 2 步：下载数据 + 回测

```bash
cd ~/freqtrade

# 下载 OKX 历史 K 线（不需要 API Key）
bash download-data.sh

# 6 个策略一键对比回测
bash run_backtest_all.sh 20250101 20260401
```

终端直接输出排名表：

```
排名  策略                     交易   胜率    总收益%   最大回撤%  Sharpe   综合分
🏆 1  S06_Combined_Multi        52  73.1%🟢  +21.70%    5.40%    2.15    42.3
🥈 2  S02_MACD_Cross            87  56.3%🟡  +24.80%   12.50%    1.65    38.1
🥉 3  S01_RSI_Reversal         142  59.9%🟢  +18.45%    8.20%    1.42    37.5
```

### 第 3 步：查看报告

```bash
open backtest_report.html
```

浏览器打开交互式报告，包含 AI 策略推荐 + 过拟合检测。

---

## 带 HyperOpt 自动优化

让 AI 自动搜索每个策略的最优参数（更耗时但效果更好）：

```bash
bash run_backtest_all.sh 20250101 20260401 -o
```

每个策略跑 3 轮 × 300 个参数组合，自动找最优。

---

## 6 个策略说明

| 策略 | 逻辑 | 适合行情 | K 线周期 |
|------|------|----------|---------|
| S01 RSI 反转 | RSI 超卖买入、超买卖出 | 震荡 | 1h |
| S02 MACD 金叉 | MACD 穿越 + EMA200 过滤 | 趋势 | 1h |
| S03 布林带 | 触下轨买入、触上轨卖出 | 区间震荡 | 1h |
| S04 EMA 排列 | 短中长 EMA 多头排列 + ADX | 强趋势 | 4h |
| S05 随机 RSI | StochRSI 超卖 + 成交量放大 | 短线波段 | 15m |
| S06 多指标综合 | RSI+MACD+BB+EMA 四指标投票 | 追求高胜率 | 1h |

---

## 其他命令

```bash
cd ~/freqtrade

# 启动实时监控（不自动交易）
bash start.sh

# 安装 Web UI
source .venv/bin/activate && freqtrade install-ui

# 单独回测某个策略
bash backtest.sh S02_MACD_Cross 20250101-20260401

# 查看日志
tail -f user_data/logs/freqtrade.log
```

---

## 想实盘交易？

需要 OKX API Key。步骤：

1. 登录 OKX → 头像 → API → 创建 API Key
2. 编辑 `~/freqtrade/config.json`，填入 key / secret / password
3. 把 `"dry_run": true` 改为 `"dry_run": false`
4. 重新启动

> 强烈建议先用 dry_run 模拟跑 2-4 周再考虑实盘。

---

## 监控的币种（默认 10 个）

BTC/USDT, ETH/USDT, SOL/USDT, XRP/USDT, DOGE/USDT, ADA/USDT, AVAX/USDT, DOT/USDT, LINK/USDT, MATIC/USDT

修改 `config.json` 的 `pair_whitelist` 即可增减。
