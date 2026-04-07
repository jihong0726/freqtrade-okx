"""
策略 2: MACD 金叉死叉策略
=========================
逻辑：MACD 线上穿信号线买入，下穿卖出
适合：趋势行情
"""
from freqtrade.strategy import IStrategy
from pandas import DataFrame
import talib.abstract as ta


class S02_MACD_Cross(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    minimal_roi = {"0": 0.08, "60": 0.04, "120": 0.02}
    stoploss = -0.06
    trailing_stop = True
    trailing_stop_positive = 0.015
    trailing_stop_positive_offset = 0.04

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        macd = ta.MACD(dataframe, fastperiod=12, slowperiod=26, signalperiod=9)
        dataframe["macd"] = macd["macd"]
        dataframe["macdsignal"] = macd["macdsignal"]
        dataframe["macdhist"] = macd["macdhist"]
        dataframe["ema_200"] = ta.EMA(dataframe, timeperiod=200)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["macd"] > dataframe["macdsignal"]) &
            (dataframe["macd"].shift(1) <= dataframe["macdsignal"].shift(1)) &
            (dataframe["close"] > dataframe["ema_200"]) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["macd"] < dataframe["macdsignal"]) &
            (dataframe["macd"].shift(1) >= dataframe["macdsignal"].shift(1)),
            "exit_long"
        ] = 1
        return dataframe
