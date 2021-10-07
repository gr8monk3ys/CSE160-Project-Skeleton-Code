#include "../../includes/packet.h"
#include "../../includes/packet_id.h"

configuration LinkStateC {
   provides interface LinkState; 
}

//The wiring of configuration and Module 
implementation LinkState {
   components LinkStateP;
   LinkState = LinkStateP;

//List of packets... 
   components new ListC(packID, 64);
   FloodingP.PreviousPackets -> ListC;  

//Sending Packets...
   components new SimpleSendC(AM_PACK);
   FloodingP.Sender -> SimpleSendC;
}
