DOCS_DIR = docs/

# Local preview only. Publishing happens in CI: a push to 2026-quarto triggers
# .github/workflows/publish.yml, which renders and deploys docs/ to GitHub
# Pages. docs/ is gitignored and is never committed from here. See CLAUDE.md.

build:
	quarto render --output-dir $(DOCS_DIR)

clean:
	rm -rf $(DOCS_DIR) .quarto

preview:
	quarto preview

# Regenerate the typographic SVG project covers (rarely needed).
covers:
	python3 _scripts/make_covers.py

.PHONY: build clean preview covers
