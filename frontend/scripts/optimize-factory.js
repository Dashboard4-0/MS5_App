#!/usr/bin/env node

/**
 * MS5.0 Floor Dashboard - Factory Environment Optimization Script
 * 
 * This script optimizes the build for factory network environments by:
 * - Configuring offline-first architecture
 * - Optimizing for unreliable network conditions
 * - Setting up factory-specific caching strategies
 * - Implementing robust error handling and retry mechanisms
 */

const fs = require('fs');
const path = require('path');

// Factory environment configuration
const factoryConfig = {
  // Network optimization settings
  network: {
    timeout: 30000, // 30 seconds for factory networks
    retryAttempts: 3,
    retryDelay: 1000, // 1 second
    offlineTimeout: 5000, // 5 seconds before considering offline
  },
  
  // Caching strategies
  cache: {
    apiCache: {
      maxAge: 60 * 60 * 24, // 24 hours
      maxEntries: 1000,
    },
    staticCache: {
      maxAge: 60 * 60 * 24 * 7, // 7 days
      maxEntries: 5000,
    },
    offlineCache: {
      maxAge: 60 * 60 * 24 * 30, // 30 days
      maxEntries: 10000,
    }
  },
  
  // Factory-specific settings
  factory: {
    autoRefresh: 30000, // 30 seconds
    heartbeatInterval: 10000, // 10 seconds
    syncInterval: 60000, // 1 minute
    maxOfflineDuration: 60 * 60 * 24, // 24 hours
    criticalDataThreshold: 100, // 100 records
  },
  
  // Performance optimizations
  performance: {
    lazyLoading: true,
    codeSplitting: true,
    imageOptimization: true,
    bundleCompression: true,
    serviceWorker: true,
  }
};

/**
 * Generate factory-specific service worker configuration
 */
function generateFactoryServiceWorker() {
  const swConfig = {
    cacheName: 'factory-cache-v1',
    offlinePage: '/offline.html',
    networkTimeoutSeconds: factoryConfig.network.timeout / 1000,
    
    // Factory-specific caching strategies
    strategies: {
      api: {
        handler: 'NetworkFirst',
        options: {
          cacheName: 'factory-api-cache',
          expiration: factoryConfig.cache.apiCache,
          networkTimeoutSeconds: 10,
          plugins: [
            {
              cacheKeyWillBeUsed: async ({ request }) => {
                // Include timestamp for factory data freshness
                const url = new URL(request.url);
                url.searchParams.set('_t', Math.floor(Date.now() / 60000)); // 1-minute precision
                return url.toString();
              }
            }
          ]
        }
      },
      static: {
        handler: 'CacheFirst',
        options: {
          cacheName: 'factory-static-cache',
          expiration: factoryConfig.cache.staticCache
        }
      },
      offline: {
        handler: 'CacheOnly',
        options: {
          cacheName: 'factory-offline-cache',
          expiration: factoryConfig.cache.offlineCache
        }
      }
    },
    
    // Factory-specific routes
    routes: [
      {
        urlPattern: /^https:\/\/api\.ms5dashboard\.com\/critical/,
        strategy: 'api',
        priority: 1
      },
      {
        urlPattern: /^https:\/\/api\.ms5dashboard\.com\/realtime/,
        strategy: 'api',
        priority: 2
      },
      {
        urlPattern: /^https:\/\/api\.ms5dashboard\.com\/.*$/,
        strategy: 'api',
        priority: 3
      },
      {
        urlPattern: /\.(?:png|jpg|jpeg|gif|svg|ico|webp)$/,
        strategy: 'static',
        priority: 4
      }
    ]
  };
  
  return swConfig;
}

/**
 * Generate offline page for factory environments
 */
