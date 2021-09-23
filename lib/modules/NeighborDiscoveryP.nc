#include "../../includes/packet.h"

module NeighborDiscovery {
    provides interface NeighborDiscovery;
    uses interface SimpleSend as Sender;
    uses interface Hashmap<uint16_t> as Neighbor;
}

implementation {

    // Creates the packet for neighbor discovery
    void makePacket(pack* msg, uint16_t seq) {
        msg -> src = TOS_NODE_ID
        msg -> dest = AM_BROADCAST_ADDR
        msg -> TTL = 20;

        msg -> protocol = PROTOCOL_PING;
        msg -> seq = seq;
    }

    // Makes a reply from the neighbor discovery packet
    void sendPacket(pack* msg) {
        msg -> src = TOS_NODE_ID;
        msg -> protocol = PROTOCOL_PINGREPLY;
        call Sender.send(*msg, AM_BROADCAST_ADDR);
    }

    // Sends out packet in addition to the sequence packet
    command void NeighborDiscovery.find(uint16_t seq) {
        pack neighborPack;
        makePacket(&neighborPack, seq);
        call Sender.send(neighborPack, AM_BROADCAST_ADDR);
    }

    // Returns the number
    command uint16_t NeighborDiscovery.numNeighbors() {
        return call Neighbors.size();
    }

    // Returns a list of all the neighbors
    command uint32_t* NeighborDiscovery.getNeighbors() {
        return call Neighbors.getKeys();
    }

    // Prints all of the neighbors nearby
    command void NeighborDiscovery.printNeighbors() {
        uint16_t i = 0;
        uint32_t* neighbors = call NeighborDiscovery.getNeighbors();

        dbg(GENERAL_CHANNEL, "Neighbors: %d\n" TOS_NODE_ID);
        while(i < call NeighborDiscovery.numNeighbors()) {
            dbg(GENERAL_CHANNEL, "%d\n", neighbors[i]);
            i++;
        }
}