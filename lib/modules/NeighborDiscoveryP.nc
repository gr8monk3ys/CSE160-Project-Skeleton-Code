#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module NeighborDiscoveryP {
   provides interface NeighborDiscovery; // using same name
   uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
   //uses interface printNeighbors as printNeighbors;
   //uses interface recieve;
}

implementation{

    //we will need to create our own packet to work with.... like using make pack.. calling the function
    void makePack(pack* neighborPack, uint16_t seq);

 
    //the pdf said to get a reply rather than an initial ping... so we can change the state of the packet to a reply 
    void Reply(pack* msg) {

        msg->src = TOS_NODE_ID; //the node in question (intital node)
        msg->protocol = PROTOCOL_PINGREPLY; //from the protocol.h file
        //that reply is now sent via the Nodes:
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

     void displayBasedoffProtocol(pack* msg) {
         //checking if the protocol is of reply
        if(msg->protocol == PROTOCOL_PINGREPLY) {

            dbg(NEIGHBOR_CHANNEL, "Neighbor reply from %d. Adding to neighbor list...\n", msg->src);
          
        }
        //checking if the protocol is of ping
        else if(msg->protocol == PROTOCOL_PING){
     
            dbg(NEIGHBOR_CHANNEL, "Neighbor discovery from %d. Adding to list & replying...\n", msg->src);

            //need to change ping to reply
            Reply(msg);
        }
        else{

             dbg(GENERAL_CHANNEL, "Wrong Protocol Type%d\n", msg->protocol);
        }          
    
    }

    //we also want to add a timer at some point.. according to the PDF:
    //Timer

    command void NeighborDiscovery.find(uint16_t seq) {
        pack neighborPack; //a new pack called Neighbor pack
        makePack(&neighborPack, seq); //making a new packet with a sequence

        call Sender.send(neighborPack, AM_BROADCAST_ADDR); //sending out packet w said attributes 
    }

    //we want to recieve the message:
    command void NeighborDiscovery.recieve(pack* msg){

            //we want the DBG to display a few things:... we will more than likely need a new function based off the protocol. 
       displayBasedoffProtocol(msg);
    }

     //getting our neighbors in a table:
    command uint16_t* NeighborDiscovery.gatherNeighbors() {
                
                //must return with function call
        return call NeighborNodes.getKeys(); //components of the map: .getKeys() is given as a helper function in Hashmap.nc
    }


    //getting the number of neighbors
    command uint16_t NeighborDiscovery.numNeighbors(){
            //get the size of the Neighbor Nodes 
            return call NeighborNodes.size();
    }

    //to print the neighbors:
    command void NeighborDiscovery.printNeighbors() {
        uint16_t i = 0; //arbitrary int 
        //a unsigned int to take over as the neighbor node gathered
        uint32_t* neighborNodes  = call NeighborDiscovery.gatherNeighbors(); //we want to gather the Neighbors in the table

        dbg(NEIGHBOR_CHANNEL, "Neighbors of Node %d\n", TOS_NODE_ID); // a general message to get the contents of the list from the Node (in question)
        
        while(i < call NeighborDiscovery.numNeighbors()){

        //using our num neighbors function to get the number of neighbors 

            dbg(NEIGHBOR_CHANNEL, "Neighbor Node: %d\n", neighborNodes[i]); //actually printing the neighbors
            
            i++; //to end the loop at some point
        }
    }

    //expanding on the make pack algo by explicitly defining it:
   command void NeighborDiscovery.makePack(pack* neighborPack, uint16_t seq){
        neighborPack->src = TOS_NODE_ID;
        neighborPack->dest = AM_BROADCAST_ADDR;
        neighborPack->TTL = 1;
        neighborPack->seq = seq;
        neighborPack->protocol = PROTOCOL_PING; //a ping and not a reply
        memcpy(neighborPack->payload, "Neighbor Discovery\n", 10); //the sequence can be changed?
    }
}