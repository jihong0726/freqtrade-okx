"""
策略 1: RSI 反转策略
====================
逻辑：RSI 超卖时买入，超买时卖出
适合：震荡行情
"""
from freqtrade.strategy import IStrategy, IntParameter
from pandas import DataFrame
import talib.abstract as ta


class S01_RSI_Reversal(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    minimal_roi = {"0": 0.05, "30": 0.03, "60": 0.02, "120": 0.01}
    stoploss = -0.05
    trailing_stop = True
    trailing_stop_positive = 0.01
    trailing_stop_positive_offset = 0.03

    # 可优化参数
    rsi_buy = IntParameter(20, 40, default=30, space="buy")
    rsi_sell = IntParameter(60, 80, default=70, space="sell")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["rsi"] < self.rsi_buy.value) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["rsi"] > self.rsi_sell.value),
            "exit_long"
        ] = 1
        return dataframe
