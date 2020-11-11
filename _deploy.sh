#!/bin/sh

./_clean.sh 
./_build.sh

rm -rf ../gh-pages/teaching-portfolio/css/
rm -rf ../gh-pages/teaching-portfolio/images/
rm -rf ../gh-pages/teaching-portfolio/libs/
rm -rf ../gh-pages/teaching-portfolio/js/
rm ../gh-pages/teaching-portfolio/*.html
rm ../gh-pages/teaching-portfolio/search_index.json

cp -r _book/* ../gh-pages/teaching-portfolio/