#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module NeighborDiscoveryP {
   provides interface NeighborDiscovery; // using same name
   uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
   //uses interface printNeighborNodes as printNeighborNodes;
   //uses interface recieve;
}

implementation{
    const uint16_t TIMEOUT_CYCLES = 5;

    //we will need to create our own packet to work with.... like using make pack.. calling the function
  //  void makePack(pack* neighborPack, uint16_t seq){
      //  dbg(NEIGHBOR_CHANNEL, "Flag - within Make pack\n");
    //}

 
    //the pdf said to get a reply rather than an initial ping... so we can change the state of the packet to a reply 
    void Reply(pack* msg) {

        dbg(NEIGHBOR_CHANNEL, "Flag - within Reply");
        msg->src = TOS_NODE_ID; //the node in question (intital node)
        msg->protocol = PROTOCOL_PINGREPLY; //from the protocol.h file
        //that reply is now sent via the Nodes:
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }


    void displayBasedoffProtocol(pack* msg) {
         //checking if the protocol is of reply
         dbg(NEIGHBOR_CHANNEL, "Flag - within protocol\n");
        if(msg->protocol == PROTOCOL_PING) {

            dbg(NEIGHBOR_CHANNEL, "Neighbor reply from %d. Adding to neighbor list...\n", msg->src);
            call NeighborNodes.insert(msg->src, TIMEOUT_CYCLES);
          
        }
        //checking if the protocol is of ping
        else if(msg->protocol == PROTOCOL_PINGREPLY){
     
            dbg(NEIGHBOR_CHANNEL, "Neighbor discovery from %d. Adding to list & replying...\n", msg->src);
            call NeighborNodes.insert(msg->src, TIMEOUT_CYCLES);
            //need to change ping to reply
            Reply(msg);
        }
        else{

             dbg(GENERAL_CHANNEL, "Wrong Protocol Type%d\n", msg->protocol);
        }          
    
    }

    //we also want to add a timer at some point.. according to the PDF:
    //Timer

    void decrement_timeout() {
        uint16_t i;
        uint32_t* neighborNodes = call NeighborNodes.getKeys();

        // Subtract 1 'clock cycle' from all the timeout values
        for (i = 0; i < call NeighborNodes.size(); i++) {
            uint16_t timeout = call NeighborNodes.get(neighborNodes[i]);
            call NeighborNodes.insert(neighborNodes[i], timeout - 1);

            // Node stopped replying, drop it
            if (timeout - 1 <= 0) {
                call NeighborNodes.remove(neighborNodes[i]);
            }
        }
    }


     //expanding on the make pack algo by explicitly defining it:
    void makePack(pack* neighborPack, uint16_t seq){
        neighborPack->src = TOS_NODE_ID;
        neighborPack->dest = AM_BROADCAST_ADDR;
        neighborPack->TTL = 1;
        neighborPack->seq = seq;
        neighborPack->protocol = PROTOCOL_PING; //a ping and not a reply

        dbg(NEIGHBOR_CHANNEL, "Flag - within make pack\n");
        dbg(NEIGHBOR_CHANNEL, "src: %d\n", neighborPack->src);
       
        memcpy(neighborPack->payload, "Length Payload\n", 19); //the sequence can be changed?
        // neighborPack -> TTL += 1;
    }

    command void NeighborDiscovery.find(uint16_t seq) {
        pack neighborPack; //a new pack called Neighbor pack
        dbg(NEIGHBOR_CHANNEL, "Flag - within find\n");
        makePack(&neighborPack, seq); //making a new packet with a sequence
        call Sender.send(neighborPack, AM_BROADCAST_ADDR); //sending out packet w said attributes 
    }

    //we want to recieve the message:
    command void NeighborDiscovery.recieve(pack* msg){
        
        dbg(NEIGHBOR_CHANNEL, "Flag - within recieve\n");
        //we want the DBG to display a few things:... we will more than likely need a new function based off the protocol. 
        displayBasedoffProtocol(msg);
    }

     //getting our NeighborNodes in a table:
    command uint16_t* NeighborDiscovery.gatherNeighbors() {
        dbg(NEIGHBOR_CHANNEL, "Flag - within gather NeighborNodes\n");
                //must return with function call
         dbg(NEIGHBOR_CHANNEL, "Contents: %d\n", call NeighborNodes.getKeys());
        return call NeighborNodes.getKeys(); //components of the map: .getKeys() is given as a helper function in Hashmap.nc

       
    }

    //getting the number of NeighborNodes
    command uint16_t NeighborDiscovery.numNeighbors(){

        dbg(NEIGHBOR_CHANNEL, "Flag - within num NeighborNodes\n");
            //get the size of the Neighbor Nodes 
        dbg(NEIGHBOR_CHANNEL, "Size: %d\n ", call NeighborNodes.size());
            return call NeighborNodes.size();
       
    }

    //to print the NeighborNodes:
    command void NeighborDiscovery.printNeighbors(){
        //dbg(NEIGHBOR_CHANNEL, "Flag - within print NeighborNodes... before while loop");
        uint16_t i = 0; //arbitrary int 
        //a unsigned int to take over as the neighbor node gathered
        uint32_t* neighborNodes  = call NeighborDiscovery.gatherNeighbors(); //we want to gather the NeighborNodes in the table

        dbg(NEIGHBOR_CHANNEL, "NeighborNodes of Node %d\n", TOS_NODE_ID); // a general message to get the contents of the list from the Node (in question)
        
        while(i < call NeighborDiscovery.numNeighbors()){
            dbg(NEIGHBOR_CHANNEL, "Flag - within print NeighborNodes... in while loop\n");
        //using our num NeighborNodes function to get the number of NeighborNodes 

            dbg(NEIGHBOR_CHANNEL, "Neighbor Node: %d\n", neighborNodes[i]); //actually printing the NeighborNodes
            
            i++; //to end the loop at some point
        }
    }

   
}