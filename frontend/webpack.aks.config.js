/**
 * MS5.0 Floor Dashboard - AKS Production Webpack Configuration
 * 
 * This configuration optimizes React Native Web for AKS deployment with:
 * - Production-grade optimization
 * - Tablet-specific optimizations
 * - PWA capabilities
 * - Offline-first architecture
 * - Factory environment support
 */

const path = require('path');
const webpack = require('webpack');
const { CleanWebpackPlugin } = require('clean-webpack-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');
const CssMinimizerPlugin = require('css-minimizer-webpack-plugin');
const TerserPlugin = require('terser-webpack-plugin');
const CompressionPlugin = require('compression-webpack-plugin');
const { BundleAnalyzerPlugin } = require('webpack-bundle-analyzer');
const WorkboxPlugin = require('workbox-webpack-plugin');

const isProduction = process.env.NODE_ENV === 'production';
const isTabletOptimized = process.env.TABLET_OPTIMIZED === 'true';
const isFactoryNetwork = process.env.FACTORY_NETWORK === 'true';

module.exports = {
  mode: isProduction ? 'production' : 'development',
  
  // Entry point for React Native Web
  entry: {
    main: './src/index.web.tsx',
    // Separate entry for offline functionality
    offline: './src/offline/OfflineManager.ts',
  },
  
  // Output configuration optimized for AKS
  output: {
    path: path.resolve(__dirname, 'build'),
    filename: isProduction 
      ? 'static/js/[name].[contenthash:8].js'
      : 'static/js/[name].js',
    chunkFilename: isProduction
      ? 'static/js/[name].[contenthash:8].chunk.js'
      : 'static/js/[name].chunk.js',
    assetModuleFilename: 'static/media/[name].[hash][ext]',
    publicPath: '/',
    clean: true,
    // Enable long-term caching
    hashDigestLength: 8,
  },
  
  // Resolve configuration for React Native Web
  resolve: {
    extensions: [
      '.web.tsx', '.web.ts', '.web.jsx', '.web.js',
      '.tsx', '.ts', '.jsx', '.js', '.json'
    ],
    alias: {
      'react-native$': 'react-native-web',
      'react-native-linear-gradient': 'react-native-web-linear-gradient',
      '@': path.resolve(__dirname, 'src'),
      '@components': path.resolve(__dirname, 'src/components'),
      '@screens': path.resolve(__dirname, 'src/screens'),
      '@navigation': path.resolve(__dirname, 'src/navigation'),
      '@services': path.resolve(__dirname, 'src/services'),
      '@store': path.resolve(__dirname, 'src/store'),
      '@utils': path.resolve(__dirname, 'src/utils'),
      '@styles': path.resolve(__dirname, 'src/styles'),
      '@assets': path.resolve(__dirname, 'assets'),
      '@hooks': path.resolve(__dirname, 'src/hooks'),
      '@config': path.resolve(__dirname, 'src/config'),
    },
    fallback: {
      "stream": require.resolve("stream-browserify"),
      "buffer": require.resolve("buffer"),
      "crypto": require.resolve("crypto-browserify"),
      "fs": false,
      "path": require.resolve("path-browserify"),
      "os": require.resolve("os-browserify/browser"),
    },
  },
  
  // Module configuration with optimizations
  module: {
    rules: [
      // TypeScript and JavaScript files
      {
        test: /\.(ts|tsx|js|jsx)$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'babel-loader',
            options: {
              presets: [
                '@babel/preset-env',
                '@babel/preset-react',
                '@babel/preset-typescript',
              ],
              plugins: [
                ['@babel/plugin-transform-runtime', { regenerator: true }],
                ['@babel/plugin-proposal-decorators', { legacy: true }],
                ['@babel/plugin-proposal-class-properties', { loose: true }],
                'react-native-reanimated/plugin',
              ],
            },
          },
        ],
      },
      
      // CSS and SCSS files
      {
        test: /\.(css|scss|sass)$/,
        use: [
          isProduction ? MiniCssExtractPlugin.loader : 'style-loader',
          {
            loader: 'css-loader',
            options: {
              modules: {
                auto: true,
                localIdentName: isProduction 
                  ? '[hash:base64:8]' 
                  : '[local]__[hash:base64:5]',
              },
              importLoaders: 2,
            },
          },
          'postcss-loader',
          'sass-loader',
        ],
      },
      
      // Static assets
      {
        test: /\.(png|jpe?g|gif|svg|ico|webp)$/,
        type: 'asset',
        parser: {
          dataUrlCondition: {
            maxSize: 8 * 1024, // 8KB
          },
        },
        generator: {
          filename: 'static/images/[name].[hash:8][ext]',
        },
      },
      
      // Fonts
      {
        test: /\.(woff|woff2|eot|ttf|otf)$/,
        type: 'asset/resource',
        generator: {
          filename: 'static/fonts/[name].[hash:8][ext]',
        },
      },
      
      // JSON files
      {
        test: /\.json$/,
        type: 'json',
      },
    ],
  },
  
  // Plugin configuration
  plugins: [
    // Clean build directory
    new CleanWebpackPlugin(),
    
    // HTML template for tablet deployment
    new HtmlWebpackPlugin({
      template: './public/index.aks.html',
      filename: 'index.html',
      inject: true,
      minify: isProduction ? {
        removeComments: true,
        collapseWhitespace: true,
        removeRedundantAttributes: true,
        useShortDoctype: true,
        removeEmptyAttributes: true,
        removeStyleLinkTypeAttributes: true,
        keepClosingSlash: true,
        minifyJS: true,
        minifyCSS: true,
        minifyURLs: true,
      } : false,
      // Tablet-specific meta tags
      meta: {
        viewport: 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, orientation=landscape',
        'mobile-web-app-capable': 'yes',
        'apple-mobile-web-app-capable': 'yes',
        'apple-mobile-web-app-status-bar-style': 'black-translucent',
        'theme-color': '#1976d2',
        'msapplication-TileColor': '#1976d2',
        'msapplication-config': '/browserconfig.xml',
      },
    }),
    
    // Environment variables
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production'),
      'process.env.TABLET_OPTIMIZED': JSON.stringify(isTabletOptimized),
      'process.env.FACTORY_NETWORK': JSON.stringify(isFactoryNetwork),
      'process.env.API_BASE_URL': JSON.stringify(process.env.API_BASE_URL || 'https://api.ms5dashboard.com'),
      'process.env.WS_BASE_URL': JSON.stringify(process.env.WS_BASE_URL || 'wss://api.ms5dashboard.com'),
      'process.env.OFFLINE_ENABLED': JSON.stringify('true'),
      'process.env.PWA_ENABLED': JSON.stringify('true'),
      // Feature flags
      'process.env.FEATURE_REAL_TIME_UPDATES': JSON.stringify('true'),
      'process.env.FEATURE_ADVANCED_ANALYTICS': JSON.stringify('true'),
      'process.env.FEATURE_ESCALATION_SYSTEM': JSON.stringify('true'),
      'process.env.FEATURE_OFFLINE_SUPPORT': JSON.stringify('true'),
    }),
    
    // Provide polyfills for Node.js modules
    new webpack.ProvidePlugin({
      Buffer: ['buffer', 'Buffer'],
      process: 'process/browser',
    }),
    
    // CSS extraction for production
    ...(isProduction ? [
      new MiniCssExtractPlugin({
        filename: 'static/css/[name].[contenthash:8].css',
        chunkFilename: 'static/css/[name].[contenthash:8].chunk.css',
      }),
    ] : []),
    
    // Service Worker for PWA
    new WorkboxPlugin.GenerateSW({
      clientsClaim: true,
      skipWaiting: true,
      maximumFileSizeToCacheInBytes: 5 * 1024 * 1024, // 5MB
      runtimeCaching: [
        {
          urlPattern: /^https:\/\/api\./,
          handler: 'NetworkFirst',
          options: {
            cacheName: 'api-cache',
            expiration: {
              maxEntries: 100,
              maxAgeSeconds: 60 * 60 * 24, // 24 hours
            },
            cacheableResponse: {
              statuses: [0, 200],
            },
          },
        },
        {
          urlPattern: /\.(?:png|jpg|jpeg|svg|gif|webp)$/,
          handler: 'CacheFirst',
          options: {
            cacheName: 'images-cache',
            expiration: {
              maxEntries: 1000,
              maxAgeSeconds: 60 * 60 * 24 * 30, // 30 days
            },
          },
        },
        {
          urlPattern: /\.(?:js|css)$/,
          handler: 'StaleWhileRevalidate',
          options: {
            cacheName: 'static-resources',
            expiration: {
              maxEntries: 100,
              maxAgeSeconds: 60 * 60 * 24 * 7, // 7 days
            },
          },
        },
      ],
      navigateFallback: '/index.html',
      navigateFallbackDenylist: [/^\/api\//, /^\/ws\//],
    }),
    
    // Compression for production
    ...(isProduction ? [
      new CompressionPlugin({
        algorithm: 'gzip',
        test: /\.(js|css|html|svg)$/,
        threshold: 8192,
        minRatio: 0.8,
      }),
      new CompressionPlugin({
        algorithm: 'brotliCompress',
        test: /\.(js|css|html|svg)$/,
        threshold: 8192,
        minRatio: 0.8,
        filename: '[path][base].br',
      }),
    ] : []),
    
    // Bundle analyzer for development
    ...(process.env.ANALYZE_BUNDLE ? [
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        openAnalyzer: false,
        reportFilename: 'bundle-analysis.html',
      }),
    ] : []),
  ],
  
  // Optimization configuration
  optimization: {
    minimize: isProduction,
    minimizer: [
      new TerserPlugin({
        terserOptions: {
          parse: {
            ecma: 8,
          },
          compress: {
            ecma: 5,
            warnings: false,
            comparisons: false,
            inline: 2,
            drop_console: isProduction,
            drop_debugger: isProduction,
          },
          mangle: {
            safari10: true,
          },
          output: {
            ecma: 5,
            comments: false,
            ascii_only: true,
          },
        },
        parallel: true,
        extractComments: false,
      }),
      ...(isProduction ? [new CssMinimizerPlugin()] : []),
    ],
    
    // Code splitting for better caching
    splitChunks: {
      chunks: 'all',
      cacheGroups: {
        vendor: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
          priority: 10,
        },
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
          priority: 5,
          reuseExistingChunk: true,
        },
        // React and React Native Web in separate chunk
        react: {
          test: /[\\/]node_modules[\\/](react|react-dom|react-native-web)[\\/]/,
          name: 'react',
          chunks: 'all',
          priority: 20,
        },
      },
    },
    
    // Runtime chunk for better caching
    runtimeChunk: {
      name: 'runtime',
    },
  },
  
  // Performance hints
  performance: {
    hints: isProduction ? 'warning' : false,
    maxEntrypointSize: 512000, // 500KB
    maxAssetSize: 512000, // 500KB
    assetFilter: (assetFilename) => {
      return assetFilename.endsWith('.js') || assetFilename.endsWith('.css');
    },
  },
  
  // Development server configuration
  devServer: {
    static: {
      directory: path.join(__dirname, 'public'),
    },
    compress: true,
    port: 8080,
    host: '0.0.0.0',
    hot: true,
    historyApiFallback: true,
    client: {
      overlay: {
        errors: true,
        warnings: false,
      },
    },
    // Enable HTTPS for development
    server: 'https',
    // Proxy for API calls
    proxy: {
      '/api': {
        target: process.env.API_BASE_URL || 'http://localhost:8000',
        changeOrigin: true,
        secure: false,
      },
      '/ws': {
        target: process.env.WS_BASE_URL || 'ws://localhost:8000',
        ws: true,
        changeOrigin: true,
      },
    },
  },
  
  // Source map configuration
  devtool: isProduction ? 'source-map' : 'eval-cheap-module-source-map',
  
  // Stats configuration
  stats: {
    colors: true,
    modules: false,
    children: false,
    chunks: false,
    chunkModules: false,
    entrypoints: false,
    assets: false,
    version: false,
    hash: false,
    timings: true,
    builtAt: true,
  },
};
