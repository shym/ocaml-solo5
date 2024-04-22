include Makeconf

# The `all` target is moved to the end to use variables in its dependencies
.PHONY: default
default: all

TOP=$(abspath .)

# Most parts (OCaml, nolibc, openlibm) currently build their result in-tree but
# we reuse dune's `_build` dir, as familiar and already usable for `example`,
# etc., for some generated files
_build:
	mkdir -p $@

LIBS := openlibm/libopenlibm.a nolibc/libnolibc.a

# CFLAGS used to build the nolibc and openlibm libraries
LIB_CFLAGS=-I$(TOP)/nolibc/include -include _solo5/overrides.h

# NOLIBC
NOLIBC_CFLAGS=$(LIB_CFLAGS) -I$(TOP)/openlibm/src -I$(TOP)/openlibm/include
nolibc/libnolibc.a:
	$(MAKE) -C nolibc libnolibc.a \
	    "CC=$(MAKECONF_TOOLCHAIN)-cc" \
	    "FREESTANDING_CFLAGS=$(NOLIBC_CFLAGS)"

# OPENLIBM
openlibm/libopenlibm.a:
	$(MAKE) -C openlibm libopenlibm.a \
	     "CC=$(MAKECONF_TOOLCHAIN)-cc" \
	     "CPPFLAGS=$(LIB_CFLAGS)"

# TOOLCHAIN
# We create prefix-gcc even when the actual compiler will be Clang because
# autoconf toolchain detection will pick the first compiler that exists in the
# list: prefix-gcc, gcc, prefix-cc, cc...
# Anyway, configure scripts always explicitly test whether the compiler defines
# Clang-specific macros when they want to distinguish GCC and Clang
ALLTOOLS := gcc cc ar as ld nm objcopy objdump ranlib readelf strip
ALLTOOLS := $(foreach tool,$(ALLTOOLS), \
                $(MAKECONF_TARGET_ARCH)-solo5-ocaml-$(tool))

TOOLDIR_FOR_BUILD := _build/build-toolchain
TOOLCHAIN_FOR_BUILD := $(addprefix $(TOOLDIR_FOR_BUILD)/,$(ALLTOOLS))
TOOLDIR_FINAL := _build/toolchain
TOOLCHAIN_FINAL := $(addprefix $(TOOLDIR_FINAL)/,$(ALLTOOLS))

# Options for the build version of the tools
TOOLCHAIN_BUILD_CFLAGS := -I$(TOP)/nolibc/include \
  -I$(TOP)/openlibm/include -I$(TOP)/openlibm/src
TOOLCHAIN_BUILD_LDFLAGS := -L$(TOP)/nolibc -L$(TOP)/openlibm

# Options for the installed version of the tools
TOOLCHAIN_FINAL_CFLAGS := -I$(MAKECONF_SYSROOT)/include
TOOLCHAIN_FINAL_LDFLAGS := -L$(MAKECONF_SYSROOT)/lib

$(TOOLDIR_FOR_BUILD) $(TOOLDIR_FINAL):
	mkdir -p $@

$(TOOLDIR_FOR_BUILD)/$(MAKECONF_TARGET_ARCH)-solo5-ocaml-%: \
    gen_toolchain_tool.sh | $(TOOLDIR_FOR_BUILD)
	ARCH="$(MAKECONF_TARGET_ARCH)" \
	  SOLO5_TOOLCHAIN="$(MAKECONF_TOOLCHAIN)" \
	  OTHERTOOLPREFIX="$(MAKECONF_TOOLPREFIX)" \
	  TOOL_CFLAGS="$(TOOLCHAIN_BUILD_CFLAGS)" \
	  TOOL_LDFLAGS="$(TOOLCHAIN_BUILD_LDFLAGS)" \
	  sh $< $* > $@
	chmod +x $@

$(TOOLDIR_FINAL)/$(MAKECONF_TARGET_ARCH)-solo5-ocaml-%: \
    gen_toolchain_tool.sh | $(TOOLDIR_FINAL)
	ARCH="$(MAKECONF_TARGET_ARCH)" \
	  SOLO5_TOOLCHAIN="$(MAKECONF_TOOLCHAIN)" \
	  OTHERTOOLPREFIX="$(MAKECONF_TOOLPREFIX)" \
	  TOOL_CFLAGS="$(TOOLCHAIN_FINAL_CFLAGS)" \
	  TOOL_LDFLAGS="$(TOOLCHAIN_FINAL_LDFLAGS)" \
	  sh $< $* > $@
	chmod +x $@

.PHONY: toolchains
toolchains: $(TOOLCHAIN_FOR_BUILD) $(TOOLCHAIN_FINAL)

