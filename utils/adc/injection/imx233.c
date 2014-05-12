// file: imx233.c
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

int *imx233_mem = 0;

int imx233_rd(long offset) {
   int result;
   static int fd = 0;
   static int *prev_mem_range = 0;

   int *mem_range = (int *)(offset & ~0xFFFF);
   if( mem_range != prev_mem_range ) {
      prev_mem_range = mem_range;

      if(imx233_mem)
         munmap(imx233_mem, 0xFFFF);
      if(fd)
         close(fd);

      fd = open("/dev/mem", O_RDWR);
      if( fd < 0 ) {
         perror("Unable to open /dev/mem");
         fd = 0;
         return -1;
      }

      imx233_mem = mmap(0, 0xffff, PROT_READ | PROT_WRITE, MAP_SHARED, fd, offset&~0xFFFF);
      if( -1 == (int)imx233_mem ) {
         perror("Unable to mmap file");
         if( -1 == close(fd) )
            perror("Also couldn't close file");
         fd=0;
         return -1;
      }
   }

   int scaled_offset = (offset-(offset&~0xFFFF));
   result = imx233_mem[scaled_offset/sizeof(long)];

   return result;
}

int imx233_wr(long offset, long value) {
   int old_value = imx233_rd(offset);
   int scaled_offset = (offset-(offset&~0xFFFF));
   imx233_mem[scaled_offset/sizeof(long)] = value;
   return old_value;
}