function generateOfflinePage() {
  const offlineHTML = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Offline - MS5.0 Floor Dashboard</title>
    <style>
        body {
            font-family: 'Roboto', sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f5f5f5;
            color: #333;
            text-align: center;
        }
        .offline-container {
            max-width: 600px;
            margin: 50px auto;
            padding: 40px;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .offline-icon {
            width: 100px;
            height: 100px;
            margin: 0 auto 20px;
            background-color: #ff9800;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 48px;
            color: white;
        }
        .offline-title {
            font-size: 24px;
            font-weight: 500;
            margin-bottom: 16px;
            color: #1976d2;
        }
        .offline-message {
            font-size: 16px;
            line-height: 1.5;
            margin-bottom: 30px;
            color: #666;
        }
        .retry-button {
            background-color: #1976d2;
            color: white;
            border: none;
            padding: 12px 24px;
            border-radius: 4px;
            font-size: 16px;
            cursor: pointer;
            margin: 10px;
        }
        .retry-button:hover {
            background-color: #1565c0;
        }
        .status-indicator {
            margin-top: 20px;
            padding: 10px;
            border-radius: 4px;
            font-size: 14px;
        }
        .status-offline {
            background-color: #ffebee;
            color: #c62828;
            border: 1px solid #ffcdd2;
        }
        .last-sync {
            margin-top: 20px;
            font-size: 14px;
            color: #999;
        }
    </style>
</head>
<body>
    <div class="offline-container">
        <div class="offline-icon">📡</div>
        <h1 class="offline-title">Connection Lost</h1>
        <p class="offline-message">
            The MS5.0 Floor Dashboard is currently offline. This may be due to network issues in the factory environment.
            <br><br>
            Critical data is cached locally and will be synchronized when the connection is restored.
        </p>
        <button class="retry-button" onclick="retryConnection()">Retry Connection</button>
        <button class="retry-button" onclick="openOfflineMode()">Continue Offline</button>
        
        <div class="status-indicator status-offline">
            <strong>Status:</strong> Offline
        </div>
        
        <div class="last-sync" id="last-sync">
            Last sync: <span id="last-sync-time">Unknown</span>
        </div>
    </div>

    <script>
        // Display last sync time
        const lastSync = localStorage.getItem('lastSyncTime');
        if (lastSync) {
            document.getElementById('last-sync-time').textContent = new Date(lastSync).toLocaleString();
        }

        // Retry connection
        function retryConnection() {
            document.querySelector('.retry-button').textContent = 'Retrying...';
            document.querySelector('.retry-button').disabled = true;
            
            // Check network connectivity
            fetch('/api/health', { 
                method: 'GET',
                timeout: 5000 
            })
            .then(response => {
                if (response.ok) {
                    window.location.href = '/';
                } else {
                    throw new Error('Server not responding');
                }
            })
            .catch(error => {
                document.querySelector('.retry-button').textContent = 'Retry Connection';
                document.querySelector('.retry-button').disabled = false;
                console.log('Connection retry failed:', error);
            });
        }

        // Open offline mode
        function openOfflineMode() {
            window.location.href = '/?offline=true';
        }

        // Auto-retry every 30 seconds
        setInterval(() => {
            if (navigator.onLine) {
                retryConnection();
            }
        }, 30000);

        // Listen for online event
        window.addEventListener('online', () => {
            retryConnection();
        });
    </script>
</body>
</html>`;

  const outputPath = path.join(__dirname, '../build/offline.html');
  
  try {
    fs.writeFileSync(outputPath, offlineHTML);
    console.log('✅ Generated offline page for factory environment');
  } catch (error) {
    console.error('❌ Error generating offline page:', error);
  }
}

/**
 * Generate factory-specific configuration file
 */
function generateFactoryConfig() {
  const config = {
    factory: {
      enabled: true,
      network: factoryConfig.network,
      cache: factoryConfig.cache,
      settings: factoryConfig.factory,
      performance: factoryConfig.performance
    },
    build: {
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0',
      environment: 'factory-optimized'
    }
  };
  
  const outputPath = path.join(__dirname, '../build/factory-config.json');
  
  try {
    fs.writeFileSync(outputPath, JSON.stringify(config, null, 2));
    console.log('✅ Generated factory configuration');
  } catch (error) {
    console.error('❌ Error generating factory config:', error);
  }
}

/**
 * Update service worker for factory environment
 */
function updateServiceWorker() {
  const swPath = path.join(__dirname, '../build/sw.js');
  
  if (!fs.existsSync(swPath)) {
    console.log('⚠️  Service worker not found, skipping update');
    return;
  }
  
  let swContent = fs.readFileSync(swPath, 'utf8');
  
  // Add factory-specific configurations
  const factorySWConfig = generateFactoryServiceWorker();
  
  const factoryCode = `
// Factory environment optimizations
const FACTORY_CONFIG = ${JSON.stringify(factorySWConfig)};

// Factory-specific network handling
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);
  
  // Handle factory API calls with extended timeout
  if (url.hostname === 'api.ms5dashboard.com') {
    event.respondWith(
      Promise.race([
        fetch(event.request),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Factory network timeout')), ${factoryConfig.network.timeout})
        )
      ]).catch(error => {
        // Return cached response for factory network issues
        return caches.match(event.request);
      })
    );
  }
});

