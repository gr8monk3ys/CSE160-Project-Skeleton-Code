#include "../../includes/packet.h"

interface NeighborDiscovery{
   command void find(uint16_t seq);
   command void recieve(pack* msg);
   command void printNeighbors();
   command uint16_t numNeighbors();
   command uint32_t* getNeighbors();   
}
