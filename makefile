DOCS_DIR = docs/

# Local preview only. Publishing happens in CI: a push to main triggers
# .github/workflows/publish.yml, which renders and deploys docs/ to GitHub
# Pages. docs/ is gitignored and is never committed from here. See CLAUDE.md.

PDF_DIR = _pdf/

# HTML only, the same render CI does. The PDFs are `make pdfs`.
build:
	quarto render --to html --output-dir $(DOCS_DIR)

# PDFs of the CV and teaching portfolio, for local use
# only: built with the local LaTeX into the gitignored _pdf/ folder, never
# committed or published. _pdf/ is outside Quarto's reach (a leading
# underscore), so a full render does not delete them.
pdfs: cv portfolio

cv:
	quarto render CV.qmd --to pdf --output-dir $(DOCS_DIR)
	mkdir -p $(PDF_DIR) && cp $(DOCS_DIR)CV.pdf $(PDF_DIR)CV.pdf

portfolio:
	quarto render teaching-portfolio.qmd --to pdf --output-dir $(DOCS_DIR)
	mkdir -p $(PDF_DIR) && cp $(DOCS_DIR)teaching-portfolio.pdf $(PDF_DIR)teaching-portfolio.pdf

clean:
	rm -rf $(DOCS_DIR) .quarto

preview:
	quarto preview

# Force a check for a newer mathviz release (the pre-render hook otherwise
# checks on every full render, and at most hourly under preview).
update-mathviz:
	QUARTO_PROJECT_RENDER_ALL=1 _scripts/update-mathviz.sh

# Publish: fast-forward main to origin/develop and push it, which triggers
# the deploy. The remote refuses anything but a fast-forward, and no checkout
# is needed, so this folder stays on develop. See CLAUDE.md §2.
release:
	git fetch origin
	git push origin origin/develop:main

# Regenerate the SVG covers (rarely needed): project and course covers, and
# the blog's formula covers, which need the local LaTeX.
covers:
	python3 _scripts/make_covers.py
	python3 _scripts/make_equation_covers.py

.PHONY: build pdfs cv portfolio clean preview covers update-mathviz release
