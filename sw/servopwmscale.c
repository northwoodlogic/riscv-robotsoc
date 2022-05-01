/* Servo PWM + scaling Test
 *
 * Read a servo pulse PPM input from RC receiver. Convert to sign + magnitude
 * for driving h-bridge
 */

#include "rsio.h"

volatile uint8_t __attribute__((section (".hostmem")))
    shared_mem[16];

volatile uint32_t *cntr = (uint32_t*)&(shared_mem[4]);

#define PPMI_THR 1
#define PWMO_FWD 0
#define PWMO_REV 1

/* Notes about the SPEKTRUM DX2E transmitter
 *
 * This transmitter does not use the full 1-2mS range
 *
 * Throttle
 * Mid Pos  == 0x80 (1.50mS)
 * Full FWD == 0xe3 (1.90mS)
 * Full REV == 0x1f (1.12mS)
 *
 * Steering
 * Minimum gain
 * Mid      == 0x80
 * left     == 0x67 (1.40mS)
 * right    == 0x99 (1.60mS)
 *
 * Nominal gain
 * Mid      == 0x80
 * left     == 0x32 (1.20mS)
 * right    == 0xcd (1.80mS)
 *
 * Maximum gain
 * Mid      == 0x80
 * left     == 0x06 (1.02mS)
 * right    == 0xf9 (1.98mS)
 */

void
main(uint8_t id)
{

    while (1) {
        /*
         * Is servo input locked? PWM controller has internal watchdog that
         * disables drive signal if no updates occur within ~160mS
         */
        if (rsio->ppmi[PPMI_THR].sts) {
            volatile uint8_t v = rsio->ppmi[PPMI_THR].val;
            uint32_t tmp;
            /*
             * Idle throttle = 0x80
             * fwd --> val > 0x80
             * rev --> val < 0x80
             *
             * Scaling function
             * fwd, 0x80 < val < 0xff --> 0-100% modulation
             * rev, 0x7f > val > 0x00 --> 0-100% modulation
             *
             * See note above about transmitter range. This sign/magnitude
             * conversion would only get to about 75% pulse width modulation
             * on the throttle drive signals without linear scaling due to the
             * DX2E transmitter.
             */

            /* Dead band */
            if (v > 124 && v < 132) {
                rsio->pwmo[PWMO_FWD].val = 0;
                rsio->pwmo[PWMO_REV].val = 0;
            /* Forward */
            } else if (v >= 0x80) {
                /* Q8.4 format, 41 = 2.5625 */
                tmp = (((v - 128) << 4) * 41) >> 8;
                if (tmp > 255)
                    tmp = 255;

                rsio->pwmo[PWMO_REV].val = 0;
                rsio->pwmo[PWMO_FWD].val = (uint8_t)tmp;
            /* Reverse */
            } else {
                /* Q8.4 format, 41 = 2.5625 */
                tmp = (((128 - v) << 4) * 41) >> 8;
                if (tmp > 255)
                    tmp = 255;

                rsio->pwmo[PWMO_FWD].val = 0;
                rsio->pwmo[PWMO_REV].val = (uint8_t)tmp;
            }
        }

        /* Debug info, host system access */
        shared_mem[0] = rsio->pwmo[PWMO_FWD].val;
        shared_mem[1] = rsio->pwmo[PWMO_REV].val;
        shared_mem[2] = rsio->ppmi[PPMI_THR].val;
        shared_mem[3] = 0xAA;

        /*
         * Counter used for rough approximation of loop iterations per second
         * when throttle fully engaged.
         * ~12218 per second | -O2 and link time optimization
         *
         * Computed on host interface by reading counter, sleeping 10 sec,
         * reading again, compute delta then divide by 10.
         *
         *     robotsoc-io -a 0x47f4; sleep 10 ; robotsoc-io -a 0x47f4
         */
        *cntr += 1;
    }
}

