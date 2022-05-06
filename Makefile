default: help
.PHONY: factorbase_* worktodo.txt

.PHONY: run verify

help:
	@echo "Popular Make Targets:"
	@echo "   image - build docker image"
	@echo "   run   - run shell in built image"

prodimage:
	docker build --pull --no-cache --compress --squash --tag primemath .

.git/image: Dockerfile driver.pl
	docker build --tag primemath . && touch .git/image

image: .git/image

run: .git/image
	docker run --gpus all --rm -it --init -v $(shell pwd):/var/primemath primemath nice /var/primemath/driver.pl --curves=6 --constant --shuffle --color

factorbase_*:
	docker run --gpus all --rm --name $@ -d --init -v $(shell pwd):/var/primemath primemath /var/primemath/driver.pl --check --color --curves=0 --thorough --factorbase /var/primemath/$@
	docker logs -f $@

bases: factorbase_*

splits:
	split -n r/64 -d factorbase.txt factorbase_

fastverify: splits bases
	cat factorbase_* | sort -n > factorbase.txt.new
	rm -f factorbase_*

verify: .git/image
	docker run --gpus all --rm --name primemath -it --init -v $(shell pwd):/var/primemath primemath /var/primemath/driver.pl --check --color --curves=0 --thorough
