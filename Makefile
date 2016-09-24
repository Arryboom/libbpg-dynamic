# libbpg Makefile
# 
# Compile options:
#
# Installation prefix
prefix=/usr/local


#################################

ifdef CONFIG_WIN32
CROSS_PREFIX:=x86_64-w64-mingw32-
#CROSS_PREFIX=i686-w64-mingw32-
EXE:=.exe
else
CROSS_PREFIX:=
EXE:=
endif

CC=$(CROSS_PREFIX)gcc
CXX=$(CROSS_PREFIX)g++
AR=$(CROSS_PREFIX)ar
EMCC=emcc

PWD:=$(shell pwd)

CFLAGS:=-fPIC -Os -Wall -MMD -fno-asynchronous-unwind-tables -fdata-sections -ffunction-sections -fno-math-errno -fno-signed-zeros -fno-tree-vectorize -fomit-frame-pointer
CFLAGS+=-D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE -D_REENTRANT
CFLAGS+=-I.
CFLAGS+=-DCONFIG_BPG_VERSION=\"$(shell cat VERSION)\"
ifdef USE_JCTVC_HIGH_BIT_DEPTH
CFLAGS+=-DRExt__HIGH_BIT_DEPTH_SUPPORT
endif

LDFLAGS=-g
ifdef CONFIG_APPLE
LDFLAGS+=-Wl,-dead_strip
else
LDFLAGS+=-Wl,--gc-sections
endif
CFLAGS+=-g
CXXFLAGS=$(CFLAGS)

PROGS=bpgdec$(EXE)

all: $(PROGS)

LIBBPG_OBJS:=$(addprefix libavcodec/, \
hevc_cabac.o  hevc_filter.o  hevc.o         hevcpred.o  hevc_refs.o\
hevcdsp.o     hevc_mvs.o     hevc_ps.o   hevc_sei.o\
utils.o cabac.o golomb.o videodsp.o )
LIBBPG_OBJS+=$(addprefix libavutil/, mem.o buffer.o log2_tab.o frame.o pixdesc.o md5.o )
LIBBPG_OBJS+=libbpg.o

$(LIBBPG_OBJS): CFLAGS+=-D_ISOC99_SOURCE -D_POSIX_C_SOURCE=200112 -D_XOPEN_SOURCE=600 -DHAVE_AV_CONFIG_H -std=c99 -D_GNU_SOURCE=1 -DUSE_VAR_BIT_DEPTH -DUSE_PRED

BPGENC_OBJS:=bpgenc.o
BPGENC_LIBS:=

ifdef CONFIG_WIN32

BPGDEC_LIBS:=

else

ifdef CONFIG_APPLE
LIBS:=
else
LIBS:=-lrt
endif # !CONFIG_APPLE 
LIBS+=-lm -lpthread

BPGDEC_LIBS:=$(LIBS)

endif #!CONFIG_WIN32

libbpg.so: $(LIBBPG_OBJS) 
	$(CC) -shared -o $@ $^

bpgdec$(EXE): bpgdec.o libbpg.so
	$(CC) $(LDFLAGS) -o $@ $^ $(BPGDEC_LIBS)


size:
	strip bpgdec
	size bpgdec libbpg.o libavcodec/*.o libavutil/*.o | sort -n
	gzip < bpgdec | wc

install: bpgdec
	install -s -m 755 $^ $(prefix)/bin
	cp libbpg.so /usr/local/lib/
	cp libbpg.h  /usr/local/include/
	ldconfig

CLEAN_DIRS=doc html libavcodec libavutil \
     jctvc jctvc/TLibEncoder jctvc/TLibVideoIO jctvc/TLibCommon jctvc/libmd5

clean:
	rm -f $(PROGS) *.o *.a *.d *.so *~ $(addsuffix /*.o, $(CLEAN_DIRS)) \
          $(addsuffix /*.d, $(CLEAN_DIRS)) $(addsuffix /*~, $(CLEAN_DIRS)) \
          $(addsuffix /*.a, $(CLEAN_DIRS))

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

-include $(wildcard *.d)
-include $(wildcard libavcodec/*.d)
-include $(wildcard libavutil/*.d)
