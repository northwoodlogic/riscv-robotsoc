#include "rsio.h"

volatile rsio_t * const rsio = (rsio_t*)0x400000;

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


void
spinlock_lock(spinlock_t *l)
{
    /* Compute CPU index from on-hot processor ID */
    uint8_t i = (rsio->hart >> 1);
    uint8_t o = i ^ 1;
    l->flag[i] = 1;
    l->turn = o;
    while ((l->flag[o] == 1) && (l->turn == o)) {
#ifdef SPINLOCK_PROFILE
        l->wait[i]++;
#else
        ;
#endif
    }
}

void
spinlock_unlock(spinlock_t *l)
{
    uint8_t i = (rsio->hart >> 1);
    l->flag[i] = 0;
}

