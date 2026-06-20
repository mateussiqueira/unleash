.PHONY: lint test build clean ci

lint:
	shellcheck unleash lib/*.sh 2>/dev/null || brew install shellcheck && shellcheck unleash lib/*.sh
	bash -n unleash lib/*.sh

test:
	bats tests/*.bats

build:
	./examples/build-standalone.sh

clean:
	rm -f unleash-standalone.sh

ci:
	@echo "=== ShellCheck ===" && \
	  for f in unleash lib/*.sh examples/*.sh; do \
	    [ -f "$$f" ] || continue; \
	    echo "  $$f"; shellcheck -S warning "$$f" || fail=1; \
	  done && \
	  echo "=== Bash Syntax ===" && \
	  for f in unleash lib/*.sh examples/*.sh; do \
	    [ -f "$$f" ] || continue; \
	    bash -n "$$f" || fail=1; \
	  done && \
	  echo "=== Markdown ===" && \
	  npx markdownlint-cli '*.md' || true && \
	  echo "=== All checks done ===" && \
	  [ -z "$$fail" ] || exit 1
