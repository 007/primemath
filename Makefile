default: help
.PHONY: factorbase_* worktodo.txt

help:
	@echo "Popular Make Targets:"
	@echo "   image - build docker image"
	@echo "   run   - run shell in built image"

prodimage:
	docker build --pull --no-cache --compress --squash --tag primemath .

image:
	docker build --tag primemath .

worktodo.txt:
	cat ./worktodo/*.txt | sort -n | uniq > ./worktodo.txt

run: image worktodo.txt
	docker run --rm --name primemath -it --init -v $(shell pwd):/var/primemath primemath:latest || true

factorbase_*:
	docker run --rm --name $@ -d --init -v $(shell pwd):/var/primemath primemath /var/primemath/driver.pl --check --color --curves=0 --thorough --factorbase /var/primemath/$@
	docker logs -f $@

bases: factorbase_*

splits:
	split -n r/64 -d factorbase.txt factorbase_

fastverify: splits bases
	cat factorbase_* | sort -n > factorbase.txt.new
	rm -f factorbase_*

verify: image
	docker run --rm --name primemath -it --init -v $(shell pwd):/var/primemath primemath /var/primemath/driver.pl --check --color --curves=0 --thorough
