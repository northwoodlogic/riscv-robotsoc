#include "rsio.h"

volatile uint8_t __attribute__((section (".hostmem")))
    shared_mem[16] = {
        0xf, 0xf, 0xf, 0xf,
        0xf, 0xf, 0xf, 0xf,
        0xf, 0xf, 0xf, 0xf,
        0xf, 0xf, 0xf, 0xf
    };

int
scale(int x, int in_min, int in_max, int out_min, int out_max)
{
    return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}


volatile int counter = 0;

void
main(uint8_t id)
{
    
    mtimer_t d6;
    mtimer_init(&d6, 2000);

    mtimer_t d5;
    mtimer_init(&d5, 1000);

    mtimer_t d4;
    mtimer_init(&d4, 500);

    mtimer_t d3;
    mtimer_init(&d3, 250);

    mtimer_t d2;
    mtimer_init(&d2, 125);

    mtimer_t d1;
    mtimer_init(&d1, 10); // 100Hz

    rsio->gpio[0].wr.gpo = 0x0;
    uint16_t elapsed;
    uint16_t last = rsio->tick;
    while (1) {
        shared_mem[3] = id;
        shared_mem[0]++;
        
        /*
         * Toggle indicator using hardware based xor function. Functionally
         * this is the same as "gpo ^= 0x7" but generates 4 fewer instructions
         */
        if (mtimer_timedout(&d2))
            rsio->gpio[0].wr.xor = 0x01;

        if (mtimer_timedout(&d3))
            rsio->gpio[0].wr.xor = 0x02;

        if (mtimer_timedout(&d4))
            rsio->gpio[0].wr.xor = 0x04;

        if (mtimer_timedout(&d5))
            rsio->gpio[0].wr.xor = 0x08;

        if (mtimer_timedout(&d6))
            rsio->gpio[0].wr.xor = 0x10;

        if (mtimer_timedout(&d1)) {
            elapsed = rsio->tick - last;
            last = rsio->tick;
            if (elapsed != 10)
                rsio->gpio[0].wr.set = 0x40;


            counter++;
            if ((counter & 0x7f) == 0x7f) {
                rsio->gpio[0].wr.xor = 0x20;
                shared_mem[1]++;
            }
        }
    }
}
