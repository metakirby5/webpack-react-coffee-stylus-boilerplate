path = require 'path'
webpack = require 'webpack'
merge = require 'webpack-merge'
HtmlWebpackPlugin = require 'html-webpack-plugin'
PreloadWebpackPlugin = require 'preload-webpack-plugin'
UglifyJsPlugin = require 'uglifyjs-webpack-plugin'
{BundleAnalyzerPlugin} = require 'webpack-bundle-analyzer'

projectConfig = require './config'

# Constants
{
  # Environment
  env: ENV
  api: API
  ports:
    app: PORT

  # Input and output folders
  app: SRC_PATH
  schema: SCHEMA_PATH
  query: QUERY_PATH
  test: TEST_PATH
  dist: BUILD_PATH
} = projectConfig

# Module folders
VENDORS = ['node_modules', 'node_modules/@bower_components']
VENDOR_RE = new RegExp VENDORS.join '|'

# File names
INDEX = 'index'
MAIN = 'main'
TEST = 'app'
VENDOR = 'vendor'

# Check if module is vendor, for chunking
isVendor = (module) ->
  r = module.userRequest
  typeof r is 'string' and r.match VENDOR_RE

# Loader configurations

stylusLoader =
  loader: 'stylus-loader'
  options:
    use: [(require 'nib')()]
    import: ['~nib/lib/nib/index.styl']
    preferPathResolver: 'webpack'

coffeelintPlugin = new webpack.LoaderOptionsPlugin
  test: /\.coffee$/
  options:
    coffeelint:
      configFile: 'coffeelint.json'

stylintPlugin = new webpack.LoaderOptionsPlugin
  test: /\.styl$/
  options:
    stylint:
      config: 'stylint.json'

# The main config
config =
  # What file to start at
  entry: [path.join SRC_PATH, "#{MAIN}.coffee"]

  # Where to output
  output:
    path: BUILD_PATH
    publicPath: '/'
    filename: '[name].js'

  # Where to load modules from
  resolve:
    modules: VENDORS.concat SRC_PATH
    extensions: [
      '.coffee', '.gql',
      '.l.styl', '.styl', '.js', '.css'
    ]
    alias:
      schema: SCHEMA_PATH
      query: QUERY_PATH

  # Module loading options
  module:
    rules: [
    # Linters, etc.
      # Coffeelint
      enforce: 'pre'
      test: /\.coffee$/
      loaders: ['coffee-lint-loader']
      exclude: VENDOR_RE
    ,
      # Stylint
      enforce: 'pre'
      test: /\.styl$/
      loaders: ['stylint-loader']
      exclude: VENDOR_RE
    ,
    # Files to load
      # Pug
      test: /\.pug$/
      loaders: ['html-loader', 'pug-html-loader']
    ,
      # Coffeescript
      test: /\.coffee$/
      loaders: [
        loader: 'babel-loader'
        options:
          plugins: ['syntax-dynamic-import', 'lodash']
      ,
        'coffee-loader'
      ]
    ,
      # GraphQL
      test: /\.gql$/
      loaders: ['graphql-tag/loader']
    ,
      # Stylus (locally scoped)
      test: /\.l\.styl$/
      loaders: [
        'style-loader'
      ,
        loader: 'css-loader'
        options:
          modules: true
          localIdentName: '[hash:5]'
      ,
        stylusLoader
      ]
    ,
      # Stylus (globally scoped)
      test: /\.styl$/
      exclude: /\.l\.styl$/
      loaders: ['style-loader', 'css-loader', stylusLoader]
    ,
      # Plain CSS
      test: /\.css$/
      loaders: ['style-loader', 'css-loader']
    ,
      # Media
      test: /\.(png|jpe?g|gif|svg|woff2?|eot|ttf)$/
      loaders: ['url']
    ]

  plugins: [
    # Generate HTML
    new HtmlWebpackPlugin
      template: path.join SRC_PATH, "#{INDEX}.pug"

    # Preload dynamic imports
    new PreloadWebpackPlugin()
  ]

withLint = (config) ->
  merge config,
    plugins: [
      # Loaders
      coffeelintPlugin
      stylintPlugin
    ]
config = withLint config

# Dev server config
devServerOpts =
  # Serve publicly
  host: '0.0.0.0'

  # Use defined port
  port: PORT

  # No iframe
  inline: true

  # Show progress
  progress: true

  # Hot reloading
  hot: true

  # Allow routing
  historyApiFallback: true

  # Display options
  stats:
    # Don't show a bunch of chunk stats
    chunkModules: false

    # Pretty colors
    colors: true

withHot = (config) ->
  merge config,
    module:
      rules: [
        test: /\.coffee$/
        loaders: ['react-hot-loader/webpack']
      ]

    plugins: [
        # Named modules
        new webpack.NamedModulesPlugin()

        # General hot loading
        new webpack.HotModuleReplacementPlugin()
    ]

    devServer: devServerOpts

# Options based on environment
switch ENV
  when 'dev'  # Development
    console.log 'Running development server...'
    config.mode = 'development'

    config = merge config,
      # Source maps
      devtool: 'cheap-module-eval-source-map'

      plugins: [
        # Development environment variable
        new webpack.DefinePlugin
          'process.env':
            NODE_ENV: '"development"'
      ]
    config = withHot config

  when 'build', 'analyze'  # Production
    console.log 'Building production scripts...'
    config.mode = 'production'

    config = merge config,
      output:
        filename: '[name].[chunkhash:5].js'
        chunkFilename: '[name].[chunkhash:5].js'

      plugins: [
        # Production environment variable
        new webpack.DefinePlugin
          'process.env':
            NODE_ENV: '"production"'

        # Optimize chunking
        new webpack.optimize.OccurrenceOrderPlugin()

        # Consistent module IDs
        new webpack.HashedModuleIdsPlugin()

        # Hoist scopes
        new webpack.optimize.ModuleConcatenationPlugin()

        # Separate vendor bundle
        new webpack.optimize.CommonsChunkPlugin
          name: VENDOR
          minChunks: isVendor

        # Manifest
        new webpack.optimize.CommonsChunkPlugin
          name: 'manifest'

        # Minify
        new UglifyJsPlugin()
      ]
    if ENV is 'analyze'
      console.log 'Analyzing bundle...'
      config = merge config,
        plugins: [new BundleAnalyzerPlugin()]

  when 'test', 'test:watch', 'test:browser'  # Test
    process.stdout.write 'Testing '
    config.mode = 'production'

    config = merge config,
      output:
        path: TEST_PATH
      devtool: 'inline-source-map'

    # Set up testing input
    config.entry = [
      'source-map-support/register'
      path.join TEST_PATH, "#{TEST}.coffee"
    ]

    # View tests on browser
    if ENV.match 'browser'
      console.log 'with dev server...'

      config = merge config,
        # Suppress source-map-support warnings
        node:
          fs: 'empty'
          module: 'empty'

        # Use mocha loader on *.spec.* files
        module:
          rules: [
            enforce: 'post'
            test: /\.spec\..*$/
            use: 'mocha-loader'
          ]

      config.plugins = [
        # Generate test HTML
        new HtmlWebpackPlugin
          template: path.join TEST_PATH, "#{INDEX}.pug"
      ]

      config = withHot config

    # View tests on CLI
    else
      console.log 'on the command line...'

      # Build for node
      config.target = 'node'

      # Disable output bundling
      config.plugins = []

    config = withLint config

    # Test environment variable
    config.plugins.push new webpack.DefinePlugin
      'process.env':
        NODE_ENV: '"test"'

# Export the configuration
module.exports = config
