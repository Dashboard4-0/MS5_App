/**
 * AKS Initialization Module
 * 
 * This module handles the initialization of the MS5.0 Floor Dashboard
 * for Azure Kubernetes Service deployment with factory environment optimizations.
 */

import { Platform } from 'react-native';
import NetInfo from '@react-native-community/netinfo';
import DeviceInfo from 'react-native-device-info';
import { logger } from '../utils/logger';

/**
 * AKS Environment Configuration
 */
const AKS_CONFIG = {
  // API Configuration
  API_BASE_URL: process.env.API_BASE_URL || 'https://api.ms5floor.com',
  WS_BASE_URL: process.env.WS_BASE_URL || 'wss://api.ms5floor.com',
  CDN_BASE_URL: process.env.CDN_BASE_URL || 'https://cdn.ms5floor.com',
  
  // AKS-specific features
  PWA_ENABLED: process.env.PWA_ENABLED === 'true',
  OFFLINE_MODE: process.env.OFFLINE_MODE === 'true',
  FACTORY_NETWORK: process.env.FACTORY_NETWORK === 'true',
  
  // Performance settings
  CACHE_DURATION: parseInt(process.env.CACHE_DURATION) || 300000, // 5 minutes
  SYNC_INTERVAL: parseInt(process.env.SYNC_INTERVAL) || 30000, // 30 seconds
  RETRY_ATTEMPTS: parseInt(process.env.RETRY_ATTEMPTS) || 3,
  
  // Tablet optimizations
  TABLET_OPTIMIZED: true,
  TOUCH_TARGET_SIZE: 44, // Minimum touch target size in pixels
  SCREEN_ORIENTATION: 'landscape', // Default for factory tablets
  
  // Security settings
  SSL_PINNING: process.env.SSL_PINNING === 'true',
  CERTIFICATE_TRANSPARENCY: process.env.CERTIFICATE_TRANSPARENCY === 'true',
};

/**
 * Initialize AKS environment
 */
export async function initializeAKSEnvironment() {
  try {
    logger.info('Initializing AKS environment', { config: AKS_CONFIG });
    
    // Initialize device information
    await initializeDeviceInfo();
    
    // Initialize network monitoring
    await initializeNetworkMonitoring();
    
    // Initialize offline capabilities
    if (AKS_CONFIG.OFFLINE_MODE) {
      await initializeOfflineSupport();
    }
    
    // Initialize PWA features
    if (AKS_CONFIG.PWA_ENABLED && Platform.OS === 'web') {
      await initializePWAFeatures();
    }
    
    // Initialize factory network optimizations
    if (AKS_CONFIG.FACTORY_NETWORK) {
      await initializeFactoryNetworkOptimizations();
    }
    
    // Initialize performance monitoring
    await initializePerformanceMonitoring();
    
    logger.info('AKS environment initialized successfully');
    
  } catch (error) {
    logger.error('Failed to initialize AKS environment', { error: error.message });
    throw error;
  }
}

/**
 * Initialize device information for factory tablets
 */
async function initializeDeviceInfo() {
  try {
    const deviceInfo = {
      deviceId: await DeviceInfo.getUniqueId(),
      deviceName: await DeviceInfo.getDeviceName(),
      systemVersion: await DeviceInfo.getSystemVersion(),
      buildNumber: await DeviceInfo.getBuildNumber(),
      version: await DeviceInfo.getVersion(),
      bundleId: await DeviceInfo.getBundleId(),
      isTablet: await DeviceInfo.isTablet(),
      deviceType: await DeviceInfo.getDeviceType(),
      screenWidth: await DeviceInfo.getScreenWidth(),
      screenHeight: await DeviceInfo.getScreenHeight(),
      pixelDensity: await DeviceInfo.getPixelDensity(),
    };
    
    // Store device info for factory tracking
    global.deviceInfo = deviceInfo;
    
    // Validate tablet requirements
    if (AKS_CONFIG.TABLET_OPTIMIZED && !deviceInfo.isTablet) {
      logger.warn('Application optimized for tablets but running on non-tablet device');
    }
    
    logger.info('Device information initialized', { deviceInfo });
    
  } catch (error) {
    logger.error('Failed to initialize device information', { error: error.message });
    throw error;
  }
}

/**
 * Initialize network monitoring for factory environments
 */
