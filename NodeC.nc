/**
 * ANDES Lab - University of California, Merced
 * This class provides the basic functions of a network node.
 *
 * @author UCM ANDES Lab
 * @date   2013/09/03
 *
 */

#include <Timer.h>
#include "includes/route.h"
#include "includes/CommandMsg.h"
#include "includes/packet.h"
#include "includes/socket.h"
#include "includes/TCP_t.h"
#include "includes/window.h"

configuration NodeC {}
implementation {
  components MainC;
  components Node;
  components new AMReceiverC(AM_PACK) as GeneralReceive;

  Node -> MainC.Boot;

  Node.Receive -> GeneralReceive;

  components RandomC;
  Node.Random -> RandomC;

  components ActiveMessageC;
  Node.AMControl -> ActiveMessageC;

  components CommandHandlerC;
  Node.CommandHandler -> CommandHandlerC;

  components new SimpleSendC(AM_PACK);
  Node.Sender -> SimpleSendC;

  components FloodingC;
  Node.Flooding -> FloodingC;

  components NeighborDiscoveryC;
  Node.NeighborDiscovery -> NeighborDiscoveryC;

  components new TimerMilliC() as NeighborTimer;
  Node.NeighborTimer -> NeighborTimer;

  components LinkStateC;
  Node.LinkState -> LinkStateC;

  components new TimerMilliC() as LinkStateTimer;
  Node.LinkStateTimer -> LinkStateTimer;

  components new TimerMilliC() as packageTimerC3;
  Node.ClientDataTimer -> packageTimerC3;

  components new TimerMilliC() as packageTimerC4;
  Node.AttemptConnection -> packageTimerC4;

  components TransportP;
  Node.Transport -> TransportP;

  components TransportC;
  Node.Transport -> TransportC;

  components WindowP;
  Node.Window -> WindowP;

  components WindowC;
  Node.Window -> WindowC;

  components new ListC(socket_addr_t, 256) as ListC1;
  Node.Connections -> ListC1;

  components new HashmapC(uint8_t * , 256) as HashmapC5;
  Node.Users -> HashmapC5;

  components LiveSocketListC;
  Node.LiveSocketList -> LiveSocketListC;

  components new HashmapC(uint16_t, 256) as HashmapC2;
  Node.MessageStorageExplored -> HashmapC2;

  components new HashmapC(socket_storage_t * , MAX_SOCKET_COUNT) as HashmapC3;
  Node.SocketPointerMap -> HashmapC3;

}