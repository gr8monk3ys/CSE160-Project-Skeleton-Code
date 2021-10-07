#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module LinkStateP {
    provides interface LinkState;
    uses interface NeighborDiscovery as nd;

}

implementation {

    // Global variables
    pack packet;

    // Struct for routing table
    uint8_t routingTable[PACKET_MAX_PAYLOAD_SIZE * 8][PACKET_MAX_PAYLOAD_SIZE * 8];
    uint16_t routeNumNodes;

    // Struct for forwarding table
    uint16_t forwardTo[50];
    uint16_t forwardNext[50];
    uint16_t forwardNumNodes;

    // Tracks packets made or sent in a node
    uint32_t sent[50];
    uint16_t packsSent = 0;
    uint16_t packsMade = 0;

    int readPack(uint8_t arrayTo, uint8_t* payloadFrom) {
        int i; 
        dbg(ROUTING_CHANNEL, "Copying link-state packet from payload onto array\n")
        while(i < PACKET_MAX_PAYLOAD_SIZE * 8;){
            if(getBit(payloadFrom, i) == 1){
                arrayTo[i] = 1;
            }
            i++;
        }
        if(i >= PACKET_MAX_PAYLOAD_SIZE * 8){
            return 1;
        }
        return 0;
    }

    void makePack(pack *Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length);

    void sendNeighborPack() {
        char str[] = "Howdy neighbors";
        top = 0;

        dbg(NEIGHBOR_CHANNEL, "Discovering neighbors. Sending packet: ")
        makePack(&sendPack, TOS_NODE_ID, TOS_NODE_ID, 1, 6, packsMade, str, PACKET_MAX_PAYLOAD_SIZE);
        logPack(&sendPackage)
        call Sender.send(sendPackage, AM_BROADCAST_ADDR);
        packsSent++;
        packsMade++;
    }

    void printLinkState(uint8_t* data, char channel[]) {
        int i = 0;
        uint8_t arr [PACKET_MAX_PAYLOAD_SIZE];

        while(i < PACKET_MAX_PAYLOAD_SIZE){
            arr[i] = data[i]
            dbg(channel, arr[i])
            i++;
        }
    }

    void sendLinkState() {
        
    }

}