#include "../../includes/packet.h"

//Link-state Interface

interface LinkState { 
   //sending the actual message
   command void ping(pack* msg);
}
