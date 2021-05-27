const { merge } = require('webpack-merge');
const common = require('./webpack.config.js');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const TerserPlugin = require('terser-webpack-plugin');

const config = {
  mode: 'production',
  devtool: 'source-map',
  optimization: {
    minimizer: [
      new CssMinimizerPlugin(),
      new TerserPlugin({
        sourceMap: true,
        terserOptions: {
          mangle: false,
        },
      }),
    ],
  },
};

module.exports = merge(common, config);
