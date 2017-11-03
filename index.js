try {
  // Compiled JavaScript first
  module.exports = require('./lib/');
} catch (e) {
  require('coffeescript/register');
  module.exports = require('./src/');
}
