"""
策略 4: EMA 多头排列趋势策略
=============================
逻辑：短期 EMA > 中期 EMA > 长期 EMA 时做多，排列破坏时平仓
适合：强趋势行情
"""
from freqtrade.strategy import IStrategy, IntParameter
from pandas import DataFrame
import talib.abstract as ta


class S04_EMA_Trend(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "4h"
    minimal_roi = {"0": 0.12, "120": 0.06, "240": 0.03}
    stoploss = -0.07
    trailing_stop = True
    trailing_stop_positive = 0.02
    trailing_stop_positive_offset = 0.05

    ema_fast = IntParameter(5, 20, default=9, space="buy")
    ema_mid = IntParameter(15, 35, default=21, space="buy")
    ema_slow = IntParameter(40, 70, default=55, space="buy")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe["ema_fast"] = ta.EMA(dataframe, timeperiod=self.ema_fast.value)
        dataframe["ema_mid"] = ta.EMA(dataframe, timeperiod=self.ema_mid.value)
        dataframe["ema_slow"] = ta.EMA(dataframe, timeperiod=self.ema_slow.value)
        dataframe["adx"] = ta.ADX(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["ema_fast"] > dataframe["ema_mid"]) &
            (dataframe["ema_mid"] > dataframe["ema_slow"]) &
            (dataframe["ema_fast"].shift(1) <= dataframe["ema_mid"].shift(1)) &
            (dataframe["adx"] > 25) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["ema_fast"] < dataframe["ema_mid"]) &
            (dataframe["ema_fast"].shift(1) >= dataframe["ema_mid"].shift(1)),
            "exit_long"
        ] = 1
        return dataframe
