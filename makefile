all: html

html:
	Rscript -e "bookdown::render_book('index.Rmd', 'bookdown::gitbook')"

clean:
	rm -rf docs/*
	rm -rf _bookdown_files/*