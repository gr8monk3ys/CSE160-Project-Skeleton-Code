#ifndef ROUTE_H
#define ROUTE_H

enum {
    ROUTE_MAX_COST = 16,
    ROUTE_SIZE = 5,
    ROUTE_TIMEOUT = 6,
    ROUTE_GARBAGE_COLLECT = 4
};

typedef nx_struct Route {
    nx_uint8_t dest;
    nx_uint8_t cost;
    nx_uint8_t next_hop;
    nx_uint8_t TTL;
    nx_uint8_t route_changed;
} Route;

#endif // ROUTE_H