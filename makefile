all: clean build

clean:
	rm -rf ../gh-pages/blog

build:
	hugo
