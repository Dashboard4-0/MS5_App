/**
 * Metro Configuration for AKS Production Deployment
 * 
 * This configuration optimizes the React Native build for Azure Kubernetes Service
 * deployment with tablet-specific considerations and PWA capabilities.
 */

const { getDefaultConfig } = require('metro-config');
const path = require('path');

/**
 * AKS-optimized Metro configuration
 * - Enhanced bundle optimization for tablet deployment
 * - PWA support with service worker capabilities
 * - Factory network environment optimizations
 * - Offline-first architecture support
 */
const config = getDefaultConfig(__dirname);

// Enhanced resolver configuration for AKS deployment
config.resolver = {
  ...config.resolver,
  // Support for additional asset types in factory environments
  assetExts: [
    ...config.resolver.assetExts,
    'svg',
    'ico',
    'woff',
    'woff2',
    'ttf',
    'eot'
  ],
  // Platform-specific extensions for tablet deployment
  platforms: ['ios', 'android', 'native', 'web'],
  // Source map configuration for production debugging
  sourceExts: ['js', 'jsx', 'ts', 'tsx', 'json'],
};

// Transformer configuration for production optimization
config.transformer = {
  ...config.transformer,
  // Enable minification for production builds
  minifierConfig: {
    mangle: true,
    keep_fnames: true,
    toplevel: true,
    compress: {
      drop_console: true, // Remove console logs in production
      drop_debugger: true,
      pure_funcs: ['console.log', 'console.info', 'console.debug'],
      passes: 3, // Multiple compression passes for optimal size
    },
  },
  // Enable tree shaking for unused code elimination
  enableBabelRCLookup: false,
  // Optimize for tablet performance
  babelTransformerPath: path.resolve(__dirname, 'babel-transformer.aks.js'),
};

// Serializer configuration for bundle optimization
config.serializer = {
  ...config.serializer,
  // Custom serializer for AKS deployment
  customSerializer: path.resolve(__dirname, 'serializer.aks.js'),
  // Enable code splitting for tablet deployment
  getModulesRunBeforeMainModule: () => [
    require.resolve('./src/config/aks-init.js'),
  ],
  // Optimize module resolution for factory networks
  processModuleFilter: (module) => {
    // Filter out development-only modules in production
    if (module.path.includes('__tests__') || 
        module.path.includes('.test.') ||
        module.path.includes('.spec.')) {
      return false;
    }
    return true;
  },
};

// Server configuration for AKS deployment
config.server = {
  ...config.server,
  // Enhanced server configuration for Kubernetes
  port: process.env.METRO_PORT || 8081,
  // Enable HTTPS for production deployment
  https: process.env.NODE_ENV === 'production',
  // Optimize for containerized deployment
  enhanceMiddleware: (middleware) => {
    return (req, res, next) => {
      // Add security headers for factory deployment
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'DENY');
      res.setHeader('X-XSS-Protection', '1; mode=block');
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
      
      // Enable CORS for factory network access
      res.setHeader('Access-Control-Allow-Origin', process.env.ALLOWED_ORIGINS || '*');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      
      return middleware(req, res, next);
    };
  },
};

// Watchman configuration for factory environments
config.watchFolders = [
  path.resolve(__dirname, 'src'),
  path.resolve(__dirname, 'node_modules'),
];

// Cache configuration for AKS deployment
config.cacheStores = [
  {
    name: 'aks-cache',
    path: path.resolve(__dirname, '.metro-cache-aks'),
  },
];

module.exports = config;
