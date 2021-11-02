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

    //     recieving a link state packet:
    // command void LinkState.recieve(pack* route_packet)
    //  //void LinkState.recieve(pack* route_packet)

    // {
    //     uint16_t i = 0;
    // }

    // Gets the route dependent on the given destination
    void getRoute(uint16_t dest)
    {
        Route return_route;
        uint16_t route_size = call RouteTable.size();
        uint16_t i = 0;

        while (i < size; i++)
        {
            Route route = call RouteTable.get(i) if (route.dest == dest)
            {
                return_route = route;
                break;
            }
            i++;
        }
        return return_route;
    }

    // Updates the route if the current route is the route provided
    void updateRoute(Route route)
    {
        uint16_t size = call RouteTable.size();
        uint16_t i = 0;

        while (i < size)
        {
            Route current = call RouteTableTable.get(i);
            if (route.dest == current.dest)
            {
                call RouteTable.set(i, route) return;
            }
            i++;
        }
    }

    // Removes the route if it is a duplicate
    void deleteRoute(uint16_t dest)
    {
        uint16_t size = call RouteTable.size();
        uint16_t i = 0;

        while (i < size)
        {
            Route route = call RouteTable.get(i);
            if (route.dest == dest)
            {
                call RouteTable.remove(i);
                return;
            }
            i++;
        }
    }

    void decrementTimer(Route route)
    {
        route.TTL = route.TTL - 1;
        updateRoute(route);

        // Timeout timer expired, start garbage collection timer
        if (route.TTL == 0 && route.cost != ROUTE_MAX_COST)
        {
            uint16_t size = call RouteTable.size();
            uint16_t i;

            route.TTL = ROUTE_GARBAGE_COLLECT;
            route.cost = ROUTE_MAX_COST;
            route.route_changed = TRUE;

            updateRoute(route);
            triggeredUpdate();

            // Invalidate routes that had a next hop with that node
            for (i = 0; i < size; i++)
            {
                Route current_route = call RouteTable.get(i);

                if (current_route.next_hop == route.next_hop && current_route.cost != ROUTE_MAX_COST)
                {
                    current_route.TTL = ROUTE_GARBAGE_COLLECT;
                    current_route.cost = ROUTE_MAX_COST;
                    current_route.route_changed = TRUE;

                    updateRoute(current_route);
                    triggeredUpdate();
                }
            }
        }
        else if (route.TTL == 0 && route.cost == ROUTE_MAX_COST)
        {
            removeRoute(route.dest);
        }
    }

    void decrementRouteTimers()
    {
        uint16_t i;
        i = 0;

        while (i < call RouteTable.size())
        {
            Route route = call RouteTable.get(i);
            decrementTimer(route)
                i++;
        }
    }

    void invalidate(Route route)
    {
        route.TTL = 1;
        decrementTimer(route);
    }

    command void LinkState.start()
    {
        if (call RouteTable.size() == 0)
        {
            dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
            return;
        }

        if (!call RegularTimer.isRunning())
        {
            dbg(ROUTING_CHANNEL, "Intiating routing protocol...\n");
            call RegularTimer.startPeriodic(randNum(25000, 35000));
        }
    }

    // command void LinkState.updateNeighbors(neighbors, numNeighbors){
    //         Route route;

    //         //neighbors is the hash map cointating the neighbor nodes:
    //         route.dest = neighbors[i];
    //         route.cost = 1;
    //         route.next_hop = neighbors[i]; //hop refers to pass
    //         route.TTL = -= 1;              //decrementing
    //     }
    // }

    command void LinkState.printRouteTable()
    {
        uint16_t size = call RouteTable.size();
        uint16_t i;

        dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
        i = 0;
        while (i < size)
        {

            Route route = call RouteTable.get(i);
            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
            i++;
        }
    }

    //we want to send off packets to nodes:
    command void LinkState.send(pack * msg)
    {
        Route route;

        if (route.cost == ROUTE_MAX_COST)
        {
            dbg(GERNERAL_CHANNEL, "Infinite cost loop, cant send packet", msg->src, msg->dest);
            return;
        }
        else if (!inTable(msg->dest))
        {
            dbg(GENERAL_CHANNEL, "No connection, cant send packet")
        }
        dbg(GENERAL_CHANNEL, "src: %d, dest: %d, seq: %d, cost: %d, next hop: %d", msg->src, msg->dest, msg->seq, route.cost, route.next_hop)
            call Sender.send(*msg, route.next_hop);
    }

    command void LinkState.updateNeighbors(uint16_t * neighbors, uint16_t numNeighbors)
    {
        uint16_t i = 0;
        uint16_t size = call RouteTable.size();

        while (i < size)
        {
            Route route = call LinkState.get(i);
            uint16_t j;

            if (route.cost == ROUTE_MAX_COST)
            {
                continue;
            }

            if (route.cost == 1)
            {
                bool isNeighbor = FALSE;
                j = 0;
                while (j < numNeighbors)
                {
                    if (route.dest == neighbors[j])
                    {
                        isNeighbor = True;
                        break;
                    }
                    j++;
                }
                if (!isNeighbor)
                {
                    invalidateRoute(route);
                }
            }
            i = 0;
            while (i < numNeighbors)
            {
                Route route;

                route.cost = 1;
                route.dest = neighbors[i];
                route.next_hop = neighbors[i];
                route.TTL = ROUTE
            }

            i++;
        }
    }

    command void LinkState.recieve(pack * routing)
    {
        uint16_t i = 0;

        while (i < routes)
        {
            Route current;
            memcpy(&current, (&routing->payload) + (i * ROUTE_SIZE), ROUTE_SIZE);
            current.dest == 0               ? continue;
            current.dest == TOS_NODE_ID     ? continue;
            current.next_hop == TOS_NODE_ID ? current.cost = ROUTE_MAX_COST;
            !inTable if (current.cost > ROUTE_MAX_COST)
            {
                dbg(GENERAL_CHANNEL, "Not a valid route cost %d from %d \n", current.cost, current.dest);
                continue;
            }
            i++;
        }
    }

    event void TriggeredEventTimer.fired()
    {
        uint16_t size = call RouteTable.size();
        uint16_t packet_index = 0;
        uint16_t current_route;
        pack msg;

        msg.src = TOS_NODE_ID;
        msg.TTL = 1;
        msg.protocol = PROTOCOL_DV;
        msg.seq = 0;

        memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

        for (current_route = 0; current_route < size; current_route++)
        {
            Route route = call RouteTable.get(current_route);
            msg.dest = route.dest;

            if (route.route_changed)
            {
                memcpy((&msg.payload) + packet_index * ROUTE_SIZE, &route, ROUTE_SIZE);

                packet_index++;
                if (packet_index == routesPerPacket)
                {
                    packet_index = 0;

                    call Sender.send(msg, AM_BROADCAST_ADDR);
                    memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);
                }
            }
        }
        resetRouteUpdates();
    }

    event void RegularTimer.fired()
    {
        uint16_t size = call RouteTable.size();
        uint16_t i;

        call TriggeredEventTimer.stop();
        decrementRouteTimers();

        while (i < size)
        {
            Route route = call LinkState.size
                              i++;
        }
        for (i = 0; i < size; i++)
        {
            Route route = call RouteTable.get(i);
            route.route_changed = TRUE;
            updateRoute(route);
        }

        signal TriggeredEventTimer.fired();
    }
}
