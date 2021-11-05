// #include "../../includes/packet.h"

// //Neighbor Discovery Interface:

// interface NeighborDiscovery{
//     //we want to recieve the message
//     command void recieve(pack* msg);
//     //we want to be able to print the neighbors
//     command void printNeighbors();
//     //we want to gather our neighbors 
//     command uint16_t* gatherNeighbors();
//     //we would like the number of our neighbors 
//     command uint16_t numNeighbors();
//     //we want to find the nodes based off the sequence identifier 
//     command void find(uint16_t seq);

//     //command void makePack(pack* neighborPack, uint16_t seq);

   
// }
#include "../../includes/packet.h"

interface NeighborDiscovery {
    command void discover(uint16_t seq);
    command void recieve(pack* msg);
    command uint32_t* getNeighbors();
    command uint16_t numNeighbors();
    command void printNeighbors();
}
