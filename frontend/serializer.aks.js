/**
 * AKS Serializer for Metro Bundler
 * 
 * Custom serializer optimized for Azure Kubernetes Service deployment
 * with tablet-specific optimizations and factory environment considerations.
 */

const Serializer = require('metro/src/DeltaBundler/Serializers/BaseSerializer');
const { createHash } = require('crypto');

/**
 * AKS-optimized serializer
 * - Enhanced bundle optimization for tablet deployment
 * - Factory network environment optimizations
 * - PWA support with service worker capabilities
 * - Offline-first architecture support
 */
class AKSSerializer extends Serializer {
  constructor(...args) {
    super(...args);
    this.aksOptimizations = {
      enableCodeSplitting: true,
      enableTreeShaking: true,
      enableMinification: process.env.NODE_ENV === 'production',
      enableCompression: true,
      tabletOptimized: true,
      factoryNetworkOptimized: true,
      offlineFirst: true,
    };
  }

  /**
   * Serialize modules for AKS deployment
   */
  async serialize(entryPoint, pre, graph, options) {
    // Apply AKS-specific optimizations
    const optimizedGraph = await this.optimizeGraphForAKS(graph);
    
    // Generate base serialization
    const baseSerialization = await super.serialize(entryPoint, pre, optimizedGraph, options);
    
    // Apply AKS enhancements
    const aksEnhancedSerialization = await this.enhanceForAKS(baseSerialization, graph, options);
    
    return aksEnhancedSerialization;
  }

  /**
   * Optimize graph for AKS deployment
   */
  async optimizeGraphForAKS(graph) {
    const optimizedGraph = { ...graph };
    
    // Remove development-only modules
    optimizedGraph.dependencies = new Map(
      Array.from(graph.dependencies.entries()).filter(([path, module]) => {
        return !this.isDevelopmentModule(path, module);
      })
    );
    
    // Apply tablet-specific optimizations
    this.applyTabletOptimizations(optimizedGraph);
    
    // Apply factory network optimizations
    this.applyFactoryNetworkOptimizations(optimizedGraph);
    
    // Apply offline-first optimizations
    this.applyOfflineFirstOptimizations(optimizedGraph);
    
    return optimizedGraph;
  }

  /**
   * Check if module is development-only
   */
  isDevelopmentModule(path, module) {
    // Skip test files
    if (path.includes('__tests__') || 
        path.includes('.test.') || 
        path.includes('.spec.')) {
      return true;
    }
    
    // Skip development utilities
    if (path.includes('react-devtools') ||
        path.includes('flipper') ||
        path.includes('debugger')) {
      return true;
    }
    
    // Skip source maps in production
    if (process.env.NODE_ENV === 'production' && path.endsWith('.map')) {
      return true;
    }
    
    return false;
  }

  /**
   * Apply tablet-specific optimizations
   */
  applyTabletOptimizations(graph) {
    // Optimize for tablet screen sizes and touch interactions
    const tabletOptimizations = {
      // Increase touch target sizes
      touchTargetSize: 44,
      // Optimize for landscape orientation
      orientation: 'landscape',
      // Optimize for tablet pixel density
      pixelDensity: 2,
      // Optimize for tablet performance
      performanceMode: 'tablet',
    };
    
    // Inject tablet optimizations into graph metadata
    graph.tabletOptimizations = tabletOptimizations;
    
    // Optimize modules for tablet usage
    graph.dependencies.forEach((module, path) => {
      if (this.isTabletOptimizableModule(path)) {
        this.optimizeModuleForTablet(module);
      }
    });
  }

  /**
   * Check if module can be optimized for tablet
   */
  isTabletOptimizableModule(path) {
    return path.includes('components') || 
           path.includes('screens') || 
           path.includes('navigation');
  }

  /**
   * Optimize module for tablet usage
   */
  optimizeModuleForTablet(module) {
    // Add tablet-specific optimizations to module
    module.tabletOptimized = true;
    
    // Optimize for touch interactions
    if (module.output && module.output[0]) {
      const code = module.output[0].data.code;
      
      // Replace touch target optimizations
      const optimizedCode = code
        .replace(/minHeight:\s*\d+/g, 'minHeight: 44')
        .replace(/minWidth:\s*\d+/g, 'minWidth: 44')
        .replace(/height:\s*\d+/g, (match) => {
          const height = parseInt(match.match(/\d+/)[0]);
          return height < 44 ? 'minHeight: 44' : match;
        })
        .replace(/width:\s*\d+/g, (match) => {
          const width = parseInt(match.match(/\d+/)[0]);
          return width < 44 ? 'minWidth: 44' : match;
        });
      
      module.output[0].data.code = optimizedCode;
    }
  }

