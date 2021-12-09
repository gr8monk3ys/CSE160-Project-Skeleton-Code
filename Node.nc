/*
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */
#include <Timer.h>

#include "includes/command.h"

#include "includes/packet.h"

#include "includes/CommandMsg.h"

#include "includes/sendInfo.h"

#include "includes/channels.h"

#include "includes/TCP_t.h"

#include "includes/chat.h"

module Node {
  uses interface Boot;

  uses interface SplitControl as AMControl;

  uses interface Receive;

  uses interface SimpleSend as Sender;

  uses interface Random as Random;

  //used to handle commands:
  uses interface CommandHandler;

  //used for flooding:
  uses interface Flooding;

  //used for neighbor discovery:
  uses interface Timer < TMilli > as NeighborTimer;
  uses interface NeighborDiscovery;

  //timer for Link state:
  uses interface Timer < TMilli > as LinkStateTimer;

  uses interface LinkState;

  uses interface Timer < TMilli > as ClientDataTimer;

  uses interface Timer < TMilli > as AttemptConnection;

  uses interface List < socket_addr_t > as Connections;

  uses interface List < Route > as RoutingTable; //to access link state values for transport:

  uses interface Transport;

  uses interface Window;

  uses interface LiveSocketList;

  uses interface Hashmap < socket_storage_t * > as SocketPointerMap;

  uses interface Hashmap < uint8_t * > as Users;

}

