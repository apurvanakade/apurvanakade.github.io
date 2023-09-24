DOCS_DIR = docs/
MAKE = quarto render

all: clean build deploy

clean: 
	rm -rf $(DOCS_DIR)

build: 
	$(MAKE) --output-dir $(DOCS_DIR)

deploy:
	git add -A 
	git commit -m "update on `date +'%Y-%m-%d %H:%M:%S'`"
	git push 