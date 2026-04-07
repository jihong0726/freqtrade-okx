"""
策略 6: 多指标综合策略
=======================
逻辑：RSI + MACD + BB + EMA 多信号确认，至少 3 个指标同时看多才入场
适合：追求高胜率、低频交易
"""
from freqtrade.strategy import IStrategy, IntParameter
from pandas import DataFrame
import talib.abstract as ta


class S06_Combined_Multi(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    minimal_roi = {"0": 0.10, "60": 0.05, "180": 0.03}
    stoploss = -0.05
    trailing_stop = True
    trailing_stop_positive = 0.02
    trailing_stop_positive_offset = 0.04

    min_signals = IntParameter(2, 4, default=3, space="buy")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        # RSI
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)

        # MACD
        macd = ta.MACD(dataframe, fastperiod=12, slowperiod=26, signalperiod=9)
        dataframe["macd"] = macd["macd"]
        dataframe["macdsignal"] = macd["macdsignal"]

        # Bollinger Bands
        bb = ta.BBANDS(dataframe, timeperiod=20, nbdevup=2.0, nbdevdn=2.0)
        dataframe["bb_lower"] = bb["lowerband"]
        dataframe["bb_upper"] = bb["upperband"]

        # EMA
        dataframe["ema_50"] = ta.EMA(dataframe, timeperiod=50)
        dataframe["ema_200"] = ta.EMA(dataframe, timeperiod=200)

        # 计算信号分数
        dataframe["sig_rsi"] = (dataframe["rsi"] < 35).astype(int)
        dataframe["sig_macd"] = (
            (dataframe["macd"] > dataframe["macdsignal"]) &
            (dataframe["macd"].shift(1) <= dataframe["macdsignal"].shift(1))
        ).astype(int)
        dataframe["sig_bb"] = (dataframe["close"] < dataframe["bb_lower"]).astype(int)
        dataframe["sig_ema"] = (dataframe["ema_50"] > dataframe["ema_200"]).astype(int)
        dataframe["signal_count"] = (
            dataframe["sig_rsi"] + dataframe["sig_macd"] +
            dataframe["sig_bb"] + dataframe["sig_ema"]
        )

        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["signal_count"] >= self.min_signals.value) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["rsi"] > 75) |
            (dataframe["close"] > dataframe["bb_upper"]),
            "exit_long"
        ] = 1
        return dataframe
