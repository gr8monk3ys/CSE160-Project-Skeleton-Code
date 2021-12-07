#include "../../includes/packet.h"

#include "../../includes/socket.h"

#include "../../includes/TCP_t.h"

module TransportP {
  provides interface Transport;

  uses interface Hashmap < socket_storage_t * > as SocketPointerMap;

  //uses interface Hashmap < Route > as RoutingTable;
  uses interface List <Route> as RoutingTable; //to access link state values for transport:

  uses interface List < socket_addr_t > as Connections;

  uses interface SimpleSend as Sender;

  uses interface LiveSocketList;

  uses interface Window;

  uses interface Random;
}

implementation {
  pack sendPackage;
  TCP_t sendPayload;
  uint16_t seqNum = 0;
  uint8_t data[TCP_MAX_DATA_SIZE];
  uint8_t MAX_NODE_COUNT = 999;
  Route row;

  socket_t assignSocketID();

  socket_addr_t assignTempAddress(nx_uint8_t srcPort, nx_uint8_t destPort, nx_uint16_t srcAddr, nx_uint16_t destAddr);

  socket_addr_t assignTempAddress(nx_uint8_t srcPort, nx_uint8_t destPort, nx_uint16_t srcAddr, nx_uint16_t destAddr) {
    socket_addr_t socketAddress;
    socketAddress.srcPort = srcPort;
    socketAddress.destPort = destPort;
    socketAddress.srcAddr = srcAddr;
    socketAddress.destAddr = destAddr;

    return socketAddress;
  }


  void sendWithTimerPing(pack * Package);

  //bool inTable(uint16_t dest);

  void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, TCP_t * payload, uint8_t length);

  void makeTCPPack(TCP_t * Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t * content, uint8_t length);


  void sendWithTimerPing(pack * Package) {
    uint8_t finalDestination = Package -> dest;
    uint8_t nextDestination = finalDestination;
    uint8_t preventRun = 0;
    uint8_t size = call RoutingTable.size();
    uint8_t i;

    for(i = 0; i < size; i++ ){
    Route row = call RoutingTable.get(i);
    }

    
    while ((!row.next_hop) && preventRun < 999) {
      nextDestination++;

      if (nextDestination >= MAX_NODE_COUNT) {
        nextDestination = 1;
      }

      preventRun++;
    }

    //row = call RoutingTable.get(nextDestination);
    //row.next_hop

    if (row.cost == 1) {
      call Sender.send(sendPackage, finalDestination);
    } else {
      call Sender.send(sendPackage, row.next_hop);
    }
  }

  socket_t assignSocketID() {
    socket_t socketID = 0;

    while (socketID == 0 || call SocketPointerMap.contains(socketID)) {
      socketID = call Random.rand16();
    }

    return socketID;
  }

  command uint16_t Transport.read(socket_t fd, uint8_t flag) {
    return FAIL;
  }

  command error_t Transport.connect(socket_t fd, socket_addr_t * addr) {
    socket_storage_t * temp_socket;

    dbg(NEIGHBOR_CHANNEL, "Attempting to connect to socket-%d\n", fd);

    if (call SocketPointerMap.contains(fd)) {
      temp_socket = call SocketPointerMap.get(fd);

      makeTCPPack( & sendPayload,
        temp_socket -> sockAddr.srcPort,
        temp_socket -> sockAddr.destPort,
        0,
        SYN,
        0,
        sendPayload.data,
        TCP_MAX_DATA_SIZE);

      makePack( & sendPackage,
        temp_socket -> sockAddr.srcAddr,
        temp_socket -> sockAddr.destAddr,
        MAX_TTL,
        PROTOCOL_TCP,
        seqNum, &
        sendPayload,
        PACKET_MAX_PAYLOAD_SIZE);

      sendWithTimerPing( & sendPackage);

      temp_socket -> state = SOCK_SYN_SENT;
      return SUCCESS;
    }
    dbg(NEIGHBOR_CHANNEL, "Error attempting connection\n");
    return FAIL;
  }

  command socket_t Transport.socket() {
    int socketLocation = -1;
    socket_t fd;
    socket_storage_t tempSocket;
    tempSocket.state = SOCK_CLOSED;
    tempSocket.timeout = 6;
    tempSocket.lastByteAck = 1;
    tempSocket.lastByteSent = 0;
    tempSocket.seqNum = 0;
    tempSocket.lastByteRec = 0;
    tempSocket.lastByteWritten = 0;
    tempSocket.lastByteRead = 0;
    tempSocket.lastByteExpected = 0;

    if (call SocketPointerMap.size() > MAX_SOCKET_COUNT) {
      return NULL_SOCKET;
    }

    fd = assignSocketID();

    socketLocation = call LiveSocketList.insert(fd, tempSocket);

    if (socketLocation != -1) {
      call SocketPointerMap.insert(fd, call LiveSocketList.getStore(socketLocation));
    }

    dbg(NEIGHBOR_CHANNEL, "New socket: %d\n", fd);

    return fd;
  }

  command error_t Transport.bind(socket_t fd, socket_addr_t * socketAddress) {
    socket_storage_t * tempSocketAddress;

    if (call SocketPointerMap.contains(fd)) {
      tempSocketAddress = call SocketPointerMap.get(fd);
      tempSocketAddress -> sockAddr.srcPort = socketAddress -> srcPort;
      tempSocketAddress -> sockAddr.destPort = socketAddress -> destPort;
      tempSocketAddress -> sockAddr.srcAddr = socketAddress -> srcAddr;
      tempSocketAddress -> sockAddr.destAddr = socketAddress -> destAddr;

      dbg(NEIGHBOR_CHANNEL, "Bounded client to server!\n");
      return SUCCESS;
    }

    dbg(NEIGHBOR_CHANNEL, "Error: can't bind!\n");
    return FAIL;
  }

  command socket_t Transport.accept() {
    socket_t fd;
    socket_storage_t * tempSocket;

    socket_addr_t newConnection = call Connections.popfront();
    socket_addr_t socketAddress;
    dbg(NEIGHBOR_CHANNEL, "Connection accepted!\n");
    fd = call Transport.socket();

    if (fd != NULL_SOCKET) {
      // reverse the address
      socketAddress = assignTempAddress(newConnection.destPort,
        newConnection.srcPort,
        newConnection.destAddr,
        newConnection.srcAddr);

      if (call Transport.bind(fd, & socketAddress) == SUCCESS) {
        tempSocket = call SocketPointerMap.get(fd);

        // SYN_ACK
        makeTCPPack( & sendPayload,
          socketAddress.srcPort,
          socketAddress.destPort,
          0,
          SYN_ACK,
          0,
          sendPayload.data,
          TCP_MAX_DATA_SIZE);

        makePack( & sendPackage,
          socketAddress.srcAddr,
          socketAddress.destAddr,
          MAX_TTL,
          PROTOCOL_TCP,
          seqNum, &
          sendPayload,
          PACKET_MAX_PAYLOAD_SIZE);

        seqNum++;

        sendWithTimerPing( & sendPackage);

        tempSocket -> state = SOCK_SYN_SENT;

        return fd;
      }
    }
  }

  command uint16_t Transport.write(socket_t fd, uint8_t flag) {
    socket_storage_t * tempSocket;
    uint16_t tempSeqNum;
    uint8_t advertisedWindow;

    if (call SocketPointerMap.contains(fd)) {
      tempSocket = call SocketPointerMap.get(fd);

      switch (flag) {
      case DATA:
        if (call Window.initData(fd, & data, & tempSeqNum) == FAIL) {
          return;
        }

        advertisedWindow = 0;
        break;
      case ACK:
        tempSeqNum = tempSocket -> lastByteExpected;
        advertisedWindow = 70 - (tempSocket -> lastByteExpected - tempSocket -> lastByteRead);
        break;
      case FIN:
        tempSeqNum = tempSocket -> lastByteSent;
        advertisedWindow = 0;
        break;
      case FIN_ACK:
        tempSeqNum = tempSocket -> lastByteExpected;
        advertisedWindow = 0;
        break;
      default:
        return;
      }

      makeTCPPack( & sendPayload,
        tempSocket -> sockAddr.srcPort,
        tempSocket -> sockAddr.destPort,
        tempSeqNum,
        flag,
        advertisedWindow, &
        data,
        TCP_MAX_DATA_SIZE);

      makePack( & sendPackage,
        tempSocket -> sockAddr.srcAddr,
        tempSocket -> sockAddr.destAddr,
        MAX_TTL,
        PROTOCOL_TCP,
        seqNum, &
        sendPayload,
        PACKET_MAX_PAYLOAD_SIZE);

      tempSeqNum++;
      sendWithTimerPing( & sendPackage);
      return;
    }
  }

  command error_t Transport.receive(pack * package) {
    socket_storage_t * tempSocket;
    TCP_t * payload = (TCP_t * ) package -> payload;

    socket_addr_t socketAddress = assignTempAddress(payload -> srcPort,
      payload -> destPort,
      package -> src,
      package -> dest);
    uint8_t socketLocation = -1; // yeet
    uint8_t i;

    switch (payload -> flag) {
    case SYN:
      dbg(NEIGHBOR_CHANNEL, "SYN packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      socketLocation = call LiveSocketList.checkIfPortIsListening(payload -> destPort);

      if (socketLocation != -1) {
        call Connections.pushback(socketAddress);

        return SUCCESS;
      }

      dbg(NEIGHBOR_CHANNEL, "Could not find listening port\n");
      return FAIL;
      break;

    case SYN_ACK:
      dbg(NEIGHBOR_CHANNEL, "SYN_ACK packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_SYN_SENT);

      if (socketLocation != -1) {

        tempSocket = call LiveSocketList.getStore(socketLocation);
        tempSocket -> state = SOCK_ESTABLISHED;

        makeTCPPack( & sendPayload,
          tempSocket -> sockAddr.srcPort,
          tempSocket -> sockAddr.destPort,
          0,
          ACK,
          0,
          payload -> data,
          TCP_MAX_DATA_SIZE);

        makePack( & sendPackage,
          tempSocket -> sockAddr.srcAddr,
          tempSocket -> sockAddr.destAddr,
          MAX_TTL,
          PROTOCOL_TCP,
          seqNum, &
          sendPayload,
          PACKET_MAX_PAYLOAD_SIZE);

        seqNum++;

        sendWithTimerPing( & sendPackage);
        return SUCCESS;
      }

      return FAIL;
      break;

    case ACK:
      dbg(NEIGHBOR_CHANNEL, "ACK packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_ESTABLISHED);

      if (socketLocation != -1 && socketLocation != 255) {

        if (call Window.receiveACK(call LiveSocketList.getFd(socketLocation), payload) == FIN) {
          tempSocket = call LiveSocketList.getStore(socketLocation);
          tempSocket -> state = SOCK_FIN_WAIT;

          call Transport.write(call LiveSocketList.getFd(socketLocation), FIN);
        }

        return SUCCESS;
      }

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_SYN_SENT);

      if (socketLocation != -1 && socketLocation != 255) {
        tempSocket = call LiveSocketList.getStore(socketLocation);
        tempSocket -> state = SOCK_ESTABLISHED;

        dbg(NEIGHBOR_CHANNEL, "Connection established with node://%d:%d\n", package -> src, payload -> destPort);
        return SUCCESS;
      }

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_FIN_WAIT);

      if (socketLocation != -1 && socketLocation != 255) {
        return SUCCESS;
      }

      dbg(NEIGHBOR_CHANNEL, "Error: No connection\n");
      return FAIL;

      break;

    case DATA:
      dbg(NEIGHBOR_CHANNEL, "DATA packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_ESTABLISHED);

      if (socketLocation != -1 && socketLocation != 255) {
        call Window.receiveData(call LiveSocketList.getFd(socketLocation), payload);

        call Transport.write(call LiveSocketList.getFd(socketLocation), ACK);
        return SUCCESS;
      }

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_SYN_SENT);

      if (socketLocation != -1 && socketLocation != 255) {
        tempSocket = call LiveSocketList.getStore(socketLocation);
        tempSocket -> state = SOCK_ESTABLISHED;
      }

      return FAIL;

      break;

    case FIN:
      dbg(NEIGHBOR_CHANNEL, "FIN packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      // there are 3 cases we have for FIN, if the socket is established, if the socket is waiting to close, and if the socket is closed

      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_ESTABLISHED);

      if (socketLocation != -1 && socketLocation != 255) {
        tempSocket = call LiveSocketList.getStore(socketLocation);
        if (tempSocket -> lastByteRec >= payload -> seq) {
          tempSocket -> state = SOCK_CLOSE_WAIT;

          call Window.readData(call LiveSocketList.getFd(socketLocation));
          // send a fin_ack to close the client side connection
          call Transport.write(call LiveSocketList.getFd(socketLocation), FIN_ACK);
        }
        return SUCCESS;
      }

      // Check if we're closing the socket
      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_CLOSE_WAIT);

      if (socketLocation != -1 && socketLocation != 255) {
        tempSocket = call LiveSocketList.getStore(socketLocation);
        tempSocket -> state = SOCK_CLOSED;

        dbg(NEIGHBOR_CHANNEL, "Connection Closed\n");
        return SUCCESS;
      }

      // Check if the socket is closed
      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_CLOSED);

      if (socketLocation != -1 && socketLocation != 255) {
        tempSocket = call LiveSocketList.getStore(socketLocation);
        call Transport.write(call LiveSocketList.getFd(socketLocation), FIN_ACK);

        return SUCCESS;
      }

      dbg(NEIGHBOR_CHANNEL, "Error: connection failed\n");
      return FAIL;
      break;

    case FIN_ACK:
      dbg(NEIGHBOR_CHANNEL, "FIN_ACK packet arrived from node://%d:%d\n", package -> src, payload -> destPort);

      // check if the socket is waiting to end
      socketLocation = call LiveSocketList.search( & socketAddress, SOCK_FIN_WAIT);

      if (socketLocation != -1 && socketLocation != 255) {
        call Transport.write(call LiveSocketList.getFd(socketLocation), FIN);
        tempSocket = call LiveSocketList.getStore(socketLocation);
        tempSocket -> state = SOCK_CLOSED;
        dbg(NEIGHBOR_CHANNEL, "Connection Closed\n");
        return SUCCESS;
      }

      dbg(NEIGHBOR_CHANNEL, "Error: connection failed\n");
      return FAIL;

      break;

    default:
      return FAIL;
    }
  }

  command error_t Transport.close(socket_t fd) {
    socket_storage_t * socket;

    if (call SocketPointerMap.contains(fd)) {
      call Transport.write(fd, FIN);
    }
  }

  command error_t Transport.listen(socket_t fd) {
    socket_storage_t * socket;

    if (call SocketPointerMap.contains(fd)) {
      socket = call SocketPointerMap.get(fd);
      socket -> state = SOCK_LISTEN;

      return SUCCESS;
    } else {
      dbg(NEIGHBOR_CHANNEL, "Socket not found\n");
      return FAIL;
    }
  }

  command error_t Transport.release(socket_t fd) {

  }

  void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, TCP_t * payload, uint8_t length) {
    Package -> src = src;
    Package -> dest = dest;
    Package -> TTL = TTL;
    Package -> seq = seq;
    Package -> protocol = protocol;
    memcpy(Package -> payload, payload, length);
  }

  void makeTCPPack(TCP_t * Package, uint8_t srcPort, uint8_t destPort, uint16_t seq, uint8_t flag, uint8_t window, uint8_t * content, uint8_t length) {
    Package -> srcPort = srcPort;
    Package -> destPort = destPort;
    Package -> seq = seq;
    Package -> flag = flag;
    Package -> window = window;
    memcpy(Package -> data, content, length);
  }
}