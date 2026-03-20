CC      = gcc
CFLAGS  = -Wall -Wextra -std=c11 -pedantic -O2
TARGETS = data_types bitwise_operations register_access gpio_control

all: $(TARGETS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $<

clean:
	rm -f $(TARGETS)

.PHONY: all clean
