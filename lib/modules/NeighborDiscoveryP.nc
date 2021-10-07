#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module NeighborDiscoveryP {
   provides interface NeighborDiscovery; // using same name
   uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
}


implementation{
 
    //the pdf said to get a reply rather than an initial ping... so we can change the state of the packet to a reply 
    void Reply(pack* msg) {
        msg->src = TOS_NODE_ID;
        msg->protocol = PROTOCOL_PINGREPLY; //from the protocol.h file
        //that reply is now sent via the Nodes:
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }


    
    //we also want to add a timer at some point:


    //we want to recieve the message:
    command void NeighborDiscovery.recieve(pack* msg){

    }

    //getting the number of neighbors
    command uint16_t NeighborDiscovery.numNeighbors(){

    }

    //getting our neighbors in a table:
    command uint16_t* NeighborDiscovery.gatherNeighbors() {
     
    }

    //to print the neighbors:
    command void NeighborDiscovery.printNeighbors() {
        uint16_t i; //arbitrary int 
        uint32_t*  = call NeighborDiscovery.gatherNeighbors(); //we want to gather the Neighbors in the table

        dbg(NEIGHBOR_CHANNEL, "Neighbors of Node %d\n", TOS_NODE_ID); // a general message to get the contents of the list from the Node (in question)

        for (i = 0; i < call NeighborDiscovery.numNeighbors(); i++){ //using our num neighbors function to get the numberb of neighbors 
            dbg(NEIGHBOR_CHANNEL, "%d\n", NeighborNodes[i]); //actually printing the neighbors
        }
    }
}