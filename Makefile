EXECUTABLE=firefly

all: libdallegro5.a $(EXECUTABLE)

run: all
	./$(EXECUTABLE)

libdallegro5.a:
	dmd -w -lib -oflibdallegro5.a -release allegro5/*.d allegro5/internal/*.d

$(EXECUTABLE): $(EXECUTABLE).d
	#dmd -release -O -of$(EXECUTABLE) $(EXECUTABLE).d -L-L.
	dmd -debug -g -O -profile -w -wi -of$(EXECUTABLE) $(EXECUTABLE).d -L-L.

.PHONY: clean
clean:
	rm -f libdallegro5.a
	rm -f $(EXECUTABLE)
	rm -f $(EXECUTABLE).o
	rm -f trace.def
	rm -f trace.log