  /**
   * Apply factory network optimizations
   */
  applyFactoryNetworkOptimizations(graph) {
    // Optimize for factory network conditions
    const factoryOptimizations = {
      // Reduce bundle size for slower networks
      maxBundleSize: 5000000, // 5MB max bundle
      // Enable aggressive compression
      compressionLevel: 9,
      // Optimize for intermittent connectivity
      offlineFirst: true,
      // Enable adaptive loading
      adaptiveLoading: true,
    };
    
    // Inject factory optimizations into graph metadata
    graph.factoryOptimizations = factoryOptimizations;
    
    // Optimize modules for factory networks
    graph.dependencies.forEach((module, path) => {
      if (this.isFactoryOptimizableModule(path)) {
        this.optimizeModuleForFactory(module);
      }
    });
  }

  /**
   * Check if module can be optimized for factory networks
   */
  isFactoryOptimizableModule(path) {
    return path.includes('services') || 
           path.includes('api') || 
           path.includes('websocket') ||
           path.includes('network');
  }

  /**
   * Optimize module for factory networks
   */
  optimizeModuleForFactory(module) {
    // Add factory network optimizations to module
    module.factoryOptimized = true;
    
    // Add network resilience
    if (module.output && module.output[0]) {
      const code = module.output[0].data.code;
      
      // Add retry logic for network requests
      const optimizedCode = code
        .replace(/fetch\(/g, 'retryWithBackoff(() => fetch(')
        .replace(/axios\./g, 'retryWithBackoff(() => axios.')
        .replace(/websocket/g, 'resilientWebSocket');
      
      module.output[0].data.code = optimizedCode;
    }
  }

  /**
   * Apply offline-first optimizations
   */
  applyOfflineFirstOptimizations(graph) {
    // Optimize for offline-first architecture
    const offlineOptimizations = {
      // Enable offline storage
      offlineStorage: true,
      // Enable background sync
      backgroundSync: true,
      // Enable cache-first strategies
      cacheFirst: true,
      // Enable offline indicators
      offlineIndicators: true,
    };
    
    // Inject offline optimizations into graph metadata
    graph.offlineOptimizations = offlineOptimizations;
    
    // Add offline capabilities to relevant modules
    graph.dependencies.forEach((module, path) => {
      if (this.isOfflineOptimizableModule(path)) {
        this.optimizeModuleForOffline(module);
      }
    });
  }

  /**
   * Check if module can be optimized for offline usage
   */
  isOfflineOptimizableModule(path) {
    return path.includes('store') || 
           path.includes('data') || 
           path.includes('sync') ||
           path.includes('cache');
  }

  /**
   * Optimize module for offline usage
   */
  optimizeModuleForOffline(module) {
    // Add offline optimizations to module
    module.offlineOptimized = true;
    
    // Add offline capabilities
    if (module.output && module.output[0]) {
      const code = module.output[0].data.code;
      
      // Add offline storage capabilities
      const optimizedCode = code
        .replace(/localStorage/g, 'offlineStorage')
        .replace(/sessionStorage/g, 'offlineStorage')
        .replace(/AsyncStorage/g, 'offlineAsyncStorage');
      
      module.output[0].data.code = optimizedCode;
    }
  }

  /**
   * Enhance serialization for AKS deployment
   */
  async enhanceForAKS(serialization, graph, options) {
    const enhanced = { ...serialization };
    
    // Add AKS-specific metadata
    enhanced.aksMetadata = {
      version: '1.0.0',
      deploymentTarget: 'aks',
      tabletOptimized: true,
      factoryNetworkOptimized: true,
      offlineFirst: true,
      pwaEnabled: true,
      buildTimestamp: new Date().toISOString(),
      buildHash: this.generateBuildHash(graph),
    };
    
    // Add service worker configuration
    enhanced.serviceWorkerConfig = this.generateServiceWorkerConfig(graph);
    
    // Add PWA manifest
    enhanced.pwaManifest = this.generatePWAManifest();
    
    // Add offline cache configuration
    enhanced.offlineCacheConfig = this.generateOfflineCacheConfig(graph);
    
    // Optimize bundle for tablet deployment
    enhanced.tabletOptimizations = this.generateTabletOptimizations();
    
    // Add factory network optimizations
    enhanced.factoryNetworkOptimizations = this.generateFactoryNetworkOptimizations();
    
    return enhanced;
  }

  /**
   * Generate build hash for cache busting
   */
  generateBuildHash(graph) {
    const hash = createHash('sha256');
    
    // Include all module hashes
    graph.dependencies.forEach((module, path) => {
      hash.update(path);
      if (module.output && module.output[0]) {
        hash.update(module.output[0].data.code);
      }
    });
    
    return hash.digest('hex').substring(0, 16);
  }

  /**
   * Generate service worker configuration
   */
  generateServiceWorkerConfig(graph) {
    return {
      version: '1.0.0',
      cacheName: 'ms5-dashboard-v1',
      precache: this.generatePrecacheList(graph),
      runtimeCache: this.generateRuntimeCacheConfig(),
      offlinePage: '/offline.html',
      updateStrategy: 'stale-while-revalidate',
      backgroundSync: {
        enabled: true,
        queues: ['api-requests', 'andon-events', 'production-data'],
      },
    };
  }

  /**
   * Generate precache list from graph
   */
  generatePrecacheList(graph) {
    const precache = [];
    
    graph.dependencies.forEach((module, path) => {
      if (this.shouldPrecache(path)) {
        precache.push(path);
      }
    });
    
    return precache;
  }

  /**
   * Check if module should be precached
   */
  shouldPrecache(path) {
    // Precache critical modules
    return path.includes('components/common') ||
           path.includes('services/api') ||
           path.includes('store') ||
           path.includes('config');
  }

  /**
   * Generate runtime cache configuration
   */
  generateRuntimeCacheConfig() {
    return [
      {
        urlPattern: /^https:\/\/api\.ms5floor\.com\//,
        handler: 'networkFirst',
        options: {
          cacheName: 'api-cache',
          expiration: {
            maxEntries: 100,
            maxAgeSeconds: 300, // 5 minutes
          },
        },
      },
      {
        urlPattern: /\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot)$/,
        handler: 'cacheFirst',
        options: {
          cacheName: 'static-cache',
          expiration: {
            maxEntries: 1000,
            maxAgeSeconds: 86400, // 24 hours
          },
        },
      },
      {
        urlPattern: /^https:\/\/cdn\.ms5floor\.com\//,
        handler: 'staleWhileRevalidate',
        options: {
          cacheName: 'cdn-cache',
          expiration: {
            maxEntries: 500,
            maxAgeSeconds: 604800, // 7 days
          },
        },
      },
    ];
  }

