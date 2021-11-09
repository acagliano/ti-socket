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
uint8_t errors[][100] = {
    "Success",
    "Timeout",
    "Backend Error"
};

int main(void){
    uint8_t buf[2048];
    uint8_t read_buf[1024] = {0};
    int is_data = 0;
    sock_error_t sock_err;
    os_ClrHome();
    if((sock_err = socket_open(buf, sizeof(buf), 5000))){
        printf(errors[sock_err]);
        socket_close();
        goto exit;
    }
    do {
        usb_HandleEvents();
        is_data = socket_read(read_buf);
        if(is_data){
            strncpy(CEMU_CONSOLE, read_buf, is_data);
            if(!socket_send(read_buf, is_data))
                strcpy(CEMU_CONSOLE, "string sent\n");
        }
    } while(os_GetCSC()== sk_Clear);
    strcpy("\n", read_buf);
exit:
    socket_close();
}
