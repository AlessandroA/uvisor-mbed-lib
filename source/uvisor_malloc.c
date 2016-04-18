
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <reent.h>

#include "uvisor-lib/uvisor-lib.h"
#include "cmsis_os.h"

#define DPRINTF(...) {};
/* Use printf with caution inside malloc: printf may allocate memory itself,
   so using printf in malloc may lead to recursive calls! */
/* #define DPRINTF(fmt, ...) printf(fmt, ## __VA_ARGS__) */

extern UvisorBoxIndex *const __uvisor_ps;
extern void uvisor_malloc_init(void);

static int is_kernel_initialized() {
    static uint8_t kernel_running = 0;
    return (kernel_running || (kernel_running = osKernelRunning()));
}

int uvisor_set_allocator(UvisorAllocator allocator)
{
    DPRINTF("uvisor_allocator: Setting new allocator %p\n", allocator);

    if (allocator == NULL) return -1;
    __uvisor_ps->active_heap = allocator;
    return 0;
}

static inline int init_allocator()
{
    int ret = 0;
#if !(defined(UVISOR_PRESENT) && (UVISOR_PRESENT == 1))
    if (__uvisor_ps == NULL) uvisor_malloc_init();
#else
    if (__uvisor_ps == NULL) return -1;
#endif

    if (__uvisor_ps->mutex_id == NULL && is_kernel_initialized()) {
        /* create mutex if not already done */
        __uvisor_ps->mutex_id = osMutexCreate(&(__uvisor_ps->mutex));
        /* mutex failed to be created */
        if (__uvisor_ps->mutex_id == NULL) return -1;
    }

    if (__uvisor_ps->active_heap == NULL) {
        /* we need to initialize the process heap */
        if (__uvisor_ps->process_heap != NULL) {
            /* lock the mutex during initialization */
            if (is_kernel_initialized()) osMutexWait(__uvisor_ps->mutex_id, osWaitForever);
            /* initialize the process heap */
            UvisorAllocator allocator = uvisor_allocator_create_with_pool(
                __uvisor_ps->process_heap,
                __uvisor_ps->process_heap_size);
            /* set the allocator */
            ret = uvisor_set_allocator(allocator);
            /* release the mutex */
            if (is_kernel_initialized()) osMutexRelease(__uvisor_ps->mutex_id);
        }
        else {
            DPRINTF("uvisor_allocator: No process heap available!\n");
            ret = -1;
        }
    }
    return ret;
}

/* public API */
UvisorAllocator uvisor_get_allocator(void)
{
    if (init_allocator()) return NULL;
    return __uvisor_ps->active_heap;
}
