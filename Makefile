.PHONY: lint test build clean

lint:
	shellcheck unleash lib/*.sh
	bash -n unleash lib/*.sh

test:
	bats tests/*.bats

build:
	./examples/build-standalone.sh

clean:
	rm -f unleash-standalone.sh
