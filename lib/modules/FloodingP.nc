#include "../../includes/packet.h"
#include "../../includes/protocol.h"
#include "../../includes/packet_id.h"

module FloodingP {
   provides interface Flooding; // using same name
   uses interface List<packID> as PreviousPackets; // Now refered to as Previous Packets 
   uses interface SimpleSend as Sender; // Now referred to as Sender 
}

implementation {

   // Global variables
   packID packet; // serves as the packet:
   uint16_t i = 0; // some arbitrary int i (unsigned int)

   
   //  Determines whether or not a packet is a duplicate
   // src = node at hand.... seq = progression ??
   bool isDuplicate(uint16_t src, uint16_t seq) {
      i = 0;
      // we are iterating through the size of the packet list.... essentially moving through our packets 
      while(i < call PreviousPackets.size()){
         
         // a variable able to represent a packet will equal a packet within the list == the previous packet
         packID previous = call PreviousPackets.get(i);

         //dbg(FLOODING_CHANNEL, "Previous packets size: %d\n", previous);

            // if the previous source (packet) = to the previous location.... we know that we have hit the same place with the same packet:
            if(previous.src == src && previous.seq == seq){
               return TRUE;
            }
         i++;
      }
      return FALSE;
   } // end of is duplicate 

   // Determines whether or not the packet that is being sent is a duplicate, if so, then it calls false
   bool dropDuplicate(pack* msg) {
      if(isDuplicate(msg -> src, msg -> seq)) {

         dbg(FLOODING_CHANNEL, "Duplicate packet being dropped\n");

         return FALSE;
         
       } 
   } // end of drop duplicate 

   //  This checks to see if the source and the destination have been established yet for debugging purposes
   void floodTrack(pack* msg) {
 
      if(msg -> src != TOS_NODE_ID && msg -> dest != AM_BROADCAST_ADDR) {

         // displaying a message along the Flooding Channel that will display the source node and destination node:
         //dbg(FLOODING_CHANNEL, "Source (Recieved): %d. Destination(Sent): %d\n", msg -> src, msg -> dest);

         // != TOS_NODE_ID == source node
         // AM_BROADCAST_ADDR == destination (from where a message is being broadcasted)
      }
      // call to send
      call Sender.send(*msg, AM_BROADCAST_ADDR); // message to be sent, destination where message will be sent
   }// end of Flood Track


   //  This does the actual flooding by checking all endpoints and then proceeding once checked
   command void Flooding.ping(pack* msg) {
      if(dropDuplicate(msg)) {   
         packet.src = msg -> src; // packet source
         packet.seq = msg -> seq; // packet sequence 
      }
      call PreviousPackets.pushback(packet); // pushing a packet into the list of sent packets.
     // dbg(FLOODING_CHANNEL, "Packet being sent (ID): %d\n" , packet);

      floodTrack(msg); // actually sending the message 
   } //  end of Flooding.ping
}
