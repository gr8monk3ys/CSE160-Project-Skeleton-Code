#ifndef TCP_T_H__
#define TCP_T_H__

enum {
    SYN = 0,
    SYN_ACK = 1,
    DATA = 2,
    ACK = 3,
    FIN = 4,
    FIN_ACK = 5,
    TCP_MAX_DATA_SIZE = PACKET_MAX_PAYLOAD_SIZE - 6
};

typedef struct TCP_t {
    nx_uint16_t destPort;
    nx_uint16_t srcPort;
    nx_uint16_t seq;
    nx_uint8_t flag;
    nx_uint8_t window;
    nx_uint8_t data[TCP_MAX_DATA_SIZE];
} TCP_t;

#endif
