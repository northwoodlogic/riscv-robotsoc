/* SPDX-License-Identifier: [MIT] */

#include <errno.h>
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <byteswap.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>


/* SPI to FPGA interface, all transfers are 64 bits.
 *
 * The first 32-bits is a command and address, followed by
 * write on write cycle or return data on a read cycle.
 * Address MUST be 4 byte aligned
 *
 * cmd[31:28] == opcode
 * cmd[27:24] == byte enables
 * cmd[23:0]  == address
 * dat[31:0]  == write or return data
 *
 * Opcode: 4'h1 == read, 4'h0 == write
 *
 */

/*
 * Feature Request: add half word & byte read & write wrapper functions
 */

/* Block ram size, in bytes. Depth is the number of 32-bit words */
#define BRAM_SIZE   18432
#define BRAM_DEPTH (BRAM_SIZE / 4)

int
spi_read(int fd, uint32_t addr, uint32_t *data)
{
    int rc;
    if ((addr & 0x3) || (addr & 0xFF000000)) {
        return -1;
    }

    uint32_t cmd = 0x10000000 | (addr & 0xFFFFFF);
    uint32_t dat = 0;

    /* Over the wire is big-endian */
    cmd = bswap_32(cmd);

    struct spi_ioc_transfer tr[] = {
            {
            .tx_buf = (uintptr_t)&cmd,
            .rx_buf = (uintptr_t)NULL,
            .len = 4,
        },
            {
            .tx_buf = (uintptr_t)NULL,
            .rx_buf = (uintptr_t)&dat,
            .len = 4,
        },
    };

    rc = ioctl(fd, SPI_IOC_MESSAGE(2), tr) < 1 ? -1 : 0;
    *data = bswap_32(dat);
    return rc;
}

/* SPI write with byte enables. */
int
spi_write_be(int fd, uint32_t addr, uint32_t data, uint32_t bsel)
{
    if ((addr & 0x3) || (addr & 0xFF000000)) {
        return -1;
    }

    /* Invalid byte select */
    if ((bsel & ~0xf) || (bsel == 0)) {
        return -1;
    }

    uint32_t cmd = 0x00000000 | (bsel << 24) | (addr & 0xFFFFFF); 

    cmd = bswap_32(cmd);
    uint32_t dat = bswap_32(data);

    struct spi_ioc_transfer tr[] = {
            {
            .tx_buf = (uintptr_t)&cmd,
            .rx_buf = (uintptr_t)NULL,
            .len = 4,
        },
            {
            .tx_buf = (uintptr_t)&dat,
            .rx_buf = (uintptr_t)NULL,
            .len = 4,
        },
    };

    return ioctl(fd, SPI_IOC_MESSAGE(2), tr) < 1 ? -1 : 0;

}

#define SBUF_LEN 256

/*
 * SPI write block of data, incoming data must be word aligned. Length is the
 * number of words, not bytes
 */
int
spi_write_block(int fd, uint32_t addr, uint32_t *data, int len)
{
    int rc;
    if ((addr & 0x3) || (addr & 0xFF000000)) {
        return -1;
    }

    /*
     * Temporary storage for byte swapping. Don't want to modify the original
     * data. Linux spidev places limits on the max size of a single transfer,
     * so send data over in chunks.
     */
    uint32_t sbuf[SBUF_LEN];
    uint32_t bsel = 0xf;

    int k;
    int i = 0;
    int remaining = len;
    while (remaining > 0) {
        uint32_t cmd = 0x00000000 | (bsel << 24) | (addr & 0xFFFFFF); 
        cmd = bswap_32(cmd);

        /* Number of words to copy in */
        uint32_t nwords = (remaining > SBUF_LEN) ? SBUF_LEN : remaining;
        uint32_t nbytes = nwords * 4;

        for (k = 0; k < nwords; k++)
            sbuf[k] = bswap_32(data[i + k]);

        struct spi_ioc_transfer tr[] = {
                {
                .tx_buf = (uintptr_t)&cmd,
                .rx_buf = (uintptr_t)NULL,
                .len = 4,
            },
                {
                .tx_buf = (uintptr_t)&sbuf[0],
                .rx_buf = (uintptr_t)NULL,
                .len = nbytes, /* spidev api needs byte count */
            },
        };

        rc = ioctl(fd, SPI_IOC_MESSAGE(2), tr) < 1 ? -1 : 0;
        if (rc)
            return rc;

        i += nwords;
        addr += nbytes;
        remaining -= nwords;
    }

    return 0;
}

