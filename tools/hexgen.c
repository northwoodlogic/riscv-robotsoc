/* SPDX-License-Identifier: [MIT] */

#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

#define BRAM_SIZE 16384
#define BRAM_DEPTH (BRAM_SIZE / 4)

/* read in a binary file, print each word in hex. this assumes a LE host system */
int
main(int argc, char *argv[])
{
	uint32_t data[BRAM_DEPTH];
	memset(data, 0, sizeof(data));

	if (argc < 2) {
		fprintf(stderr, "give me a bin file\n");
		return 1;
	}

	FILE* fp = fopen(argv[1], "r");
	if (fp == NULL) {
		fprintf(stderr, "unable to open file: %s\n", argv[1]);
		return 1;
	}

	int rc = fread(data, 1, sizeof(data), fp);
	if (rc <= 0) {
		fprintf(stderr, "did read anything\n");
		return 1;
	}
	fprintf(stderr, "read %d bytes\n", rc);
	
	/* Print the whole block ram data even if the bin file was smaller */
	int n;
	for (n = 0; n < BRAM_DEPTH; n++) {
		printf("%08X\n", data[n]);
	}

	return 0;
}
