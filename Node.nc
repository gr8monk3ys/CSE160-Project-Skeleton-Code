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

module Node{
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
   uses interface Timer<TMilli> as NeighborTimer;
   uses interface NeighborDiscovery;

   //timer for Link state:
   uses interface Timer<TMilli> as LinkStateTimer;

   uses interface LinkState;

   uses interface List<socket_addr_t> as Connections;

   uses interface Transport;
}

implementation{

   pack sendPackage;
   uint16_t seq = 1;

   // Prototypes
   void makePack(pack* Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t Protocol, uint16_t seq, uint8_t* payload, uint8_t length);
   uint32_t randNum(uint32_t min, uint32_t max);

   // Gets called for initial processes
   event void Boot.booted() {
      call AMControl.start();
      call NeighborTimer.startOneShot(30000);
      call LinkStateTimer.startOneShot(30000);
      dbg(GENERAL_CHANNEL, "Booted\n");
   }

   // Begins simulated radio call while booting
   event void AMControl.startDone(error_t err) {
      if (err == SUCCESS) {
         dbg(GENERAL_CHANNEL, "Radio On\n");
      }
else {
         //Retry until successful
         call AMControl.start();
      }
   }

   event void AMControl.stopDone(error_t err) {}

   //A function when we recieve packets:
   event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {

      dbg(GENERAL_CHANNEL, "Packet Received\n");

      if (len == sizeof(pack)) {
         pack* myMsg = (pack*)payload;

      if (myMsg->protocol == PROTOCOL_TCP) {
        if (myMsg->dest == TOS_NODE_ID) {
           dbg(NEIGHBOR_CHANNEL, "Packet recieved from: %i\n", myMsg->src);
           //   call Transport.receive(myMsg);
             return msg;
         }

         myMsg->TTL = myMsg->TTL - 1;

         if (myMsg->TTL > 0) {
             makePack(&sendPackage,
                       TOS_NODE_ID,
                       myMsg->dest,
                       myMsg->TTL,
                       0,
                       myMsg->seq,
                       myMsg->payload,
                       PACKET_MAX_PAYLOAD_SIZE);

             return msg;
         }
         dbg(NEIGHBOR_CHANNEL, "TCP Timed out");
         return msg;
       }

      // // Flooding for recieve
      // if(myMsg->TTL > 0){
      //    call Flooding.ping(myMsg);
      //    // If there is no TTL, return message
      //    if(myMsg->TTL == 0){
      //       return msg;
      //       }
      // dbg(GENERAL_CHANNEL, "Package Payload: %s\n", myMsg->payload);
      // return msg;
      // }

      if (myMsg->protocol == PROTOCOL_DV) {
         call LinkState.recieve(myMsg);
      }
      else if (myMsg->dest == TOS_NODE_ID) {

      }
      else if (myMsg->dest == AM_BROADCAST_ADDR) {
         call NeighborDiscovery.recieve(myMsg);
      }
      else {
         call LinkState.send(myMsg);
      }
   }
   dbg(GENERAL_CHANNEL, "Unknown Packet Type %d\n", len);
   return msg;
}

   // Called to give a ping command to any called nodes
   event void CommandHandler.ping(uint16_t destination, uint8_t* payload) {

      dbg(GENERAL_CHANNEL, "PING EVENT \n");

      makePack(&sendPackage, TOS_NODE_ID, destination, 19, PROTOCOL_PING, seq, payload, PACKET_MAX_PAYLOAD_SIZE);
      call Sender.send(sendPackage, destination);
      call LinkState.send(&sendPackage);
   }

   ///////////////////////////////

   //To run neighbor discovery:
    event void NeighborTimer.fired() {
        call NeighborDiscovery.find(seq);
    }

    //to run link state routing:
     event void LinkStateTimer.fired() {
       uint32_t* neighbors = call NeighborDiscovery.gatherNeighbors();
       uint16_t numNeighbors = call NeighborDiscovery.numNeighbors();

       call LinkState.updateNeighbors(neighbors, numNeighbors);
       call LinkState.start();
     }

     // Issues a call to all neighboring IDs of a node
     event void CommandHandler.printNeighbors() {
        //TO ACTUALLY START THE FINDING METHOD, AND THE MAKE PACK FUNCTION
       call NeighborDiscovery.printNeighbors();
     }

     //to print the table 
     event void CommandHandler.printRouteTable() {}

     event void CommandHandler.printLinkState() {}

     event void CommandHandler.printDistanceVector() {}

     event void CommandHandler.setTestServer() {}

     event void CommandHandler.setTestClient() {}

     event void CommandHandler.setAppServer() {}

     event void CommandHandler.setAppClient() {}

     // Puts together packets 
     void makePack(pack* Package, uint16_t src, uint16_t dest, uint16_t TTL, uint16_t protocol, uint16_t seq, uint8_t* payload, uint8_t length) {
        Package->src = src;
        Package->dest = dest;
        Package->TTL = TTL;
        Package->seq = seq;
        Package->protocol = protocol;
        memcpy(Package->payload, payload, length);
     }

     uint32_t randNum(uint32_t min, uint32_t max) {
          return (call Random.rand16() % (max - min + 1)) + min;
      }
}
