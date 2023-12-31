//+------------------------------------------------------------------+
//|                                                 ZoneRecovery.mq4 |
//|                                                     Inu Bayu Aji |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

/**
# Error
- close all order juga tidak berfungsi karena ada spread

# Event untuk backtest
 * 6 januari 2021 posisi awal sell (10)
 * 8 januari 2021 posisi awal buy (6)
 * 12 januari 2021 posisi awal sell (6)

# Pengembangan kedepan
- risk menenegement tidak ada, kapan waktunya tidak lagi menggunakan zone recovery
- kalkulasi maxsimal lot tidak ada sehingga diperlukkan mekanisme berapa maksimal lot
- mencegah terjadinya banayak zone recovery
- cara menghitung compund atau inisial lot saat modal sudah bertamba
- calculasi nanti disederhanakkan agar perhitungan lebih cepat

# Catatan
untuk penerapan dasar EA ini sudah sesui tinggal kurang dikembangkan lagi agar lebih baik
sudah bisa dilakukan testing ke pair lainya
*/
#property copyright "Inu Bayu Aji"
#property link      "https://github.com/inubayuaji"
#property version   "1.00"
#property strict
//--- input paramater
input int recoveryZoneGap = 200; // Recovery Gap in Point
input int recoveryZoneExit = 400; // Recovery Exit in Point
input double initialLotSize = 0.01; // Initial Lot Size
//--- global variable
bool inTrade = false;
int newOrderCount;
int nextOrderType;
int zoneRecoveryCount = 0;
double buyLotTotal = 0;
double sellLotTotal = 0;
double upperRecoveryZone;
double lowerRecoveryZone;
double middleRecoveryZone;
double riskRewardRatio;
double multiplier;
//+------------------------------------------------------------------+
int OnInit() {
    riskRewardRatio = recoveryZoneExit / recoveryZoneGap;
    multiplier = (riskRewardRatio + 1) / riskRewardRatio;

    DrawOBjects();

    if(initialLotSize > MarketInfo(Symbol(), MODE_MAXLOT) || initialLotSize < MarketInfo(Symbol(), MODE_MINLOT)) {
        return INIT_PARAMETERS_INCORRECT;
    }

    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    DeleteObjects();
}
//+------------------------------------------------------------------+
void OnTick() {
    if(IsTesting()) {
        TestingEventListener();
    }

    if(inTrade) {
        // make next recovery zone
        if(nextOrderType == OP_BUY && zoneRecoveryCount < 8) {
            if(Bid <= lowerRecoveryZone) {
                zoneRecoveryCount++;
                CreateNextRecoveryOrder(nextOrderType);
            }
        }
        if(nextOrderType == OP_SELL && zoneRecoveryCount < 8) {
            if(Bid >= upperRecoveryZone) {
                zoneRecoveryCount++;
                CreateNextRecoveryOrder(nextOrderType);
            }
        }

        // exit recovery zone
        if(Bid <= (lowerRecoveryZone - (recoveryZoneExit / MathPow(10, Digits)))) {
            CloseAllOrders();

            zoneRecoveryCount = 0;
            buyLotTotal = 0;
            sellLotTotal = 0;
            inTrade = false;
        }
        if(Bid >= (upperRecoveryZone + (recoveryZoneExit / MathPow(10, Digits)))) {
            CloseAllOrders();

            zoneRecoveryCount = 0;
            buyLotTotal = 0;
            sellLotTotal = 0;
            inTrade = false;
        }


        // exit zone recovery max order
        if(nextOrderType == OP_BUY && zoneRecoveryCount == 8) {
            if(Bid <= middleRecoveryZone) {
                CloseAllOrders();

                zoneRecoveryCount = 0;
                buyLotTotal = 0;
                sellLotTotal = 0;
                inTrade = false;
            }
        }
        if(nextOrderType == OP_SELL && zoneRecoveryCount == 8) {
            if(Bid >= middleRecoveryZone) {
                CloseAllOrders();

                zoneRecoveryCount = 0;
                buyLotTotal = 0;
                sellLotTotal = 0;
                inTrade = false;
            }
        }
    }
}
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long& lparam,
                  const double& dparam,
                  const string& sparam) {
    if(id == CHARTEVENT_OBJECT_CLICK) {
        if(sparam == "btn_buy") {
            CreateFirstOrder(OP_BUY);

            Sleep(150);
            ObjectSetInteger(0, "btn_buy", OBJPROP_STATE, 0);
        }

        if(sparam == "btn_sell") {
            CreateFirstOrder(OP_SELL);

            Sleep(150);
            ObjectSetInteger(0, "btn_sell", OBJPROP_STATE, 0);
        }
    }
}
//+------------------------------------------------------------------+
void TestingEventListener() {
    if(ObjectGetInteger(0, "btn_buy", OBJPROP_STATE)) {
        CreateFirstOrder(OP_BUY);

        ObjectSetInteger(0, "btn_buy", OBJPROP_STATE, 0);
    }

    if(ObjectGetInteger(0, "btn_sell", OBJPROP_STATE)) {
        CreateFirstOrder(OP_SELL);

        ObjectSetInteger(0, "btn_sell", OBJPROP_STATE, 0);
    }
}
//+------------------------------------------------------------------+
void DrawOBjects() {
    ObjectCreate(0, "btn_buy", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "btn_buy", OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, "btn_buy", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "btn_buy", OBJPROP_YDISTANCE, 25);
    ObjectSetString(0, "btn_buy", OBJPROP_TEXT, "Buy");

    ObjectCreate(0, "btn_sell", OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, "btn_sell", OBJPROP_CORNER, CORNER_LEFT_LOWER);
    ObjectSetInteger(0, "btn_sell", OBJPROP_XDISTANCE, 70);
    ObjectSetInteger(0, "btn_sell", OBJPROP_YDISTANCE, 25);
    ObjectSetString(0, "btn_sell", OBJPROP_TEXT, "Sell");
}
//+------------------------------------------------------------------+
void DeleteObjects() {
    ObjectDelete(0, "btn_buy");
    ObjectDelete(0, "btn_sell");
}
//+------------------------------------------------------------------+
void CreateFirstOrder(int orderType) {
    double entryPrice;
    double slPrice;
    double tpPrice;

    if(!inTrade && orderType == OP_BUY) {
        entryPrice = Ask;
        slPrice = entryPrice - ((recoveryZoneExit + recoveryZoneGap) / MathPow(10, Digits));
        tpPrice = entryPrice + (recoveryZoneExit / MathPow(10, Digits));

        if(OrderSend(Symbol(), OP_BUY, initialLotSize, entryPrice, 5, slPrice, tpPrice)) {
            inTrade = true;
            buyLotTotal += initialLotSize;
            zoneRecoveryCount++;

            upperRecoveryZone = entryPrice;
            lowerRecoveryZone = entryPrice - (recoveryZoneGap / MathPow(10, Digits));
            middleRecoveryZone = (upperRecoveryZone + lowerRecoveryZone) / 2;

            nextOrderType = OP_SELL;
            CreateNextRecoveryOrder(nextOrderType);
        }
    }

    if(!inTrade && orderType == OP_SELL) {
        entryPrice = Bid;
        slPrice = entryPrice + ((recoveryZoneExit + recoveryZoneGap) / MathPow(10, Digits));
        tpPrice = entryPrice - (recoveryZoneExit / MathPow(10, Digits));

        if(OrderSend(Symbol(), OP_SELL, initialLotSize, entryPrice, 5,slPrice, tpPrice)) {
            inTrade = true;
            sellLotTotal += initialLotSize;
            zoneRecoveryCount++;

            upperRecoveryZone = entryPrice + (recoveryZoneGap / MathPow(10, Digits));
            lowerRecoveryZone = entryPrice;
            middleRecoveryZone = (upperRecoveryZone + lowerRecoveryZone) / 2;

            nextOrderType = OP_BUY;
            CreateNextRecoveryOrder(nextOrderType);
        }
    }
}
//+------------------------------------------------------------------+
void CreateNextRecoveryOrder(int orderType) {
    int isSuccess;
    double lotSize = 0;
    double slPrice;
    double tpPrice;

    if(orderType == OP_BUY) {
        nextOrderType = OP_SELL;
        lotSize = NormalizeDouble(((multiplier * sellLotTotal) - buyLotTotal) * 1.1, 2); // masih salah disii
        buyLotTotal += lotSize;
        slPrice = lowerRecoveryZone - (recoveryZoneExit / MathPow(10, Digits));
        tpPrice = upperRecoveryZone + (recoveryZoneExit / MathPow(10, Digits));

        isSuccess = OrderSend(Symbol(), OP_BUYSTOP, lotSize, upperRecoveryZone, 5, slPrice, tpPrice);
    }

    if(orderType == OP_SELL) {
        nextOrderType = OP_BUY;
        lotSize = NormalizeDouble(((multiplier * buyLotTotal) - sellLotTotal) * 1.1, 2); // masih salah disii
        sellLotTotal += lotSize;
        slPrice = upperRecoveryZone + (recoveryZoneExit / MathPow(10, Digits));
        tpPrice = lowerRecoveryZone - (recoveryZoneExit / MathPow(10, Digits));

        isSuccess = OrderSend(Symbol(), OP_SELLSTOP, lotSize, lowerRecoveryZone, 5, slPrice, tpPrice);
    }
}
//+------------------------------------------------------------------+
void CloseAllOrders() {
    int isSuccess;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol()) {
                if(OrderType() == OP_BUY) {
                    isSuccess = OrderClose(OrderTicket(), OrderLots(), Bid, 5);
                }

                if(OrderType() == OP_SELL) {
                    isSuccess = OrderClose(OrderTicket(), OrderLots(), Ask, 5);
                }

                if(OrderType() == OP_BUYSTOP || OrderType() == OP_SELLSTOP) {
                    isSuccess = OrderDelete(OrderTicket());
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
