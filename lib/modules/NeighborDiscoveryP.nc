#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module NeighborDiscoveryP {
   provides interface NeighborDiscovery; // using same name
   uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
}


implementation{
    
}