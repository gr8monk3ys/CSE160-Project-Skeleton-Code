#include <Timer.h>

#include "../../includes/route.h"

#include "../../includes/packet.h"

#undef min
#define min(a, b)((a) < (b) ? (a) : (b))

module LinkStateP {
  provides interface LinkState;

  uses interface List < Route > as RoutingTable;
  uses interface SimpleSend as Sender;

  uses interface Random;

  uses interface Timer < TMilli > as TriggeredEventTimer;
  uses interface Timer < TMilli > as RegularTimer;
}

implementation {

  uint16_t routesPerPacket = 1;

  uint32_t randNum(uint32_t min, uint32_t max) {
    return (call Random.rand16() % (max - min + 1)) + min;
  }

  bool inTable(uint16_t dest) {
    uint16_t size = call RoutingTable.size();
    uint16_t i;
    bool isInTable = FALSE;

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);

      if (route.dest == dest) {
        isInTable = TRUE;
        break;
      }
    }

    return isInTable;
  }

  Route getRoute(uint16_t dest) {
    Route return_route;
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);

      if (route.dest == dest) {
        return_route = route;
        break;
      }
    }

    return return_route;
  }

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

    dbg(ROUTING_CHANNEL, "ERROR - Can't remove nonexistent route %d\n", dest);
  }

  void updateRoute(Route route) {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    for (i = 0; i < size; i++) {
      Route current_route = call RoutingTable.get(i);

      if (route.dest == current_route.dest) {
        call RoutingTable.set(i, route);
        return;
      }
    }

    dbg(ROUTING_CHANNEL, "ERROR - Update attempt on nonexistent route %d\n", route.dest);
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
      call TriggeredEventTimer.startOneShot(randNum(1000, 5000));

      for (i = 0; i < size; i++) {
        Route current_route = call RoutingTable.get(i);

        if (current_route.next_hop == route.next_hop && current_route.cost != ROUTE_MAX_COST) {
          current_route.TTL = ROUTE_GARBAGE_COLLECT;
          current_route.cost = ROUTE_MAX_COST;
          current_route.route_changed = TRUE;
          updateRoute(current_route);
          call TriggeredEventTimer.startOneShot(randNum(1000, 5000));
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
      dbg(ROUTING_CHANNEL, "ERROR - Can't route with no neighbors! Make sure to updateNeighbors first.\n");
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
      dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: no connection\n", msg -> src, msg -> dest);
      return;
    }

    route = getRoute(msg -> dest);

    if (route.cost == ROUTE_MAX_COST) {
      dbg(ROUTING_CHANNEL, "Cannot send packet from %d to %d: cost infinity\n", msg -> src, msg -> dest);
      return;
    }

    dbg(ROUTING_CHANNEL, "Routing Packet: src: %d, dest: %d, seq: %d, next_hop: %d, cost: %d\n", msg -> src, msg -> dest, msg -> seq, route.next_hop, route.cost);

    call Sender.send( * msg, route.next_hop);
  }

  command void LinkState.recieve(pack * routing_packet) {
    uint16_t i;

    for (i = 0; i < routesPerPacket; i++) {
      Route current_route;
      memcpy( & current_route, ( & routing_packet -> payload) + i * ROUTE_SIZE, ROUTE_SIZE);

      if (current_route.dest == 0) {
        continue;
      }

      if (current_route.dest == TOS_NODE_ID) {
        continue;
      }

      if (current_route.cost > ROUTE_MAX_COST) {
        dbg(ROUTING_CHANNEL, "ERROR - Invalid route cost of %d from %d\n", current_route.cost, current_route.dest);
        continue;
      }

      if (current_route.next_hop == TOS_NODE_ID) {
        current_route.cost = ROUTE_MAX_COST;
      }

      current_route.cost = min(current_route.cost + 1, ROUTE_MAX_COST);

      if (!inTable(current_route.dest)) {
        if (current_route.cost == ROUTE_MAX_COST) {
          continue;
        }

        current_route.dest = routing_packet -> dest;
        current_route.next_hop = routing_packet -> src;
        current_route.TTL = ROUTE_TIMEOUT;
        current_route.route_changed = TRUE;

        call RoutingTable.pushback(current_route);

        call TriggeredEventTimer.startOneShot(randNum(1000, 5000));
        continue;
      }

      else {
        Route existing_route = getRoute(current_route.dest);

        if (existing_route.next_hop == routing_packet -> src) {
          existing_route.TTL = ROUTE_TIMEOUT;
        }

        if ((existing_route.next_hop == routing_packet -> src &&
            existing_route.cost != current_route.cost) ||
          existing_route.cost > current_route.cost) {

          existing_route.next_hop = routing_packet -> src;
          existing_route.TTL = ROUTE_TIMEOUT;
          existing_route.route_changed = TRUE;

          if (current_route.cost == ROUTE_MAX_COST &&
            existing_route.cost != ROUTE_MAX_COST) {
            existing_route.TTL = ROUTE_GARBAGE_COLLECT;
          }
          existing_route.cost = current_route.cost;
        } else {
          existing_route.TTL = ROUTE_TIMEOUT;
        }

        updateRoute(existing_route);
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

        if (existing_route.cost != route.cost) {
          updateRoute(route);
          call TriggeredEventTimer.startOneShot(randNum(1000, 5000));
        }
      }
      else {
        call RoutingTable.pushback(route);
        call TriggeredEventTimer.startOneShot(randNum(1000, 5000));
      }
    }
  }

  command void LinkState.printRouteTable() {
    uint16_t size = call RoutingTable.size();
    uint16_t i;

    dbg(GENERAL_CHANNEL, "--- dest\tnext hop\tcost ---\n");
    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      dbg(GENERAL_CHANNEL, "--- %d\t\t%d\t\t\t%d\n", route.dest, route.next_hop, route.cost);
    }
    dbg(GENERAL_CHANNEL, "--------------------------------\n");
  }

  event void TriggeredEventTimer.fired() {
    uint16_t size = call RoutingTable.size();
    uint16_t packet_index = 0;
    uint16_t current_route;
    pack msg;

    msg.src = TOS_NODE_ID;
    msg.TTL = 1;
    msg.protocol = PROTOCOL_LINKSTATE;
    msg.seq = 0;

    memset(( & msg.payload), '\0', PACKET_MAX_PAYLOAD_SIZE);

    for (current_route = 0; current_route < size; current_route++) {
      Route route = call RoutingTable.get(current_route);

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

    call TriggeredEventTimer.stop();
    decrementRouteTimers();

    for (i = 0; i < size; i++) {
      Route route = call RoutingTable.get(i);
      route.route_changed = TRUE;
      updateRoute(route);
    }

    signal TriggeredEventTimer.fired();
  }
}