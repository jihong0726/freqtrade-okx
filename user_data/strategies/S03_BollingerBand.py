"""
策略 3: 布林带均值回归策略
===========================
逻辑：价格触及下轨买入，触及上轨卖出
适合：区间震荡行情
"""
from freqtrade.strategy import IStrategy, DecimalParameter
from pandas import DataFrame
import talib.abstract as ta


class S03_BollingerBand(IStrategy):
    INTERFACE_VERSION = 3
    timeframe = "1h"
    minimal_roi = {"0": 0.06, "45": 0.03, "90": 0.015}
    stoploss = -0.04
    trailing_stop = False

    # 可优化参数
    bb_buy_offset = DecimalParameter(0.97, 1.0, default=0.985, space="buy")
    bb_sell_offset = DecimalParameter(1.0, 1.03, default=1.015, space="sell")

    def populate_indicators(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        bb = ta.BBANDS(dataframe, timeperiod=20, nbdevup=2.0, nbdevdn=2.0)
        dataframe["bb_upper"] = bb["upperband"]
        dataframe["bb_middle"] = bb["middleband"]
        dataframe["bb_lower"] = bb["lowerband"]
        dataframe["bb_width"] = (dataframe["bb_upper"] - dataframe["bb_lower"]) / dataframe["bb_middle"]
        dataframe["rsi"] = ta.RSI(dataframe, timeperiod=14)
        return dataframe

    def populate_entry_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] < dataframe["bb_lower"] * self.bb_buy_offset.value) &
            (dataframe["rsi"] < 40) &
            (dataframe["volume"] > 0),
            "enter_long"
        ] = 1
        return dataframe

    def populate_exit_trend(self, dataframe: DataFrame, metadata: dict) -> DataFrame:
        dataframe.loc[
            (dataframe["close"] > dataframe["bb_upper"] * self.bb_sell_offset.value) |
            (dataframe["rsi"] > 75),
            "exit_long"
        ] = 1
        return dataframe
