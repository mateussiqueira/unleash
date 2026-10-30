.PHONY: lint test build clean ci

lint:
	python3 scripts/check-shell.py

test:
	bats tests/*.bats

build:
	./examples/build-standalone.sh

clean:
	rm -f unleash-standalone.sh

ci: lint test
	@echo "=== Markdown ==="
	npx markdownlint-cli '*.md' || true
