
EXEC_DIR := target/release
SOURCE_DIR := src

UPPER_STEPS := $(EXEC_DIR)/step4_if_fn_do \
               $(EXEC_DIR)/step5_tco \
               $(EXEC_DIR)/step6_file \
               $(EXEC_DIR)/step7_quote \
               $(EXEC_DIR)/step8_macros \
               $(EXEC_DIR)/step9_try \
               $(EXEC_DIR)/stepA_mal
STEP0       := $(EXEC_DIR)/step0_repl
STEP1-2     := $(EXEC_DIR)/step1_read_print \
               $(EXEC_DIR)/step2_eval
STEP3       := $(EXEC_DIR)/step3_env
STEPS := $(STEP0) $(STEP1-2) $(STEP3) $(UPPER_STEPS)

all: $(STEPS)

$(STEPS): $(EXEC_DIR)/%: 
	cargo build --release --bin $*

$(STEPS): $(SOURCE_DIR)/readline.rs
$(STEP1-2) $(STEP3) $(UPPER_STEPS): $(SOURCE_DIR)/types.rs $(SOURCE_DIR)/reader.rs $(SOURCE_DIR)/printer.rs
$(STEP3) $(UPPER_STEPS): $(SOURCE_DIR)/env.rs
$(UPPER_STEPS): $(SOURCE_DIR)/core.rs

lint:
	rustfmt *.rs
	cargo clippy

.PHONY: clean lint all

clean:
	rm -fr target/
	rm -f .mal-history *~ Cargo.lock
