#include <Timer.h>
#include "../../includes/route.h"

configuration LinkStateC{
   provides interface LinkState;
}

implementation {
   components LinkStateP;
   LinkState = LinkStateP;

   components  RandomC;
   LinkStateP.Random->RandomC;

   components new ListC(Route, 256);
   LinkStateP.RoutingTable->ListC;

   components new SimpleSendC(AM_PACK);
   LinkStateP.Sender->SimpleSendC;

   components new TimerMilliC() as LinkStateTimer;
   LinkStateP.LinkStateTimer->LinkStateTimer;
}