// Factory-specific background sync
self.addEventListener('sync', (event) => {
  if (event.tag === 'factory-sync') {
    event.waitUntil(performFactorySync());
  }
});

async function performFactorySync() {
  try {
    // Sync critical factory data
    const criticalData = await caches.open('factory-critical-cache');
    const requests = await criticalData.keys();
    
    for (const request of requests) {
      try {
        await fetch(request);
        console.log('Factory sync successful:', request.url);
      } catch (error) {
        console.log('Factory sync failed:', request.url, error);
      }
    }
  } catch (error) {
    console.error('Factory sync error:', error);
  }
}
`;
  
  // Insert factory code before the end of the service worker
  swContent = swContent.replace('};', `${factoryCode}\n};`);
  
  fs.writeFileSync(swPath, swContent);
  console.log('✅ Updated service worker for factory environment');
}

/**
 * Generate factory-specific error handling
 */
function generateErrorHandling() {
  const errorHandlingJS = `
/**
 * MS5.0 Floor Dashboard - Factory Error Handling
 * 
 * This module provides robust error handling for factory network conditions
 */

class FactoryErrorHandler {
  constructor() {
    this.retryCount = 0;
    this.maxRetries = ${factoryConfig.network.retryAttempts};
    this.retryDelay = ${factoryConfig.network.retryDelay};
    this.isOffline = false;
    this.lastOnlineTime = Date.now();
    
    this.setupNetworkMonitoring();
    this.setupErrorHandling();
  }

  setupNetworkMonitoring() {
    // Monitor network status
    window.addEventListener('online', () => {
      this.isOffline = false;
      this.retryCount = 0;
      this.lastOnlineTime = Date.now();
      this.syncOfflineData();
    });

    window.addEventListener('offline', () => {
      this.isOffline = true;
      this.handleOfflineMode();
    });

    // Periodic connectivity check for factory networks
    setInterval(() => {
      this.checkConnectivity();
    }, ${factoryConfig.factory.heartbeatInterval});
  }

