// #include "../../includes/packet.h"
// #include "../../includes/protocol.h"

// module NeighborDiscoveryP{
//    provides interface NeighborDiscovery; // using same name
//    uses interface Hashmap<uint16_t> as NeighborNodes; // Now refered to as Previous Packets 
//    uses interface SimpleSend as Sender; // Now referred to as Sender
// }

// implementation{

//     const uint16_t THRESHOLD = 5;

// // expanding on the make pack algo by explicitly defining it:
// void makePack(pack* neighborPack, uint16_t seq) {
//     neighborPack->src = TOS_NODE_ID;
//     neighborPack->dest = AM_BROADCAST_ADDR;
//     neighborPack->TTL = 1;
//     neighborPack->seq = seq;
//     neighborPack->protocol = PROTOCOL_PING; //a ping and not a reply

//     // dbg(NEIGHBOR_CHANNEL, "Within: makePack()\n");
//     dbg(NEIGHBOR_CHANNEL, "Source Node: %d\n", neighborPack->src);
//     memcpy(neighborPack->payload, "Neighbor Discovery\n", 19);
// }

// void Reply(pack* msg) {
//     dbg(NEIGHBOR_CHANNEL, "Flag - accessed Reply protocol");
//     msg->src = TOS_NODE_ID; //the node in question (intital node)
//     msg->protocol = PROTOCOL_PINGREPLY; //from the protocol.h file
//     //that reply is now sent via the Nodes:
//     call Sender.send(*msg, AM_BROADCAST_ADDR);
// }

// //Timer
// void decrement_timeout() {
//     uint16_t i = 0;
//     uint32_t* neighborNodes = call NeighborNodes.getKeys();

//     while (i < call NeighborNodes.size()) {
//         uint16_t timeout = call NeighborNodes.get(neighborNodes[i]);
//         call NeighborNodes.insert(neighborNodes[i], timeout - 1);
//         if (timeout - 1 <= 0) {
//             call NeighborNodes.remove(neighborNodes[i]);
//         }
//         i++;
//     }
// }

// command void NeighborDiscovery.find(uint16_t seq) {
//     pack neighborPack; //a new pack called Neighbor pack
//     // dbg(NEIGHBOR_CHANNEL, "Within: find()\n");
//     makePack(&neighborPack, seq); //making a new packet with a sequence
//     call Sender.send(neighborPack, AM_BROADCAST_ADDR); //sending out packet w said attributes 
// }

// //getting our NeighborNodes in a table:
// command uint16_t* NeighborDiscovery.gatherNeighbors() {
//     //must return with function call
//     return call NeighborNodes.getKeys(); //components of the map: .getKeys() is given as a helper function in Hashmap.nc
// }

// //getting the number of NeighborNodes
// command uint16_t NeighborDiscovery.numNeighbors() {
//     //get the size of the Neighbor Nodes 
//     return call NeighborNodes.size();
// }

// //to print the NeighborNodes:
// command void NeighborDiscovery.printNeighbors() {
//     uint16_t i = 0;

//     //we want to gather the NeighborNodes in the table
//     uint32_t* neighborNodes = call NeighborDiscovery.gatherNeighbors();

//     dbg(NEIGHBOR_CHANNEL, "Neighbor Nodes of Node %d\n", TOS_NODE_ID); // a general message to get the contents of the list from the Node (in question)

//     while (i < call NeighborDiscovery.numNeighbors()) {
//         //using our num NeighborNodes function to get the number of NeighborNodes 
//         dbg(NEIGHBOR_CHANNEL, "Neighbor Node: %d\n", neighborNodes[i]); //actually printing the NeighborNodes    
//         i++;
//     }

//     dbg(NEIGHBOR_CHANNEL, "---------------------------\n");
// }

// void displayOffProtocol(pack* msg) {
//     //checking if the protocol is of ping
//     if (msg->protocol == PROTOCOL_PING) {

//         dbg(NEIGHBOR_CHANNEL, "Neighbor reply from %d. Adding to neighbor list\n", msg->src);
//         call NeighborNodes.insert(msg->src, THRESHOLD);
//     }
//     //checking if the protocol is of reply
//     else if (msg->protocol == PROTOCOL_PINGREPLY) {

//         dbg(NEIGHBOR_CHANNEL, "Neighbor discovery from %d. Adding to list & replying...\n", msg->src);
//         call NeighborNodes.insert(msg->src, THRESHOLD);
//         //need to change ping to reply
//         Reply(msg);
//     }
//     else {
//          dbg(NEIGHBOR_CHANNEL, "Wrong Protocol Type%d\n", msg->protocol);
//     }
// }

