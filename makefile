all: clean build deploy

clean:
	mdbook clean

build:
	mdbook build

deploy:
	rm ../gh-pages/*.html
	rm -rf ../gh-pages/css/
	rm -rf ../gh-pages/images/
	rm -rf ../gh-pages/FontAwesome/
	cp -r book/* ../gh-pages/