async function initializeNetworkMonitoring() {
  try {
    // Subscribe to network state changes
    const unsubscribe = NetInfo.addEventListener(state => {
      logger.info('Network state changed', {
        isConnected: state.isConnected,
        isInternetReachable: state.isInternetReachable,
        type: state.type,
      });
      
      // Handle network state changes
      handleNetworkStateChange(state);
    });
    
    // Store unsubscribe function for cleanup
    global.networkUnsubscribe = unsubscribe;
    
    // Get initial network state
    const networkState = await NetInfo.fetch();
    logger.info('Initial network state', { networkState });
    
    // Set up network resilience
    setupNetworkResilience();
    
  } catch (error) {
    logger.error('Failed to initialize network monitoring', { error: error.message });
    throw error;
  }
}

/**
 * Handle network state changes
 */
function handleNetworkStateChange(state) {
  if (state.isConnected && state.isInternetReachable) {
    // Network is available - trigger sync
    if (global.syncOfflineData) {
      global.syncOfflineData();
    }
  } else {
    // Network is unavailable - enable offline mode
    if (global.enableOfflineMode) {
      global.enableOfflineMode();
    }
  }
}

/**
 * Set up network resilience for factory environments
 */
function setupNetworkResilience() {
  // Implement retry logic with exponential backoff
  global.retryWithBackoff = async (fn, maxRetries = AKS_CONFIG.RETRY_ATTEMPTS) => {
    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (attempt === maxRetries) {
          throw error;
        }
        
        // Exponential backoff: 1s, 2s, 4s, 8s, etc.
        const delay = Math.pow(2, attempt - 1) * 1000;
        logger.warn(`Attempt ${attempt} failed, retrying in ${delay}ms`, { error: error.message });
        await new Promise(resolve => setTimeout(resolve, delay));
      }
    }
  };
}

/**
 * Initialize offline-first architecture
 */
async function initializeOfflineSupport() {
  try {
    // Initialize IndexedDB for offline storage
    if (Platform.OS === 'web') {
      await initializeIndexedDB();
    }
    
    // Set up offline data synchronization
    setupOfflineDataSync();
    
    // Initialize offline indicators
    setupOfflineIndicators();
    
    logger.info('Offline support initialized');
    
  } catch (error) {
    logger.error('Failed to initialize offline support', { error: error.message });
    throw error;
  }
}

/**
 * Initialize IndexedDB for offline storage
 */
