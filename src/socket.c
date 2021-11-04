#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "exposure.h"
#include <usbdrvce.h>
#include <srldrvce.h>

#define CEMU_CONSOLE ((char*)0xFB0000)
typedef enum _sock_errors {
    SOCK_SUCCESS,
    SOCK_TIMEOUT,
    SOCK_BACKEND_ERROR,
} sock_error_t;

srl_device_t srl_device;
size_t bytes_read = 0;
bool srl_ready = false;
bool cemu_mode = false;
uint8_t* srl_buf = NULL;
size_t srl_buf_size = 0;

static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data) {
    if(event == USB_HOST_CONFIGURE_EVENT) {

        /* If we already have a serial device, ignore the new one */
        if(srl_ready) return USB_SUCCESS;

        usb_device_t device = usb_FindDevice(NULL, NULL, USB_SKIP_HUBS);
        if(device == NULL) return USB_SUCCESS;

        /* Initialize the serial library with the newly attached device */
        srl_error_t error = srl_Open(&srl_device, device, srl_buf, sizeof srl_buf, SRL_INTERFACE_ANY, 9600);
        if(error) return USB_SUCCESS;

        srl_ready = true;
    }

    if(event == USB_DEVICE_DISCONNECTED_EVENT) {
        usb_device_t device = event_data;
        if(device == srl_device.dev) {
            srl_Close(&srl_device);
            srl_ready = false;
        }
    }

    return USB_SUCCESS;
}


// set timeouts?
sock_error_t socket_open(uint8_t* buf, size_t buf_size){
    srl_buf = buf;
    srl_buf_size = buf_size;
    if(cemu_check()) {
        cemu_mode = true;
        strcpy(CEMU_CONSOLE, "cemu pipes detected\n");
        return SOCK_SUCCESS;
    }
    const usb_standard_descriptors_t *desc = srl_GetCDCStandardDescriptors();
    usb_error_t usb_error = usb_Init(handle_usb_event, NULL, desc, USB_DEFAULT_INIT_FLAGS);
    if(usb_error) return SOCK_BACKEND_ERROR;
    do{
        usb_HandleEvents();
    } while(!srl_ready);
    if(srl_ready) return SOCK_SUCCESS;
    return SOCK_TIMEOUT;
}

size_t socket_send(const uint8_t* data, size_t len){
    if(cemu_mode) {
        cemu_send(len, sizeof len);
        cemu_send(data, len);
        return len;
    }
    else {
        srl_Write(&srl_device, len, sizeof len);
        return srl_Write(&srl_device, data, len);
    }
}

size_t usb_read_to_size(uint8_t* data, size_t size) {
    bytes_read += srl_Read(&srl_device, &data[bytes_read], size - bytes_read);
    if(bytes_read >= size) {bytes_read = 0; return true;}
    else return false;
}

size_t pipe_read_to_size(uint8_t* data, size_t size) {
    if(bytes_read < size)
        bytes_read += cemu_get(&data[bytes_read], size - bytes_read);

    if(bytes_read >= size) {
        bytes_read = 0;
        return bytes_read;
    }

    return 0;
}


bool socket_read(uint8_t* data){
    size_t (*read_func)(uint8_t* data, size_t size) = (cemu_mode) ? pipe_read_to_size : usb_read_to_size;
    static packet_size = 0;
    if(packet_size) {
        if(read_func(data, packet_size)) {packet_size = 0; return true;}
    } else {
        if(read_func(data, sizeof(packet_size))) packet_size = *(size_t*)data;
    }
    return false;
}


bool socket_close(void){
    if(cemu_mode) return true;
    usb_Cleanup();
    return true;
}
