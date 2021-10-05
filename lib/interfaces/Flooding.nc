#include "../../includes/packet.h"

//Flooding Interface

interface Flooding { 
   //sending the actual message
   command void ping(pack* msg);
}
