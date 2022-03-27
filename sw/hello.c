#include <stdint.h>


/* 
 * 0x400000 = Status, millisecond counter (read only)
 *  [31]=ebrake, [30:16]=unused, [15:0]=count
 *
 * 0x400004 = R/C Receiver PPM input, 2x channels (read only)
 *  [24]=ch1 locked, [23:16]=ch1, [8]=ch0 locked, [7:0]=ch0
 *
 * 0x400008 = R/C Transmitter output channels 0-3 (read write)
 *  [31:24]=ch3, [23:16]=ch2, [15:8]=ch1, [7:0]=ch0
 *
 * 0x40000C = R/C Transmitter output channels 4-7 (read write)
 *  [31:24]=ch7, [23:16]=ch6, [15:8]=ch5, [7:0]=ch4
 *
 * 0x400010 = Phase correct PWM channels 0-3 (read write)
 *  [31:24]=ch3, [23:16]=ch2, [15:8]=ch1, [7:0]=ch0
 *  |---- full bridge 1 ----| |-- full bridge 0 --|
 *
 * 0x400014 = Phase correct PWM channels 4-7 (read write)
 *  [31:24]=ch7, [23:16]=ch6, [15:8]=ch5, [7:0]=ch4
 *  |---- full bridge 3 ----| |-- full bridge 2 --|
 *
 * 0x400018 = GPIO / indicators
 *  [31:16]=unused, [15:8]=input value,      [7:0]=output value (read)
 *  [31:24]=clr,    [23:16]=set, [15:8]=xor, [7:0]=assign value (write)
 *
 * 0x40001C = Reserved for 4x 8-bit pulse counters
 *
 */

typedef struct {
    uint8_t val;
    uint8_t sts;
} __attribute__((packed)) rsio_ppmi_t;

typedef struct {
    uint8_t val;
} __attribute__((packed)) rsio_ppmo_t;

typedef struct {
    uint8_t val;
} __attribute__((packed)) rsio_pwmo_t;

typedef struct {
    uint8_t gpo;
    uint8_t xor;
    uint8_t set;
    uint8_t clr;
} __attribute__((packed)) rsio_gpio_wr_t;

typedef struct {
    uint8_t gpo;
    uint8_t gpi;
    uint8_t _u0;
    uint8_t _u1;
} __attribute__((packed)) rsio_gpio_rd_t;

typedef struct {
    union {
        rsio_gpio_wr_t wr;
        rsio_gpio_rd_t rd;
    };
} __attribute__((packed)) rsio_gpio_t;

/* robot-soc I/O peripheral block */
typedef struct {
    uint16_t    tick;
    uint8_t     _u0;
    uint8_t     ebrake;

    rsio_ppmi_t ppmi[2];
    rsio_ppmo_t ppmo[8];
    rsio_ppmo_t pwmo[8];
    rsio_gpio_t gpio[1];

} __attribute__((packed)) rsio_t;

/*
 * C99 allows the compiler to optimize const pointers away. This does
 * not generate code that's more ineffecient than #define based definitions
 */
volatile rsio_t * const rsio = (rsio_t*)0x400000;

volatile uint8_t __attribute__((section (".hostmem")))
    shared_mem[16] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 };


typedef struct {
    uint16_t ms;
    uint16_t last;
} mtimer_t;

void
mtimer_init(mtimer_t *t, uint16_t ms)
{
    t->ms = ms;
    t->last = rsio->tick;
}

void
mtimer_reset(mtimer_t *t)
{
    t->last = rsio->tick;
}

int
mtimer_timedout(mtimer_t *t)
{
    uint16_t now = rsio->tick;
    uint16_t elapsed = now - t->last;

    if (elapsed >= t->ms) {
        t->last = now;
        return 1;
    }
    return 0;
}


volatile int counter = 0;

void
main(void)
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
