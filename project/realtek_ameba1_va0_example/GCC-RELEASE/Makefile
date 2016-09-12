all: ram_all

OS := $(shell uname)

.PHONY: toolchain
toolchain:
ifeq ($(OS),Linux)
	if [ ! -d ../../../tools/arm-none-eabi-gcc/4.8.3-2014q1 ] ; then tar -jxf ../../../tools/arm-none-eabi-gcc/gcc-arm-none-eabi-4_8-2014q1-20140314-linux.tar.bz2 -C ../../../tools/arm-none-eabi-gcc/ ; mv ../../../tools/arm-none-eabi-gcc/gcc-arm-none-eabi-4_8-2014q1 ../../../tools/arm-none-eabi-gcc/4.8.3-2014q1 ; fi
else
	if [ ! -d ../../../tools/arm-none-eabi-gcc/4.8.3-2014q1 ] ; then tar -zxf ../../../tools/arm-none-eabi-gcc/4.8.3-2014q1.tar.gz -C ../../../tools/arm-none-eabi-gcc/ ; fi
endif
	
	
.PHONY: ram_all
ram_all: toolchain
	@$(MAKE) -f application.mk

.PHONY: mp
mp: toolchain
	@$(MAKE) -f application.mk mp

.PHONY: clean clean_all
clean:
	@$(MAKE) -f application.mk clean
clean_all:
	@$(MAKE) -f application.mk clean_all
	
.PHONY: flash debug ramdebug setup
setup:
	@$(MAKE) -f application.mk $(MAKECMDGOALS)

flash: toolchain
	@$(MAKE) -f application.mk flashburn
	
debug: toolchain
	@$(MAKE) -f application.mk debug	

ramdebug: toolchain
	@$(MAKE) -f application.mk ramdebug	