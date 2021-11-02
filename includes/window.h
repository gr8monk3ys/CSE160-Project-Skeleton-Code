#ifndef __WINDOW_H__
#define __WINDOW_H__

enum {
   WINDOW_DEFAULT_STATUS = FALSE,
   WINDOW_DEFAULT_DATA_IN_TRANSFER = 0,
   WINDOW_DEFAULT_MAX_DATA_IN_TRANSFER = 5,
   WINDOW_DEFAULT_TIMEOUT = 4,
   WINDOW_DEFAULT_VALUE = 24,
   WINDOW_DEFAULT_BYTE_STREAM = 0
};

typedef struct{
    bool completed;
    uint16_t size;
    uint16_t prevValue;
    uint8_t dataTransfer;
    uint8_t maxDataTransfer;
    uint8_t timeout;
    uint8_t synTimeout;
    uint8_t window;
    uint8_t bytesInStream;
} window_t;

#endif