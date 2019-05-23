CC ?= gcc

CFLAGS += -std=c99 -W -Wall -pedantic -frecord-gcc-switches \
	-O2 -ftree-vectorize -ftree-slp-vectorize \
	-Ideps/lodepng \
	-D_POSIX_C_SOURCE=200809L \
	-D_FILE_OFFSET_BITS=64 \
	-DLODEPNG_NO_COMPILE_ANCILLARY_CHUNKS \
	-DLODEPNG_NO_COMPILE_CPP \
	-DLODEPNG_NO_COMPILE_ALLOCATORS

LDFLAGS += -pie

# inspired by hardened Gentoo, Debian etc.
CFLAGS += -fPIE -fstack-protector-strong -D_FORTIFY_SOURCE=2
CFLAGS += -Wformat -Wformat-security -Werror=format-security
LDFLAGS += -Wl,-z,now -Wl,-z,relro

# git version
GIT_VERSION := $(shell git --no-pager describe --tags --always)
ifneq ($(strip $(shell git status --porcelain 2> /dev/null)),)
	GIT_VERSION := $(GIT_VERSION)-D
endif
CFLAGS += -DGIT_VERSION=\"$(GIT_VERSION)\"

DESTDIR ?= /usr

all : png2pos

man : png2pos.1.gz

.PHONY : clean install uninstall

clean :
	@-rm -f *.o png2pos deps/lodepng/*.o
	@-rm -f *.pos *.gz debug.* *.backup
	@-rm -f *.c_ *.h_

install : all man
	mkdir -p $(DESTDIR)/bin $(DESTDIR)/share/man/man1 $(DESTDIR)/share/bash-completion/completions
	install -m755 -D -Z -s png2pos $(DESTDIR)/bin/
	install -m644 -D -Z png2pos.1.gz $(DESTDIR)/share/man/man1/
	install -m644 -D -Z png2pos.complete $(DESTDIR)/share/bash-completion/completions/

uninstall :
	rm -f $(DESTDIR)/bin/png2pos
	rm -f $(DESTDIR)/share/man/man1/png2pos.1.gz
	rm -f $(DESTDIR)/share/bash-completion/completions/png2pos.complete

png2pos : png2pos.o deps/lodepng/lodepng.o
	@printf "%-16s%s\n" LD $@
	@$(CC) $^ $(LDFLAGS) -o $@

%.o : %.c
	@printf "%-16s%s\n" CC $@
	@$(CC) -c $(CFLAGS) -o $@ $<

deps/lodepng/%.o : deps/lodepng/%.cpp
	@printf "%-16s%s\n" CC $@
	@$(CC) -x c -c $(CFLAGS) -o $@ $<

# man page
%.1.gz : %.1
	@printf "%-16s%s\n" GZIP $@
	@gzip -c -9 $< > $@

# code indentation
indent : png2pos.c_ seccomp.h_

%.h_ : %.h
%.c_ : %.c
	@printf "%-16s%s\n" INDENT $@
	@indent \
	    --ignore-profile \
	    --indent-level 4 \
	    --line-comments-indentation 0 \
	    --case-indentation 4 \
	    --no-tabs \
	    --line-length 128 \
	    --ignore-newlines \
	    --blank-lines-after-declarations \
	    --blank-lines-after-procedures \
	    --blank-lines-before-block-comments \
	    --braces-on-if-line \
	    --braces-on-func-def-line \
	    --braces-on-struct-decl-line \
	    --break-before-boolean-operator \
	    --cuddle-do-while \
	    --cuddle-else \
	    --dont-break-procedure-type \
	    --format-all-comments \
	    --indent-label 0 \
	    --no-space-after-function-call-names \
	    --swallow-optional-blank-lines \
	    --dont-line-up-parentheses \
	    --no-comment-delimiters-on-blank-lines \
	    -v $< -o $@

debug : CFLAGS += -ggdb3 -DDEBUG -DNOSECCOMP
debug : png2pos
	@readelf -p .GCC.command.line png2pos

analyze : debug
	@cppcheck . --enable=all --force
	@valgrind \
	    --leak-check=full \
	    --show-leak-kinds=all \
	    --track-origins=yes \
	    --verbose \
	    --log-file=valgrind-out.txt \
	    ./png2pos -s 4 -p -c -r -a R -o /dev/null docs/lena_png2pos_*.png
