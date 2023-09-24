DOCS_DIR = _site/
MAKE = quarto render

all: clean build

clean: 
	rm -rf $(DOCS_DIR)

build: 
	$(MAKE) --output-dir $(DOCS_DIR)