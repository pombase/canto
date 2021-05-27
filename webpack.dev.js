const { merge } = require('webpack-merge');
const common = require('./webpack.config.js');

const config = {
  mode: 'development',
  devtool: 'eval-source-map',
};

module.exports = merge(common, config);
