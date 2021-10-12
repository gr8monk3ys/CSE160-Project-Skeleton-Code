#include <Timer.h>
#include "../../includes/route.h"
#include "../../includes/packet.h"

module LinkStateP
{
    provides interface LinkState;
    uses interface NeighborDiscovery as nd;

    uses interface List<Route> as RouteTable;
    uses interface SimpleSend as Sender;

    uses interface Random;
    uses interface Timer<TMilli> as LinkStateTimer;
}

implementation
{
    pack packet;         //packet to be used
    uint16_t routes = 1; //route weight

    //our routing table to be used:
    uint8_t RouteTable[PACKET_MAX_PAYLOAD_SIZE * 8][PACKET_MAX_PAYLOAD_SIZE * 8];
    uint16_t routeNumNodes;

    //getting the neighbors within the table:
    //we need to check if the packet was already placed in the table:
    //the LSA Cache should be placed here (in a series of conditional loops:)

    //recieving a link state packet:
    command void LinkState.recieve(pack * route_packet)
    {
        uint16_t i = 0;
    }

    command void LinkState.updateNeighbors(neighbors, numNeighbors)
    {

        //Add neighbors to routing table for (i = 0; i < neighborSize; i++)
        {
            //the iterator for Route:
            Route route;

            //neighbors is the hash map cointating the neighbor nodes:
            route.dest = neighbors[i];
            route.cost = 1;
            route.next_hop = neighbors[i]; //hop refers to pass
            route.TTL = -= 1;              //decrementing

            //needs to be entered into the Route Table... or the Route table should be accessed here:
        }
    }

    //we want to print the table:
    command void LinkState.printRoutingTable()
    {
        //getting the routing table:
        uint16_t size = call RouteTable.size();
        uint16_t i;

        dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
        for (i = 0; i < size; i++)
        {
            Route route = call RouteTable.get(i);

            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
        }
    }

    //we want to send off packets to nodes:
    command void LinkState.send(pack * msg)
    {
        //to start the procedure:
        void LinkState.start();
    }

    command void LinkState.recieve(pack * route_packet)
    {
    }
}
