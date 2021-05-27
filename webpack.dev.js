const { merge } = require('webpack-merge');
const common = require('./webpack.common.js');

const config = {
  mode: 'development',
  devtool: 'eval-source-map',
};

module.exports = merge(common, config);
