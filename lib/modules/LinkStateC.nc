#include <Timer.h>
#include "../../includes/route.h"

configuration LinkStateC {
   provides interface LinkState; 
}

//The wiring of configuration and Module 
implementation LinkState {
   components LinkStateP;
   LinkState = LinkStateP;

//List of packets... 
   components new ListC(Route, 256);
   LinkStateP.RoutingTable -> ListC;  

//Sending Packets...
   components new SimpleSendC(AM_PACK);
   FloodingP.Sender -> SimpleSendC;
}