// //we want to recieve the message:
// command void NeighborDiscovery.recieve(pack* msg) {

//     //we want the DBG to display a few things:... we will more than likely need a new function based off the protocol. 
//     displayOffProtocol(msg);
// }

// }

#include "../../includes/packet.h"

module NeighborDiscoveryP {
    provides interface NeighborDiscovery;

    uses interface SimpleSend as Sender;
    uses interface Hashmap<uint16_t> as Neighbors;
}

implementation {
    const uint16_t TIMEOUT_CYCLES = 5; // Number of missed replies before dropping a neighbor

    /**
     * Changes provided neighbor discovery packet into a neighbor discovery reply and sends it
     */
    void pingReply(pack* msg) {
        msg->src = TOS_NODE_ID;
        msg->protocol = PROTOCOL_PINGREPLY;
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    /**
     * Helper function for processing neighbor discovery packets
     * Neighbor discovery implemented with only ping and ping replies
     */
    void protocolHandler(pack* msg) {
        switch(msg->protocol) {
            case PROTOCOL_PING:
                dbg(NEIGHBOR_CHANNEL, "Neighbor discovery from %d. Adding to list & replying...\n", msg->src);
                call Neighbors.insert(msg->src, TIMEOUT_CYCLES);
                pingReply(msg);
                break;

            case PROTOCOL_PINGREPLY:
                dbg(NEIGHBOR_CHANNEL, "Neighbor reply from %d. Adding to neighbor list...\n", msg->src);
                call Neighbors.insert(msg->src, TIMEOUT_CYCLES);
                break;

            default:
                dbg(GENERAL_CHANNEL, "Unrecognized neighbor discovery protocol: %d\n", msg->protocol);
        }
    }

    /**
     * Removes 1 'cycle' from all the timeout values on the neighbor list
     * Removes the node ID from the list if the timeout drops to 0
     */
    void decrement_timeout() {
        uint16_t i;
        uint32_t* neighbors = call Neighbors.getKeys();

        // Subtract 1 'clock cycle' from all the timeout values
        for (i = 0; i < call Neighbors.size(); i++) {
            uint16_t timeout = call Neighbors.get(neighbors[i]);
            call Neighbors.insert(neighbors[i], timeout - 1);

            // Node stopped replying, drop it
            if (timeout - 1 <= 0) {
                call Neighbors.remove(neighbors[i]);
            }
        }
    }

    /**
     * Creates packet used for neighbor discovery
     * Uses dest=AM_BROADCAST_ADDR as the method to detect a neighbor discovery packet
     */
    void createNeighborPack(pack* neighborPack, uint16_t seq) {
        neighborPack->src = TOS_NODE_ID;
        neighborPack->dest = AM_BROADCAST_ADDR;
        neighborPack->TTL = 1;
        neighborPack->seq = seq;
        neighborPack->protocol = PROTOCOL_PING;
        memcpy(neighborPack->payload, "Neighbor Discovery\n", 19);
    }

    /**
     * Sends out neighbor discovery packet with the sequence number passed to it
     */
    command void NeighborDiscovery.discover(uint16_t seq) {
        pack neighborPack;
        decrement_timeout();
        createNeighborPack(&neighborPack, seq);
        call Sender.send(neighborPack, AM_BROADCAST_ADDR);
    }

    /**
     * Called when node recieves neighbor discovery packet
     */
    command void NeighborDiscovery.recieve(pack* msg) {
        protocolHandler(msg);
    }

    /**
     * Returns list of neighbors. Pair with numNeighbors() to iterate
     */
    command uint32_t* NeighborDiscovery.getNeighbors() {
        return call Neighbors.getKeys();
    }

    /**
     * Returns the number of neighbors
     */
    command uint16_t NeighborDiscovery.numNeighbors() {
        return call Neighbors.size();
    }

    /**
     * Prints the list of neighbors for this node
     */
    command void NeighborDiscovery.printNeighbors() {
        uint16_t i;
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();

        dbg(GENERAL_CHANNEL, "--- Neighbors of Node %d ---\n", TOS_NODE_ID);
        for (i = 0; i < call NeighborDiscovery.numNeighbors(); i++) {
            dbg(GENERAL_CHANNEL, "%d\n", neighbors[i]);
        }
        dbg(GENERAL_CHANNEL, "---------------------------\n");
    }
}
