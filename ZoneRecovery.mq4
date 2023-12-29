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

input int recoveryZoneGap = 200; // Recovery Gap in Point
input int recoveryZoneExit = 400; // Recovery Exit in Point

bool inTrade = false;
int orderCount;
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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    riskRewardRatio = recoveryZoneExit / recoveryZoneGap;
    multiplier = (riskRewardRatio + 1) / riskRewardRatio;
    orderCount = OrderTotalForCurrentSymbol();

    DrawOBjects();

    return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    DeleteObjects();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    EventListener();

    if(!inTrade) {
        newOrderCount = OrderTotalForCurrentSymbol();

        if(orderCount < newOrderCount) {
            inTrade = true;
            orderCount = newOrderCount;

            HandleFirstOrder();
        }
    } else {
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
            orderCount = OrderTotalForCurrentSymbol();
        }
        if(Bid >= (upperRecoveryZone + (recoveryZoneExit / MathPow(10, Digits)))) {
            CloseAllOrders();

            zoneRecoveryCount = 0;
            buyLotTotal = 0;
            sellLotTotal = 0;
            inTrade = false;
            orderCount = OrderTotalForCurrentSymbol();
        }


        // exit order maksimal zone recovery
        if(nextOrderType == OP_BUY && zoneRecoveryCount == 8) {
            if(Bid <= middleRecoveryZone) {
                CloseAllOrders();

                zoneRecoveryCount = 0;
                buyLotTotal = 0;
                sellLotTotal = 0;
                inTrade = false;
                orderCount = OrderTotalForCurrentSymbol();
            }
        }
        if(nextOrderType == OP_SELL && zoneRecoveryCount == 8) {
            if(Bid >= middleRecoveryZone) {
                CloseAllOrders();

                zoneRecoveryCount = 0;
                buyLotTotal = 0;
                sellLotTotal = 0;
                inTrade = false;
                orderCount = OrderTotalForCurrentSymbol();
            }
        }
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
void EventListener() {
    int isSuccess;

    if(ObjectGetInteger(0, "btn_buy", OBJPROP_STATE)) {
        ObjectSetInteger(0, "btn_buy", OBJPROP_STATE, 0);

        isSuccess = OrderSend(Symbol(), OP_BUY, 0.01, Ask, 5, 0, 0);
    }

    if(ObjectGetInteger(0, "btn_sell", OBJPROP_STATE)) {
        ObjectSetInteger(0, "btn_sell", OBJPROP_STATE, 0);

        isSuccess = OrderSend(Symbol(), OP_SELL, 0.01, Bid, 5, 0, 0);
    }
}
//+------------------------------------------------------------------+
int OrderTotalForCurrentSymbol() {
    int count = 0;

    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol()) {
                count++;
            }
        }
    }

    return count;
}
//+------------------------------------------------------------------+
int GetLatestOrderTicket() {
    int latestOrderTicket = -1;
    datetime latestOrderTime = NULL;

    for(int i = OrdersTotal()-1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol()) {
                if(OrderOpenTime() > latestOrderTime) {
                    if(OrderType() == OP_BUY || OrderType() == OP_SELL) {
                        latestOrderTime = OrderOpenTime();
                        latestOrderTicket = OrderTicket();
                    }
                }
            }
        }
    }

    return latestOrderTicket;
}
//+------------------------------------------------------------------+
void HandleFirstOrder() {
    int isSuccess;
    double slPrice;
    double tpPrice;

    if(OrderSelect(GetLatestOrderTicket(), SELECT_BY_TICKET)) {
        if(OrderType() == OP_BUY) {
            zoneRecoveryCount++;
            buyLotTotal += OrderLots();

            upperRecoveryZone = OrderOpenPrice();
            lowerRecoveryZone = OrderOpenPrice() - (recoveryZoneGap / MathPow(10, Digits));
            middleRecoveryZone = (upperRecoveryZone + lowerRecoveryZone) / 2;

            slPrice = OrderOpenPrice() - ((recoveryZoneExit + recoveryZoneGap) / MathPow(10, Digits));
            tpPrice = OrderOpenPrice() + (recoveryZoneExit / MathPow(10, Digits));

            isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), slPrice, tpPrice, 0);

            nextOrderType = OP_SELL;
            CreateNextRecoveryOrder(nextOrderType);
        }

        if(OrderType() == OP_SELL) {
            zoneRecoveryCount++;
            sellLotTotal += OrderLots();

            upperRecoveryZone = OrderOpenPrice() + (recoveryZoneGap / MathPow(10, Digits));
            lowerRecoveryZone = OrderOpenPrice();
            middleRecoveryZone = (upperRecoveryZone + lowerRecoveryZone) / 2;

            slPrice = OrderOpenPrice() + ((recoveryZoneExit + recoveryZoneGap) / MathPow(10, Digits));
            tpPrice = OrderOpenPrice() - (recoveryZoneExit / MathPow(10, Digits));

            isSuccess = OrderModify(OrderTicket(), OrderOpenPrice(), slPrice, tpPrice, 0);

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

    Print("Ini Harga keluarnya!!! " + DoubleToStr(Bid));

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
