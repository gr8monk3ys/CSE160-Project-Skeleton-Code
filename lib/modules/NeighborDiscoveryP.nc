#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module NeighborDiscoveryP {
   provides interface NeighborDiscovery; // using same name
   uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
}


implementation{

    //we will need to create our own packet to work with.... like using make pack.. calling the function
    void makePack(pack *NeighborPack, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length);

 
    //the pdf said to get a reply rather than an initial ping... so we can change the state of the packet to a reply 
    void Reply(pack* msg) {
        
        msg->src = TOS_NODE_ID; //the node in question (intital node)
        msg->protocol = PROTOCOL_PINGREPLY; //from the protocol.h file
        //that reply is now sent via the Nodes:
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    
    //we also want to add a timer at some point.. according to the PDF:



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

        for (i = 0; i < call NeighborDiscovery.numNeighbors(); i++){ //using our num neighbors function to get the number of neighbors 

            dbg(NEIGHBOR_CHANNEL, "Neighbor Node: %d\n", NeighborNodes[i]); //actually printing the neighbors
        }
    }

    
    //expanding on the make pack algo by explicitly defining it:
    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t *payload, uint8_t length) {
        NeighborPack->src = TOS_NODE_ID;
        NeighborPack->dest = AM_BROADCAST_ADDR;
        NeighborPack->TTL = 1;
        NeighborPack->seq = seq;
        NeighborPack->protocol = PROTOCOL_PING;
        memcpy(NeighborPack->payload, 10); //the sequence can be changed?
    }
}