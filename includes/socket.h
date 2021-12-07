// #ifndef __SOCKET_H__
// #define __SOCKET_H__

// enum{
    
//     MAX_NUM_OF_SOCKETS = 10,
//     ROOT_SOCKET_ADDR = 255,
//     ROOT_SOCKET_PORT = 255,
//     SOCKET_BUFFER_SIZE = 128, //buffer size
//     NULL_SOCKET = 0
// };

// typedef enum socket_state{
//     CLOSED,
//     LISTEN,
//     ESTABLISHED,
//     SYN_SENT,
//     SYN_RCVD,
//     FIN_WAIT
// }socket_state;


// typedef nx_uint8_t nx_socket_port_t;
// typedef uint8_t socket_port_t;

// // socket_addr_t is a simplified version of an IP connection.
// typedef nx_struct socket_addr_t{
//     nx_socket_port_t port;
//     nx_uint16_t addr;
// }socket_addr_t;


// // File descripter id. Each id is associated with a socket_store_t
// typedef uint8_t socket_t;

// // State of a socket. 
// typedef struct socket_store_t{
//     uint8_t flag;
//     enum socket_state state;
//     socket_port_t src;
//     socket_addr_t dest;
//     uint8_t timeout;

//     // This is the sender portion.
//     uint8_t sendBuff[SOCKET_BUFFER_SIZE];
//     uint8_t lastWritten;
//     uint8_t lastAck;
//     uint8_t lastSent;

//     // This is the receiver portion
//     uint8_t rcvdBuff[SOCKET_BUFFER_SIZE];
//     uint8_t lastRead;
//     uint8_t lastRcvd;
//     uint8_t nextExpected;

//     uint16_t RTT;
//     uint8_t effectiveWindow;
// }socket_store_t;

// #endif

#ifndef __STRUCT_H__
#define __STRUCT_H__

typedef enum socketState{
   SOCK_ESTABLISHED  = 0,
   SOCK_LISTEN       = 1,
   SOCK_CLOSED       = 2,
   SOCK_SYN_SENT     = 3,
   SOCK_CLOSE_WAIT   = 4,
   SOCK_FIN_WAIT     = 5
}socketState;

enum{
    MAX_SOCKET_COUNT = 99,
    SOCKET_SEND_BUFFER_SIZE = 128,
    SOCKET_RECEIVE_BUFFER_SIZE = 128,
    NULL_SOCKET = 0
};

typedef nx_struct socket_addr_t {
   nx_uint8_t srcPort;
   nx_uint8_t destPort;
   nx_uint16_t srcAddr;
   nx_uint16_t destAddr;
} socket_addr_t;

typedef struct socket_storage_t{
    socketState state;
    socket_addr_t sockAddr;
    uint8_t sendBuff[SOCKET_SEND_BUFFER_SIZE];
    uint8_t recBuff[SOCKET_RECEIVE_BUFFER_SIZE];
    uint8_t timeout;
    uint16_t seqNum;
    uint16_t lastByteSent;
    uint16_t lastByteWritten;
    uint16_t lastByteAck;
    uint16_t lastByteRec;
    uint16_t lastByteRead;
    uint16_t lastByteExpected;
}socket_storage_t;

typedef uint16_t socket_t;

#endif