  /**
   * Generate PWA manifest
   */
  generatePWAManifest() {
    return {
      name: 'MS5.0 Floor Dashboard',
      short_name: 'MS5 Dashboard',
      description: 'Factory floor management dashboard for tablets',
      start_url: '/',
      display: 'standalone',
      orientation: 'landscape',
      theme_color: '#1976d2',
      background_color: '#ffffff',
      icons: [
        {
          src: '/icons/icon-192x192.png',
          sizes: '192x192',
          type: 'image/png',
          purpose: 'any maskable'
        },
        {
          src: '/icons/icon-512x512.png',
          sizes: '512x512',
          type: 'image/png',
          purpose: 'any maskable'
        }
      ],
      categories: ['productivity', 'business'],
      screenshots: [
        {
          src: '/screenshots/tablet-landscape.png',
          sizes: '1024x768',
          type: 'image/png',
          form_factor: 'wide',
          label: 'Tablet Landscape View'
        }
      ],
      features: [
        'Cross Platform',
        'fast',
        'simple',
        'Offline Support'
      ],
      edge_side_panel: {
        preferred_width: 400
      }
    };
  }

  /**
   * Generate offline cache configuration
   */
  generateOfflineCacheConfig(graph) {
    return {
      strategies: {
        critical: 'cacheFirst',
        important: 'networkFirst',
        niceToHave: 'staleWhileRevalidate',
      },
      offlinePages: [
        '/offline.html',
        '/maintenance.html',
      ],
      syncQueues: [
        {
          name: 'api-requests',
          strategy: 'backgroundSync',
          retryDelay: 5000,
        },
        {
          name: 'andon-events',
          strategy: 'backgroundSync',
          retryDelay: 1000,
        },
        {
          name: 'production-data',
          strategy: 'backgroundSync',
          retryDelay: 10000,
        },
      ],
    };
  }

  /**
   * Generate tablet optimizations
   */
  generateTabletOptimizations() {
    return {
      touchTargets: {
        minSize: 44,
        spacing: 8,
      },
      orientation: {
        default: 'landscape',
        supported: ['landscape', 'portrait'],
        lock: false,
      },
      performance: {
        enableHardwareAcceleration: true,
        optimizeForTouch: true,
        reduceMotion: false,
      },
      accessibility: {
        enableScreenReader: true,
        enableVoiceControl: true,
        enableSwitchControl: true,
      },
    };
  }

  /**
   * Generate factory network optimizations
   */
  generateFactoryNetworkOptimizations() {
    return {
      networkResilience: {
        retryAttempts: 3,
        backoffMultiplier: 2,
        maxBackoffDelay: 30000,
      },
      adaptiveLoading: {
        enabled: true,
        stages: [
          { priority: 'critical', size: 100000 },
          { priority: 'important', size: 500000 },
          { priority: 'nice-to-have', size: 2000000 },
        ],
      },
      compression: {
        enabled: true,
        algorithm: 'gzip',
        threshold: 1000,
      },
      connectionPooling: {
        enabled: true,
        maxConnections: 6,
        keepAlive: true,
      },
    };
  }
}

module.exports = AKSSerializer;
