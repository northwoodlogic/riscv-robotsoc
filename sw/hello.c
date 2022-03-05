#include <stdint.h>

volatile uint32_t *q = (uint32_t*)0x40000000;
volatile uint32_t *test = (uint32_t*)1024;
volatile uint32_t *rslt = (uint32_t*)1028;

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
	*test = 0xAA55AA55;
	*rslt = *test;
	while (1) {
		*rslt += 1;
		delay();
		*q ^= 7;
	}
}
