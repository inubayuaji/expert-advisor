//+------------------------------------------------------------------+
//|                                                   GridSystem.mq4 |
//|                                                     Inu Bayu Aji |
//|                     https://github.com/inubayuaji/expert-advisor |
//+------------------------------------------------------------------+

/**
# Error
- jika ada spike harga sistem grid error
 * 2024-01-05 sd 2024-01-06 (USDCHF) -> spike error
- upperGridLevel dan lowerGridLevel tidak tetap masih bergeser2, alasanya kenapa tidak tahu

# Pengembangan kedepan
- triger entry pertama pada wilayah tertentu mengunakan hline dengan nama khusus
*/

#property copyright "Inu Bayu Aji"
#property link      "https://github.com/inubayuaji/expert-advisor"
#property version   "1.00"
#property strict
//--- input parameters
input int       gapSize=200;
input double    lotSize=0.01;
//--- global variable
int             magicNumber = 1000002;
int             gridDirection;
int             gridLevel = 0;
int             gridUpCount = 0;
int             gridDownCount = 0;
bool            isOnGrid = false;
double          upperGridLevel;
double          lowerGridLevel;
double          gapSizePoint;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    gapSizePoint = gapSize / MathPow(10, Digits);

    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(isOnGrid) {
        if(Bid >= upperGridLevel) {
            gridLevel++;

            // max grid level 4 harus close
            if(gridLevel == 4) {
                GridClose();

                return;
            }

            // harga kembali naik dari turun
            if(gridDownCount < 0) {
                GridClose();

                return;
            }

            // harga bergerak naik terus
            gridUpCount = gridLevel;
            upperGridLevel = upperGridLevel + gapSizePoint;
            lowerGridLevel = lowerGridLevel + gapSizePoint;

            GridPruning();
            GridOrder();
        }

        if(Bid <= lowerGridLevel) {
            gridLevel--;

            // max grid level 4 harus close
            if(gridLevel == 4) {
                GridClose();

                return;
            }

            // harga kembali turun
            if(gridUpCount > 0) {
                GridClose();

                return;
            }

            // harga bergerak turun terus
            gridDownCount = gridLevel;
            upperGridLevel = upperGridLevel - gapSizePoint;
            lowerGridLevel = lowerGridLevel - gapSizePoint;

            GridPruning();
            GridOrder();
        }
    } else {
        isOnGrid = true;
        upperGridLevel = Bid + gapSizePoint;
        lowerGridLevel = Bid - gapSizePoint;

        GridOrder();
    }
}
//+------------------------------------------------------------------+
void GridOrder() {
    int isSuccess;

    isSuccess = OrderSend(Symbol(), OP_BUY, lotSize, Ask, 5, 0, 0, IntegerToString(gridLevel), magicNumber);
    isSuccess = OrderSend(Symbol(), OP_SELL, lotSize, Bid, 5, 0, 0, IntegerToString(gridLevel), magicNumber);
}
//+------------------------------------------------------------------+
void GridPruning() {
    int isSuccess;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber) {
                if(OrderProfit() > 0) {
                    if(OrderType() == OP_BUY) {
                        isSuccess = OrderClose(OrderTicket(), OrderLots(), Bid, 5);
                    }

                    if(OrderType() == OP_SELL) {
                        isSuccess = OrderClose(OrderTicket(), OrderLots(), Ask, 5);
                    }
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
void GridClose() {
    int isSuccess;

    isOnGrid = false;
    gridLevel = 0;
    gridUpCount = 0;
    gridDownCount = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        if(OrderSelect(i, SELECT_BY_POS)) {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == magicNumber) {
                if(OrderType() == OP_BUY) {
                    isSuccess = OrderClose(OrderTicket(), OrderLots(), Bid, 5);
                }

                if(OrderType() == OP_SELL) {
                    isSuccess = OrderClose(OrderTicket(), OrderLots(), Ask, 5);
                }
            }
        }
    }
}
//+------------------------------------------------------------------+
