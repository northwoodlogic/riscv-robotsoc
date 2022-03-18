#include <stdint.h>

/*
 * Address Map
 * 0x400000 = LED 0-3
 *
 * 0x400004 = PWM channels 0-3 (read write)
 *  [31:24]=ch3, [23:16]=ch2, [15:8]=ch1, [7:0]=ch0
 *  |---- full bridge 1 ----| |-- full bridge 0 --|
 *
 * 0x400008 = PWM channels 4-7 (read write)
 *  [31:24]=ch7, [23:16]=ch6, [15:8]=ch5, [7:0]=ch4
 *  |---- full bridge 3 ----| |-- full bridge 2 --|
 *
 * 0x40000C = Status, millisecond counter (read only)
 *  [31]=ebrake, [30:16]=unused, [15:0]=count
 *
 * 0x400010 = R/C Receiver PPM input, 2x channels
 *  [24]=ch1 locked, [23:16]=ch1, [8]=ch0 locked, [7:0]=ch0
 * 
 * 0x400014 = Unused
 *
 * 0x400018 = R/C Transmitter PPM output, 4x channels
 *  [31:24]=ch3, [23:16]=ch2, [15:8]=ch1, [7:0]=ch0
 *
 * 0x40001C = R/C Transmitter PPM output, 4x channels
 *  [31:24]=ch7, [23:16]=ch6, [15:8]=ch5, [7:0]=ch4
 */

volatile uint32_t *q = (uint32_t*)0x400000;
volatile uint32_t *test = (uint32_t*)1024;
volatile uint32_t *rslt = (uint32_t*)1028;

volatile uint8_t  *pwm1    = (uint8_t*)0x400005;
volatile uint8_t  *thr_in  = (uint8_t*)0x400010;
volatile uint8_t  *str_in  = (uint8_t*)0x400012;
volatile uint8_t  *thr_out = (uint8_t*)0x40001E;
volatile uint8_t  *str_out = (uint8_t*)0x40001F;

volatile uint8_t __attribute__((section (".hostmem")))
    shared_mem[16] = {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2 };

void
delay()
{
    volatile int cnt = 0;
    while (cnt++ < 5000)
        ;
}

void
main(void)
{
    *q = 0x2;
    *pwm1 = 0;
    *test = 0xAA55AA55;
    *rslt = *test;
    while (1) {
        *rslt += 1;
        delay();
        *q ^= 7;
        *pwm1 += 1;

        *thr_out = *thr_in;
        *str_out = *str_in;
    }
}
