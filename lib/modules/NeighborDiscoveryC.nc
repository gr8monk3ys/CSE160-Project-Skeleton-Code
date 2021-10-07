#include "../../includes/packet.h"
#include "../../includes/packet_id.h"


configuration NeighborDiscoveryC {
   provides interface NeighborDiscovery; 
}

//The wiring of configuration and Module 
implementation {
   components NeighborDiscoveryP;
   NeighborDiscovery = NeighborDiscoveryP;

//List of packets... 
   components new ListC(packID, 64);
   FloodingP.PreviousPackets -> ListC;  

//Sending Packets...
   components new SimpleSendC(AM_PACK);
   FloodingP.Sender -> SimpleSendC;
}
