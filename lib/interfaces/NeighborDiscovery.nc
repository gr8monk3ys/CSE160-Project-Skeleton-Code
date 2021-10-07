#include "../../includes/packet.h"

//Neighbor Discovery Interface:

interface NeighborDiscovery{
        //we want to recieve the message
    command void ping(pack msg*);

    command void printNeighbors();

    command uint32_t* getNeighbors();

    command uint16_t numNeighbors();


//    command void  (uint16_t seq);
   
}