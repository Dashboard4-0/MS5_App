/**
 * MS5.0 Floor Dashboard - Advanced Bundle Optimization Configuration
 * 
 * This configuration implements cosmic-scale performance optimization with:
 * - Advanced code splitting strategies
 * - Intelligent lazy loading
 * - Bundle size optimization
 * - Performance monitoring
 * - Zero redundancy architecture
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
const PreloadWebpackPlugin = require('@vue/preload-webpack-plugin');
const DuplicatePackageCheckerPlugin = require('duplicate-package-checker-webpack-plugin');
const SizePlugin = require('size-plugin');

const isProduction = process.env.NODE_ENV === 'production';
const isTabletOptimized = process.env.TABLET_OPTIMIZED === 'true';
const isFactoryNetwork = process.env.FACTORY_NETWORK === 'true';
const enableBundleAnalysis = process.env.ANALYZE_BUNDLE === 'true';

// Performance budgets
const PERFORMANCE_BUDGETS = {
  maxEntrypointSize: 400000, // 400KB
  maxAssetSize: 300000,      // 300KB
  maxChunkSize: 200000,      // 200KB
  maxInitialChunkSize: 150000, // 150KB
};

// Bundle splitting strategy
const BUNDLE_SPLITTING_STRATEGY = {
  // Critical path chunks (loaded immediately)
  critical: {
    react: /[\\/]node_modules[\\/](react|react-dom)[\\/]/,
    reactNative: /[\\/]node_modules[\\/]react-native-web[\\/]/,
    core: /[\\/]src[\\/](store|services|utils|config)[\\/]/,
  },
  
  // Feature chunks (loaded on demand)
  features: {
    dashboard: /[\\/]src[\\/]screens[\\/]Dashboard[\\/]/,
    production: /[\\/]src[\\/]screens[\\/]Production[\\/]/,
    analytics: /[\\/]src[\\/]screens[\\/]Analytics[\\/]/,
    admin: /[\\/]src[\\/]screens[\\/]Admin[\\/]/,
    reports: /[\\/]src[\\/]screens[\\/]Reports[\\/]/,
  },
  
  // Third-party libraries
  vendors: {
    ui: /[\\/]node_modules[\\/](@mui|@material-ui|antd)[\\/]/,
    charts: /[\\/]node_modules[\\/](recharts|chart\.js|d3)[\\/]/,
    utils: /[\\/]node_modules[\\/](lodash|moment|date-fns)[\\/]/,
    networking: /[\\/]node_modules[\\/](axios|socket\.io)[\\/]/,
  }
};

module.exports = {
  mode: isProduction ? 'production' : 'development',
  
  // Entry points with intelligent splitting
  entry: {
    // Main application entry
    main: {
      import: './src/index.web.tsx',
      dependOn: ['runtime', 'vendors'],
    },
    
    // Runtime chunk for better caching
    runtime: './src/runtime.ts',
    
    // Vendor chunk for third-party libraries
    vendors: './src/vendors.ts',
    
    // Critical components loaded immediately
    critical: './src/critical.ts',
    
    // Offline functionality
    offline: './src/offline/OfflineManager.ts',
  },
  
  // Output configuration with advanced optimization
  output: {
    path: path.resolve(__dirname, 'build'),
    filename: isProduction 
      ? 'static/js/[name].[contenthash:8].js'
      : 'static/js/[name].js',
    chunkFilename: isProduction
      ? 'static/js/[name].[contenthash:8].chunk.js'
      : 'static/js/[name].chunk.js',
    assetModuleFilename: 'static/media/[name].[hash:8][ext]',
    publicPath: '/',
    clean: true,
    
    // Advanced caching configuration
    hashDigestLength: 8,
    hashFunction: 'xxhash64',
    hashSalt: 'ms5-dashboard-v1',
    
    // Environment-specific optimizations
    ...(isProduction && {
      // Enable long-term caching
      chunkLoadingGlobal: 'ms5ChunkLoader',
      globalObject: 'self',
    }),
  },
  
  // Enhanced resolve configuration
  resolve: {
    extensions: [
      '.web.tsx', '.web.ts', '.web.jsx', '.web.js',
      '.tsx', '.ts', '.jsx', '.js', '.json'
    ],
    alias: {
      // React Native Web aliases
      'react-native$': 'react-native-web',
      'react-native-linear-gradient': 'react-native-web-linear-gradient',
      'react-native-svg': 'react-native-svg-web',
      
      // Path aliases for better tree shaking
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
      '@types': path.resolve(__dirname, 'src/types'),
    },
    
    // Fallback configuration for Node.js modules
    fallback: {
      "stream": require.resolve("stream-browserify"),
      "buffer": require.resolve("buffer"),
      "crypto": require.resolve("crypto-browserify"),
      "fs": false,
      "path": require.resolve("path-browserify"),
      "os": require.resolve("os-browserify/browser"),
      "util": require.resolve("util"),
      "url": require.resolve("url"),
      "querystring": require.resolve("querystring-es3"),
    },
    
    // Module resolution optimization
    modules: [
      path.resolve(__dirname, 'src'),
      path.resolve(__dirname, 'node_modules'),
    ],
    
    // Symlink resolution
    symlinks: false,
    
    // Cache resolution results
    cache: true,
  },
  
  // Enhanced module configuration
  module: {
    rules: [
      // TypeScript and JavaScript files with advanced optimization
      {
        test: /\.(ts|tsx|js|jsx)$/,
        exclude: /node_modules/,
        use: [
          {
            loader: 'babel-loader',
            options: {
              presets: [
                ['@babel/preset-env', {
                  targets: {
                    browsers: ['last 2 versions', '> 1%', 'not dead'],
                  },
                  modules: false, // Enable tree shaking
                  useBuiltIns: 'usage',
                  corejs: 3,
                }],
                ['@babel/preset-react', {
                  runtime: 'automatic',
                  development: !isProduction,
                }],
                '@babel/preset-typescript',
              ],
              plugins: [
                // Performance optimizations
                ['@babel/plugin-transform-runtime', { 
                  regenerator: true,
                  corejs: 3,
                  helpers: true,
                  useESModules: true,
                }],
                ['@babel/plugin-proposal-decorators', { legacy: true }],
                ['@babel/plugin-proposal-class-properties', { loose: true }],
                
                // Production optimizations
                ...(isProduction ? [
                  '@babel/plugin-transform-react-constant-elements',
                  '@babel/plugin-transform-react-inline-elements',
                  'babel-plugin-transform-react-remove-prop-types',
                ] : []),
                
                // React Native Web optimizations
                'react-native-reanimated/plugin',
              ],
              cacheDirectory: true,
              cacheCompression: false,
            },
          },
        ],
      },
      
      // CSS and SCSS files with advanced processing
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
                exportLocalsConvention: 'camelCase',
              },
              importLoaders: 2,
              sourceMap: !isProduction,
            },
          },
          {
            loader: 'postcss-loader',
            options: {
              postcssOptions: {
                plugins: [
                  'autoprefixer',
                  'cssnano',
                  'postcss-preset-env',
                ],
              },
            },
          },
          'sass-loader',
        ],
      },
      
      // Optimized asset handling
      {
        test: /\.(png|jpe?g|gif|svg|ico|webp)$/,
        type: 'asset',
        parser: {
          dataUrlCondition: {
            maxSize: 4 * 1024, // 4KB for inline
          },
        },
        generator: {
          filename: 'static/images/[name].[hash:8][ext]',
        },
      },
      
      // Font optimization
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
  
  // Advanced plugin configuration
  plugins: [
    // Clean build directory
    new CleanWebpackPlugin({
      cleanOnceBeforeBuildPatterns: ['**/*'],
      cleanStaleWebpackAssets: true,
    }),
    
    // Enhanced HTML template
    new HtmlWebpackPlugin({
      template: './public/index.aks.html',
      filename: 'index.html',
      inject: true,
      chunks: ['runtime', 'vendors', 'main'],
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
    
    // Resource preloading for critical resources
    new PreloadWebpackPlugin({
      rel: 'preload',
      include: 'initial',
      fileBlacklist: [/\.map$/, /hot-update\.js$/],
    }),
    
    // Environment variables with feature flags
    new webpack.DefinePlugin({
      'process.env.NODE_ENV': JSON.stringify(process.env.NODE_ENV || 'production'),
      'process.env.TABLET_OPTIMIZED': JSON.stringify(isTabletOptimized),
      'process.env.FACTORY_NETWORK': JSON.stringify(isFactoryNetwork),
      'process.env.API_BASE_URL': JSON.stringify(process.env.API_BASE_URL || 'https://api.ms5dashboard.com'),
      'process.env.WS_BASE_URL': JSON.stringify(process.env.WS_BASE_URL || 'wss://api.ms5dashboard.com'),
      'process.env.OFFLINE_ENABLED': JSON.stringify('true'),
      'process.env.PWA_ENABLED': JSON.stringify('true'),
      
      // Performance feature flags
      'process.env.FEATURE_REAL_TIME_UPDATES': JSON.stringify('true'),
      'process.env.FEATURE_ADVANCED_ANALYTICS': JSON.stringify('true'),
      'process.env.FEATURE_ESCALATION_SYSTEM': JSON.stringify('true'),
      'process.env.FEATURE_OFFLINE_SUPPORT': JSON.stringify('true'),
      'process.env.FEATURE_PERFORMANCE_MONITORING': JSON.stringify('true'),
      'process.env.FEATURE_BUNDLE_ANALYSIS': JSON.stringify(enableBundleAnalysis),
    }),
    
    // Provide polyfills for Node.js modules
    new webpack.ProvidePlugin({
      Buffer: ['buffer', 'Buffer'],
      process: 'process/browser',
    }),
    
    // Duplicate package checker
    new DuplicatePackageCheckerPlugin({
      verbose: true,
      emitError: false,
      showHelp: true,
    }),
    
    // Bundle size monitoring
    new SizePlugin({
      writeFile: isProduction,
    }),
    
    // CSS extraction for production
    ...(isProduction ? [
      new MiniCssExtractPlugin({
        filename: 'static/css/[name].[contenthash:8].css',
        chunkFilename: 'static/css/[name].[contenthash:8].chunk.css',
        ignoreOrder: true,
      }),
    ] : []),
    
    // Advanced Service Worker configuration
    new WorkboxPlugin.GenerateSW({
      clientsClaim: true,
      skipWaiting: true,
      maximumFileSizeToCacheInBytes: 5 * 1024 * 1024, // 5MB
      
      // Intelligent caching strategies
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
            networkTimeoutSeconds: 3,
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
        {
          urlPattern: /^https:\/\/fonts\./,
          handler: 'CacheFirst',
          options: {
            cacheName: 'fonts-cache',
            expiration: {
              maxEntries: 50,
              maxAgeSeconds: 60 * 60 * 24 * 365, // 1 year
            },
          },
        },
      ],
      
      navigateFallback: '/index.html',
      navigateFallbackDenylist: [/^\/api\//, /^\/ws\//],
      
      // Additional SW features
      cleanupOutdatedCaches: true,
      offlineGoogleAnalytics: true,
    }),
    
    // Advanced compression
    ...(isProduction ? [
      new CompressionPlugin({
        algorithm: 'gzip',
        test: /\.(js|css|html|svg|json)$/,
        threshold: 8192,
        minRatio: 0.8,
        compressionOptions: {
          level: 9,
        },
      }),
      new CompressionPlugin({
        algorithm: 'brotliCompress',
        test: /\.(js|css|html|svg|json)$/,
        threshold: 8192,
        minRatio: 0.8,
        filename: '[path][base].br',
        compressionOptions: {
          level: 11,
        },
      }),
    ] : []),
    
    // Bundle analyzer for development
    ...(enableBundleAnalysis ? [
      new BundleAnalyzerPlugin({
        analyzerMode: 'static',
        openAnalyzer: false,
        reportFilename: 'bundle-analysis.html',
        generateStatsFile: true,
        statsFilename: 'bundle-stats.json',
        statsOptions: {
          source: false,
          modules: false,
          chunks: false,
          chunkModules: false,
          chunkOrigins: false,
          providedExports: false,
          usedExports: false,
          optimizationBailout: false,
          errorDetails: false,
          publicPath: false,
          builtAt: false,
          version: false,
        },
      }),
    ] : []),
  ],
  
  // Advanced optimization configuration
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
            pure_funcs: isProduction ? ['console.log', 'console.info'] : [],
            passes: 2,
          },
          mangle: {
            safari10: true,
            properties: {
              regex: /^_/,
            },
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
    
    // Advanced code splitting strategy
    splitChunks: {
      chunks: 'all',
      minSize: 20000,
      maxSize: PERFORMANCE_BUDGETS.maxChunkSize,
      minChunks: 1,
      maxAsyncRequests: 30,
      maxInitialRequests: 30,
      cacheGroups: {
        // Critical vendor libraries
        react: {
          test: BUNDLE_SPLITTING_STRATEGY.critical.react,
          name: 'react',
          chunks: 'all',
          priority: 40,
          enforce: true,
        },
        
        reactNative: {
          test: BUNDLE_SPLITTING_STRATEGY.critical.reactNative,
          name: 'react-native',
          chunks: 'all',
          priority: 35,
          enforce: true,
        },
        
        // UI libraries
        ui: {
          test: BUNDLE_SPLITTING_STRATEGY.vendors.ui,
          name: 'ui',
          chunks: 'all',
          priority: 30,
        },
        
        // Chart libraries
        charts: {
          test: BUNDLE_SPLITTING_STRATEGY.vendors.charts,
          name: 'charts',
          chunks: 'all',
          priority: 25,
        },
        
        // Utility libraries
        utils: {
          test: BUNDLE_SPLITTING_STRATEGY.vendors.utils,
          name: 'utils',
          chunks: 'all',
          priority: 20,
        },
        
        // Networking libraries
        networking: {
          test: BUNDLE_SPLITTING_STRATEGY.vendors.networking,
          name: 'networking',
          chunks: 'all',
          priority: 15,
        },
        
        // Feature-based splitting
        dashboard: {
          test: BUNDLE_SPLITTING_STRATEGY.features.dashboard,
          name: 'dashboard',
          chunks: 'all',
          priority: 10,
        },
        
        production: {
          test: BUNDLE_SPLITTING_STRATEGY.features.production,
          name: 'production',
          chunks: 'all',
          priority: 10,
        },
        
        analytics: {
          test: BUNDLE_SPLITTING_STRATEGY.features.analytics,
          name: 'analytics',
          chunks: 'all',
          priority: 10,
        },
        
        admin: {
          test: BUNDLE_SPLITTING_STRATEGY.features.admin,
          name: 'admin',
          chunks: 'all',
          priority: 10,
        },
        
        reports: {
          test: BUNDLE_SPLITTING_STRATEGY.features.reports,
          name: 'reports',
          chunks: 'all',
          priority: 10,
        },
        
        // Common code
        common: {
          name: 'common',
          minChunks: 2,
          chunks: 'all',
          priority: 5,
          reuseExistingChunk: true,
        },
        
        // Default vendor chunk
        default: {
          test: /[\\/]node_modules[\\/]/,
          name: 'vendors',
          chunks: 'all',
          priority: 1,
        },
      },
    },
    
    // Runtime chunk optimization
    runtimeChunk: {
      name: 'runtime',
    },
    
    // Module concatenation for better performance
    concatenateModules: isProduction,
    
    // Side effects optimization
    sideEffects: false,
  },
  
  // Enhanced performance configuration
  performance: {
    hints: isProduction ? 'warning' : false,
    maxEntrypointSize: PERFORMANCE_BUDGETS.maxEntrypointSize,
    maxAssetSize: PERFORMANCE_BUDGETS.maxAssetSize,
    assetFilter: (assetFilename) => {
      return assetFilename.endsWith('.js') || 
             assetFilename.endsWith('.css') || 
             assetFilename.endsWith('.woff2');
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
    
    // Proxy configuration
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
    
    // Performance monitoring
    devMiddleware: {
      stats: 'minimal',
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
    performance: true,
    optimizationBailout: true,
  },
  
  // Cache configuration
  cache: {
    type: 'filesystem',
    buildDependencies: {
      config: [__filename],
    },
    cacheDirectory: path.resolve(__dirname, '.webpack-cache'),
    compression: 'gzip',
    maxAge: 1000 * 60 * 60 * 24 * 7, // 7 days
  },
};
