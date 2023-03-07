CC = gcc
OBJ = scanner.o
EX = scanner

#ta test eginan sto mhxanhma thanatos

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)

scanner: scanner.o
	$(CC) $(CFLAGS) $^ -o $@
	$(RM) $@.o


all: scanner

clean:
	$(RM) $(OBJ) $(EX)