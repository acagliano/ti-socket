
//
// by Anthony Cagliano
// an API for sending data out a virtual "socket" that is layered
//      on top of the serial or IP driver.


#include <stddef.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "exposure.h"
#include <usbdrvce.h>
#include <srldrvce.h>

#define CEMU_CONSOLE ((char*)0xFB0000)
#define TIMEOUT_TO_48K  48000
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
uint32_t sock_timeout;


static usb_error_t handle_usb_event(usb_event_t event, void *event_data,
                                    usb_callback_data_t *callback_data) {
    if(event == USB_HOST_CONFIGURE_EVENT) {
        printf("Triggered Host Event\n");

        /* If we already have a serial device, ignore the new one */
        if(srl_ready) return USB_SUCCESS;

        usb_device_t device = usb_FindDevice(NULL, NULL, USB_SKIP_HUBS);
        if(device == NULL) {
            printf("no device found\n");
            return USB_SUCCESS;
        }

        /* Initialize the serial library with the newly attached device */
        srl_error_t error = srl_Open(&srl_device, device, srl_buf, srl_buf_size, SRL_INTERFACE_ANY, 9600);
        if(error) {
            printf("serial init error %u\n", error);
            return USB_SUCCESS;
        }

        srl_ready = true;
        printf("serial success");
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

sock_error_t socket_open(uint8_t* buf, size_t buf_size, size_t ms){
    srl_buf = buf;
    srl_buf_size = buf_size;
    if(cemu_check()) {
        strcpy(CEMU_CONSOLE, "CEmu pipe compatibility mode enabled\n");
        cemu_mode = true;
        return SOCK_SUCCESS;
    }
    if(ms) sock_timeout = usb_MsToCycles(ms);
    const usb_standard_descriptors_t *desc = srl_GetCDCStandardDescriptors();
    usb_error_t usb_error = usb_Init(handle_usb_event, NULL, desc, USB_DEFAULT_INIT_FLAGS);
    if(usb_error) return SOCK_BACKEND_ERROR;
    uint32_t start_time = usb_GetCycleCounter();
    do{
        usb_HandleEvents();
        if((usb_GetCycleCounter() - start_time) > (sock_timeout<<1))
            return SOCK_TIMEOUT;
    } while(!srl_ready);
    return SOCK_SUCCESS;
}

sock_error_t socket_settimeout(size_t ms) {
    sock_timeout = usb_MsToCycles(ms);
    return SOCK_SUCCESS;
}

#define SIZEOF_LEN   sizeof(size_t)
sock_error_t serial_send(const uint8_t* data, size_t len){
    size_t bytes_sent = 0;
    uint32_t start_time = usb_GetCycleCounter();
    do {
        bytes_sent += srl_Write(&srl_device, bytes_sent + (uint8_t*)&len, SIZEOF_LEN - bytes_sent);
        usb_HandleEvents();
        if((usb_GetCycleCounter() - start_time) > sock_timeout)
            return SOCK_TIMEOUT;
    } while(bytes_sent < SIZEOF_LEN);
    bytes_sent = 0;
    do {
        bytes_sent += srl_Write(&srl_device, &data[bytes_sent], len - bytes_sent);
        usb_HandleEvents();
        if((usb_GetCycleCounter() - start_time) > sock_timeout)
            return SOCK_TIMEOUT;
    } while(bytes_sent < len);
    return SOCK_SUCCESS;
}

sock_error_t pipe_send(const uint8_t* data, size_t len){
    sprintf(CEMU_CONSOLE, "sending %u bytes to CEmu pipe\n", len);
    cemu_send((uint8_t*)&len, SIZEOF_LEN);
    cemu_send(data, len);
    return SOCK_SUCCESS;
}

sock_error_t socket_send(const uint8_t* data, size_t len){
    if(cemu_mode)
        return pipe_send(data, len);
    else
        return serial_send(data, len);
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
        return true;
    }
    return 0;
}


bool socket_read(uint8_t* data){
    size_t (*read_func)(uint8_t* data, size_t size) = (cemu_mode) ? pipe_read_to_size : usb_read_to_size;
    static size_t packet_size = 0;
    usb_HandleEvents();
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
