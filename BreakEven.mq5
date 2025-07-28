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
input double                  gatilhoBE = 2;//Gatilho BreakEven

double                        PRC;//Preço normalizado
double                        STL;//StopLoss normalizado
double                        TKP;//TakeProfit normalizado

double                        smaArray[];
int                           smaHandle;

bool                          posAberta;
bool                          ordPendente;
bool                          beAtivo;

MqlTick                       ultimoTick;
MqlRates                      rates[];

int OnInit()
  {
      smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, ma_metodo, ma_preco);
      if(smaHandle==INVALID_HANDLE)
         {
            Print("Erro ao criar média móvel - erro", GetLastError());
            return(INIT_FAILED);
         }
      ArraySetAsSeries(smaArray, true);
      ArraySetAsSeries(rates, true);     
      
      trade.SetTypeFilling(preenchimento);
      trade.SetDeviationInPoints(desvPts);
      trade.SetExpertMagicNumber(magicNum);
      
      return(INIT_SUCCEEDED);
  }
void OnTick()
  {               
      if(!SymbolInfoTick(Symbol(),ultimoTick))
         {
            Alert("Erro ao obter informações de Preços: ", GetLastError());
            return;
         }
         
      if(CopyRates(_Symbol, _Period, 0, 3, rates)<0)
         {
            Alert("Erro ao obter as informações de MqlRates: ", GetLastError());
            return;
         }
      
      if(CopyBuffer(smaHandle, 0, 0, 3, smaArray)<0)
         {
            Alert("Erro ao copiar dados da média móvel: ", GetLastError());
            return;
         }
         
      posAberta = false;
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {  
                  posAberta = true;
                  break;
               }
         }
         
      ordPendente = false;
      for(int i = OrdersTotal()-1; i>=0; i--)
         {
            ulong ticket = OrderGetTicket(i);
            string symbol = OrderGetString(ORDER_SYMBOL);
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {
                  ordPendente = true;
                  break;
               }
         }
      
      if(!posAberta)
         {
            beAtivo = false;
         }
         
      if(posAberta && !beAtivo)
         {
            BreakEven(ultimoTick.last);
         }
            
      if(ultimoTick.last>smaArray[0] && rates[1].close>rates[1].open && !posAberta && !ordPendente)
         {
            PRC = NormalizeDouble(ultimoTick.ask, _Digits);
            STL = NormalizeDouble(PRC - stopLoss, _Digits);
            TKP = NormalizeDouble(PRC + takeProfit, _Digits);
            if(trade.Buy(lote, _Symbol, PRC, STL, TKP, ""))
               {
                  Print("Ordem de Compra - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Compra - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }
      else if(ultimoTick.last<smaArray[0] && rates[1].close<rates[1].open && !posAberta && !ordPendente)
         {
            PRC = NormalizeDouble(ultimoTick.bid, _Digits);
            STL = NormalizeDouble(PRC + stopLoss, _Digits);
            TKP = NormalizeDouble(PRC - takeProfit, _Digits);
            if(trade.Sell(lote, _Symbol, PRC, STL, TKP, ""))
               {
                  Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
            else
               {
                  Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
               }
         }   
  }
//---
//---
void BreakEven(double preco)
   {
      for(int i = PositionsTotal()-1; i>=0; i--)
         {
            string symbol = PositionGetSymbol(i);
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(symbol == _Symbol && magic == magicNum)
               {
                  ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
                  double PrecoEntrada = PositionGetDouble(POSITION_PRICE_OPEN);
                  double TakeProfitCorrente = PositionGetDouble(POSITION_TP);
                  if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                     {
                        if( preco >= (PrecoEntrada + gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada, TakeProfitCorrente))
                                 {
                                    Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {
                                    Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }                           
                     }
                  else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
                     {
                        if( preco <= (PrecoEntrada - gatilhoBE) )
                           {
                              if(trade.PositionModify(PositionTicket, PrecoEntrada, TakeProfitCorrente))
                                 {
                                    Print("BreakEven - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                    beAtivo = true;
                                 }
                              else
                                 {
                                    Print("BreakEven - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
                                 }
                           }
                     }
               }
         }
   }
