#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3

//--- Plot 1: Gamma Buy Volume (Calls)
#property indicator_label1  "Gamma Buy (Calls)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLimeGreen
#property indicator_width1  2

//--- Plot 2: Gamma Sell Volume (Puts)
#property indicator_label2  "Gamma Sell (Puts)"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrTomato
#property indicator_width2  2

//--- Plot 3: Net GEX Volume (Calls - Puts)
#property indicator_label3  "Net GEX"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDodgerBlue
#property indicator_width3  2

//--- Inputs
input int    InpUpdatePeriodSeconds = 1800;    // Intervalo de atualização (segundos)
input bool   InpUseOpenInterest     = false;   // Usar Open Interest em vez de Volume
input bool   InpUseProxy            = false;   // Usar proxy
input string InpProxyServer         = "";      // Servidor proxy
input int    InpProxyPort           = 0;       // Porta proxy

//--- Buffers
double BufferGammaBuy[];   // Calls
double BufferGammaSell[];  // Puts
double BufferNetGEX[];     // Calls - Puts

//--- Estado
static datetime lastUpdateTime = 0;
static double   lastGammaBuy   = 0.0;
static double   lastGammaSell  = 0.0;
static double   lastNetGEX     = 0.0;

//--- Estruturas
struct OptionData {
   string option;
   string callPut;          // "C" ou "P"
   double strike;
   long   open_interest;
   long   opt_volume;       // volume do dia (se disponível)
   double gamma;            // gamma por contrato
};

struct OptionsResponse {
   double close;
   OptionData options[];
};

int OnInit()
{
   SetIndexBuffer(0, BufferGammaBuy, INDICATOR_DATA);
   SetIndexBuffer(1, BufferGammaSell, INDICATOR_DATA);
   SetIndexBuffer(2, BufferNetGEX, INDICATOR_DATA);

   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   string cboe = SymbolToCBOE(_Symbol);
   IndicatorSetString(INDICATOR_SHORTNAME, "GEX Volume (" + cboe + ")");
   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total <= 0)
      return 0;

   datetime nowTime = time[rates_total - 1];

   bool shouldUpdate = (nowTime - lastUpdateTime >= InpUpdatePeriodSeconds) || (prev_calculated == 0);

   if(shouldUpdate)
   {
      lastUpdateTime = nowTime;

      OptionsResponse resp;
      string cboeSymbol = SymbolToCBOE(_Symbol);

      if(FetchOptionsData(cboeSymbol, resp))
      {
         double sumGammaVolCalls = 0.0;
         double sumGammaVolPuts  = 0.0;

         for(int i = 0; i < ArraySize(resp.options); i++)
         {
            double weight = 0.0;
            if(InpUseOpenInterest)
            {
               weight = (double)resp.options[i].open_interest;
            }
            else
            {
               // Preferir volume; se 0, cair para OI
               weight = (double)resp.options[i].opt_volume;
               if(weight <= 0.0)
                  weight = (double)resp.options[i].open_interest;
            }

            if(weight <= 0.0 || resp.options[i].gamma == 0.0)
               continue;

            double gammaWeighted = resp.options[i].gamma * weight;

            if(resp.options[i].callPut == "C")
               sumGammaVolCalls += gammaWeighted;
            else if(resp.options[i].callPut == "P")
               sumGammaVolPuts  += gammaWeighted;
         }

         lastGammaBuy  = sumGammaVolCalls;
         lastGammaSell = sumGammaVolPuts;
         lastNetGEX    = lastGammaBuy - lastGammaSell;

         PrintFormat("[GEX] Updated: Buy=%.2f | Sell=%.2f | Net=%.2f (Use %s)",
                     lastGammaBuy, lastGammaSell, lastNetGEX,
                     InpUseOpenInterest ? "OpenInterest" : "Volume");
      }
      else
      {
         Print("[GEX] Falha ao obter dados da CBOE. Mantendo últimos valores.");
      }
   }

   // Preencher os buffers com o último valor conhecido
   ArrayResize(BufferGammaBuy,  rates_total);
   ArrayResize(BufferGammaSell, rates_total);
   ArrayResize(BufferNetGEX,    rates_total);

   for(int i = 0; i < rates_total; i++)
   {
      BufferGammaBuy[i]  = lastGammaBuy;
      BufferGammaSell[i] = -lastGammaSell; // mostrar vendas como negativo
      BufferNetGEX[i]    = lastNetGEX;
   }

   return(rates_total);
}

//================ Auxiliares de dados ================//

string SymbolToCBOE(string symbol)
{
   if(symbol=="US500" || symbol=="US500IDX" || symbol=="SPX500") return "SPX";
   if(symbol=="SPX" || symbol=="$SPX") return "SPX";
   if(symbol=="SPY") return "SPY";
   if(symbol=="QQQ") return "QQQ";
   if(symbol=="IWM") return "IWM";
   if(symbol=="VIX") return "VIX";
   return symbol;
}

