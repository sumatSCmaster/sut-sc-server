const gulp = require('gulp');
const ts = require('gulp-typescript');
const tsProject = ts.createProject('./tsconfig.json');
const sourcemaps = require('gulp-sourcemaps');

const destBuildFolder = 'build';

function defaultTask(cb) {
    let result = tsProject.src()
    .pipe(sourcemaps.init())
    .pipe(tsProject())
    .pipe(sourcemaps.write());
    result.pipe(gulp.dest(`${destBuildFolder}`));
    return gulp.src('./src/views/*.{pug,css}').pipe(gulp.dest(`./${destBuildFolder}/views`));
}

exports.default = defaultTask;
