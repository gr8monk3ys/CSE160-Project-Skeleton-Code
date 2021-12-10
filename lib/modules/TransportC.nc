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

}
