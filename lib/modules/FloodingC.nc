#include "../../includes/packet.h"

configuration FloodingC{
   provides interface Flooding;
}

//The wiring of configuration and Module 
implementation{
   components FloodingP;
   Flooding = FloodingP;

   //List of packets... named cache
      components new ListC(pack, 64);
      FloodingP.cache->ListC;

      //Sending Packets...
         components new SimpleSendC(AM_PACK);
         FloodingP.Sender->SimpleSendC;
}
