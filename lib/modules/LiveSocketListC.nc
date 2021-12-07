#include "../../includes/socket.h"

typedef struct socket_object_t{
    bool inUse;
    socket_t fd;
    socket_storage_t store;
}socket_object_t;

socket_object_t createNewSocket(bool status, socket_t fd, socket_storage_t store) {
   socket_object_t socketObject;
                   socketObject.inUse = status;
                   socketObject.fd = fd;
                   socketObject.store = store;

   return socketObject;
}

module LiveSocketListC {
   provides interface LiveSocketList;
}

implementation {
   socket_object_t socketList[MAX_SOCKET_COUNT];
   uint16_t socketCount = 0;

   command int LiveSocketList.insert(socket_t fd, socket_storage_t socket) {
       socketCount++;

       socketList[socketCount] = createNewSocket(TRUE, fd, socket);

       dbg(NEIGHBOR_CHANNEL,"socketLocation://%d\n", socketCount);

       return socketCount;
   }

   command socket_storage_t* LiveSocketList.getStore(uint16_t socketLocation) {
      return &socketList[socketLocation].store;
   }

   command socket_t LiveSocketList.getFd(uint16_t socketLocation) {
      return socketList[socketLocation].fd;
   }

   command int LiveSocketList.checkIfPortIsListening(uint8_t destPort) {
      int i;
      for (i = 0; i <= socketCount; i++) {
         if (socketList[i].inUse &&
             socketList[i].store.state == SOCK_LISTEN &&
             socketList[i].store.sockAddr.srcPort == destPort) {
             return i;
         }
      }

      return -1;
   }

   command int LiveSocketList.search(socket_addr_t *connection, socketState status) {
      int i;

      for (i = 0; i <= socketCount; i++) {
           if (socketList[i].inUse &&
              socketList[i].store.state == status &&
              connection->destPort == socketList[i].store.sockAddr.srcPort &&
              connection->srcPort == socketList[i].store.sockAddr.destPort &&
              connection->srcAddr == socketList[i].store.sockAddr.destAddr &&
              connection->destAddr == socketList[i].store.sockAddr.srcAddr) {


              return i;
           }
      }
      return -1;
   }
}
