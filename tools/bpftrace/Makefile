EXTRA_CFLAGS += -g -O2 -std=gnu11 -Wall -Wno-error=date-time
obj-m += offset_module.o

.PHONY: all clean
all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
