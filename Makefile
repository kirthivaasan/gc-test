ifeq (3.81,$(MAKE_VERSION))
  $(error You seem to be using the OSX antiquated Make version. Hint: brew \
    install make, then invoke gmake instead of make)
endif

all: dist/libgarbledcirc.a

test: tests/c-tests.test obj/specs-test.test

%.test: %.exe
	$<

include Makefile.include

FSTAR_HINTS ?= --use_hints --use_hint_hashes --record_hints
FSTAR_EXTRACT = --extract '-* +Spec'

FSTAR_NO_FLAGS = $(FSTAR_HOME)/bin/fstar.exe $(FSTAR_HINTS) \
  --odir obj --cache_checked_modules $(FSTAR_INCLUDES) --cmi \
  --already_cached '+Hacl +Spec +Lib +EverCrypt Prims FStar LowStar C Spec.Loops TestLib WasmSupport' --warn_error '+241@247+285' \
  --cache_dir obj --hint_dir hints \
  --z3rlimit 1000

FSTAR_ROOTS = $(wildcard $(addsuffix /*.fsti,$(SOURCE_DIRS))) \
  $(wildcard $(addsuffix /*.fst,$(SOURCE_DIRS))) \

ifndef MAKE_RESTARTS
.depend: .FORCE
	$(FSTAR_NO_FLAGS) --dep full $(notdir $(FSTAR_ROOTS)) $(FSTAR_EXTRACT) > $@

.PHONY: .FORCE
.FORCE:
endif

include .depend

# Verification
FSTAR = $(FSTAR_NO_FLAGS) $(OTHERFLAGS)

hints:
	mkdir $@

obj:
	mkdir $@

%.checked: FSTAR_FLAGS=

%.checked: | hints obj
	$(FSTAR) $< $(FSTAR_FLAGS) && touch -c $@

# Extraction
.PRECIOUS: obj/%.ml
obj/%.ml:
	$(FSTAR) $(notdir $(subst .checked,,$<)) --codegen OCaml \
	--extract_module $(basename $(notdir $(subst .checked,,$<)))

.PRECIOUS: obj/%.krml
obj/%.krml:
	$(FSTAR) $(notdir $(subst .checked,,$<)) --codegen Kremlin \
	--extract_module $(basename $(notdir $(subst .checked,,$<)))

obj/Specs_Driver.ml: specs/ml/Specs_Driver.ml
	cp $< $@

# F* --> C
KRML=$(KREMLIN_HOME)/krml
HAND_WRITTEN_C_FILES = code/c/garbled_circuits_driver.c


dist/Makefile.basic: $(filter-out %prims.krml,$(ALL_KRML_FILES)) $(HAND_WRITTEN_C_FILES)
	mkdir -p $(dir $@)
	cp $(HAND_WRITTEN_C_FILES) $(dir $@)
	$(KRML) -tmpdir $(dir $@) -skip-compilation \
	  $(filter %.krml,$^) \
	  -warn-error @4@5@18 \
	  -fparentheses \
	  -bundle Impl.GarbledCircuit.Intrinsics= \
	  -bundle 'LowStar.*,Prims' \
	  -bundle Impl.GarbledCircuit=Impl.GarbledCircuit.*,Spec.*[rename=GarbledCircuit] \
	  -minimal \
	  -bundle 'FStar.*' \
	  -add-include '<stdint.h>' \
	  -add-include '<stdio.h>' \
	  -add-include '"kremlin/internal/target.h"' \
	  $(notdir $(HAND_WRITTEN_C_FILES)) \
	  -o libgarbledcirc.a

# Compiling generated C code
dist/libgarbledcirc.a: dist/Makefile.basic
	$(MAKE) -C $(dir $@) -f $(notdir $<)

# Ocaml compilation
ifeq ($(OS),Windows_NT)
  export OCAMLPATH := $(FSTAR_HOME)/bin;$(OCAMLPATH)
else
  export OCAMLPATH := $(FSTAR_HOME)/bin:$(OCAMLPATH)
endif

TAC = $(shell which tac >/dev/null 2>&1 && echo "tac" || echo "tail -r")

ALL_CMX_FILES = $(patsubst %.ml,%.cmx,$(shell echo $(ALL_ML_FILES) | $(TAC)))

obj/Specs_Driver.cmx: $(ALL_CMX_FILES)

OCAMLOPT = ocamlfind opt -package fstarlib -linkpkg -g -I $(GC_HOME)/obj -w -8-20-26

.PRECIOUS: obj/%.cmx
obj/%.cmx: obj/%.ml
	$(OCAMLOPT) -c $< -o $@

obj/specs-test.exe: $(ALL_CMX_FILES) obj/Specs_Driver.cmx
	$(OCAMLOPT) $^ -o $@


# compiling hand written tests
CFLAGS += -I dist -I $(KREMLIN_HOME)/include

tests/c-tests.exe: dist/libgarbledcirc.a tests/c-tests.o
	$(CC) $^ -o $@
