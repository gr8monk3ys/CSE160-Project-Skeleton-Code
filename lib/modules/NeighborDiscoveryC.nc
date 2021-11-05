// #include "../../includes/packet.h"

// configuration NeighborDiscoveryC{
//    provides interface NeighborDiscovery;
// }

// //The wiring of configuration and Module 
// implementation{
//    components NeighborDiscoveryP;
//    NeighborDiscovery = NeighborDiscoveryP;

//    //List of packets... no we want to use a hash map: since we are dealing with nodes and their corresponding neighbors
//       components new HashmapC(uint16_t, 256) as NeighborNodes;
//       NeighborDiscoveryP.NeighborNodes->NeighborNodes; //using name NeighborNodes

//    //Sending Packets... using the name sender
//       components new SimpleSendC(AM_PACK);
//       NeighborDiscoveryP.Sender->SimpleSendC;
// }

/**
 * @author Jadon Hansell
 * 
 * Neighbor discovery through flooding
 */

#include "../../includes/packet.h"

configuration NeighborDiscoveryC {
    provides interface NeighborDiscovery;
}

implementation {
    components NeighborDiscoveryP;
    NeighborDiscovery = NeighborDiscoveryP;

    components new SimpleSendC(AM_PACK);
    NeighborDiscoveryP.Sender -> SimpleSendC;

    components new HashmapC(uint16_t, 256) as Neighbors;
    NeighborDiscoveryP.Neighbors-> Neighbors;
}
