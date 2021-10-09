#include <Timer.h>
#include "../../includes/route.h"

configuration LinkStateC {
   provides interface LinkState; 
}

//The wiring of configuration and Module 
implementation LinkState {
   components LinkStateP;
   LinkState = LinkStateP;

   components new ListC(Route, 256);
   LinkStateP.RoutingTable -> ListC;  

   components new SimpleSendC(AM_PACK);
   LinkStateP.Sender -> SimpleSendC;

   components new TimerMilliC() as RegularTimer;
   LinkStateP.RegularTimer -> RegularTimer;
}