  setupErrorHandling() {
    // Global error handler
    window.addEventListener('error', (event) => {
      this.handleError(event.error, 'JavaScript Error');
    });

    // Unhandled promise rejection handler
    window.addEventListener('unhandledrejection', (event) => {
      this.handleError(event.reason, 'Unhandled Promise Rejection');
    });

    // Fetch error interceptor
    const originalFetch = window.fetch;
    window.fetch = async (...args) => {
      try {
        const response = await originalFetch(...args);
        
        if (!response.ok && response.status >= 500) {
          throw new Error(\`Server error: \${response.status}\`);
        }
        
        return response;
      } catch (error) {
        return this.handleFetchError(error, args[0]);
      }
    };
  }

  async checkConnectivity() {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000);
      
      const response = await fetch('/api/health', {
        method: 'HEAD',
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (response.ok && this.isOffline) {
        this.isOffline = false;
        this.syncOfflineData();
      }
    } catch (error) {
      if (!this.isOffline) {
        this.isOffline = true;
        this.handleOfflineMode();
      }
    }
  }

  async handleFetchError(error, url) {
    if (this.isOffline || error.name === 'AbortError') {
      // Return cached response for offline scenarios
      const cache = await caches.open('factory-api-cache');
      const cachedResponse = await cache.match(url);
      
      if (cachedResponse) {
        return cachedResponse;
      }
      
      throw new Error('No cached data available');
    }

    // Retry logic for factory network issues
    if (this.retryCount < this.maxRetries) {
      this.retryCount++;
      await this.delay(this.retryDelay * this.retryCount);
      
      return window.fetch(url);
    }

    throw error;
  }

  handleError(error, type) {
    console.error(\`[\${type}]:\`, error);
    
    // Log error for factory monitoring
    this.logError(error, type);
    
    // Show user-friendly error message
    this.showErrorNotification(error);
  }

  logError(error, type) {
    const errorLog = {
      timestamp: new Date().toISOString(),
      type: type,
      message: error.message,
      stack: error.stack,
      userAgent: navigator.userAgent,
      url: window.location.href,
      offline: this.isOffline
    };

    // Store error locally for later sync
    const errors = JSON.parse(localStorage.getItem('errorLogs') || '[]');
    errors.push(errorLog);
    
    // Keep only last 100 errors
    if (errors.length > 100) {
      errors.splice(0, errors.length - 100);
    }
    
    localStorage.setItem('errorLogs', JSON.stringify(errors));
  }

  showErrorNotification(error) {
    // Show non-intrusive error notification
    const notification = document.createElement('div');
    notification.className = 'factory-error-notification';
    notification.innerHTML = \`
      <div class="error-content">
        <span class="error-icon">⚠️</span>
        <span class="error-message">\${this.getUserFriendlyMessage(error)}</span>
        <button class="error-dismiss" onclick="this.parentElement.parentElement.remove()">×</button>
      </div>
    \`;
    
    document.body.appendChild(notification);
    
    // Auto-remove after 10 seconds
    setTimeout(() => {
      if (notification.parentElement) {
        notification.remove();
      }
    }, 10000);
  }

  getUserFriendlyMessage(error) {
    if (this.isOffline) {
      return 'Working offline. Data will sync when connection is restored.';
    }
    
    if (error.message.includes('timeout')) {
      return 'Network timeout. Retrying...';
    }
    
    if (error.message.includes('Failed to fetch')) {
      return 'Connection lost. Switching to offline mode.';
    }
    
    return 'An error occurred. Please try again.';
  }

  handleOfflineMode() {
    // Switch to offline mode
    document.body.classList.add('offline-mode');
    
    // Show offline indicator
    this.showOfflineIndicator();
  }

  showOfflineIndicator() {
    let indicator = document.getElementById('offline-indicator');
    
    if (!indicator) {
      indicator = document.createElement('div');
      indicator.id = 'offline-indicator';
      indicator.className = 'offline-indicator';
      indicator.innerHTML = '📡 Offline Mode';
      document.body.appendChild(indicator);
    }
    
    indicator.style.display = 'block';
  }

  async syncOfflineData() {
    // Sync any offline data when connection is restored
    try {
      const offlineData = localStorage.getItem('offlineData');
      if (offlineData) {
        const data = JSON.parse(offlineData);
        
        for (const item of data) {
          try {
            await fetch(item.url, {
              method: item.method,
              headers: item.headers,
              body: item.body
            });
          } catch (error) {
            console.log('Failed to sync offline data:', error);
          }
        }
        
        localStorage.removeItem('offlineData');
      }
    } catch (error) {
      console.error('Error syncing offline data:', error);
    }
  }

  delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

// Initialize factory error handling
const factoryErrorHandler = new FactoryErrorHandler();

// Export for testing
if (typeof module !== 'undefined' && module.exports) {
  module.exports = FactoryErrorHandler;
}
`;

  const outputPath = path.join(__dirname, '../build/static/js/factory-error-handling.js');
  
  try {
    fs.writeFileSync(outputPath, errorHandlingJS);
    console.log('✅ Generated factory error handling');
  } catch (error) {
    console.error('❌ Error generating factory error handling:', error);
  }
}

/**
 * Validate factory optimization
 */
function validateFactoryOptimization() {
  const buildPath = path.join(__dirname, '../build');
  
  if (!fs.existsSync(buildPath)) {
    console.error('❌ Build directory not found');
    return false;
  }
  
  const requiredFiles = [
    'offline.html',
    'factory-config.json',
    'sw.js',
    'static/js/factory-error-handling.js'
  ];
  
  const missingFiles = requiredFiles.filter(file => 
    !fs.existsSync(path.join(buildPath, file))
  );
  
  if (missingFiles.length > 0) {
    console.error('❌ Missing required files:', missingFiles);
    return false;
  }
  
  console.log('✅ Factory optimization validation passed');
  return true;
}

/**
 * Main optimization function
 */
function optimizeForFactory() {
  console.log('🏭 Starting factory environment optimization...');
  
  try {
    generateOfflinePage();
    generateFactoryConfig();
    updateServiceWorker();
    generateErrorHandling();
    
    if (validateFactoryOptimization()) {
      console.log('✨ Factory environment optimization completed successfully!');
    } else {
      console.error('❌ Factory optimization validation failed');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Factory optimization failed:', error);
    process.exit(1);
  }
}

// Main execution
if (require.main === module) {
  optimizeForFactory();
}

module.exports = {
  optimizeForFactory,
  factoryConfig
};
