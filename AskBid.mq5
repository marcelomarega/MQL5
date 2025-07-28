
void OnTick()
  {
      double ask, bid;
      ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      Comment("Preço ASK = ", ask, "\nPreço BID = ", bid);
  }
