#ifndef exposure_h
#define exposure_h

#include <stddef.h>
#include <stdint.h>
#include <keypadc.h>

bool cemu_check(void);
size_t cemu_get(void *buf, size_t size);
void cemu_send(void *buf, size_t size);


#endif
