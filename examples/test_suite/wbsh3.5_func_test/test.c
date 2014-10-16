#include <stdio.h>
#include <fcntl.h>
#include <string.h>
#include <stdlib.h>
#include <termios.h>
#include <unistd.h>
#include <errno.h>


#define MAX_BUF 255


void gpio_init(int gpio_num) {
    int fd;
    char buf[MAX_BUF];

    fd = open("/sys/class/gpio/export", O_WRONLY);
    sprintf(buf, "%d", gpio_num);
    write(fd, buf, strlen(buf));

    close(fd);

    return;
}

void gpio_out(int gpio_num) {
    int fd;
    char buf[MAX_BUF];

    sprintf(buf, "/sys/class/gpio/gpio%d/direction", gpio_num);
    fd = open(buf, O_WRONLY);

    write(fd, "out", 3);

    close(fd);

    return;
}

void gpio_in(int gpio_num) {
    int fd;
    char buf[MAX_BUF];

    sprintf(buf, "/sys/class/gpio/gpio%d/direction", gpio_num);
    fd = open(buf, O_WRONLY);

    write(fd, "in", 2);

    close(fd);

    return;
}


void gpio_high(int gpio_num) {
    int fd;
    char buf[MAX_BUF];

    sprintf(buf, "/sys/class/gpio/gpio%d/value", gpio_num);
    fd = open(buf, O_WRONLY);

    write(fd, "1", 1);

    close(fd);

    return;
}

void gpio_low(int gpio_num) {
    int fd;
    char buf[MAX_BUF];

    sprintf(buf, "/sys/class/gpio/gpio%d/value", gpio_num);
    fd = open(buf, O_WRONLY);

    write(fd, "0", 1);

    close(fd);

    return;
}

int adc_value_by_name(char* adc_name) {
    char command_line1[MAX_BUF];
    char command_line[MAX_BUF];
    sprintf(command_line1, "wb-adc-set-mux %s", adc_name);
    system(command_line1);
    sprintf(command_line, "wb-adc-get-value %s", adc_name);



    FILE *pp;
    pp = popen(command_line, "r");

    int adc_result=0;

    if (pp != NULL) {
	while (1) {
	    char *line;
    	    char buf[1000];
    	    line = fgets(buf, sizeof buf, pp);
    	    if (line == NULL) break;
	    sscanf(line,"%d\n", &adc_result);
	}
    }
    pclose(pp);
    return adc_result;
}


int check_ethernet () {
//    system("udhcpc -n");

    FILE *pp;
    pp = popen("ping 8.8.8.8 -c 1 | grep 64", "r");

    if (pp != NULL) {
	while (1) {
	    char *line;
	    char buf[1000];
	    line = fgets(buf, sizeof buf, pp);
	    if (line == NULL) {
		pclose(pp);
		return 1;
	    }
	    printf("%s\n",line);
	    pclose(pp);
	    return 0;
	}
    }
}

int check_wifi () {
    //system("service hostapd stop");
    //system("ifconfig wlan0 up");

    //FILE *pp;
    //pp = popen("iwlist wlan0 scanning | grep Yasha", "r");

    //Looking for name of WLAN adapter
    FILE *pp;
    pp = popen("iwconfig", "r");


    if ( pp == NULL) {
	printf("Can't execute iwconfig\n");
	return 1;
    }

    char adapter_name[ MAX_BUF ];


    char* place;
    char* place2;

    while (1) { //Reading all the output looking for wlanXX record
	char *line;
	char buf[ MAX_BUF ];
	line = fgets(buf, sizeof buf, pp);
	if (line == NULL) {
	    pclose(pp);
	    return 1; //We got to the end of ouput found no WLAN adapter name
	}
	place=strstr(buf,"wlan"); //looking for substring
	if (place != NULL) { //We found the WLAN adapter name, extracting it
	    place2 = strstr(place," "); //Looking for space aftern wlanXX record
	    bzero(place2, 1); //Write zero to that place as EOL
	    strcpy(adapter_name,place); //Put adapter name to adapter_name
	    pclose(pp);
	    break;
	}
    }

    printf("%s\n",adapter_name);

    char command_line[MAX_BUF];
    sprintf(command_line, "ifconfig %s up", adapter_name);
    system(command_line); //Make wlanXX up

    sprintf(command_line, "iwlist %s scanning | grep PlantsVsZombiesN", adapter_name); //Looking for YashaTheForester network

    pp = popen(command_line, "r");

    if (pp != NULL) {
	while (1) {
	    char *line;
	    char buf[ MAX_BUF ];
	    line = fgets(buf, sizeof buf, pp);
	    if (line == NULL) {
		pclose(pp);
		return 1;
	    }
	    printf("%s\n",line);
	    pclose(pp);
	    return 0;
	}
    }
}