int
spi_write(int fd, uint32_t addr, uint32_t data)
{
    return spi_write_be(fd, addr, data, 0xF);
}


int
spi_read_block(int fd, uint32_t addr, uint32_t *data, int len)
{
    int rc;
    if ((addr & 0x3) || (addr & 0xFF000000)) {
        return -1;
    }

    /*
     * Temporary storage for byte swapping. Don't want to modify the original
     * data. Linux spidev places limits on the max size of a single transfer,
     * so send data over in chunks.
     */
    uint32_t sbuf[SBUF_LEN];
    uint32_t bsel = 0xf;

    int k;
    int i = 0;
    int remaining = len;
    while (remaining > 0) {
        uint32_t cmd = 0x10000000 | (bsel << 24) | (addr & 0xFFFFFF); 
        cmd = bswap_32(cmd);

        /* Number of words to copy in */
        uint32_t nwords = (remaining > SBUF_LEN) ? SBUF_LEN : remaining;
        uint32_t nbytes = nwords * 4;

        struct spi_ioc_transfer tr[] = {
                {
                .tx_buf = (uintptr_t)&cmd,
                .rx_buf = (uintptr_t)NULL,
                .len = 4,
            },
                {
                .tx_buf = (uintptr_t)NULL,
                .rx_buf = (uintptr_t)&sbuf[0],
                .len = nbytes, /* spidev api needs byte count */
            },
        };

        rc = ioctl(fd, SPI_IOC_MESSAGE(2), tr) < 1 ? -1 : 0;
        if (rc)
            return rc;

        for (k = 0; k < nwords; k++)
            data[i + k] = bswap_32(sbuf[k]);

        i += nwords;
        addr += nbytes;
        remaining -= nwords;
    }

    return 0;
}

#if 0
int spi_xfer(int fd, uint8_t *tx, uint8_t *rx, int len)
{
    struct spi_ioc_transfer tr = {
            .tx_buf = (uintptr_t)tx,
            .rx_buf = (uintptr_t)rx,
            .len = len,
        };

    return ioctl(fd, SPI_IOC_MESSAGE(1), &tr) < 1 ? -1 : 0;

}
#endif

/* fpga test wants mode 0,
 * clock polarity = 0, phase = 0
 */
int
spi_open(const char *device, uint32_t mode)
{
    int ret = 0;
    uint8_t bits = 8;
    uint32_t speed = 1000000;
    int fd = open(device, O_RDWR);
    const char *msg = NULL;
    do {
        if(fd == -1) {
            msg = "Error opening SPI device";
            break;
        }

        ret = ioctl(fd, SPI_IOC_WR_MODE, &mode);
        if (ret == -1) {
            msg = "can't set spi mode";
            break;
        }

        ret = ioctl(fd, SPI_IOC_RD_MODE, &mode);
        if (ret == -1) {
            msg = "can't get spi mode";
            break;
        }

        /*
         * bits per word
         */
        ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
        if (ret == -1) {
            msg = "can't set bits per word";
            break;
        }

        ret = ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
        if(ret == -1) {
            msg = "can't get bits per word";
            break;
        }

        /*
         * max speed hz
         */
        ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
        if(ret == -1) {
            msg = "can't set max speed hz";
            break;
        }

        ret = ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &speed);
        if(ret == -1) {
            msg = "can't get max speed hz";
            break;
        }

    } while(0);

    if(msg != NULL) {
        if(fd != -1) {
            close(fd);
        }
        fprintf(stderr, "%s\n", msg);
        return -1;
    }
#if 0
    fprintf(stderr, "Opened SPI device: fd=%d\n", fd);
    fprintf(stderr, "spi mode: 0x%x\n", mode);
    fprintf(stderr, "bits per word: %d\n", bits);
    fprintf(stderr, "max speed: %d Hz (%d KHz)\n", speed, speed/1000);
#endif
    return fd;
}


/*
 * Args:
 * -h print help
 * -s spidev interface, defaults to /dev/spidev0.0 if omitted
 * -a address for read or write
 * -d data if omitted do read transaction, otherwise write data
 */

