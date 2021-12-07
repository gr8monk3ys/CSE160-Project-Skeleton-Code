#include "../../includes/socket.h"

interface LiveSocketList {
   command int insert(socket_t fd, socket_storage_t s);
   command socket_storage_t* getStore(uint16_t i);
   command socket_t getFd(uint16_t i);
   command int checkIfPortIsListening(uint8_t destPort);
   command int search(socket_addr_t *connection, socketState status);
}