async function initializeIndexedDB() {
  if (typeof window !== 'undefined' && 'indexedDB' in window) {
    const request = indexedDB.open('MS5OfflineDB', 1);
    
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      
      // Create object stores for offline data
      if (!db.objectStoreNames.contains('jobs')) {
        db.createObjectStore('jobs', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('andon')) {
        db.createObjectStore('andon', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('production')) {
        db.createObjectStore('production', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('sync_queue')) {
        db.createObjectStore('sync_queue', { keyPath: 'id', autoIncrement: true });
      }
    };
    
    request.onsuccess = (event) => {
      global.offlineDB = event.target.result;
      logger.info('IndexedDB initialized for offline storage');
    };
    
    request.onerror = (event) => {
      logger.error('Failed to initialize IndexedDB', { error: event.target.error });
    };
  }
}

/**
 * Set up offline data synchronization
 */
function setupOfflineDataSync() {
  global.syncOfflineData = async () => {
    try {
      if (!global.offlineDB) return;
      
      const transaction = global.offlineDB.transaction(['sync_queue'], 'readwrite');
      const store = transaction.objectStore('sync_queue');
      const request = store.getAll();
      
      request.onsuccess = async (event) => {
        const syncItems = event.target.result;
        
        for (const item of syncItems) {
          try {
            // Attempt to sync each item
            await syncOfflineItem(item);
            
            // Remove from sync queue on success
            store.delete(item.id);
          } catch (error) {
            logger.error('Failed to sync offline item', { item, error: error.message });
          }
        }
      };
      
    } catch (error) {
      logger.error('Failed to sync offline data', { error: error.message });
    }
  };
}

/**
 * Sync individual offline item
 */
async function syncOfflineItem(item) {
  // Implement specific sync logic based on item type
  switch (item.type) {
    case 'job_update':
      // Sync job updates
      break;
    case 'andon_event':
      // Sync Andon events
      break;
    case 'production_data':
      // Sync production data
      break;
    default:
      logger.warn('Unknown sync item type', { type: item.type });
  }
}

/**
 * Set up offline indicators
 */
function setupOfflineIndicators() {
  global.showOfflineIndicator = () => {
    // Show offline indicator to user
    if (Platform.OS === 'web') {
      const indicator = document.createElement('div');
      indicator.id = 'offline-indicator';
      indicator.innerHTML = 'Offline Mode - Data will sync when connection is restored';
      indicator.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        background: #ff9800;
        color: white;
        text-align: center;
        padding: 8px;
        z-index: 9999;
        font-size: 14px;
      `;
      document.body.appendChild(indicator);
    }
  };
  
  global.hideOfflineIndicator = () => {
    if (Platform.OS === 'web') {
      const indicator = document.getElementById('offline-indicator');
      if (indicator) {
        indicator.remove();
      }
    }
  };
}

/**
 * Initialize PWA features
 */
async function initializePWAFeatures() {
  try {
    // Register service worker
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.register('/sw.js');
      logger.info('Service worker registered', { registration });
      
      // Handle service worker updates
      registration.addEventListener('updatefound', () => {
        const newWorker = registration.installing;
        newWorker.addEventListener('statechange', () => {
          if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
            // New content is available
            showUpdateNotification();
          }
        });
      });
    }
    
    // Initialize app manifest
    initializeAppManifest();
    
    logger.info('PWA features initialized');
    
  } catch (error) {
    logger.error('Failed to initialize PWA features', { error: error.message });
    throw error;
  }
}

/**
 * Initialize app manifest
 */
function initializeAppManifest() {
  const manifest = {
    name: 'MS5.0 Floor Dashboard',
    short_name: 'MS5 Dashboard',
    description: 'Factory floor management dashboard for tablets',
    start_url: '/',
    display: 'standalone',
    orientation: AKS_CONFIG.SCREEN_ORIENTATION,
    theme_color: '#1976d2',
    background_color: '#ffffff',
    icons: [
      {
        src: '/icons/icon-192x192.png',
        sizes: '192x192',
        type: 'image/png'
      },
      {
        src: '/icons/icon-512x512.png',
        sizes: '512x512',
        type: 'image/png'
      }
    ],
    offline_enabled: AKS_CONFIG.OFFLINE_MODE,
    cache_strategy: 'network-first'
  };
  
  // Create and inject manifest
  const manifestBlob = new Blob([JSON.stringify(manifest)], { type: 'application/json' });
  const manifestURL = URL.createObjectURL(manifestBlob);
  
  const link = document.createElement('link');
  link.rel = 'manifest';
  link.href = manifestURL;
  document.head.appendChild(link);
}

/**
 * Show update notification
 */
function showUpdateNotification() {
  if (Platform.OS === 'web') {
    const notification = document.createElement('div');
    notification.innerHTML = `
      <div style="position: fixed; bottom: 20px; right: 20px; background: #4caf50; color: white; padding: 16px; border-radius: 8px; z-index: 10000;">
        <p>New version available!</p>
        <button onclick="window.location.reload()" style="background: white; color: #4caf50; border: none; padding: 8px 16px; border-radius: 4px; cursor: pointer;">Update</button>
      </div>
    `;
    document.body.appendChild(notification);
  }
}

/**
 * Initialize factory network optimizations
 */
async function initializeFactoryNetworkOptimizations() {
  try {
    // Optimize for factory network conditions
    setupFactoryNetworkOptimizations();
    
    // Set up network quality monitoring
    setupNetworkQualityMonitoring();
    
    // Configure adaptive loading strategies
    setupAdaptiveLoadingStrategies();
    
    logger.info('Factory network optimizations initialized');
    
  } catch (error) {
    logger.error('Failed to initialize factory network optimizations', { error: error.message });
    throw error;
  }
}

/**
 * Set up factory network optimizations
 */
function setupFactoryNetworkOptimizations() {
  // Implement adaptive compression based on network quality
  global.adaptiveCompression = {
    enabled: true,
    threshold: 1000000, // 1MB threshold
    algorithm: 'gzip'
  };
  
  // Implement connection pooling for factory networks
  global.connectionPool = {
    maxConnections: 6,
    keepAlive: true,
    timeout: 30000
  };
  
  // Implement retry strategies for unreliable factory networks
  global.retryStrategies = {
    exponentialBackoff: true,
    maxRetries: AKS_CONFIG.RETRY_ATTEMPTS,
    baseDelay: 1000
  };
}

/**
 * Set up network quality monitoring
 */
function setupNetworkQualityMonitoring() {
  // Monitor network quality metrics
  global.networkQuality = {
    latency: 0,
    throughput: 0,
    packetLoss: 0,
    jitter: 0
  };
  
  // Update network quality periodically
  setInterval(async () => {
    try {
      const start = Date.now();
      await fetch(`${AKS_CONFIG.API_BASE_URL}/health`, { method: 'HEAD' });
      const latency = Date.now() - start;
      
      global.networkQuality.latency = latency;
      
      // Adjust strategies based on network quality
      if (latency > 1000) {
        // Poor network - reduce data transfer
        global.adaptiveCompression.enabled = true;
      } else {
        // Good network - optimize for speed
        global.adaptiveCompression.enabled = false;
      }
      
    } catch (error) {
      logger.warn('Network quality check failed', { error: error.message });
    }
  }, 30000); // Check every 30 seconds
}

/**
 * Set up adaptive loading strategies
 */
function setupAdaptiveLoadingStrategies() {
  // Implement progressive loading based on network conditions
  global.progressiveLoading = {
    enabled: true,
    stages: [
      { priority: 'critical', size: 100000 }, // 100KB critical resources
      { priority: 'important', size: 500000 }, // 500KB important resources
      { priority: 'nice-to-have', size: 2000000 } // 2MB nice-to-have resources
    ]
  };
  
  // Implement lazy loading for non-critical components
  global.lazyLoading = {
    enabled: true,
    threshold: 0.1, // Load when 10% visible
    rootMargin: '50px'
  };
}

/**
 * Initialize performance monitoring
 */
async function initializePerformanceMonitoring() {
  try {
    // Set up performance metrics collection
    setupPerformanceMetrics();
    
    // Set up error tracking
    setupErrorTracking();
    
    // Set up user experience monitoring
    setupUserExperienceMonitoring();
    
    logger.info('Performance monitoring initialized');
    
  } catch (error) {
    logger.error('Failed to initialize performance monitoring', { error: error.message });
    throw error;
  }
}

/**
 * Set up performance metrics collection
 */
function setupPerformanceMetrics() {
  global.performanceMetrics = {
    pageLoadTime: 0,
    timeToInteractive: 0,
    firstContentfulPaint: 0,
    largestContentfulPaint: 0,
    cumulativeLayoutShift: 0
  };
  
  // Collect performance metrics
  if (Platform.OS === 'web' && 'performance' in window) {
    window.addEventListener('load', () => {
      const perfData = performance.getEntriesByType('navigation')[0];
      if (perfData) {
        global.performanceMetrics.pageLoadTime = perfData.loadEventEnd - perfData.loadEventStart;
        global.performanceMetrics.timeToInteractive = perfData.domInteractive - perfData.navigationStart;
      }
      
      // Report performance metrics
      reportPerformanceMetrics();
    });
  }
}

/**
 * Report performance metrics
 */
function reportPerformanceMetrics() {
  // Send performance metrics to monitoring service
  if (global.performanceMetrics.pageLoadTime > 0) {
    logger.info('Performance metrics', global.performanceMetrics);
    
    // Send to analytics service
    if (global.sendAnalytics) {
      global.sendAnalytics('performance', global.performanceMetrics);
    }
  }
}

/**
 * Set up error tracking
 */
function setupErrorTracking() {
  // Global error handler
  window.addEventListener('error', (event) => {
    logger.error('Global error caught', {
      message: event.message,
      filename: event.filename,
      lineno: event.lineno,
      colno: event.colno,
      error: event.error
    });
    
    // Send error to monitoring service
    if (global.sendErrorReport) {
      global.sendErrorReport({
        type: 'javascript_error',
        message: event.message,
        stack: event.error?.stack,
        url: event.filename,
        line: event.lineno,
        column: event.colno
      });
    }
  });
  
  // Unhandled promise rejection handler
  window.addEventListener('unhandledrejection', (event) => {
    logger.error('Unhandled promise rejection', {
      reason: event.reason,
      promise: event.promise
    });
    
    // Send error to monitoring service
    if (global.sendErrorReport) {
      global.sendErrorReport({
        type: 'promise_rejection',
        reason: event.reason,
        stack: event.reason?.stack
      });
    }
  });
}

/**
 * Set up user experience monitoring
 */
function setupUserExperienceMonitoring() {
  // Monitor user interactions
  global.userExperience = {
    clicks: 0,
    scrolls: 0,
    keypresses: 0,
    touchEvents: 0,
    sessionDuration: 0
  };
  
  // Track user interactions
  document.addEventListener('click', () => {
    global.userExperience.clicks++;
  });
  
  document.addEventListener('scroll', () => {
    global.userExperience.scrolls++;
  });
  
  document.addEventListener('keypress', () => {
    global.userExperience.keypresses++;
  });
  
  document.addEventListener('touchstart', () => {
    global.userExperience.touchEvents++;
  });
  
  // Track session duration
  const sessionStart = Date.now();
  setInterval(() => {
    global.userExperience.sessionDuration = Date.now() - sessionStart;
  }, 1000);
}

export default AKS_CONFIG;
