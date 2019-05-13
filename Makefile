OBJS:=game.nes game.fns
.PHONY: all clean

all:
	nesasm game.asm
clean:
	rm $(OBJS)
