#include <Trade\Trade.mqh>
CTrade trade;

input int ma_periodo = 20;//Período da Média
input int ma_desloc = 0;//Deslocamento da Média
input ulong magicNum = 123456;//Magic Number
input ulong desvPts = 50;//Desvio em Pontos

input double lote = 5.0;//Volume
input double stopLoss = 5;//Stop Loss
input double takeProfit = 5;//Take Profit

double   ask, bid, last;
double   smaArray[];
int      smaHandle;

int OnInit()
  {
      smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, MODE_SMA, PRICE_CLOSE);
      ArraySetAsSeries(smaArray, true);
      
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
      trade.SetDeviationInPoints(desvPts);
      trade.SetExpertMagicNumber(magicNum);
      
      return(INIT_SUCCEEDED);
  }
void OnTick()
  {    
      ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      last = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
      
      CopyBuffer(smaHandle, 0, 0, 3, smaArray);
      
      if(last>smaArray[0] && PositionsTotal()==0)
         {
            //Comment("Compra");
            trade.Buy(lote, _Symbol, ask, ask-stopLoss, ask+takeProfit, "");
         }
      else if(last<smaArray[0] && PositionsTotal()==0)
         {
            //Comment("Venda");
            trade.Sell(lote, _Symbol, bid, bid+stopLoss, bid-takeProfit, ""); 
         }   
  }
