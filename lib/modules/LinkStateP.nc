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
     void LinkState.recieve(pack * route_packet)
    
    {
        uint16_t i = 0;
    }

 te of the table
    Route getRoute(uint16_t dest){
        Route return_route;
        uint16_t route_size = call RouteTable.size();
        uint16_t i;

        while(i < size; i++){
            Route route = call RoutingTable.get(i)
            if(route.dest == dest) {
                return_route = route;
                break;
            }
            i++;
        }
        return return_route;
    } duplicate

    // Removes the route if it is a
    void deleteRoute(uint16_t dest){
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        while(i < size){
            Route route = call RoutingTable.get(i);
            if(route.dest == dest) {
                call RoutingTable.remove(i);
                return;
            }
        }
    }



    command void LinkState.updateNeighbors(neighbors, numNeighbors)
    {

        //Add neighbors to routing table for (i = 0; i < neighborSize; i++)
        {
            //the iterator for Route:
            Route route;

    ute route;

            //neighbors is the hash map cointating the neighbor nodes:
            route.dest = neighbors[i];
            route.cost = 1;
            route.next_hop = neighbors[i]; //hop refers to pass
            route.TTL = -= 1;              //decrementing
        }
    }

    command void LinkState.printRoutingTable()
    {
        uint16_t size = call RouteTable.size();
        uint16_t i;

        dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
        i = 0
        while(i < size){
            
            Route route = call RouteTable.get(i);
            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
            i++
        }
    }

    //we want to send off packets to nodes:
    command void LinkState.send(pack * msg)
    {
        Route route;
        
        if(route.cost == ROUTE_MAX_COST) {
            dbg(GERNERAL_CHANNEL,  "Infinite cost loop, cant send packet", msg->src, msg->dest);
            return;
        } else if(!inTable(msg->dest)) {
            dbg(GENERAL_CHANNEL, "No connection, cant send packet")
        }
        dbg(GENERAL_CHANNEL, "src: %d, dest: %d, seq: %d, cost: %d, next hop: %d", msg->src, msg->dest, msg->seq, route.cost, route.next_hop)
        call Sender.send(*msg, route.next_hop);

        void LinkState.start();
    }

    command void LinkState.recieve(pack * route_packet)
    {
    }
}
