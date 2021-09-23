/**
 * @author UCM ANDES Lab
 * $Author: abeltran2 $
 * $LastChangedDate: 2014-08-31 16:06:26 -0700 (Sun, 31 Aug 2014) $
 *
 */


#include "../../includes/CommandMsg.h"
#include "../../includes/command.h"
#include "../../includes/channels.h"

configuration CommandHandlerC{
   provides interface CommandHandler;
}

implementation{
    components CommandHandlerP;
    CommandHandler = CommandHandlerP;
    components new AMReceiverC(AM_COMMANDMSG) as CommandReceive;
    CommandHandlerP.Receive -> CommandReceive;

   //Lists
   components new PoolC(message_t, 20);
   components new QueueC(message_t*, 20);

   CommandHandlerP.Pool -> PoolC;
   CommandHandlerP.Queue -> QueueC;

   components ActiveMessageC;
   CommandHandlerP.Packet -> ActiveMessageC;
}
