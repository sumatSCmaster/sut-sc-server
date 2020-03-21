const gulp = require('gulp');
const ts = require('gulp-typescript');
const tsProject = ts.createProject('./tsconfig.json');
const sourcemaps = require('gulp-sourcemaps');

const destBuildFolder = 'build';

function defaultTask(cb) {
    let result = tsProject.src()
    .pipe(tsProject())
    result.pipe(gulp.dest(`${destBuildFolder}`));
    gulp.src('./src/views/planillas/*.pug').pipe(gulp.dest(`./${destBuildFolder}/views/planillas`));
    gulp.src('./src/views/planillas/css/*.css').pipe(gulp.dest(`./${destBuildFolder}/views/planillas/css`));
    gulp.src('./src/views/planillas/images/*.png').pipe(gulp.dest(`./${destBuildFolder}/views/planillas/images`));
    return gulp.src('./src/views/*.{pug,css}').pipe(gulp.dest(`./${destBuildFolder}/views`));
}

exports.default = defaultTask;
