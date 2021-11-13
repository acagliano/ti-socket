/*
 *--------------------------------------
 * Program Name:
 * Author:
 * License:
 * Description:
 *--------------------------------------
 */

#include <srldrvce.h>
#include <socket.h>

#include <stdio.h>
#include <keypadc.h>
#include <stdbool.h>
#include <string.h>
#include <tice.h>

#define CEMU_CONSOLE ((char*)0xFB0000)
uint8_t *str = "The dumb developer wrote a random sentence.";
uint8_t errors[][50] = {
    "Success",
    "Timeout",
    "Backend Error"
};

uint8_t keystrings[][50] = {
    "Up",
    "Down",
    "Left",
    "Right"
};

int main(void){
    uint8_t buf[2048];
    sock_error_t sock_err;
    os_ClrHome();
    if((sock_err = socket_open(buf, sizeof(buf), 5000))){
        printf("%s\n", errors[sock_err]);
        socket_close();
        goto exit;
    }
    do {
        sk_key_t key = os_GetCSC();
        uint8_t read_buf[1024] = {0};
        usb_HandleEvents();
        if(key==sk_Up) socket_send("Up", strlen("Up")+1);
        else if(key==sk_Down) socket_send("Down", strlen("Down")+1);
        else if(key==sk_Left) socket_send("Left", strlen("Left")+1);
        else if(key==sk_Right) socket_send("Right", strlen("Right")+1);
        else if(key==sk_Clear) break;
        if(socket_read(read_buf)) strcpy(CEMU_CONSOLE, read_buf);
    } while(1);
exit:
    socket_close();
}
