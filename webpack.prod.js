const { merge } = require('webpack-merge');
const common = require('./webpack.config.js');

const config = {
  mode: 'production',
  devtool: 'source-map',
};

module.exports = merge(common, config);
