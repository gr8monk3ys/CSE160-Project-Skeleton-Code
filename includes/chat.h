#ifndef __CHAT_H__
#define __CHAT_H__

enum{
    DEFAULT_CHAT_NODE=1,
    CHAT_TYPE_MSG=2,
    CHAT_TYPE_HELLO=1,
    CHAT_TYPE_WHISPER=3,
    DEFAULT_CHAT_PORT=41
};

typedef struct chatData {
    uint16_t type;
    uint16_t* message;
    uint16_t* username;
} chatData;

#endif