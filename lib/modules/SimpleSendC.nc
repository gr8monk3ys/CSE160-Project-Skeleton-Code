#include "../../includes/am_types.h"

generic configuration SimpleSendC(int channel){
   provides interface SimpleSend;
}

implementation{
   components new SimpleSendP();
   SimpleSend = SimpleSendP.SimpleSend;

   components new TimerMilliC() as sendTimer;
   components RandomC as Random;
   components new AMSenderC(channel);

   //Timers
   SimpleSendP.sendTimer -> sendTimer;
   SimpleSendP.Random -> Random;

   SimpleSendP.Packet -> AMSenderC;
   SimpleSendP.AMPacket -> AMSenderC;
   SimpleSendP.AMSend -> AMSenderC;

   //Lists
   components new PoolC(sendInfo, 20);
   components new QueueC(sendInfo*, 20);

   SimpleSendP.Pool -> PoolC;
   SimpleSendP.Queue -> QueueC;
}
