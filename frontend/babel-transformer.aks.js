/**
 * Babel Transformer for AKS Production Deployment
 * 
 * Custom Babel transformer optimized for Azure Kubernetes Service deployment
 * with tablet-specific optimizations and factory environment considerations.
 */

const fs = require('fs');
const path = require('path');
const babel = require('@babel/core');

/**
 * AKS-optimized Babel transformer
 * - Enhanced code optimization for tablet performance
 * - Factory network environment optimizations
 * - PWA transformation capabilities
 * - Offline-first architecture support
 */
module.exports = {
  transform({ src, filename, options }) {
    // AKS-specific Babel configuration
    const babelConfig = {
      presets: [
        [
          '@babel/preset-env',
          {
            targets: {
              // Optimize for tablet browsers in factory environments
              browsers: [
                'last 2 Chrome versions',
                'last 2 Safari versions',
                'last 2 Edge versions',
                'iOS >= 12',
                'Android >= 8'
              ],
            },
            modules: false, // Preserve ES modules for tree shaking
            useBuiltIns: 'usage',
            corejs: 3,
          },
        ],
        [
          '@babel/preset-react',
          {
            runtime: 'automatic',
            development: process.env.NODE_ENV !== 'production',
          },
        ],
        [
          '@babel/preset-typescript',
          {
            allowDeclareFields: true,
            onlyRemoveTypeImports: true,
          },
        ],
      ],
      plugins: [
        // Production optimizations
        ...(process.env.NODE_ENV === 'production' ? [
          // Remove console logs in production
          ['transform-remove-console', { exclude: ['error', 'warn'] }],
          // Optimize React components
          'babel-plugin-transform-react-remove-prop-types',
          // Dead code elimination
          'babel-plugin-minify-dead-code-elimination',
          // Optimize object properties
          'babel-plugin-transform-object-rest-spread',
        ] : []),
        
        // AKS-specific plugins
        [
          'babel-plugin-module-resolver',
          {
            root: ['./src'],
            alias: {
              '@': './src',
              '@components': './src/components',
              '@screens': './src/screens',
              '@services': './src/services',
              '@utils': './src/utils',
              '@store': './src/store',
              '@hooks': './src/hooks',
              '@config': './src/config',
            },
          },
        ],
        
        // React Native optimizations
        '@babel/plugin-proposal-class-properties',
        '@babel/plugin-proposal-object-rest-spread',
        '@babel/plugin-transform-runtime',
        
        // Tablet-specific optimizations
        [
          'babel-plugin-transform-imports',
          {
            'react-native-vector-icons': {
              transform: 'react-native-vector-icons/${member}',
              preventFullImport: true,
            },
            'react-native-elements': {
              transform: 'react-native-elements/dist/${member}',
              preventFullImport: true,
            },
          },
        ],
        
        // PWA support
        [
          'babel-plugin-transform-pwa',
          {
            enabled: process.env.PWA_ENABLED === 'true',
            manifest: './public/manifest.json',
            serviceWorker: './public/sw.js',
          },
        ],
        
        // Factory environment optimizations
        [
          'babel-plugin-transform-factory-env',
          {
            offlineSupport: true,
            tabletOptimizations: true,
            networkResilience: true,
          },
        ],
      ],
      // Source map configuration for production debugging
      sourceMaps: process.env.NODE_ENV === 'production' ? 'inline' : true,
      // Compact output for production
      compact: process.env.NODE_ENV === 'production',
      // Retain lines for better debugging
      retainLines: process.env.NODE_ENV !== 'production',
    };

    // Transform the code
    const result = babel.transformSync(src, {
      ...babelConfig,
      filename,
      sourceFileName: filename,
    });

    // Apply AKS-specific transformations
    let transformedCode = result.code;
    
    // Inject AKS environment variables
    transformedCode = injectAKSEnvironmentVariables(transformedCode);
    
    // Optimize for tablet performance
    transformedCode = optimizeForTabletPerformance(transformedCode);
    
    // Add offline-first capabilities
    transformedCode = addOfflineFirstSupport(transformedCode);

    return {
      ast: result.ast,
      code: transformedCode,
      map: result.map,
    };
  },
};

/**
 * Inject AKS-specific environment variables
 */
function injectAKSEnvironmentVariables(code) {
  const aksEnvVars = {
    API_BASE_URL: process.env.API_BASE_URL || 'https://api.ms5floor.com',
    WS_BASE_URL: process.env.WS_BASE_URL || 'wss://api.ms5floor.com',
    CDN_BASE_URL: process.env.CDN_BASE_URL || 'https://cdn.ms5floor.com',
    PWA_ENABLED: process.env.PWA_ENABLED || 'true',
    OFFLINE_MODE: process.env.OFFLINE_MODE || 'true',
    FACTORY_NETWORK: process.env.FACTORY_NETWORK || 'true',
  };

  const envVarCode = Object.entries(aksEnvVars)
    .map(([key, value]) => `process.env.${key} = "${value}";`)
    .join('\n');

  return `${envVarCode}\n${code}`;
}

/**
 * Optimize code for tablet performance
 */
function optimizeForTabletPerformance(code) {
  // Optimize touch targets for factory environment
  code = code.replace(
    /touchableOpacityStyle\s*=\s*{([^}]*)}/g,
    'touchableOpacityStyle={{ ...$1, minHeight: 44, minWidth: 44 }}'
  );

  // Optimize image loading for tablet displays
  code = code.replace(
    /source\s*=\s*{([^}]*)}/g,
    'source={{ ...$1, resizeMode: "contain" }}'
  );

  // Add tablet-specific performance optimizations
  const tabletOptimizations = `
    // Tablet performance optimizations
    if (window.devicePixelRatio && window.devicePixelRatio > 2) {
      // High DPI tablet optimizations
      document.body.style.imageRendering = 'optimizeQuality';
    }
  `;

  return code + tabletOptimizations;
}

/**
 * Add offline-first architecture support
 */
function addOfflineFirstSupport(code) {
  const offlineSupport = `
    // Offline-first architecture support
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
          .then((registration) => {
            console.log('SW registered: ', registration);
          })
          .catch((registrationError) => {
            console.log('SW registration failed: ', registrationError);
          });
      });
    }
    
    // Offline detection and handling
    window.addEventListener('online', () => {
      document.body.classList.remove('offline');
      // Trigger sync when back online
      if (window.syncOfflineData) {
        window.syncOfflineData();
      }
    });
    
    window.addEventListener('offline', () => {
      document.body.classList.add('offline');
      // Show offline indicator
      if (window.showOfflineIndicator) {
        window.showOfflineIndicator();
      }
    });
  `;

  return code + offlineSupport;
}
