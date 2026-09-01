IDRIC ?= idris2
IDRIC_SOURCES := $(wildcard Network/*.idric Mirage/*.idric tests/*.idric)

.PHONY: all test sms-request check-vocabulary clean

all: check-vocabulary
	$(IDRIC) --build idric-net.ipkg

check-vocabulary:
	@if grep -nE '(^|[^[:alnum:]_])Nat([^[:alnum:]_]|$$)' $(IDRIC_SOURCES) README.md CONSTRAINTS.md; then \
		echo 'error: active Idriç source must use ℕ for natural numbers' >&2; \
		exit 1; \
	fi
	@if grep -nE '(^|[^[:alnum:]_])(Int|Integer)([^[:alnum:]_]|$$)' $(IDRIC_SOURCES); then \
		echo 'error: active Idriç source must not expose raw signed integer types; use ℕ, semantic types, or explicit-width ABI storage' >&2; \
		exit 1; \
	fi

test: all
	$(IDRIC) tests/NetworkTests.idric -o idric-net-tests
	./build/exec/idric-net-tests
	$(IDRIC) tests/SMSTests.idric -o idric-net-sms-tests
	./build/exec/idric-net-sms-tests

sms-request: all
	$(IDRIC) tools/SmsRequest.idric -o idric-sms-request

clean:
	rm -rf build
