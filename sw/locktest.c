#include "rsio.h"

volatile uint8_t __attribute__((section (".hostmem"))) shared_mem[16];

spinlock_t lock;

void
main()
{
    while (1) {
        spinlock_lock(&lock);
        rsio->gpio[0].wr.gpo ^= 1;
        shared_mem[rsio->hart]++;
        spinlock_unlock(&lock);
    }
}
