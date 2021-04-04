serve: build
	mdbook serve

build: clean
	mdbook build #build project
	cp -r "theme/fonts" "book" #copy fonts to output directory

clean:
	mdbook clean
