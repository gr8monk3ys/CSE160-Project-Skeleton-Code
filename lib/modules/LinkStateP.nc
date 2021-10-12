#include <Timer.h>
#include "../../includes/route.h"
#include "../../includes/packet.h"

module LinkStateP {
    provides interface LinkState;
    uses interface NeighborDiscovery as nd;

    uses interface List<Route> as RoutingTable;
    uses interface SimpleSend as Sender;

    uses interface Random;
    uses interface Timer<TMilli> as RegularTimer;

}

implementation {

    // Global variables
    pack packet;
    uint16_t routes = 1;

    // Struct for routing table
    uint8_t routingTable[PACKET_MAX_PAYLOAD_SIZE * 8][PACKET_MAX_PAYLOAD_SIZE * 8];
    uint16_t routeNumNodes;

    command void LinkState.start() {
        if (call RoutingTable.size() == 0) {
            dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
            return;
        }

        if (!call RegularTimer.isRunning()) {
            dbg (ROUTING_CHANNEL, "Intiating routing protocol...\n");
            call RegularTimer.startPeriodic(randNum(25000, 35000);
        }
    }

    /**
     * Sends given packet based on the routing table's next hop value
     */
    command void LinkState.send(pack* msg) {
        Route route;

        if (!inTable(msg->dest)) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg->src, msg->dest);
            return;
        }

        route = getRoute(msg->dest);

        if (route.cost == ROUTE_MAX_COST) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: cost infinity\n", msg->src, msg->dest);
            return;
        }
        
        dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", msg->src, msg->dest, msg->seq, route.next_hop, route.cost);

        call Sender.send(*msg, route.next_hop);
    }

    /**
     * Called when the node recieves a routing packet
     * Processes the route information from the packet
     */
    command void LinkState.recieve(pack* routing_packet) {
        uint16_t i = 0;

        // Iterate over each route in the payload
        while(i < routesPerPacket){
            Route current_route;
            memcpy(&current_route, (&routing_packet->payload) + i*ROUTE_SIZE, ROUTE_SIZE);
            
            // Blank route
            if (current_route.dest == 0) {
                continue;
            }

            // Don't need to add yourself
            if (current_route.dest == TOS_NODE_ID) {
                continue;
            }

            // Cost should never be higher than the maximum
            if (current_route.cost > ROUTE_MAX_COST) {
                dbg(ROUTING_CHANNEL, "ERROR - Invalid route cost of %d from %d\n", current_route.cost, current_route.dest);
                continue;
            }

            // Split Horizon w/ Poison Reverse
            // Done at recieving end because packets are sent to AM_BROADCAST_ADDR
            if (current_route.next_hop == TOS_NODE_ID) {
                current_route.cost = ROUTE_MAX_COST;
            }

            // Cap the cost at ROUTE_MAX_COST (default: 16)
            current_route.cost = min(current_route.cost + 1, ROUTE_MAX_COST);

            // No existing route
            if (!inTable(current_route.dest)) {
                // No need to add a new entry for a dead route
                if (current_route.cost == ROUTE_MAX_COST) {
                    continue;
                }

                current_route.dest = routing_packet->dest;
                current_route.next_hop = routing_packet->src;
                current_route.TTL = ROUTE_TIMEOUT;
                current_route.route_changed = TRUE;

                call RoutingTable.pushback(current_route);

                triggeredUpdate();
                continue;
            } 

            // Route Already Exists
            else {
                Route existing_route = getRoute(current_route.dest);

                // Update to existing route, reset TTL
                if (existing_route.next_hop == routing_packet->src) {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                // Updated cost to existing route, or new cheaper cost
                if ((existing_route.next_hop == routing_packet->src
                    && existing_route.cost != current_route.cost)
                    || existing_route.cost > current_route.cost) {
                    
                    existing_route.next_hop = routing_packet->src;
                    existing_route.TTL = ROUTE_TIMEOUT;
                    existing_route.route_changed = TRUE;

                    // Dead route, start garbage collection timer
                    // Don't reset timer if cost was already ROUTE_MAX_COST
                    if (current_route.cost == ROUTE_MAX_COST &&
                        existing_route.cost != ROUTE_MAX_COST) {

                        existing_route.TTL = ROUTE_GARBAGE_COLLECT;
                    }

                    existing_route.cost = current_route.cost;
                
                // No updated cost, just reinitialize the timer
                } else {
                    existing_route.TTL = ROUTE_TIMEOUT;
                }

                updateRoute(existing_route);
            } 
            i++;
        }
    }

    /**
     * Updates the neighbor list associated with this routing handler.
     * Updates routes in table for neighbors
     */
    command void LinkState.updateNeighbors(uint32_t* neighbors, uint16_t numNeighbors) {
        uint16_t i;
        uint16_t size = call RoutingTable.size();

        // Invalidate missing neighbors (in case one is dropped)
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            uint16_t j;

            // Don't immediately re-invalidate an invalid entry
            if (route.cost == ROUTE_MAX_COST) {
                continue;
            }

            // Invalidate the route if it's no longer a neighbor
            if (route.cost == 1) {
                bool isNeighbor = FALSE;

                for (j = 0; j < numNeighbors; j++) {
                    if (route.dest == neighbors[j]) {
                        isNeighbor = TRUE;
                        break;
                    }
                }

                if (!isNeighbor) {
                    invalidate(route);
                }
            }

        }

        // Add neighbors to routing table
        for (i = 0; i < numNeighbors; i++) {
            Route route;

            route.dest = neighbors[i];
            route.cost = 1;
            route.next_hop = neighbors[i];
            route.TTL = ROUTE_TIMEOUT;
            route.route_changed = TRUE;

            if (inTable(route.dest)) {
                Route existing_route = getRoute(route.dest);

                // Existing node suddenly became a new neighbor
                if (existing_route.cost != route.cost) {
                    updateRoute(route);
                    triggeredUpdate();
                }
            }
            // New neighbor 
            else {
                call RoutingTable.pushback(route);
                triggeredUpdate();
            }
        }
    }

    /**
     * Called by simulation
     * Prints the routing table in 'destination, next hop, cost' format
     */
    command void LinkState.printRoutingTable() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
        }
        dbg(GENERAL_CHANNEL, "--------------------------------\n");
    }

    /**
     * Sends all routes with route_changed = TRUE to all neighbor nodes
     * Should only ever be run as a one-time timer, not periodically
     */
    event void TriggeredEventTimer.fired() {
        uint16_t size = call RoutingTable.size();
        uint16_t packet_index = 0;
        uint16_t current_route;
        pack msg;

        msg.src = TOS_NODE_ID;
        msg.TTL = 1;
        msg.protocol = PROTOCOL_DV;
        msg.seq = 0; // NOTE: Change if requests are needed

        memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

        // Go through all routes looking for changed ones
        for (current_route = 0; current_route < size; current_route++) {
            Route route = call RoutingTable.get(current_route);

            msg.dest = route.dest;

            if (route.route_changed) {

                memcpy((&msg.payload) + packet_index*ROUTE_SIZE, &route, ROUTE_SIZE);

                packet_index++;
                if (packet_index == routesPerPacket) {
                    packet_index = 0;

                    call Sender.send(msg, AM_BROADCAST_ADDR);
                    memset((&msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);
                }
            }
        }

        resetRouteUpdates();
    }

    /**
     * Processes TTL and sends entire routing table to neighbors
     */
    event void RegularTimer.fired() {
        uint16_t size = call RoutingTable.size();
        uint16_t i;

        // Stop triggered event timer, no need to send at this point
        call TriggeredEventTimer.stop();
        decrementRouteTimers();

        // Mark all nodes as changed, let TriggeredEvent handle the sending
        for (i = 0; i < size; i++) {
            Route route = call RoutingTable.get(i);
            route.route_changed = TRUE;
            updateRoute(route);
        }

        signal TriggeredEventTimer.fired();
    }

}