void
show_help()
{
    printf("usage:\n"
        "  -h print help\n"
        "  -s spidev interface, defaults to /dev/spidev0.0 if omitted\n"
        "  -a address for read or write\n"
        "  -d data if omitted do read transaction, otherwise write data\n"
        "  -b write byte select, 0xF if omitted\n"
        "  -l load ROM image into memory, starting at specified address\n"
        "  -r dump ROM image from BRAM to file\n"
        "  -v be verbose\n"
    );
}

int
main(int argc, char *argv[])
{
        int rc, opt;
        int verbose = 0;
        int iswrite = 0;
        uint32_t addr = 0;
        uint32_t data = 0;
        uint32_t bsel = 0xF;
        uint32_t dmem[BRAM_DEPTH]; // BRAM size is 16KB
        uint32_t rmem[BRAM_DEPTH]; // used for read back / data compare
        FILE *fp = NULL;
        const char *rom = NULL;
        const char *rdf = NULL;
        const char *dev = "/dev/spidev0.0";

        while ((opt = getopt(argc, argv, "hvs:a:d:b:l:r:")) != -1) {
            switch (opt) {
                case 'h':
                    show_help();
                    return 0;
                case 'v':
                    verbose++;
                    break;
                case 's':
                    dev = optarg;
                    break;
                case 'l':
                    rom = optarg;
                    break;
                case 'r':
                    rdf = optarg;
                    break;
                case 'a':
                    addr = (uint32_t)strtoull(optarg, NULL, 0);
                    break;
                case 'd':
                    iswrite = 1;
                    data = (uint32_t)strtoull(optarg, NULL, 0);
                    break;
                case 'b':
                    bsel = (uint32_t)strtoull(optarg, NULL, 0);
                    if ((bsel & ~0xF) || (!bsel)) {
                        printf("invalid byte select\n");
                        return 1;
                    }
                    break;
                default:
                    printf("Unknown option: %c\n", (char)opt);
                    return 1;
            }
        }

        int fd = spi_open(dev, 0);
        if (fd < 0)
                return 1;

        if (rdf) {
            printf("Dumping BRAM to: %s\n", rdf);
            rc = spi_read_block(fd, addr, rmem, BRAM_DEPTH);
            if (rc) {
                printf("mem read error\n");
                return rc;
            }

            fp = fopen(rdf, "w+");
            if (!fp) {
                printf("Unable to open ROM dump file: %s\n", rdf);
                return 1;
            }

            rc = fwrite(rmem, 1, sizeof(rmem), fp);
            fclose(fp);
            if (rc != sizeof(rmem)) {
                printf("Unable to write ROM dump file\n");
                return 1;
            }
            return 0;
        }

        if (rom) {
            printf("Loading mem file: %s\n", rom);
            /* This assumes a LE host CPU */
            
            fp = fopen(rom, "r");
            if (!fp) {
                printf("Unable to open ROM file: %s\n", rom);
                return 1;
            }

            int n = 0;
            memset(dmem, 0, sizeof(dmem));
            while (n < sizeof(dmem)) {
                int rem = sizeof(dmem) - n;
                char *ptr = &((char*)dmem)[n];
                rc = fread(ptr, 1, rem, fp);
                if (rc < 0)
                    break;

                /* read some data, keep track */
                n += rc;
                if (rc < rem)
                    break;
            }
            fclose(fp);
            printf("mem file, read %d bytes\n", n);

            /* Always write the whole mem array */
            rc = spi_write_block(fd, addr, dmem, BRAM_DEPTH);
            if (rc) {
                printf("mem write error\n");
                return rc;
            }

            rc = spi_read_block(fd, addr, rmem, BRAM_DEPTH);
            if (rc) {
                printf("mem read error\n");
                return rc;
            }

            for (n = 0; n < BRAM_DEPTH; n++) {
                if (rmem[n] != dmem[n]) {
                    printf("mem compare mismatch at addr: 0x%x\n", addr + n);
                    return 1;
                }
                if (verbose)
                    printf("0x%04X: 0x%08X\n", n, rmem[n]);
            }
            
            return 0;
        }

        if (iswrite) {
            rc = spi_write_be(fd, addr, data, bsel);
            printf("write: 0x%x=0x%08x\n", addr, data);
        } else {
            rc = spi_read(fd, addr, &data);
            printf(" read: 0x%x=0x%08x\n", addr, data);
        }

        if (rc)
            printf("transfer error!\n");

        return rc;
}

