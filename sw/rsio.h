#ifndef RSIO_H
#define RSIO_H

#include <stdint.h>

/* 
 * 0x400000 = Status, millisecond counter (read only)
 *  [31]=ebrake, [30:20]=unused, [19:16]=hart, [15:0]=count
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
    uint8_t     hart;
    uint8_t     ebrake;

    rsio_ppmi_t ppmi[2];
    rsio_ppmo_t ppmo[8];
    rsio_pwmo_t pwmo[8];
    rsio_gpio_t gpio[1];

} __attribute__((packed)) rsio_t;

/*
 * This doesn't get optimized out when defined in this manner unless link time
 * optimization is enabled.
 */
extern volatile rsio_t * const rsio;


/*
 * Non-blocking millisecond timer.
 */
typedef struct {
    uint16_t ms;
    uint16_t last;
} mtimer_t;

void mtimer_init(mtimer_t *t, uint16_t ms);
void mtimer_reset(mtimer_t *t);
int mtimer_timedout(mtimer_t *t);

/*
 * Spin-lock, Peterson's Algorithm - Works with 2 CPUs only.
 */
typedef volatile struct {
    uint8_t flag[2];
#ifdef SPINLOCK_PROFILE
    uint8_t wait[2];
#endif
    uint8_t turn;
} spinlock_t;

void spinlock_lock(spinlock_t *l);
void spinlock_unlock(spinlock_t *l);


#endif