bool FetchOptionsData(string symbol, OptionsResponse &resp)
{
   // Atenção: é necessário permitir a URL abaixo em Ferramentas > Opções > Guia "Assessor Expert" > WebRequest
   string url = "https://cdn.cboe.com/api/global/delayed_quotes/options/_" + symbol + ".json";
   string headers = "User-Agent: MetaTrader5\r\n";

   if(InpUseProxy && InpProxyServer != "" && InpProxyPort > 0)
   {
      // Configuração de proxy opcional (MT5 usa configurações do terminal, este trecho é ilustrativo)
      // Não há API direta para proxy por requisição; manter comentário para referência
   }

   uchar data[];
   uchar result[];
   string response_headers;
   int timeout = 7000;

   int res = WebRequest("GET", url, headers, timeout, data, result, response_headers);
   if(res != 200)
   {
      Print("HTTP Error: ", res, " ao acessar ", url);
      return false;
   }

   string json = CharArrayToString(result);

   int closeStart = StringFind(json, "\"close\":");
   if(closeStart != -1)
   {
     int closeEnd = StringFind(json, ",", closeStart);
     if(closeEnd == -1) closeEnd = StringFind(json, "}", closeStart);
     if(closeEnd != -1)
     {
        string closeStr = StringSubstr(json, closeStart + 8, closeEnd - closeStart - 8);
        resp.close = StringToDouble(closeStr);
     }
   }

   int optionsStart = StringFind(json, "\"options\":[");
   if(optionsStart == -1) return false;
   int optionsEnd = StringFind(json, "]", optionsStart);
   if(optionsEnd == -1) return false;

   string optionsJson = StringSubstr(json, optionsStart + 10, optionsEnd - optionsStart - 10);
   if(!ParseOptionsData(optionsJson, resp.options)) return false;

   return true;
}

bool ParseOptionsData(string json, OptionData &options[])
{
   int count = 0;
   int pos = 0;
   while((pos = StringFind(json, "{", pos)) != -1)
   {
      count++;
      pos++;
   }
   if(count == 0) return false;

   ArrayResize(options, count);

   int index = 0;
   pos = 0;
   while(pos < (int)StringLen(json) && index < count)
   {
      int start = StringFind(json, "{", pos);
      if(start == -1) break;
      int end   = StringFind(json, "}", start);
      if(end == -1) break;

      string item = StringSubstr(json, start, end - start + 1);
      if(ParseSingleOption(item, options[index]))
         index++;

      pos = end + 1;
   }

   ArrayResize(options, index);
   return index > 0;
}

bool ParseSingleOption(string json, OptionData &opt)
{
   // option symbol
   int sStart = StringFind(json, "\"option\":\"");
   if(sStart == -1) return false;
   int sEnd = StringFind(json, "\"", sStart + 10);
   if(sEnd == -1) return false;
   opt.option = StringSubstr(json, sStart + 10, sEnd - sStart - 10);

   // call/put e strike a partir do símbolo padrão CBOE, ex: SPX 240117C04700000
   opt.callPut = StringSubstr(opt.option, StringLen(opt.option) - 9, 1); // C/P
   string strikeStr = StringSubstr(opt.option, StringLen(opt.option) - 8, 5);
   opt.strike = StringToDouble(strikeStr);

   // open_interest
   int oiStart = StringFind(json, "\"open_interest\":");
   if(oiStart != -1)
   {
      int oiEnd = StringFind(json, ",", oiStart);
      if(oiEnd == -1) oiEnd = StringFind(json, "}", oiStart);
      if(oiEnd != -1)
      {
         string oiStr = StringSubstr(json, oiStart + 16, oiEnd - oiStart - 16);
         opt.open_interest = (long)StringToInteger(oiStr);
      }
   }

   // volume (campo pode aparecer como "volume" ou "option_volume")
   int volStart = StringFind(json, "\"volume\":");
   if(volStart == -1)
      volStart = StringFind(json, "\"option_volume\":");
   if(volStart != -1)
   {
      int volEnd = StringFind(json, ",", volStart);
      if(volEnd == -1) volEnd = StringFind(json, "}", volStart);
      if(volEnd != -1)
      {
         string volStr = StringSubstr(json, volStart + (StringSubstr(json, volStart, 8) == "\"volume\"" ? 9 : 16), volEnd - volStart - (StringSubstr(json, volStart, 8) == "\"volume\"" ? 9 : 16));
         opt.opt_volume = (long)StringToInteger(volStr);
      }
   }

   // gamma
   int gStart = StringFind(json, "\"gamma\":");
   if(gStart != -1)
   {
      int gEnd = StringFind(json, ",", gStart);
      if(gEnd == -1) gEnd = StringFind(json, "}", gStart);
      if(gEnd != -1)
      {
         string gStr = StringSubstr(json, gStart + 9, gEnd - gStart - 9);
         opt.gamma = StringToDouble(gStr);
      }
   }

   return true;
}