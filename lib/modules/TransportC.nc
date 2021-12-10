#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCP_t.h"
#include "../../includes/route.h"

configuration TransportC {
  provides interface Transport;
}

implementation {
  components TransportP;
  Transport = TransportP;

  components RandomC;
  TransportP.Random -> RandomC;

  components new ListC(Route, 256);
  TransportP.RoutingTable -> ListC;

  components new SimpleSendC(AM_PACK);
  TransportP.Sender -> SimpleSendC;

  components LinkStateC;
  TransportP.LinkState -> LinkStateC;

  components WindowP;
  TransportP.Window -> WindowP;

  components new ListC(socket_addr_t, 256) as ListC1;
  TransportP.Connections -> ListC1;

  components LiveSocketListC;
  TransportP.LiveSocketList -> LiveSocketListC;

  components new HashmapC(socket_storage_t * , MAX_SOCKET_COUNT) as HashmapC3;
  TransportP.SocketPointerMap -> HashmapC3;

}
