all: html

html:
	Rscript -e "bookdown::render_book('index.Rmd', 'bookdown::gitbook')"

clean:
	rm -rf docs/*
	rm -rf _bookdown_files/*

serve: 
	Rscript -e "bookdown::serve_book(dir = '.', output_dir = 'docs', preview = TRUE, in_session = TRUE, quiet = FALSE)"

stop: 
	Rscript -e "bookdown::servr::daemon_stop(1)"
