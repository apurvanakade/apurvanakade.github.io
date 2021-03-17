#!/bin/sh

./_clean.sh 
./_build.sh

rm -rf ../gh-pages/css/
rm -rf ../gh-pages/images/
rm -rf ../gh-pages/libs/
rm -rf ../gh-pages/js/
rm ../gh-pages/*.html
rm ../gh-pages/search_index.json

cp -r _book/* ../gh-pages/