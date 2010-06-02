
# ldc / dmd
DMD=ldc
OUT=core
COREOBJ=obj/$(OUT).bc
LINKOBJ=$(COREOBJ)

# this needs to be split to ldc / dmd when I actually support dmd
TANGO_FLAGS=-release
TANGO_REVISION=5464
ifeq ($(M32),true)
	TANGO_BUILD=./build/bin/linux32/bob
else
	TANGO_BUILD=./build/bin/linux64/bob
endif


CFLAGS=
DFLAGS=-I../common -nodefaultlib

ifeq ($(DMD),ldc)
	LD=llvm-ld
	CC=llvm-gcc --emit-llvm
	O=-of=obj/
	LDO=-o=
else
	LD=gcc -m32
	CC=gcc -m32
	O=-odobj -of
	LDO=-o
endif


ifeq ($(BYTECODE),true)
	ifeq ($(DMD),ldc)
		EXTRA=-d-version=testbytecode -d-version=renderingbytecode
	else
		EXTRA=-version=testbytecode
	endif
endif

ifeq ($(DATATEST),true)
	ifeq ($(DMD),ldc)
		EXTRA+= -d-version=datatest
	else
		EXTRA+= -version=datatest
	endif
endif

ifeq ($(DMD),ldc)
	DFLAGS+=\
		-singleobj \
		-output-bc \
		-relocation-model=pic \
		-I../common/tango-svn/tango/core/rt/compiler/ldc/ \
		-I../common/tango-svn/ \
		-enable-eh \
		-enable-correct-eh-support \
		-realign-stack

	#-disable-boundscheck
	LDFLAGS+=-native -stats
	#CFLAGS=
	TANGO_FLAGS+= \
		-output-bc \
		-relocation-model=pic \
		-d-version=release \
		-g \
		-O5 \
		-enable-eh \
		-enable-correct-eh-support \
		-realign-stack
		

	ifeq ($(M32),true)
		EXTRA+= -m32
	else
		EXTRA+= -m64
	endif
else
	DFLAGS+=-I../common
	LDFLAGS+=-Xlinker
	#-melf_i386 --format elf32-i386
	# --gc-sections
	CFLAGS=-m32
endif


ifeq ($(WARN),true)
	DFLAGS+= -w
endif

LIBS=../common/mongo-c-driver/libmongoc.a \
	../common/tango-svn/libtango.a \
	../common/libowfat/libowfat.a \
	-lz -ldl -lm -lpthread

LDOPT= -instcombine -constmerge -strip-debug -dse -gvn
ifeq ($(MAKECMDGOALS),release)
	ifeq ($(PROFILE),true)
		EXTRA+= -pg
	else
		#EXTRA+= -fomit-frame-pointer -ffunction-sections
	endif
	
	#CFLAGS+=-march=nocona -O2 -finline-functions -fno-bounds-check -femit-templates=all -fdata-sections -funit-at-a-time -freorder-blocks -fno-ident -fmerge-all-constants -combine -fweb
	CFLAGS+= -O3
	DFLAGS+= -release $(EXTRA)
	LDFLAGS+= \
		-adce \
		-basicaa \
		-basiccg \
		-constmerge \
		-deadargelim \
		-domfrontier \
		-domtree \
		-dse \
		-functionattrs \
		-globaldce \
		-globalopt \
		-globalsmodref-aa \
		-gvn \
		-inline \
		-instcombine \
		-internalize \
		-ipsccp \
		-jump-threading \
		-loops \
		-loopsimplify \
		-lcssa \
		-memcpyopt \
		-memdep \
		-scalar-evolution \
		-scalarrepl \
		-sccp \
		-verify-dom-info \
		$(LDOPT)
	
	ifeq ($(DMD),ldc)
		DFLAGS+= -d-version=release -d-version=notdebug -stats
		DFLAGS+= \
			-O5 \
			-unwind-tables \
			-enable-inlining \
			-tailcallopt \
			-enable-finite-only-fp-math
	else
		DFLAGS+= -version=release -version=notdebug
	endif
else
	# -Wall -Wextra -Wno-unreachable-code
