const fs = require('fs-extra');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const path = require('path');
const webpack = require('webpack');
const yaml = require('js-yaml');

function getAppVersion() {
  const cantoYaml = yaml.load(fs.readFileSync('./canto.yaml', 'utf8'));
  return cantoYaml.app_version;
}

module.exports = {
  entry: './root/static/js/index.js',
  output: {
    filename: 'main.js',
    path: path.resolve(__dirname, 'root/dist'),
    publicPath: '/dist/' + getAppVersion() + '/',
  },
  mode: 'development',
  resolve: {
    alias: {
      'tag-it': path.resolve(__dirname, 'root/static/js/tag-it.js')
    }
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [
          {
            loader: MiniCssExtractPlugin.loader,
          },
          {
            loader: 'css-loader',
          }
        ]
      },
      {
        test: /\.woff($|\?)|\.woff2($|\?)|\.ttf($|\?)|\.eot($|\?)|\.svg($|\?)/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: 'fonts/'
            }
          }
        ]
      },
      {
        test: /\.(gif|png)$/,
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: 'images/'
            }
          }
        ]
      },
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery',
      'window.jQuery': 'jquery'
    }),
    new MiniCssExtractPlugin({
      filename: '[name].css',
      chunkFilename: '[id].css',
      ignoreOrder: false,
    }),
  ],
  devtool: "source-map"
};
