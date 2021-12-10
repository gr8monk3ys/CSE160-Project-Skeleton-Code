#include "../../includes/packet.h"
#include "../../includes/socket.h"
#include "../../includes/TCP_t.h"
#include "../../includes/route.h"
#include "../../includes/window.h"

configuration WindowC {
  provides interface Window;
}

implementation {
  components WindowP;
  Window = WindowP;

  components new HashmapC(socket_storage_t * , MAX_SOCKET_COUNT) as HashmapC3;
  WindowP.SocketPointerMap -> HashmapC3;

  components new HashmapC(window_t, 256) as HashmapC4;
  WindowP.WindowInfoList -> HashmapC4;
}
