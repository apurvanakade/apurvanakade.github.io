const gulp = require('gulp'),
      fileinclude = require('gulp-file-include'),
      watch = require('gulp-watch'),
      sass  = require("gulp-sass"),
      markdown  = require("gulp-markdown");


gulp.task("markdown",function(){
  return gulp.src("content/*.md")
      .pipe(markdown())
      .pipe(gulp.dest("html"));
});

gulp.task("sass", function(){
  return gulp.src("styles/style.scss")
      .pipe(sass())
      .pipe(gulp.dest("../"));
});

gulp.task('markdown', function () {
  return gulp.src('markdown/*.md')
      .pipe(markdown())
      .pipe(gulp.dest('html/'));
});

gulp.task("htmlIndex", function(){
  return gulp.src("html/index.html")
      .pipe(fileinclude({
        prefix: '@@',
        basepath: '@file'
      }))
      .pipe(gulp.dest('../'));
});

// Watch asset folder for changes
gulp.task("default", function() {
  gulp.watch("content/*.md", gulp.registry().get("markdown"));
  gulp.watch("styles/*.scss", gulp.registry().get("sass"));
  gulp.watch("markdown/*.md", gulp.registry().get("markdown"));
  gulp.watch("html/**", gulp.registry().get("htmlIndex"));
});
