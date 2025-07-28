#include <Trade\Trade.mqh>
CTrade trade;

input int                     ma_periodo = 20;//Período da Média
input int                     ma_desloc = 0;//Deslocamento da Média
input ENUM_MA_METHOD          ma_metodo = MODE_SMA;//Método Média Móvel
input ENUM_APPLIED_PRICE      ma_preco = PRICE_CLOSE;//Preço para Média
input ulong                   magicNum = 123456;//Magic Number
input ulong                   desvPts = 50;//Desvio em Pontos
input ENUM_ORDER_TYPE_FILLING preenchimento = ORDER_FILLING_RETURN;//Preenchimento da Ordem

input double                  lote = 5.0;//Volume
input double                  stopLoss = 5;//Stop Loss
input double                  takeProfit = 5;//Take Profit

double                        smaArray[];
int                           smaHandle;

MqlTick                       ultimoTick;

int OnInit()
  {
      smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, ma_metodo, ma_preco);
      if(smaHandle==INVALID_HANDLE)
         {
            Print("Erro ao criar média móvel - erro", GetLastError());
            return(INIT_FAILED);
         }
      ArraySetAsSeries(smaArray, true);
      
      trade.SetTypeFilling(preenchimento);
      trade.SetDeviationInPoints(desvPts);
      trade.SetExpertMagicNumber(magicNum);
      
      return(INIT_SUCCEEDED);
  }
void OnTick()
  {               
      if(!SymbolInfoTick(_Symbol, ultimoTick))
         {
            Alert("Erro ao obter informações de preços: ", GetLastError());
            return;
         }
                 
      if(CopyBuffer(smaHandle, 0, 0, 3, smaArray)<0)
         {
         Alert("Erro ao copiar dados da média móvel: ", GetLastError());
         return;
         }
      
      if(ultimoTick.last>smaArray[0] && PositionsTotal()==0)
         {            
            if(trade.Buy(lote, _Symbol, ultimoTick.ask, ultimoTick.ask-stopLoss, ultimoTick.ask+takeProfit, ""))
               {
                  Print("Ordem de Compra - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Compra - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }
      else if(ultimoTick.last<smaArray[0] && PositionsTotal()==0)
         {
            if(trade.Sell(lote, _Symbol, ultimoTick.bid, ultimoTick.bid+stopLoss, ultimoTick.bid-takeProfit, ""))
               {
                  Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }   
  }