int check_nrf () {
    return WEXITSTATUS( system("python dev_probe_test.py") );
}




int check_433 () {
    FILE *pp;
    pp = popen("python rfm69-linux-master/test1.py | grep ModeReady", "r");

    if (pp != NULL) {
	while (1) {
	    char *line;
	    char buf[1000];
	    line = fgets(buf, sizeof buf, pp);
	    if (line == NULL) {
		pclose(pp);
		return 1;
	    }
	    printf("%s\n",line);
	    pclose(pp);
	    return 0;
	}
    }
}


int check_can () {
    FILE *pp;
    pp = popen("dmesg | grep mcp25", "r");

    if (pp != NULL) {
	while (1) {
	    char *line;
	    char buf[1000];
	    line = fgets(buf, sizeof buf, pp);
	    if (line == NULL) {
		pclose(pp);
		return 1;
	    }
	    printf("%s\n",line);
	    pclose(pp);
	    return 0;
	}
    }
}



void old_check_serial() {


    system("wb-gsm on");

    char *portname = "/dev/ttyAPP0";

    int fd = open (portname, O_RDWR | O_NOCTTY | O_SYNC);

    if (fd < 0) {
        perror ("error opening port");
        return;
    }


    //set_interface_attribs (fd, B115200, 0);  // set speed to 115,200 bps, 8n1 (no parity)
    //set_blocking (fd, 0);                // set no blocking

    char buf [100];

    write (fd, "AAAAAAAAAT\n", 11);           // send 11 character greeting

    usleep(1000);

    int n = read (fd, buf, sizeof buf);

    printf("%s", buf);

    read (fd, buf, sizeof buf);
    printf("%s", buf);


    write (fd, "ATD89154816100;\n", 16);		// so call me maybe


    close(fd);
    return;
}


void check_gsm() {
    system("wb-gsm on");
    sleep(18);
    system("echo AAAAAAAT > /dev/ttyAPP0");
    sleep(6);
//    system("echo ATD89154816100\\; > /dev/ttyAPP0");
    //~ system("echo ATDT89199658836\\; > /dev/ttyAPP0");
    system("echo ATDT89263572423\\; > /dev/ttyAPP0");

    printf("\nWait for call...");
    return;
}

void check_beeper() {
    system("./beeper_test.sh");
    printf("Wait for beep...\n");
}



