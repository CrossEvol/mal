STEPS = step0_repl step1_read_print step2_eval step3_env \
        step4_if_fn_do step5_tco step6_file step7_quote \
        step8_macros step9_try stepA_mal

LAST_STEP = stepA_mal

.PHONY: all mal clean format $(STEPS)

all: $(STEPS)

# Build every step binary via dune
$(STEPS):
	dune build bin/$@.exe 2>/dev/null || dune build bin/$@.bc

# Convenience: build only the final step and copy it as "mal"
mal:
	dune build bin/$(LAST_STEP).exe 2>/dev/null || dune build bin/$(LAST_STEP).bc
	cp $$(dune exec --root . -- sh -c 'which $(LAST_STEP)' 2>/dev/null || \
	     echo _build/default/bin/$(LAST_STEP).exe) mal 2>/dev/null || \
	cp _build/default/bin/$(LAST_STEP).bc mal

clean:
	dune clean
	rm -f mal

format:
	ocamlformat --inplace --enable-outside-detected-project \
	    bin/*.ml lib/*.ml
