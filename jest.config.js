// /* eslint-disable */
const { pathsToModuleNameMapper } = require('ts-jest/utils');

const paths = {
  "@helpers/*": ["src/helpers/*"],
  "@utils/*": ["src/utils/*"],
  "@validations/*": ["src/validations/*"],
  "@middlewares/*": ["src/middlewares/*"],
  "@config/*": ["src/config/*"],
  "@root/*": ["src/*"]
};

module.exports = {
  preset: 'ts-jest',
  rootDir: '.',
  testEnvironment: 'node',
  moduleNameMapper: pathsToModuleNameMapper(paths, {
    prefix: '<rootDir>/',
  }),
  testPathIgnorePatterns: ["<rootDir>/build/*"]
};