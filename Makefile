.PHONY: setup build test test-userspace clean run-qemu lettuce lettuce-verify lettuce-check lettuce-run bench bench-long

# =============================================================================
# Salt + KeuOS — Top-Level Makefile
# =============================================================================

setup:
	@bash scripts/bootstrap.sh

build:
	cd salt-front && cargo build --release
	@echo "Compiler built: salt-front/target/release/saltc"

# Salt contract verification + compilation check.
# This runs without QEMU or LLVM21 — it parses, typechecks, and verifies Z3
# contracts across the entire kernel source tree, then compiles the entry
# module to MLIR.
#
# Full kernel smoke tests (QEMU boot) and native binary tests (sp test)
# require the LLVM21-based salt-opt backend and are not available here.
test:
	sp check
	sp build
	@echo "Salt source validation complete."

test-userspace: build
	@echo "=== KeuOS User Program Test Suite ==="
	@python3 tools/runner_qemu.py test
	@echo ""

.PHONY: test-userspace

clean:
	cd salt-front && cargo clean
	rm -f /tmp/salt_hello /tmp/salt_build/*
	@echo "Clean."

run-qemu:
	qemu-system-x86_64 -cdrom keuos.iso -m 512M -serial stdio -no-reboot

# =============================================================================
# LETTUCE — Verified HTTP/Redis Server
# =============================================================================

SALTC := salt-front/target/release/saltc
LETTUCE_SRC := lettuce/src/server.salt
LETTUCE_MLIR := /tmp/lettuce_server.mlir

lettuce: build lettuce-verify
	@echo ""
	@echo "============================================"
	@echo "  LETTUCE — Verified HTTP Server"
	@echo "============================================"
	@echo ""
	@echo "  ✓ Compiler built"
	@echo "  ✓ Z3 contracts verified (resp, aof, store)"
	@echo "  ✓ MLIR emitted: $(LETTUCE_MLIR)"
	@echo ""
	@echo "  Run with: make lettuce-run"
	@echo "  Test with: redis-cli -p 6379 PING"

lettuce-verify: build
	@echo "=== Lettuce: Z3 Contract Verification ==="
	@bash lettuce/tests/test_verified_http.sh
	@echo ""
	@echo "=== Lettuce: Compiling with verification (default-on) ==="
	@$(SALTC) $(LETTUCE_SRC) -o $(LETTUCE_MLIR) 2>&1 | grep -v 'GENERIC WARNING'
	@echo ""

# Compile all Lettuce modules (library and server) and run Z3 verification tests.
# This is a stricter check than lettuce-verify: it compiles every .salt file
# under lettuce/ and runs the full test suite.
lettuce-check: build
	@echo "=== Lettuce: Compiling all modules ==="
	@for f in resp.salt store.salt aof.salt list.salt hash.salt src/server.salt src/server_native.salt; do \
	  printf "    $$f ... "; \
	  if $(SALTC) lettuce/$$f --lib --disable-alias-scopes -o /dev/null 2>/dev/null; then \
	    echo "OK"; \
	  else \
	    echo "FAIL"; \
	    exit 1; \
	  fi; \
	done
	@echo ""
	@echo "=== Lettuce: Running Z3 contract verification tests ==="
	@bash lettuce/tests/test_verified_http.sh

lettuce-run: build
	@echo "=== Building LETTUCE server binary ==="
	@zsh scripts/run_test.sh $(LETTUCE_SRC) --compile-only 2>&1 | grep -v 'GENERIC WARNING\|zoxide\|_ZO_DOCTOR' | tail -15
	@echo ""
	@echo "Binary: /tmp/salt_build/server"
	@echo "Target: KeuOS (QEMU/KVM)"
	@echo "Run in QEMU: make run-qemu"

bench: build
	@bash benchmarks/lettuce_bench.sh 2>&1 | grep -v 'zoxide\|_ZO_DOCTOR\|GENERIC WARNING\|Blocking functions'

bench-long: build
	@bash benchmarks/lettuce_bench.sh --long 2>&1 | grep -v 'zoxide\|_ZO_DOCTOR\|GENERIC WARNING\|Blocking functions'
