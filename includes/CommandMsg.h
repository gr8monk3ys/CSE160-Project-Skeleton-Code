//Author: UCM ANDES Lab
//$Author: abeltran2 $
//$LastChangedBy: abeltran2 $

#ifndef __COMMAND_MSG_H__
#define __COMMAND_MSG_H__

# include "protocol.h"

enum{
	CMD_PACKET_HEADER_LENGTH = 3,
	CMD_PACKET_MAX_PAYLOAD_SIZE = 28 - CMD_PACKET_HEADER_LENGTH,
};


typedef nx_struct CommandMsg{
	nx_uint16_t dest;
	nx_uint8_t id;
	nx_uint8_t payload[CMD_PACKET_MAX_PAYLOAD_SIZE];	
}CommandMsg;

enum{
	AM_COMMANDMSG=99
};

#endif