#	CFLAGS+=-g -fno-bounds-check
	CFLAGS+=-g
	DFLAGS+= -g $(EXTRA)
	ifeq ($(DMD),ldc)
		#-annotate -op -D
		DFLAGS+= -O0 -v-cg -noverify
		DFLAGS+= -d-debug -d-version=notrelease -d-version=debug
		LDFLAGS+= -disable-opt
	else
		DFLAGS+= -debug -version=notrelease -version=debug
	endif
endif
# -Wall

LIBOWFAT=

FILES=core.d \
	panel.d \
	shared.d \
	session.d \
	edb.d \
	lib.d \
	objects.d


# lame hack to include the templates
FILES+=templates/*.d

#lame hack for movideal! REMOVE ME
FILES+=../../$(SITE)/src/*.d \
	addon/http_request.d \
	../common/kxml/xml.d \
	obj/common.resolve.bc
LINKOBJ+=obj/common.resolve.bc


ifeq ($(UNITTESTS),true)
	FILES+= unittests.d
	ifeq ($(DMD),ldc)
		DFLAGS+= -unittest -d-version=unittests
	else
		DFLAGS+= -unittest -version=unittests
	endif
endif

debug : prepare $(FILES)
	$(DMD) $(DFLAGS) -c $(FILES) $(O)core.bc
	$(LD) $(LDFLAGS) $(LINKOBJ) $(LIBS) $(LDO)$(OUT)

prepare :
	mkdir -p obj
	rm -f core

release : prepare $(OBJS)
	$(DMD) $(DFLAGS) -c $(FILES) $(O)core.bc
	$(LD) $(LDFLAGS) $(LINKOBJ) $(LIBS) $(LDO)$(OUT)
	

ifeq ($(PROFILE),false)
	strip -s $(OUT)
endif

clean:
	rm -rf $(OUT) obj

mongoc:
	cd ../common/mongo-c-driver && scons --c99 --pic
	
libowfat:
	cd ../common/libowfat && make && mv libowfat.a save-me && make clean && mv save-me libowfat.a
	
tango:
	svn co -r $(TANGO_REVISION) http://svn.dsource.org/projects/tango/trunk ../common/tango-svn && \
	cd ../common/tango-svn/ && \
	rm -f libtango.a && \
	$(TANGO_BUILD) -v -r=ldc -c=ldc -p=linux -u -o="$(TANGO_FLAGS) $(EXTRA)" . && \
	ar -r libtango.a *.o *.bc && \
	rm *.o *.bc

libs: tango libowfat mongoc
	#cd ../common/tango/lib/ && ./build-gdc.sh
	#cd ../common/tango/lib/ && ./build-tango.sh --verbose gdc
	#cd ../common/ && \
	#	svn co http://svn.dsource.org/projects/tango/trunk tango-svn && \
	#	ln -s tango-svn  tango && \
	#	cd tango && \
	#	mkdir gdc && \
	#	cd gdc && \
	#	./../build/bin/linux64/bob -vu -p=linux -r=gdc -c=gdc -o="-frelease -fversion=Posix" -l=libtango-gdc ..

obj/common.resolve.bc : ../common/resolve.c
	$(CC) $(CFLAGS) -c ../common/resolve.c -o obj/common.resolve.bc


obj/core.bc : core.d
	$(DMD) -c $(DFLAGS) core.d $(O)core.bc

obj/panel.bc : panel.d
	$(DMD) -c $(DFLAGS) panel.d $(O)panel.bc

obj/edb.bc : edb.d
	$(DMD) -c $(DFLAGS) edb.d $(O)edb.bc

obj/addon.http_request.bc : addon/http_request.d
	$(DMD) -c $(DFLAGS) addon/http_request.d $(O)addon.http_request.bc

obj/shared.bc : shared.d
	$(DMD) -c $(DFLAGS) shared.d $(O)shared.bc

obj/objects.bc : objects.d edb.d
	$(DMD) -c $(DFLAGS) objects.d $(O)objects.bc

obj/parsers.bc : parsers.d
	$(DMD) -c $(DFLAGS) parsers.d $(O)parsers.bc

obj/lib.bc : lib.d
	$(DMD) -c $(DFLAGS) lib.d $(O)lib.bc

obj/unittests.bc : unittests.d
	$(DMD) -c $(DFLAGS) unittests.d $(O)unittests.bc



#---------------------
# templates
#---------------------

obj/templates.date.bc : templates/date.d
	$(DMD) -c $(DFLAGS) templates/date.d $(O)templates.date.bc

obj/templates.render.bc : templates/render.d
	$(DMD) -c $(DFLAGS) templates/render.d $(O)templates.render.bc

obj/templates.textbox.bc : templates/textbox.d
	$(DMD) -c $(DFLAGS) templates/textbox.d $(O)templates.textbox.bc

obj/templates.pager.bc : templates/pager.d
	$(DMD) -c $(DFLAGS) templates/pager.d $(O)templates.pager.bc
	
obj/templates.link.bc : templates/link.d
	$(DMD) -c $(DFLAGS) templates/link.d $(O)templates.link.bc

#---------------------
# data
#---------------------

obj/session.bc : session.d edb.d
	$(DMD) -c $(DFLAGS) session.d $(O)session.bc

obj/data.user.bc : data/user.d edb.d
	$(DMD) -c $(DFLAGS) data/user.d $(O)data.user.bc

obj/data.cooperativa_user.bc : data/cooperativa_user.d edb.d
	$(DMD) -c $(DFLAGS) data/cooperativa_user.d $(O)data.cooperativa_user.bc

obj/data.blog.bc : data/blog.d edb.d
	$(DMD) -c $(DFLAGS) data/blog.d $(O)data.blog.bc
	
obj/data.project.bc : data/project.d edb.d
	$(DMD) -c $(DFLAGS) data/project.d $(O)data.project.bc

obj/data.pages.bc : data/pages.d edb.d
	$(DMD) -c $(DFLAGS) data/pages.d $(O)data.pages.bc

obj/data.categories.bc : data/categories.d edb.d
	$(DMD) -c $(DFLAGS) data/categories.d $(O)data.categories.bc

obj/data.content.bc : data/content.d edb.d
	$(DMD) -c $(DFLAGS) data/content.d $(O)data.content.bc

obj/data.listing.bc : data/listing.d edb.d
	$(DMD) -c $(DFLAGS) data/listing.d $(O)data.listing.bc




obj/data.all.bc : data/all.d edb.d
	$(DMD) -c $(DFLAGS) data/all.d $(O)data.all.bc

obj/data.tests.bc : data/tests.d
	$(DMD) -c $(DFLAGS) data/tests.d $(O)data.tests.bc

#-------------
# admin
#-------------

obj/data.admin.user.bc : data/admin/user.d edb.d
	$(DMD) -c $(DFLAGS) data/admin/user.d

obj/data.admin.site.bc : data/admin/site.d edb.d
	$(DMD) -c $(DFLAGS) data/admin/site.d

#-------------
# musica
#-------------

obj/data.musica.user.bc : data/musica/user.d edb.d
	$(DMD) -c $(DFLAGS) data/musica/user.d

#-------------
# latema
#-------------

obj/data.latema.user.bc : data/latema/user.d edb.d
	$(DMD) -c $(DFLAGS) data/latema/user.d

#-------------
# ubermicro
#-------------

obj/data.ubermicro.user.bc : data/ubermicro/user.d edb.d
	$(DMD) -c $(DFLAGS) data/ubermicro/user.d $(O)data.ubermicro.user.bc

obj/data.ubermicro.gen.bc : data/ubermicro/gen.d edb.d
	$(DMD) -c $(DFLAGS) data/ubermicro/gen.d $(O)data.ubermicro.gen.bc

obj/data.ubermicro.unit.bc : data/ubermicro/unit.d edb.d
	$(DMD) -c $(DFLAGS) data/ubermicro/unit.d $(O)data.ubermicro.unit.bc

obj/data.ubermicro.model.bc : data/ubermicro/model.d edb.d
	$(DMD) -c $(DFLAGS) data/ubermicro/model.d $(O)data.ubermicro.model.bc

#-------------
# the collective
#-------------

obj/data.thecollective.default_objs.bc : data/thecollective/default_objs.d edb.d
	$(DMD) -c $(DFLAGS) data/thecollective/default_objs.d $(O)data.thecollective.default_objs.bc


#-------------
# movideal
#-------------

obj/data.movideal.default_objs.bc : data/movideal/default_objs.d edb.d
	$(DMD) -c $(DFLAGS) data/movideal/default_objs.d $(O)data.movideal.default_objs.bc


