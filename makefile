DOCS_DIR = docs/

# Local preview only. Publishing happens in CI: a push to main triggers
# .github/workflows/publish.yml, which renders and deploys docs/ to GitHub
# Pages. docs/ is gitignored and is never committed from here. See CLAUDE.md.

# HTML only, the same render CI does. The PDFs are `make cv` and
# `make portfolio`.
build:
	quarto render --to html --output-dir $(DOCS_DIR)

# Rebuild the CV's PDF with the local LaTeX install and copy it to CV.pdf at
# the repo root, which is committed and published as a resource. Run it after
# editing CV.qmd or cv/*.qmd, then commit CV.pdf.
cv:
	quarto render CV.qmd --to pdf --output-dir $(DOCS_DIR)
	cp $(DOCS_DIR)CV.pdf CV.pdf

# The same for the teaching portfolio: run it after editing
# teaching-portfolio.qmd, then commit teaching-portfolio.pdf.
portfolio:
	quarto render teaching-portfolio.qmd --to pdf --output-dir $(DOCS_DIR)
	cp $(DOCS_DIR)teaching-portfolio.pdf teaching-portfolio.pdf

# The recommendation-letters checklist PDF, cut from rec-letters.qmd: run it
# after editing that page's checklist sections, then commit the PDF.
checklist:
	python3 _scripts/build_rec_checklist.py

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

.PHONY: build cv portfolio checklist clean preview covers update-mathviz release
