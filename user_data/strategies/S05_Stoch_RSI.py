"""
策略 5: 随机 RSI + 成交量策略
===============================
逻辑：Stochastic RSI 超卖 + 成交量放大买入
适合：短线波段
"""
from freqtrade.strategy import IStrategy, IntParameter, DecimalParameter
from pandas import DataFrame
import talib.abstract as ta


class S05_Stoch_RSI(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "15m"
    minimal_roi = {"0": 0.03, "15": 0.02, "30": 0.01, "60": 0.005}
    stoploss = -0.03
    trailing_stop = True
    trailing_stop_positive = 0.008
    trailing_stop_positive_offset = 0.02

    stoch_buy = IntParameter(10, 30, default=20, space="buy")
    stoch_sell = IntParameter(70, 90, default=80, space="sell")
    vol_mult = DecimalParameter(1.2, 3.0, default=1.5, space="buy")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        stoch_rsi = ta.STOCHRSI(dataframe, timeperiod=14, fastk_period=3, fastd_period=3)
        dataframe["stoch_k"] = stoch_rsi["fastk"]
        dataframe["stoch_d"] = stoch_rsi["fastd"]
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)
        dataframe["vol_sma"] = dataframe["volume"].rolling(window=20).mean()
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["stoch_k"] < self.stoch_buy.value) &
            (dataframe["stoch_k"] > dataframe["stoch_d"]) &
            (dataframe["stoch_k"].shift(1) <= dataframe["stoch_d"].shift(1)) &
            (dataframe["volume"] > dataframe["vol_sma"] * self.vol_mult.value) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["stoch_k"] > self.stoch_sell.value) &
            (dataframe["stoch_k"] < dataframe["stoch_d"]),
            "exit_long"
        ] = 1
        return dataframe
