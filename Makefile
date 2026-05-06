.ONESHELL:

test:
	cd tests
	bash test.sh
	cd -

clean:
	git clean -fdX

install: cmd-sync.sh
	mkdir -p ~/bin
	cp cmd-sync.sh ~/bin/cmd-sync
	chmod +x ~/bin/cmd-sync

uninstall:
	rm ~/bin/cmd-sync
