#includes "../../packet.h"

configuration NeighborDiscovery {
   provide interface NeighborDiscovery; 
}

implementation {
   components NeighborDiscoveryP;
   NeighborDiscovery = NeighborDiscoveryP;

   components new HashMapC(uint16_t, 128);
   NeighborDiscoveryP.Neighbor -> Neighbor; 
   
   components new SimpleSendC(AM_PACK);
   NeighborDiscoveryP.Sender -> SimpleSendC;


}
