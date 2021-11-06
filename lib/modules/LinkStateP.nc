#include <Timer.h>
#include "../../includes/route.h"
#include "../../includes/packet.h"
#define min(a, b)((a) < (b) ? (a) : (b))

module LinkStateP {
  provides interface LinkState;

  uses interface List <Route> as RoutingTable;
  uses interface SimpleSend as Sender;

  uses interface Random;

  uses interface Timer <TMilli> as LinkStateTimer;
  uses interface Timer <TMilli> as RegularTimer;
}

implementation {

  uint16_t routesPerPacket = 1;

  //gathering a random number:
  uint32_t randNum(uint32_t min, uint32_t max) {
    return (call Random.rand16() % (max - min + 1)) + min;
  }

  //checking whether or not the route is in the table of routes
  bool inTable(uint16_t dest) {
    uint16_t size = call RoutingTable.size();
    uint16_t i;
    bool isInTable = FALSE; //false to begin with 

    
    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i); //gathering an element from the Table to use

      if (route.dest == dest) {
        isInTable = TRUE; //based of the destination of the packet 
        break;
      }
    }

    return isInTable;
  }

    //we are going to gather the most current route based of the destination of the packet:
  Route getRoute(uint16_t dest) {
    Route return_current_route;
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);

      if (route.dest == dest) {
        return_current_route = route;
        break;
      }
    }

    return return_current_route;
  }

    //We are removing duplicate routes 
  void removeRoute(uint16_t dest) {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);

      if (route.dest == dest) {
        call RoutingTable.remove(i);
        return;
      }
    }

    dbg(ROUTING_CHANNEL, "Error: Cant remove route that doesnt exist %d\n", dest);
  }

  void updateRoute(Route route) {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route current = call RoutingTable.get(i);

      if (route.dest == current.dest) {
        call RoutingTable.set(i, route);
        return;
      }
    }

    dbg(ROUTING_CHANNEL, "Error: Route may not Exist %d\n", route.dest);
  }

  void resetRouteUpdates() {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      route.route_changed = FALSE;
      call RoutingTable.set(i, route);
    }
  }

  void decrementTimer(Route route) {
    route.TTL = route.TTL - 1;
    updateRoute(route);

    if (route.TTL == 0 && route.cost != ROUTE_MAX_COST) {
      uint16_t size = call RoutingTable.size();
      uint16_t i;

      route.TTL = ROUTE_GARBAGE_COLLECT;
      route.cost = ROUTE_MAX_COST;
      route.route_changed = TRUE;

      updateRoute(route);
      call LinkStateTimer.startOneShot(randNum(1000, 5000));

      for (i = 0; i < size; i++) {
        Route current = call RoutingTable.get(i);

        if (current.next_hop == route.next_hop && current.cost != ROUTE_MAX_COST) {
          current.TTL = ROUTE_GARBAGE_COLLECT;
          current.cost = ROUTE_MAX_COST;
          current.route_changed = TRUE;

          updateRoute(current);
          call LinkStateTimer.startOneShot(randNum(1000, 5000));
        }
      }
    }
    else if (route.TTL == 0 && route.cost == ROUTE_MAX_COST) {
      removeRoute(route.dest);
    }
  }

  void decrementRouteTimers() {
    uint16_t i;

    for (i = 0; i < call RoutingTable.size(); i++) {
      Route route = call RoutingTable.get(i);

      decrementTimer(route);
    }
  }

  void invalidate(Route route) {
    route.TTL = 1;
    decrementTimer(route);
  }

  command void LinkState.start() {
    if (call RoutingTable.size() == 0) {
      dbg(ROUTING_CHANNEL, "Error: Can't route with no neighbors! Make sure to updateNeighbors first.\n");
      return;
    }

    if (!call RegularTimer.isRunning()) {
      dbg(ROUTING_CHANNEL, "Intiating routing protocol...\n");
      call RegularTimer.startPeriodic(randNum(25000, 35000));
    }
  }

  command void LinkState.send(pack * msg) {
    Route route;

    if (!inTable(msg -> dest)) {
      dbg(ROUTING_CHANNEL, "Error: Can't send packet from %d to %d\n", msg -> src, msg -> dest);
      return;
    }

    route = getRoute(msg -> dest);

    if (route.cost == ROUTE_MAX_COST) {
      dbg(ROUTING_CHANNEL, "Error: Can't send packet from %d to %d\n", msg -> src, msg -> dest);
      return;
    }

    dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", msg -> src, msg -> dest, msg -> seq, route.next_hop, route.cost);

    call Sender.send(* msg, route.next_hop);
  }

    //when we recieve a packet:
  command void LinkState.recieve(pack * routing_packet) {
    uint16_t i;

    for (i = 0; i < routesPerPacket; i++) {
      Route current;
      memcpy( & current, ( & routing_packet -> payload) + i * ROUTE_SIZE, ROUTE_SIZE);

      if (current.dest == 0) {
        continue;
      }

      if (current.dest == TOS_NODE_ID) {
        continue;
      }

      if (current.cost > ROUTE_MAX_COST) {
        dbg(ROUTING_CHANNEL, "Error: Invalid route cost of %d from %d\n", current.cost, current.dest);
        continue;
      }

      if (current.next_hop == TOS_NODE_ID) {
        current.cost = ROUTE_MAX_COST;
      }

      current.cost = min(current.cost + 1, ROUTE_MAX_COST);

      if (!inTable(current.dest)) {
        if (current.cost == ROUTE_MAX_COST) {
          continue;
        }

        current.dest = routing_packet -> dest;
        current.next_hop = routing_packet -> src;
        current.TTL = ROUTE_TIMEOUT;
        current.route_changed = TRUE;

        call RoutingTable.pushback(current);

        call LinkStateTimer.startOneShot(randNum(1000, 5000));
        continue;
      }

      else {
        Route existing = getRoute(current.dest);

        if (existing.next_hop == routing_packet -> src) {
          existing.TTL = ROUTE_TIMEOUT;
        }

        if ((existing.next_hop == routing_packet -> src &&
            existing.cost != current.cost) ||
          existing.cost > current.cost) {

          existing.next_hop = routing_packet -> src;
          existing.TTL = ROUTE_TIMEOUT;
          existing.route_changed = TRUE;

          if (current.cost == ROUTE_MAX_COST &&
            existing.cost != ROUTE_MAX_COST) {

            existing.TTL = ROUTE_GARBAGE_COLLECT;
          }

          existing.cost = current.cost;

        } else {
          existing.TTL = ROUTE_TIMEOUT;
        }

        updateRoute(existing);
      }
    }
  }

  command void LinkState.updateNeighbors(uint32_t * neighbors, uint16_t numNeighbors) {
    uint16_t i;
    uint16_t size = call RoutingTable.size();

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      uint16_t j;

      if (route.cost == ROUTE_MAX_COST) {
        continue;
      }

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

    for (i = 0; i < numNeighbors; i++) {
      Route route;

      route.dest = neighbors[i];
      route.cost = 1;
      route.next_hop = neighbors[i];
      route.TTL = ROUTE_TIMEOUT;
      route.route_changed = TRUE;

      if (inTable(route.dest)) {
        Route existing = getRoute(route.dest);

        if (existing.cost != route.cost) {
          updateRoute(route);
          call LinkStateTimer.startOneShot(randNum(1000, 5000));
        }
      }
      else {
        call RoutingTable.pushback(route);
        call LinkStateTimer.startOneShot(randNum(1000, 5000));
      }
    }
  }

  event void LinkStateTimer.fired() {
    uint16_t size = call RoutingTable.size();
    uint16_t packet_index = 0;
    uint16_t current;
    pack msg;

    msg.src = TOS_NODE_ID;
    msg.TTL = 1;
    msg.protocol = PROTOCOL_LINKSTATE;
    msg.seq = 0;

    memset(( & msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

    for (current = 0; current < size; current++) {
      Route route = call RoutingTable.get(current);

      msg.dest = route.dest;

      if (route.route_changed) {

        memcpy(( & msg.payload) + packet_index * ROUTE_SIZE, & route, ROUTE_SIZE);

        packet_index++;
        if (packet_index == routesPerPacket) {
          packet_index = 0;

          call Sender.send(msg, AM_BROADCAST_ADDR);
          memset(( & msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);
        }
      }
    }

    resetRouteUpdates();
  }

  event void RegularTimer.fired() {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    call LinkStateTimer.stop();
    decrementRouteTimers();

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      route.route_changed = TRUE;
      updateRoute(route);
    }

    signal LinkStateTimer.fired();
  }

  command void LinkState.printRouteTable() {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      dbg(GENERAL_CHANNEL, "--- %d\t%d\t%d\n", route.dest, route.next_hop, route.cost);
    }
    dbg(GENERAL_CHANNEL, "--------------------------------\n");
  }
}