int check_rs485() {

    char *portname0 = "/dev/ttyNSC0";
    char *portname1 = "/dev/ttyNSC1";

    int fd0 = open (portname0, O_RDWR | O_NOCTTY);
    int fd1 = open (portname1, O_RDWR | O_NOCTTY);


    if (fd0 < 0) {
        perror ("error opening port");
        return;
    }
    if (fd1 < 0) {
        perror ("error opening port");
        return;
    }


    int c, res;
    struct termios newtio;

    bzero(&newtio, sizeof(newtio));

    //cfsetospeed (&newtio, B115200);
    //cfsetispeed (&newtio, B115200);

    newtio.c_cflag = B115200 | CS8 | CLOCAL | CREAD;
    newtio.c_iflag = IGNPAR;
    newtio.c_oflag = 0;

    /* set input mode (non-canonical, no echo,...) */
    newtio.c_lflag = 0;

    newtio.c_cc[VTIME]    = 0;   /* inter-character timer unused */
    newtio.c_cc[VMIN]     = 0;   /* blocking read until 5 chars received */

    tcflush(fd0, TCIFLUSH);
    tcsetattr(fd0,TCSANOW,&newtio);

    tcflush(fd1, TCIFLUSH);
    tcsetattr(fd1,TCSANOW,&newtio);

    usleep(10000);


    char buf0 [ MAX_BUF ];
    char buf1 [ MAX_BUF ];

    memset(buf0, 0, sizeof(buf0));
    memset(buf1, 0, sizeof(buf1));

    write (fd0, "qwerty", 6);           // send message
    usleep(10000);
    int n = read (fd1, buf0, MAX_BUF );
    //printf("%d\n", n);
    //printf("%.6s", buf0);

    int res0 = strncmp(buf0, "qwerty", 6);
    //printf("Result %d\n", res0);


    //usleep(100000);

    write (fd1, "asdfgh", 6);
    usleep(10000);
    n = read (fd0, buf1, MAX_BUF );
    //printf("%d\n", n);
    //printf("%.6s", buf1);

    int res1 = strncmp(buf1, "asdfgh", 6);
    //printf("Result %d\n", res1);

    close(fd0);
    close(fd1);

    //Any result not equal to zero means RS-485 doesn't work
    //All mistakes before were caused by wrong transceiver chips which can't read


    if (res0!=0) {
	printf("NSC1 doesn't work\n");
    }

    if (res1!=0) {
	printf("NSC0 doesn't work\n");
    }

    if ( (res0!=0) || (res1!=0) )
	return 1;

    return 0;
}





