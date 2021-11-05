#include <Timer.h>

#include "../../includes/route.h"

#include "../../includes/packet.h"

#undef min
#define min(a, b)((a) < (b) ? (a) : (b))

module LinkStateP {
  provides interface LinkState;
  uses interface NeighborDiscovery as nd;

  uses interface List < Route > as RouteTable;
  uses interface SimpleSend as Sender;

  uses interface Random;
  uses interface Timer < TMilli > as LinkStateTimer;

  uses interface Timer < TMilli > as RegularTimer;
}

implementation {
  //pack packet; //packet to be used
  uint16_t routes = 1; //route weight

  //our routing table to be used:
  //uint16_t routeNumNodes;

  uint32_t rand(uint32_t min, uint32_t max) {
    return (call Random.rand16() % (max - min + 1)) + min;
  }

  bool inTable(uint16_t dest) {
    uint16_t size = call RouteTable.size();
    uint16_t i;
    bool isInTable = FALSE;

    for (i = 0; i < size; i++) {
      Route route = call RouteTable.get(i);

      if (route.dest == dest) {
        isInTable = TRUE;
        break;
      }
    }
    return isInTable;
  }

  // Gets the route dependent on the given destination
  Route getRoute(uint16_t dest) {
    Route return_route;
    uint16_t route_size = call RouteTable.size();
    uint16_t i = 0;

    while (i < route_size) {
      Route route = call RouteTable.get(i);

      if (route.dest == dest) {
        return_route = route;
        break;
      }
      i++;
    }
    return return_route;
  }

  // Removes the route if it is a duplicate
  void deleteRoute(uint16_t dest) {
    uint16_t size = call RouteTable.size();
    uint16_t i = 0;

    while (i < size) {
      Route route = call RouteTable.get(i);
      if (route.dest == dest) {
        call RouteTable.remove(i);
        return;
      }
      i++;
    }
    
    dbg(ROUTING_CHANNEL, "ERROR - Can't remove nonexistent route %d\n", dest);
  }

  // Updates the route if the current route is the route provided
  void updateRoute(Route route) {
    uint16_t size = call RouteTable.size();
    uint16_t i = 0;

    while (i < size) {
      Route current_route = call RouteTable.get(i);
      if (route.dest == current_route.dest) {
        call RouteTable.set(i, route); //set doesnt exist in the functions for Lists

        return;
      }
      i++;
    }
  }

  // void reset() {
  //   uint16_t size = call RouteTable.size();
  //   uint16_t i;

  //   for (i = 0; i < size; i++) {
  //     Route route = call RouteTable.get(i);
  //     route.route_changed = FALSE;
  //     call RouteTable.set(i, route);
  //   }
  // }

  void resetRouteUpdates() {
    uint16_t size = call RouteTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route route = call RouteTable.get(i);
      route.route_changed = FALSE;
      call RouteTable.set(i, route);
    }
  }

  void decrementTimer(Route route) {
    route.TTL = route.TTL - 1;
    updateRoute(route);

    // Timeout timer expired, start garbage collection timer
    if (route.TTL == 0 && route.cost != ROUTE_MAX_COST) {
      uint16_t size = call RouteTable.size();
      uint16_t i;

      route.TTL = ROUTE_GARBAGE_COLLECT;
      route.cost = ROUTE_MAX_COST;
      route.route_changed = TRUE;

      updateRoute(route);
      //call LinkStateTimer.startOneShot( rand(1000, 5000) ); (); //we dont have a function for this
      call LinkStateTimer.startOneShot(rand(1000, 5000));

      // Invalidate routes that had a next hop with that node
      for (i = 0; i < size; i++) {
        Route current_route = call RouteTable.get(i);

        if (current_route.next_hop == route.next_hop && current_route.cost != ROUTE_MAX_COST) {
          current_route.TTL = ROUTE_GARBAGE_COLLECT;
          current_route.cost = ROUTE_MAX_COST;
          current_route.route_changed = TRUE;

          updateRoute(current_route);
          call LinkStateTimer.startOneShot(rand(1000, 5000));
        }
      }
    } else if (route.TTL == 0 && route.cost == ROUTE_MAX_COST) {
      deleteRoute(route.dest);
    }
  }

  void decrementRouteTimers() {
    uint16_t i;
    i = 0;

    while (i < call RouteTable.size()) {
      Route route = call RouteTable.get(i);
      decrementTimer(route);
      i++;
    }
  }

  void invalidate(Route route) {
    route.TTL = 1;
    decrementTimer(route);
  }

  command void LinkState.start() {
    dbg(ROUTING_CHANNEL, "Size of RouteTable: %d\n", call RouteTable.size());
    if (call RouteTable.size() == 0) { // no nodes - so error
      dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
      return;
    }

    if (!call RegularTimer.isRunning()) { //
      dbg(ROUTING_CHANNEL, "Intiating routing protocol...\n");
      call RegularTimer.startOneShot(rand(25000, 35000));
    }
  }

  //we want to send off packets to nodes:
  command void LinkState.send(pack * msg) {
    Route route;

    if (!inTable(msg->dest)) {
            dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg->src, msg->dest);
            return;
        }

    route = getRoute(msg -> dest);

    if (route.cost == ROUTE_MAX_COST) {
      dbg(GENERAL_CHANNEL, "No connection, cant send packet from %d to %d: the cost is infinte\n", msg->src, msg->dest);
      return;

    }
    dbg(GENERAL_CHANNEL, "src: %d, dest: %d, seq: %d, cost: %d, next hop: %d", msg -> src, msg -> dest, msg -> seq, route.cost, route.next_hop);

    call Sender.send( * msg, route.next_hop);
  }

  command void LinkState.recieve(pack * routing_packet) {
    uint16_t i;

    // Iterate over each route in the payload
    for (i = 0; i < routes; i++) {
      Route current_route;
      memcpy( & current_route, ( & routing_packet -> payload) + i * ROUTE_SIZE, ROUTE_SIZE);

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

        current_route.dest = routing_packet -> dest;
        current_route.next_hop = routing_packet -> src;
        current_route.TTL = ROUTE_TIMEOUT;
        current_route.route_changed = TRUE;

        call RouteTable.pushback(current_route);
        call LinkStateTimer.startOneShot(rand(1000, 5000));
        continue;
      }

      // Route Already Exists
      else {
        Route existing_route = getRoute(current_route.dest);

        // Update to existing route, reset TTL
        if (existing_route.next_hop == routing_packet -> src) {
          existing_route.TTL = ROUTE_TIMEOUT;
        }

        // Updated cost to existing route, or new cheaper cost
        if ((existing_route.next_hop == routing_packet -> src &&
            existing_route.cost != current_route.cost) ||
          existing_route.cost > current_route.cost) {

          existing_route.next_hop = routing_packet -> src;
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
    }
  }

  command void LinkState.updateNeighbors(uint32_t * neighbors, uint16_t numNeighbors) {
    uint16_t i = 0;
    
    uint16_t size = call RouteTable.size();
    

    while (i < size) {
      Route route = call RouteTable.get(i);
      uint16_t j;

      if (route.cost == ROUTE_MAX_COST) {
        continue;
      }

      if (route.cost == 1) {
        bool isNeighbor = FALSE;

        j = 0;
        while (j < numNeighbors) {
          if (route.dest == neighbors[j]) {
            isNeighbor = TRUE;
            break;
          }
          j++;
        }

        if (!isNeighbor) {
          invalidate(route);
        }
      }
      i++;
    }

    i = 0;
    while (i < numNeighbors) {
      
      Route route;

      route.cost = 1;
      route.dest = neighbors[i];
      route.next_hop = neighbors[i];
      route.TTL = ROUTE_TIMEOUT;
      route.route_changed = TRUE;

      if (inTable(route.dest)) {
        Route existing_route = getRoute(route.dest);

        if (existing_route.cost != route.cost) {
          updateRoute(route);
          call LinkStateTimer.startOneShot(rand(1000, 5000));
        }
      } 
      else {
        call RouteTable.pushback(route);
        call LinkStateTimer.startOneShot(rand(1000, 5000));
      }
      i++;
    }

    dbg(GENERAL_CHANNEL, "RouteTable size: %d\n", size);
  }

  command void LinkState.printRouteTable() {
    uint16_t size = call RouteTable.size();
    uint16_t i;

    dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
    i = 0;
    while (i < size) {

      Route route = call RouteTable.get(i);
      dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
      i++;
    }
    dbg(GENERAL_CHANNEL, "--------------------------------\n");
  }

  event void LinkStateTimer.fired() {
    uint16_t size = call RouteTable.size();
    uint16_t packet_index = 0;
    uint16_t current_route;
    pack msg;

    msg.src = TOS_NODE_ID;
    msg.TTL = 1;
    msg.protocol = PROTOCOL_DV;
    msg.seq = 0; // NOTE: Change if requests are needed

    memset(( & msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

    // Go through all routes looking for changed ones
    for (current_route = 0; current_route < size; current_route++) {
      Route route = call RouteTable.get(current_route);

      msg.dest = route.dest;

      if (route.route_changed) {

        memcpy(( & msg.payload) + packet_index * ROUTE_SIZE, &route, ROUTE_SIZE);

        packet_index++;
        if (packet_index == routes) {
          packet_index = 0;

          call Sender.send(msg, AM_BROADCAST_ADDR);
          memset(( & msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);
        }
      }
    }

    resetRouteUpdates();
  }

  event void RegularTimer.fired() {
    uint16_t size = call RouteTable.size();
    uint16_t i;

    call LinkStateTimer.stop();
    decrementRouteTimers();

    for (i = 0; i < size; i++) {
      Route route = call RouteTable.get(i);
      route.route_changed = TRUE;
      updateRoute(route);
    }

    signal LinkStateTimer.fired();
  }

}