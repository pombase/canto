const path = require('path');

module.exports = {
  entry: './root/static/js/canto-modules.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'root/dist'),
  },
  mode: 'development',
  resolve: {
    alias: {
      'tag-it': path.resolve(__dirname, 'node_modules/tag-it/js/tag-it.js')
    }
  },
};
