/*
 * Author: UCM ANDES Lab
 * $author$
 * $LastChangedDate: 2014-06-16 13:16:24 -0700 (Mon, 16 Jun 2014) $
 * Description: Processes commands and returns an Command ID Number.
 */

#ifndef COMMAND_H
#define COMMAND_H
 
//Command ID Number
enum{
	CMD_PING = 0,
	CMD_NEIGHBOR_DUMP=1,
	CMD_LINKSTATE_DUMP=2,
	CMD_ROUTETABLE_DUMP=3,
	CMD_TEST_CLIENT=4,
	CMD_TEST_SERVER=5,
	CMD_KILL=6,
	CMD_STOP_TEST_CLIENT=7,
	CMD_ERROR=9,
	CMD_START_CHAT_SERVER=10,
	CMD_MSG=11,
	CMD_HELLO=12,
	CMD_WHISPER=13,
	CMD_LIST_USERS=14
};

enum{
	CMD_LENGTH = 1,
};

#endif /* COMMAND_H */
