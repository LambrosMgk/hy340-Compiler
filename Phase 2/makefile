CC = gcc

#ta test eginan sto mhxanhma thanatos

%.o: %.c $(DEPS)
	$(CC) -c -o $@ $< $(CFLAGS)
	
all: clean flex syntax parser

flex: al.l
	flex --outfile=scanner.c al.l

syntax: syntax.y
	bison -v --yacc --defines --output=syntax.c syntax.y

parser:
	gcc -o parser scanner.c syntax.c symbol_table.c

clean:
	$(RM) syntax.c syntax.h scanner.c syntax.output parser