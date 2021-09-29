#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module FloodingP {
   provides interface Flooding; //using same name
   uses interface List<packID> as PreviousPackets; //Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; //Now referred to as Sender 
}

//Logic of the code:

implementation {

   //Global variables
   packID packet; //serves as the packet:
   uint16_t i = 0; //some arbitrary int i (unsigned int)

   // This checks to see if the source and the destination have been established yet for debugging purposes
   void floodTrack(pack* msg) {
      if(msg -> src != TOS_NODE_ID && msg -> dest != AM_BROADCAST_ADDR) {
         dbg(FLOODING_CHANNEL, "Source: %d. Destination: %d\n", msg -> src, msg -> dest);
      }
      call Sender.send(*msg, AM_BROADCAST_ADDR);
   }

   // Determines whether or not a packet is a duplicate
   bool isDuplicate(uint16_t src, uint16_t seq) {
      i = 0;
      while(i < call PreviousPackets.size()){
         packID previous = call PreviousPackets.get(i);
         if(previous.src == src && previous.seq == seq){
            return TRUE;
         }
         i++;
      }
      return FALSE;
   }

   // Determines whether or not the packet that is being sent is a duplicate, if so, then it calls false
   bool dropDuplicate(pack* msg) {
      if(isDuplicate(msg -> src, msg -> seq)) {
         dbg(FLOODING_CHANNEL, "Duplicate packet being dropped\n");
         return FALSE;
      }
   }

   // This does the actual flooding by checking all endpoints and then proceeding once checked
   command void Flooding.ping(pack* msg) {
      if(dropDuplicate(msg)) {
         packet.src = msg -> src;
         packet.seq = msg -> seq;
         
      }
      call PreviousPackets.pushback(packet);  
      floodTrack(msg);
   }
}
