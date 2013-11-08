#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "imx233.h"

#define LRADC_IRQ_PENDING 0x00000003
#define CH0_SCHEDULE 0x00000003

// NUM_SAMPLES is a 5-bit value
#define NUM_SAMPLES 0x10
//#define NUM_SAMPLES 0x01

extern int imx233_rd(long offset);
extern int imx233_wr(long offset, long value);
extern void usleep(int value);

void usage() {
	fprintf(stderr, "Set output current for LRADC1 channel\n");
	fprintf(stderr, "USAGE: ./lradc_current <uA>|off\n");
	fprintf(stderr, "Available currents: 0uA, 20uA, ..., 280uA, 300uA\n");
	fprintf(stderr, "Use \"off\" to switch off current source. 0uA setting could result in some current\n");
	exit(EXIT_FAILURE);
}


int main(int argc, char **argv) {

   unsigned value;
   unsigned value0;
   unsigned value1;

   // If the name of the offset ends in CLR, the bits that are hi will be set to 0.
   // If the name of the offset ends in SET, the bits that are hi will be set to 1.
   // If the name of the offset ends in TOG, the bits that are hi will be toggled.



	if (argc != 2) {
		usage();
	}

	int current;
	char *endptr;
	char *str = argv[1];

	if (!strcmp(str, "off")) {
	    imx233_wr(HW_LRADC_CTRL2_CLR, 0x0200); //set TEMP_SENSOR_IENABLE1=0
	    exit(EXIT_SUCCESS);
	}

	current = strtol(str, &endptr, 10);

	if (endptr == str) {
	   usage();
	   fprintf(stderr, "Error: No digits were found\n");
	}

	if ( (current < 0) || (current > 300) || ( (current % 20) != 0)) {
	   fprintf(stderr, "Error: Wrong current value\n");
	   usage();
	}

	unsigned int ctrl2_val = (current / 20) << 4;
	 //~ printf( "ctrl2_val=%d\n", ctrl2_val );

    imx233_wr(HW_LRADC_CTRL2_SET, 0x0200); //set TEMP_SENSOR_IENABLE1
    imx233_wr(HW_LRADC_CTRL2_CLR, 0xF0); //clear TEMP_ISRC1
	imx233_wr(HW_LRADC_CTRL2_SET, ctrl2_val); //set TEMP_ISRC1



   //~ printf("%x\n", imx233_rd(HW_LRADC_CTRL2));





   //~ printf("v0=%d v1=%d\n", value0, value1);
   //~ value = (value1-value0) * 1012/(4000*NUM_SAMPLES)-273;
      //~ printf( "TEMP=%dC\n", value );

   return 0;

}

