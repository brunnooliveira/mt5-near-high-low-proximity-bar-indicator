//+------------------------------------------------------------------+
//|                                      NearHighLowProximityBar.mq5 |
//|                                   Copyright 2025, brunnooliveira |
//|                                https://github.com/brunnooliveira |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2025, rpanchyk"
#property link        "https://github.com/brunnooliveira"
#property version     "1.00"
#property description "Indicator shows bar with close price near high or low price"
#property description ""
#property description "Used documentation:"
#property description "- https://www.mql5.com/en/code/1349"
#property description "- https://www.mql5.com/en/docs/customind/indicators_examples/draw_color_candles"
#property description "- https://github.com/rpanchyk/mt5-inside-bar-ind"

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots 1

#property indicator_type1 DRAW_COLOR_CANDLES
#property indicator_label1 "Open;High;Low;Close"
#property indicator_width1 3

// includes
#include <Generic\HashMap.mqh>

// types
class OHLCBar // Keeps OHLC prices at time
  {
public:
                     OHLCBar() : m_Time(0), m_Open(0), m_High(0), m_Low(0), m_Close(0) {}
   datetime          GetTime() { return m_Time; }
   double            GetOpen() { return m_Open; }
   double            GetHigh() { return m_High; }
   double            GetLow() { return m_Low; }
   double            GetClose() { return m_Close; }
   void              Set(datetime time, double open, double high, double low, double close) { m_Time = time; m_Open = open; m_High = high; m_Low = low; m_Close = close; }
private:
   datetime          m_Time;
   double            m_Open;
   double            m_High;
   double            m_Low;
   double            m_Close;
  };

enum ENUM_ALERT_TYPE
  {
   NO_ALERT, // None
   EACH_BAR_ALERT, // On each identified bar
   FIRST_BAR_ALERT // On first identified only
  };

// buffers
double BarOpenBuf[], BarHighBuf[], BarLowBuf[], BarCloseBuf[]; // Buffers for data
double BarLineColorBuf[]; // Buffer for color indexes

// config
input group "Section :: Main";
input bool InpMarkFirstBarOnly = false; // Mark first identified only in sequence
input ENUM_ALERT_TYPE InpAlertType = NO_ALERT; // Alert type
input double InpThreshold = 0.1; // Proximity threshold

input group "Section :: Style";
input color InpUpBarColor = clrGreen; // Color of bullish identified
input color InpDownBarColor = clrRed; // Color of bearish identified

input group "Section :: Dev";
input bool InpDebugEnabled = false; // Enable debug (verbose logging)