# OCAML
# Extract sources from ocaml-src.tar.gz (if available, supporting the
# differences of options between various tar implementations to strip the first
# directory in the archive) or from the ocaml-src OPAM package and apply patches
# if there any in `patches/<OCaml version>/`
ocaml:
	mkdir -p $@
	if test -f ocaml-src.tar.gz; then \
	  if tar --version >/dev/null 2>&1; then \
	      tar -x -f ocaml-src.tar.gz -z -C $@ --strip-components=1; \
	    else tar -x -f ocaml-src.tar.gz -z -C $@ -s '/^[^\/]*\///'; \
	  fi ; \
	elif opam var ocaml-src:lib; then cp -R `opam var ocaml-src:lib` $@; \
	else echo Cannot find OCaml sources; false; \
	fi
	if test -d "patches/`head -n1 ocaml/VERSION`" ; then \
	  git apply --directory=$@ "patches/`head -n1 ocaml/VERSION`"/*; \
	fi

ocaml/Makefile.config: $(LIBS) $(TOOLCHAIN_FOR_BUILD) | ocaml
	cd ocaml && \
	  PATH="$(abspath $(TOOLDIR_FOR_BUILD)):$$PATH" \
	  ./configure \
		--target=$(MAKECONF_TARGET_ARCH)-solo5-ocaml \
		--prefix=$(MAKECONF_SYSROOT) \
		--disable-shared \
		--disable-systhreads \
		--disable-unix-lib \
		--disable-instrumented-runtime \
		--disable-debug-runtime \
		--disable-ocamltest \
		--disable-ocamldoc \
		--without-zstd \
		$(MAKECONF_OCAML_CONFIGURE_OPTIONS)

OCAML_IS_BUILT := _build/ocaml_is_built
$(OCAML_IS_BUILT): ocaml/Makefile.config | _build
	PATH="$(abspath $(TOOLDIR_FOR_BUILD)):$$PATH" $(MAKE) -C ocaml cross.opt
	cd ocaml && ocamlrun tools/stripdebug ocamlc ocamlc.tmp
	cd ocaml && ocamlrun tools/stripdebug ocamlopt ocamlopt.tmp
	touch $@

# TODO: Decide whether these files should be provided in the repository (if so,
# we should make sure they cover all the use cases and move the files to the
# root) or rebuilt every time
DOT_INSTALL_PREFIX_FOR_OCAML := _build/ocaml.install
DOT_INSTALL_CHUNKS_FOR_OCAML := $(addprefix $(DOT_INSTALL_PREFIX_FOR_OCAML),\
    .lib .libexec)
$(DOT_INSTALL_CHUNKS_FOR_OCAML): | ocaml/Makefile.config
	MAKE="$(MAKE)" ./gen_ocaml_install.sh \
	  $(DOT_INSTALL_PREFIX_FOR_OCAML) ocaml $(MAKECONF_SYSROOT)

# CONFIGURATION FILES
_build/solo5.conf: gen_solo5_conf.sh $(OCAML_IS_BUILT)
	SYSROOT="$(MAKECONF_SYSROOT)" ./gen_solo5_conf.sh > $@

_build/empty-META: | _build
	touch $@

# INSTALL
PACKAGES := $(basename $(wildcard *.opam))
INSTALL_FILES := $(foreach pkg,$(PACKAGES),$(pkg).install)

$(INSTALL_FILES): $(TOOLCHAIN_FINAL) $(DOT_INSTALL_CHUNKS_FOR_OCAML)
	./gen_dot_install.sh $(DOT_INSTALL_PREFIX_FOR_OCAML) $(TOOLCHAIN_FINAL)\
	     > $@

# COMMANDS
.PHONY: install
install: all
	MAKE=$(MAKE) PREFIX=$(MAKECONF_PREFIX) ./install.sh

.PHONY: uninstall
uninstall:
	./uninstall.sh

.PHONY: clean
clean:
	$(RM) -rf _build
	$(MAKE) -C openlibm clean
	$(MAKE) -C nolibc clean FREESTANDING_CFLAGS=_
	if [ -d ocaml ] ; then $(MAKE) -C ocaml clean ; fi
	$(RM) -f $(INSTALL_FILES)

.PHONY: distclean
distclean: clean
	$(RM) -f Makeconf
# Don't remove the ocaml directory itself, to play nicer with
# development in there
	if [ -d ocaml ] ; then $(MAKE) -C ocaml distclean ; fi

.PHONY: all
all: $(LIBS) $(OCAML_IS_BUILT) \
     _build/solo5.conf _build/empty-META \
     $(TOOLCHAIN_FINAL)

.PHONY: test
test:
	$(MAKE) -C nolibc test-headers \
	    "CC=$(MAKECONF_TOOLCHAIN)-cc" \
	    "FREESTANDING_CFLAGS=$(NOLIBC_CFLAGS)"
