try {
  // Compiled JavaScript first
  module.exports = require('./lib/');
} catch (e) {
  require('coffee-script/register');
  module.exports = require('./src/');
}