implementation {

  pack sendPackage;
  pack ackPackage;
  uint8_t * currentUser;
  //uint16_t seq = 1;
  uint16_t current_seq = 1;

  // Prototypes
  void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t * payload, uint8_t length);
  void pingHandler(pack * msg);
  uint32_t randNum(uint32_t min, uint32_t max);
  //void sendWithTimerPing(pack *Package);
  uint16_t ignoreSelf(uint16_t destination);
  uint16_t sendInitial(uint16_t initial);

  // Gets called for initial processes
  event void Boot.booted() {
    call AMControl.start();
    call NeighborTimer.startPeriodic(randNum(25000, 35000));
    call LinkStateTimer.startPeriodic(randNum(25000, 35000));
    dbg(GENERAL_CHANNEL, "Booted\n");
  }

  // Begins simulated radio call while booting
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      dbg(GENERAL_CHANNEL, "Radio On\n");
    } else {
      //Retry until successful
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {}

  void pingHandler(pack * msg) {
    switch (msg -> protocol) {
    case PROTOCOL_PING:
      dbg(GENERAL_CHANNEL, "--- Ping recieved from: %d\n", msg -> src);
      dbg(GENERAL_CHANNEL, "--- Packet Payload: %s\n", msg -> payload);
      makePack( & sendPackage, msg -> dest, msg -> src, MAX_TTL, PROTOCOL_PINGREPLY, current_seq++, (uint8_t * ) msg -> payload, PACKET_MAX_PAYLOAD_SIZE);
      call LinkState.send( & sendPackage);
      break;

    case PROTOCOL_PINGREPLY:
      dbg(GENERAL_CHANNEL, "--- Ping reply recieved from %d\n", msg -> src);
      break;

    default:
      dbg(GENERAL_CHANNEL, "Unrecognized ping protocol: %d\n", msg -> protocol);
    }
  }

  //A function when we recieve packets:
  event message_t * Receive.receive(message_t * msg, void * payload, uint8_t len) {

    //dbg(GENERAL_CHANNEL, "Packet Received\n");

    if (len == sizeof(pack)) {
      pack * myMsg = (pack * ) payload;

      // Check TTL
      if (myMsg -> TTL-- == 0) {
        return msg;
      }
      if (myMsg -> protocol == PROTOCOL_TCP) {
        if (myMsg -> dest == TOS_NODE_ID) {
          dbg(NEIGHBOR_CHANNEL, "Packet recieved from: %i\n", myMsg -> src);
          //   call Transport.receive(myMsg);
          return msg;
        }

        myMsg -> TTL = myMsg -> TTL - 1;

        //For Transport?
        if (myMsg -> TTL > 0) {
          makePack( & sendPackage,
            TOS_NODE_ID,
            myMsg -> dest,
            myMsg -> TTL,
            0,
            myMsg -> seq,
            myMsg -> payload,
            PACKET_MAX_PAYLOAD_SIZE);

          //sendWithTimerPing(&sendPackage);

          return msg;
        }
        dbg(GENERAL_CHANNEL, "TCP Timed out");
        return msg;
      }

      // Flooding for recieve
      if (myMsg -> TTL > 0) {
        call Flooding.ping(myMsg);
        // If there is no TTL, return message
        if (myMsg -> TTL == 0) {
          return msg;
        }
        dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg -> payload);
        return msg;
      }

      //Distance Vector -- LinkState Routing
      if (myMsg -> protocol == PROTOCOL_LINKSTATE) {
        call LinkState.recieve(myMsg);

        //REGULAR PING
      } else if (myMsg -> dest == TOS_NODE_ID) {
        pingHandler(myMsg);

        //neighbor discovery
      } else if (myMsg -> dest == AM_BROADCAST_ADDR) {
        call NeighborDiscovery.recieve(myMsg);

        //NOT DESTINATION 
      } else {
        call LinkState.send(myMsg);
      }
      return msg;
    }
    dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
    return msg;
  }

  ///////////////////////////////

  //To run neighbor discovery:

  event void NeighborTimer.fired() {
    call NeighborDiscovery.find(current_seq++);
  }

  //to run link state routing:
  event void LinkStateTimer.fired() {

    //to gather our neighbors and the total number as the key....
    uint32_t * neighbors = call NeighborDiscovery.gatherNeighbors();
    uint16_t numNeighbors = call NeighborDiscovery.numNeighbors();

    call LinkState.updateNeighbors(neighbors, numNeighbors);
    call LinkState.start();
  }

  // Called to give a ping command to any called nodes
  event void CommandHandler.ping(uint16_t destination, uint8_t * payload) {

    dbg(GENERAL_CHANNEL, "PING EVENT \n");
    //specific packet (via protocol ping is being produced)
    makePack( & sendPackage, TOS_NODE_ID, destination, MAX_TTL, PROTOCOL_PING, current_seq++, payload, PACKET_MAX_PAYLOAD_SIZE);
    call Sender.send(sendPackage, destination);
    call LinkState.send( & sendPackage);
  }

  //event void CommandHandler.ping(uint16_t destination, uint8_t * payload) {}

  void sendACKMessage(uint16_t origin, uint8_t arrivedAtDestination) {

    dbg(GENERAL_CHANNEL, "SENDING FROM: %i to %i\n", TOS_NODE_ID, origin);

    makePack( & ackPackage,
      TOS_NODE_ID,
      origin,
      500,
      1,
      arrivedAtDestination,
      'ACK',
      PACKET_MAX_PAYLOAD_SIZE);

    call Sender.send(ackPackage, origin);
  }

  // Issues a call to all neighboring IDs of a node
  event void CommandHandler.printNeighbors() {
    //TO ACTUALLY START THE FINDING METHOD, AND THE MAKE PACK FUNCTION
    call NeighborDiscovery.printNeighbors();
  }

  //to print the table of node IDS  
  event void CommandHandler.printRouteTable() {
    call LinkState.printRouteTable();
  }

  event void CommandHandler.printLinkState() {
    dbg(GENERAL_CHANNEL, "printLinkState\n");
  }

  //printing a routing table
  event void CommandHandler.printDistanceVector() {
    call LinkState.printRouteTable();
  }

  event void CommandHandler.setTestServer(uint8_t port) {
    socket_t fd = call Transport.socket();
    socket_addr_t socketAddress;

    dbg(TRANSPORT_CHANNEL, "Init server at port-%d\n", port);

    if (fd != NULL_SOCKET) {
      socketAddress.srcAddr = TOS_NODE_ID;
      socketAddress.srcPort = port;
      socketAddress.destAddr = 0;
      socketAddress.destPort = 0;

      if (call Transport.bind(fd, & socketAddress) == SUCCESS) {
        dbg(TRANSPORT_CHANNEL, "socket %d binded to port-%d\n", fd, port);
        call Transport.listen(fd);
        call AttemptConnection.startPeriodic(1000);

        return;
      }

      dbg(TRANSPORT_CHANNEL, "Server could not be set up\n");
      return;
    }

    dbg(TRANSPORT_CHANNEL, "Server could not be set up\n");
    return;
  }

  event void AttemptConnection.fired() {
    socket_storage_t * tempSocket;
    uint32_t * socketKeys = call SocketPointerMap.getKeys();

    int i;
    // if we have connections on our server, we should accept this
    if (call Connections.size() > 0) {
      call Transport.accept();
    }

    // go through all the sockets we have we have
    for (i = 0; i < call SocketPointerMap.size(); i++) {
      tempSocket = call SocketPointerMap.get(socketKeys[i]);

      if (tempSocket -> state == SOCK_ESTABLISHED) {
        // read data
        call Window.readData(socketKeys[i]);
      }
    }
  }

  event void CommandHandler.setTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort, uint8_t * transfer) {
    socket_storage_t temp;
    socket_addr_t socketAddress;
    socket_t fd = call Transport.socket();

    uint16_t * transferSize = (uint16_t * ) transfer;

    dbg(TRANSPORT_CHANNEL, "Init client at port-%d headed to node://%d:%d with content '%s'\n", srcPort, dest, destPort, transfer);

    socketAddress.srcAddr = TOS_NODE_ID;
    socketAddress.srcPort = srcPort;
    socketAddress.destAddr = dest;
    socketAddress.destPort = destPort;

    call Transport.bind(fd, & socketAddress);
    call Transport.connect(fd, & socketAddress);
    call Window.setWindowInfo(fd, transferSize[0]);
    call ClientDataTimer.startPeriodic(2500);
  }

  event void ClientDataTimer.fired() {
    socket_storage_t * tempSocket;
    uint32_t * socketKeys = call SocketPointerMap.getKeys();

    int i;
    for (i = 0; i < call SocketPointerMap.size(); i++) {
      tempSocket = call SocketPointerMap.get(socketKeys[i]);

      if (tempSocket -> state == SOCK_ESTABLISHED) {
        dbg(TRANSPORT_CHANNEL, "Connection established - Sending DATA\n");

        call Window.init(socketKeys[i]);
        call Transport.write(socketKeys[i], DATA);

      } else if (tempSocket -> state == SOCK_SYN_SENT) {
        if (tempSocket -> timeout == 0) {
          dbg(TRANSPORT_CHANNEL, "Connection Failed - Retrying\n");

          call Transport.connect(socketKeys[i], & tempSocket -> sockAddr);
          tempSocket -> timeout = 6;
        } else {
          // lets keep retrying
          tempSocket -> timeout -= 1;
        }

      } else if (tempSocket -> state == SOCK_FIN_WAIT) {
        if (tempSocket -> timeout == 0) {
          dbg(TRANSPORT_CHANNEL, "Connection Failed - Retrying\n");

          call Transport.write(socketKeys[i], FIN);

          tempSocket -> timeout = 6;
        } else {

          // lets keep retrying
          tempSocket -> timeout -= 1;
        }
      }
    }
  }

  event void CommandHandler.stopTestClient(uint8_t dest, uint8_t srcPort, uint8_t destPort) {
    socket_addr_t socketAddress;
    uint8_t socketIndex;

    socketAddress.srcAddr = TOS_NODE_ID;
    socketAddress.srcPort = srcPort;
    socketAddress.destAddr = dest;
    socketAddress.destPort = destPort;

    // find established socket and close it
    socketIndex = call LiveSocketList.search( & socketAddress, SOCK_ESTABLISHED);

    if (socketIndex != -1) {
      call Transport.close(call LiveSocketList.getFd(socketIndex));
    }
  }

  event void CommandHandler.startChatServer() {
    socket_t fd = call Transport.socket();
    socket_addr_t socketAddress;

    dbg(TRANSPORT_CHANNEL, "Init server at port-%d\n", DEFAULT_CHAT_PORT);

    if (fd != NULL_SOCKET) {
      socketAddress.srcAddr = TOS_NODE_ID;
      socketAddress.srcPort = DEFAULT_CHAT_PORT;
      socketAddress.destAddr = 0;
      socketAddress.destPort = 0;

      if (call Transport.bind(fd, & socketAddress) == SUCCESS) {
        dbg(TRANSPORT_CHANNEL, "Chat server booted!\n");
        call Transport.listen(fd);
        call AttemptConnection.startPeriodic(1000);

        return;
      }

      dbg(TRANSPORT_CHANNEL, "Server could not be set up\n");
      return;
    }
  }

  event void CommandHandler.hello(uint8_t * message) {
    socket_storage_t temp;
    socket_addr_t socketAddress;
    socket_t fd = call Transport.socket();

    uint16_t * transferSize = (uint16_t * ) message;

    socketAddress.srcAddr = TOS_NODE_ID;
    socketAddress.srcPort = DEFAULT_CHAT_PORT;
    socketAddress.destAddr = DEFAULT_CHAT_NODE;
    socketAddress.destPort = DEFAULT_CHAT_PORT;

    call Transport.bind(fd, & socketAddress);
    call Transport.connect(fd, & socketAddress);
    call Window.setWindowInfo(fd, transferSize[0]);
    call ClientDataTimer.startPeriodic(2500);
    return;
  }

  event void CommandHandler.whisper(uint8_t * username, uint8_t * message) {
    socket_storage_t temp;
    socket_addr_t socketAddress;
    socket_t fd = call Transport.socket();

    uint16_t * transferSize = (uint16_t * ) username;

    socketAddress.srcAddr = TOS_NODE_ID;
    socketAddress.srcPort = DEFAULT_CHAT_PORT;
    socketAddress.destAddr = DEFAULT_CHAT_NODE;
    socketAddress.destPort = DEFAULT_CHAT_PORT + 1;

    call Transport.bind(fd, & socketAddress);
    call Transport.connect(fd, & socketAddress);
    call Window.setWindowInfo(fd, transferSize[0]);
    call ClientDataTimer.startPeriodic(2500);
    return;
  }

  event void CommandHandler.setAppClient() {}

  // Puts together packets 
  void makePack(pack * Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t * payload, uint8_t length) {
    Package -> src = src;
    Package -> dest = dest;
    Package -> TTL = TTL;
    Package -> seq = seq;
    Package -> protocol = protocol;
    memcpy(Package -> payload, payload, length);
  }

  uint32_t randNum(uint32_t min, uint32_t max) {
    return (call Random.rand16() % (max - min + 1)) + min;
  }
}