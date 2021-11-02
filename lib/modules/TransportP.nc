#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCP_t.h"

module TransportP{
    provides interface Transport;

    uses interface Hashmap<socket_storage_t*> as SocketPointerMap;

    uses interface Hashmap<RouterTableRow> as RouterTable;

    uses interface List<socket_addr_t> as Connections;

    uses interface SimpleSend as Sender;

    uses interface LiveSocketList;

    uses interface WindowManager;

    uses interface Random;
}

implementation{
   pack sendPack;
   TCP_t sendPayload;
   uint16_t seqNum = 0;
   uint8_t data[TCP_MAX_DATA_SIZE];
   uint8_t MAX_NODE_COUNT = 30;

   TCP_t assignSocketID();

   socket_addr_t assignTempAddress(uint8_t srcPort, uint8_t destPort, uint16_t srcAddr, uint16_t destAddr);

   socket_addr_t assignTempAddress(uint8_t srcPort, uint8_t destPort, uint16_t srcAddr, uint16_t destAddr) {
       socket_addr_t socketAddress;
                     socketAddress.srcPort = srcPort;
                     socketAddress.destPort = destPort;
                     socketAddress.srcAddr = srcAddr;
                     socketAddress.destAddr = destAddr;

          return socketAddress;
   }

   void sendWithTimerPing(pack* Package);

   void makePack(pack* Package, uint8_t src, uint8_t dest, uint8_t TTL, uint8_t protocol, uint8_t seq, TCP_t* payload, uint8_t length);

   void makeTCPPack(TCP_t* Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t* content, uint8_t length);

   void sendWithTimerPing(pack* Package) {
       uint8_t finDest = Package->dest;
       uint8_t nextDest = finDest;
       uint8_t preventRun = 0;
       RouterTableRow row;

       while ((!call RouterTable.contains(nextDest)) && preventRun < 30) {
           nextDest++;
           nextDest >= MAX_NODE_COUNT ? nextDest = 1;
           preventRun++;
       }
       row = call RouterTable.get(nextDest);
       row.distance == 1 ? call Sender.send(sendPack, findDest) : call Sender.send(sendPack, row.nextNode)
}

TCP_t assignSocketID() {
    TCP_t socketID = 0;

    while (socketID == 0 || call SocketPointerMap.contains(socketID)) {
        socketID = call Random.rand16();
    }
    return socketID;
}

command uint16_t Transport.read(TCP_t fd, uint8_t flag) {
    return FAIL;
}

command error_t Transport.connect(TCP_t fd, socket_addr_t* addr) {
     socket_storage_t* temp_socket;

     dbg(NEIGHBOR_CHANNEL, "Attempting to connect to socket-%d\n", fd);

     if (call SocketPointerMap.contains(fd)) {
         temp_socket = call SocketPointerMap.get(fd);

         makeTCPPack(&sendPayload,
                     temp_socket->sockAddr.srcPort,
                     temp_socket->sockAddr.destPort,
                     0,
                     SYN,
                     0,
                     sendPayload.data,
                     TCP_MAX_DATA_SIZE);

         makePack(&sendPack,
                  temp_socket->sockAddr.srcAddr,
                  temp_socket->sockAddr.destAddr,
                  MAX_TTL,
                  PROTOCOL_TCP,
                  seqNum,
                  &sendPayload,
                  PACKET_MAX_PAYLOAD_SIZE);

         sendWithTimerPing(&sendPack);

         temp_socket->state = SOCK_SYN_SENT;
         return SUCCESS;
     }
     dbg(NEIGHBOR_CHANNEL, "Error attempting connection\n");
     return FAIL;
}

command error_t Transport.close(TCP_t fd) {
   socket_storage_t* socket;
   call SocketPointerMap.contains(fd) ? call Transport.write(fd, FIN)
}

command error_t Transport.listen(TCP_t fd) {
   socket_storage_t* socket;

   if (call SocketPointerMap.contains(fd)) {
      socket = call SocketPointerMap.get(fd);
      socket->state = SOCK_LISTEN;
      return SUCCESS;
   }
else {
    dbg(NEIGHBOR_CHANNEL,"Socket not found\n");
    return FAIL;
}
}

void makePack(pack* Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, TCP_t* payload, uint8_t length) {
  Package->src = src;
  Package->dest = dest;
  Package->TTL = TTL;
  Package->seq = seq;
  Package->protocol = protocol;
  memcpy(Package->payload, payload, length);
}

void makeTCPPack(TCP_t* Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t* content, uint8_t length) {
   Package->srcPort = srcPort;
   Package->destPort = destPort;
   Package->seq = seq;
   Package->flag = flag;
   Package->window = window;
   memcpy(Package->data, content, length);
}

}