// runtime
CHashMap<int, datetime> barToTime;
OHLCBar prevBar;
OHLCBar currBar;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("NearHighLow indicator initialization started");

   ArrayInitialize(BarOpenBuf, EMPTY_VALUE);
   ArrayInitialize(BarHighBuf, EMPTY_VALUE);
   ArrayInitialize(BarLowBuf, EMPTY_VALUE);
   ArrayInitialize(BarCloseBuf, EMPTY_VALUE);
   ArrayInitialize(BarLineColorBuf, EMPTY_VALUE);

   ArraySetAsSeries(BarOpenBuf, true);
   ArraySetAsSeries(BarHighBuf, true);
   ArraySetAsSeries(BarLowBuf, true);
   ArraySetAsSeries(BarCloseBuf, true);
   ArraySetAsSeries(BarLineColorBuf, true);

   SetIndexBuffer(0, BarOpenBuf, INDICATOR_DATA);
   SetIndexBuffer(1, BarHighBuf, INDICATOR_DATA);
   SetIndexBuffer(2, BarLowBuf, INDICATOR_DATA);
   SetIndexBuffer(3, BarCloseBuf, INDICATOR_DATA);
   SetIndexBuffer(4, BarLineColorBuf, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpUpBarColor); // 0th index color
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpDownBarColor); // 1st index color

   IndicatorSetString(INDICATOR_SHORTNAME, "NearHighLow indicator");

   prevBar.Set(0, 0, 0, 0, 0);
   currBar.Set(0, 0, 0, 0, 0);

   Print("NearHighLow indicator initialization finished");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("NearHighLow indicator deinitialization started");

   ArrayFree(BarOpenBuf);
   ArrayFree(BarHighBuf);
   ArrayFree(BarLowBuf);
   ArrayFree(BarCloseBuf);
   ArrayFree(BarLineColorBuf);

   Print("NearHighLow indicator deinitialization finished");
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
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
   if(rates_total == prev_calculated)
     {
      return rates_total;
     }

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   int limit = (int) MathMin(rates_total, rates_total - prev_calculated + 2);
   if(InpDebugEnabled)
     {
      PrintFormat("RatesTotal: %i, PrevCalculated: %i, Limit: %i", rates_total, prev_calculated, limit);
     }

   BarOpenBuf[0] = -1;
   BarHighBuf[0] = -1;
   BarLowBuf[0] = -1;
   BarCloseBuf[0] = -1;
   BarLineColorBuf[0] = -1;

   for(int i = limit - 2; i > 0; i--)
     {
      BarOpenBuf[i] = open[i];
      BarHighBuf[i] = high[i];
      BarLowBuf[i] = low[i];
      BarCloseBuf[i] = close[i];

      currBar.Set(time[i], open[i], high[i], low[i], close[i]);

      if(IsNearHighLowBar())
        {
         string message = "New near high/low bar at " + TimeToString(time[i]);
         if(InpDebugEnabled)
           {
            Print(message);
           }

         if(InpMarkFirstBarOnly)
           {
            bool isFirstInsideBar = time[i] - prevBar.GetTime() == PeriodSeconds(PERIOD_CURRENT);
            BarLineColorBuf[i] = isFirstInsideBar ? open[i] <= close[i] ? 0 : 1 : -1;
           }
         else
           {
            BarLineColorBuf[i] = open[i] <= close[i] ? 0 : 1;
           }

         if(i == 1 && IsAlertEnabled(time[i])) // Handle alert on last bar only
           {
            if(time[i] != ReadLastNearHighLowBarTime()) // Don't flood with the same alerts
              {
               Alert(message);
               WriteLastNearHighLowBarTime(time[i]);
              }
           }
        }
      else
        {
         BarLineColorBuf[i] = -1;

         prevBar.Set(time[i], open[i], high[i], low[i], close[i]);
        }
     }

   return rates_total; // Set prev_calculated on next call
  }

//+------------------------------------------------------------------+
//| Returns true if bar matches near high/low conditions             |
//+------------------------------------------------------------------+
bool IsNearHighLowBar()
  {
    // Calculate proximity thresholds
    double range = currBar.GetHigh() - currBar.GetLow();
    double highProximity = currBar.GetHigh() - range * InpThreshold;
    double lowProximity = currBar.GetLow() + range * InpThreshold;

    if (currBar.GetClose() >= highProximity && currBar.GetClose() > currBar.GetOpen() 
          || currBar.GetClose() <= lowProximity && currBar.GetClose() < currBar.GetOpen())
    {
      return true;
    }
    return false;
  }

//+------------------------------------------------------------------+
//| Returns true if alert can be shown                               |
//+------------------------------------------------------------------+
bool IsAlertEnabled(datetime time)
  {
   switch(InpAlertType)
     {
      case EACH_BAR_ALERT:
         return true;
      case FIRST_BAR_ALERT:
         return time - prevBar.GetTime() == PeriodSeconds(PERIOD_CURRENT);
      case NO_ALERT:
      default:
         return false;
     }
  }

//+------------------------------------------------------------------+
//| Obtains last near high/low bar time occurrence                          |
//+------------------------------------------------------------------+
datetime ReadLastNearHighLowBarTime()
  {
   datetime lastNearHighLowBarTime;
   if(barToTime.TryGetValue(PeriodSeconds(PERIOD_CURRENT), lastNearHighLowBarTime))
     {
      return lastNearHighLowBarTime;
     }
   return NULL;
  }

//+------------------------------------------------------------------+
//| Saves last near high/low bar time occurrence                            |
//+------------------------------------------------------------------+
void WriteLastNearHighLowBarTime(datetime time)
  {
   barToTime.TrySetValue(PeriodSeconds(PERIOD_CURRENT), time);
  }
//+------------------------------------------------------------------+