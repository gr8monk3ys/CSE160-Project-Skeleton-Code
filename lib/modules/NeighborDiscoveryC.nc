#include "../../includes/packet.h"
#include "../../includes/packet_id.h"


configuration NeighborDiscoveryC {
   provides interface NeighborDiscovery; 
}

//The wiring of configuration and Module 
implementation {
   components NeighborDiscoveryP;
   NeighborDiscovery = NeighborDiscoveryP;

//List of packets... no we want to use a hash map: since we are dealing with nodes and their corresponding neighbors
   components new HashmapC(uint16_t, 128);
   NeighborDiscoveryP.NeighborNodes -> HashMapC; //using name NeighborNodes

//Sending Packets... using the name sender
   components new SimpleSendC(AM_PACK);
   NeighborDiscoveryP.Sender -> SimpleSendC;
}
