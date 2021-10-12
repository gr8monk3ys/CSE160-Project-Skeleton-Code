#include "../../includes/packet.h"
#include "../../includes/protocol.h"

module FloodingP{
   provides interface Flooding; // using same name
   uses interface List<pack> as cache; // Now refered to as cache 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
}

implementation{

   // Global variables
   uint8_t sequence = 0;
   uint16_t i = 0; // some arbitrary int i (unsigned int)

      bool isDuplicate(uint16_t src, uint16_t seq) {
      i = 0;
      // we are iterating through the size of the packet list.... essentially moving through our packets 
      while (i < call PreviousPackets.size()) {

         // a variable able to represent a packet will equal a packet within the list == the previous packet
         pack previous = call PreviousPackets.get(i);

         //dbg(FLOODING_CHANNEL, "Previous packets size: %d\n", previous);

            // if the previous source (packet) = to the previous location.... we know that we have hit the same place with the same packet:
            if (previous.src == src && previous.seq == seq) {
               return TRUE;
            }
         i++;
      }
      return FALSE;
   } // end of is duplicate 

   // Determines whether or not the packet that is being sent is a duplicate, if so, then it calls false
   bool dropDuplicate(pack* msg) {
      if (isDuplicate(msg->src, msg->seq)) {

         dbg(FLOODING_CHANNEL, "Duplicate packet being dropped\n");

         return FALSE;

       }
   } // end of drop duplicate 

   //  This checks to see if the source and the destination have been established yet for debugging purposes
   void floodTrack(pack* msg) {
      if (msg->dest != TOS_NODE_ID && msg->seq != sequence) {

         // displaying a message along the Flooding Channel that will display the source node and destination node:
         dbg(FLOODING_CHANNEL, "Source (Recieved): %d. Destination(Sent): %d\n", msg->src, msg->dest);
         sequence = msg->seq;
         call Sender.send(*msg, AM_BROADCAST_ADDR);
         call cache.pushfront(msg->src);
      }

         dbg(FLOODING_CHANNEL, "Cache %d\n", call cache.popback());
   }

   command void Flooding.ping(pack* msg) {
      logPack(msg);
      msg->protocol = TOS_NODE_ID;
      msg->TTL -= 1;

      floodTrack(msg);
   }
}