int main() {
    int adc_first_result;
    int adc_second_result;
    //Check A1-A4

//~
    //~ gpio_init(52); //Test A1
    //~ gpio_out(52);
    //~
    //~ gpio_high(52);
    //~ adc_first_result=adc_value_by_name("A1");
//~
    //~ gpio_low(52);
    //~ int adc_second_result=adc_value_by_name("A1");
//~
    //~ if ( (adc_first_result < 150) && (adc_second_result > 550) )
	//~ printf("\033[22;32mA1\033[0m\n");
    //~ else
	//~ printf("\033[22;31mA1\033[0m\n");
//~
//~
//~
    //~ gpio_init(50); //Test A2
    //~ gpio_out(50);
    //~
    //~ gpio_high(50);
    //~ adc_first_result=adc_value_by_name("A2");
//~
    //~ gpio_low(50);
    //~ adc_second_result=adc_value_by_name("A2");
//~
//~
    //~ if ( (adc_first_result < 150) && (adc_second_result > 550) )
	//~ printf("\033[22;32mA2\033[0m\n");
    //~ else
	//~ printf("\033[22;31mA2\033[0m\n");
//~
//~
    //~ gpio_init(57); //Test A3
    //~ gpio_out(57);
    //~
    //~ gpio_high(57);
    //~ adc_first_result=adc_value_by_name("A3");
//~
    //~ gpio_low(57);
    //~ adc_second_result=adc_value_by_name("A3");
//~
    //~ if ( (adc_first_result < 150) && (adc_second_result > 550) )
	//~ printf("\033[22;32mA3\033[0m\n");
    //~ else
	//~ printf("\033[22;31mA3\033[0m\n");
//~
//~
//~
//~
    //~ gpio_init(54); //Test A4
    //~ gpio_out(54);
    //~
    //~ gpio_high(54);
    //~ adc_first_result=adc_value_by_name("A4");
//~
    //~ gpio_low(54);
    //~ adc_second_result=adc_value_by_name("A4");
//~
    //~ if ( (adc_first_result < 100) && (adc_second_result > 550) )
	//~ printf("\033[22;32mA4\033[0m\n");
    //~ else
	//~ printf("\033[22;31mA4\033[0m\n");



//init and poweroff relays

    gpio_init(247); //Relay 1
    gpio_out(247);
    gpio_low(247);

    gpio_init(246); //Relay 2
    gpio_out(246);
    gpio_low(246);


//~ //Check R1-R4
//~
    //~ gpio_init(16); //Test R1
    //~ gpio_out(16);
    //~
    //~ gpio_high(16);
    //~ adc_first_result=adc_value_by_name("4");
//~
    //~ gpio_low(16);
    //~ adc_second_result=adc_value_by_name("4");
//~
    //~ if ( (adc_first_result > 4000) && (adc_second_result < 100) )
	//~ printf("\033[22;32mR1\033[0m\n");
    //~ else
	//~ printf("\033[22;31mR1\033[0m\n");
//~
//~
//~
    //~ gpio_init(7); //Test R2
    //~ gpio_out(7);
    //~
    //~ gpio_high(7);
    //~ adc_first_result=adc_value_by_name("6");
//~
    //~ gpio_low(7);
    //~ adc_second_result=adc_value_by_name("6");
//~
    //~ if ( (adc_first_result > 4000) && (adc_second_result < 100) )
	//~ printf("\033[22;32mR2\033[0m\n");
    //~ else
	//~ printf("\033[22;31mR2\033[0m\n");
//~
//~
    //~ gpio_init(6); //Test R3
    //~ gpio_out(6);
    //~
    //~ gpio_high(6);
    //~ adc_first_result=adc_value_by_name("7");
//~
    //~ gpio_low(6);
    //~ adc_second_result=adc_value_by_name("7");
//~
    //~ if ( (adc_first_result > 4000) && (adc_second_result < 100) )
	//~ printf("\033[22;32mR3\033[0m\n");
    //~ else
	//~ printf("\033[22;31mR3\033[0m\n");
//~
//~
    //~ gpio_init(5); //Test R4
    //~ gpio_out(5);
    //~
    //~ gpio_high(5);
    //~ adc_first_result=adc_value_by_name("5");
//~
    //~ gpio_low(5);
    //~ adc_second_result=adc_value_by_name("5");
//~
    //~ if ( (adc_first_result > 4000) && (adc_second_result < 100) )
	//~ printf("\033[22;32mR4\033[0m\n");
    //~ else
	//~ printf("\033[22;31mR4\033[0m\n");
//~



//Check relays

    //Test Relay1

    gpio_in(16); //Set R1 to Hi-Z for ADC reading

    gpio_high(247);
    adc_first_result=adc_value_by_name("4");

    gpio_low(247);
    adc_second_result=adc_value_by_name("4");

    if ( (adc_first_result > 1250) && (adc_second_result < 100) )
	printf("\033[22;32mRelay1\033[0m\n");
    else
	printf("\033[22;31mRelay1\033[0m\n");


    //Test Relay2

    gpio_in(5); //Set R4 to Hi-Z for ADC reading

    gpio_high(246);
    adc_first_result=adc_value_by_name("5");

    gpio_low(246);
    adc_second_result=adc_value_by_name("5");

    if ( (adc_first_result > 1750) && (adc_first_result < 1950) && (adc_second_result > 4000) )
	printf("\033[22;32mRelay2\033[0m\n");
    else
	printf("\033[22;31mRelay2\033[0m\n");



    if ( check_ethernet() == 0 )
	printf ("\033[22;32mEthernet\033[0m\n");
    else
	printf("\033[22;31mEthernet\033[0m\n");

    if ( check_wifi() == 0 )
	printf ("\033[22;32mWi-Fi\033[0m\n");
    else
	printf("\033[22;31mWi-Fi\033[0m\n");

    if ( check_433() == 0 )
	printf ("\033[22;32m433\033[0m\n");
    else
	printf("\033[22;31m433\033[0m\n");

    if ( check_can() == 0 )
	printf ("\033[22;32mCAN\033[0m\n");
    else
	printf("\033[22;31mCAN\033[0m\n");

    if ( check_rs485() == 0 )
	printf ("\033[22;32mRS-485\033[0m\n");
    else
	printf("\033[22;31mRS-485\033[0m\n");

    if ( check_nrf() == 0 )
	printf ("\033[22;32mNRF24\033[0m\n");
    else
	printf("\033[22;31mNRF24\033[0m\n");


    check_beeper();

    check_gsm();
    return 0;
}
