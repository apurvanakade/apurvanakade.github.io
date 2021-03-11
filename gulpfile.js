var gulp = require('gulp'),
    markdown = require('gulp-markdown'),
    sass         = require("gulp-sass"),
    del          = require("del"),
    fileinclude  = require("gulp-file-include") 

exports.markdown = () => (
  gulp.src('src/content/*.md')
    .pipe(markdown())
    .pipe(gulp.dest('dist'))
);

// Compile SCSS files to CSS
gulp.task("sass", function(){
  del(["static/css/**/*"])
  return gulp.src("src/scss/**/*.scss")
    .pipe(sass())
    .pipe(gulp.dest("dist/css"))
});

gulp.task("htmlIndex", function(){
  return gulp.src("src/html/index.html")
      .pipe(fileinclude({
        prefix: '@@',
        basepath: '@root'
      }))
      .pipe(gulp.dest('dist'));
});

// Watch asset folder for changes
gulp.task("default", function() {
  // gulp.watch("src/scss/**", gulp.registry().get("sass"));
  // gulp.watch("src/js/**", gulp.registry().get("js"));
  // gulp.watch("src/**", gulp.registry().get("markdown"));
  // gulp.watch("src/**", gulp.registry().get("htmlIndex"));
  gulp.watch("src/**", gulp.series(["sass", "markdown", "htmlIndex"]));
});
