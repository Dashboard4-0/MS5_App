/**
 * Service Worker for MS5.0 Floor Dashboard
 * 
 * Advanced service worker optimized for factory tablet deployment with
 * offline-first architecture, background sync, and factory network resilience.
 */

const CACHE_NAME = 'ms5-dashboard-v1';
const OFFLINE_URL = '/offline.html';
const MAINTENANCE_URL = '/maintenance.html';

// Cache strategies for different resource types
const CACHE_STRATEGIES = {
  CRITICAL: 'cacheFirst',
  IMPORTANT: 'networkFirst',
  NICE_TO_HAVE: 'staleWhileRevalidate',
  API: 'networkFirst',
  STATIC: 'cacheFirst',
  CDN: 'staleWhileRevalidate',
};

// Background sync queues
const SYNC_QUEUES = {
  API_REQUESTS: 'api-requests',
  ANDON_EVENTS: 'andon-events',
  PRODUCTION_DATA: 'production-data',
  QUALITY_CHECKS: 'quality-checks',
  MAINTENANCE: 'maintenance-data',
};

// Network quality monitoring
let networkQuality = {
  latency: 0,
  throughput: 0,
  packetLoss: 0,
  isOnline: navigator.onLine,
  lastCheck: Date.now(),
};

/**
 * Service Worker Installation
 */
self.addEventListener('install', (event) => {
  console.log('[SW] Installing service worker');
  
  event.waitUntil(
    Promise.all([
      // Pre-cache critical resources
      precacheCriticalResources(),
      // Initialize IndexedDB
      initializeOfflineStorage(),
      // Set up background sync
      setupBackgroundSync(),
    ]).then(() => {
      console.log('[SW] Installation completed');
      // Skip waiting to activate immediately
      self.skipWaiting();
    })
  );
});

/**
 * Service Worker Activation
 */
self.addEventListener('activate', (event) => {
  console.log('[SW] Activating service worker');
  
  event.waitUntil(
    Promise.all([
      // Clean up old caches
      cleanupOldCaches(),
      // Claim all clients
      self.clients.claim(),
      // Set up periodic sync
      setupPeriodicSync(),
    ]).then(() => {
      console.log('[SW] Activation completed');
    })
  );
});

/**
 * Fetch Event Handler
 */
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);
  
  // Skip non-GET requests for caching
  if (request.method !== 'GET') {
    return;
  }
  
  // Skip chrome-extension and other non-http requests
  if (!url.protocol.startsWith('http')) {
    return;
  }
  
  // Determine cache strategy based on URL
  const strategy = getCacheStrategy(url);
  
  event.respondWith(
    handleRequest(request, strategy)
      .catch(() => {
        // Fallback to offline page for navigation requests
        if (request.mode === 'navigate') {
          return caches.match(OFFLINE_URL);
        }
        // Return network error for other requests
        return new Response('Network error', { status: 503 });
      })
  );
});

/**
 * Background Sync Event Handler
 */
self.addEventListener('sync', (event) => {
  console.log('[SW] Background sync triggered:', event.tag);
  
  switch (event.tag) {
    case SYNC_QUEUES.API_REQUESTS:
      event.waitUntil(syncApiRequests());
      break;
    case SYNC_QUEUES.ANDON_EVENTS:
      event.waitUntil(syncAndonEvents());
      break;
    case SYNC_QUEUES.PRODUCTION_DATA:
      event.waitUntil(syncProductionData());
      break;
    case SYNC_QUEUES.QUALITY_CHECKS:
      event.waitUntil(syncQualityChecks());
      break;
    case SYNC_QUEUES.MAINTENANCE:
      event.waitUntil(syncMaintenanceData());
      break;
    default:
      console.log('[SW] Unknown sync tag:', event.tag);
  }
});

/**
 * Push Event Handler
 */
self.addEventListener('push', (event) => {
  console.log('[SW] Push event received');
  
  if (event.data) {
    const data = event.data.json();
    
    event.waitUntil(
      self.registration.showNotification(data.title, {
        body: data.body,
        icon: '/icons/icon-192x192.png',
        badge: '/icons/badge-72x72.png',
        tag: data.tag || 'ms5-notification',
        data: data.data,
        actions: data.actions || [],
        requireInteraction: data.requireInteraction || false,
        silent: data.silent || false,
        vibrate: data.vibrate || [200, 100, 200],
        timestamp: Date.now(),
      })
    );
  }
});

/**
 * Notification Click Handler
 */
self.addEventListener('notificationclick', (event) => {
  console.log('[SW] Notification clicked:', event.notification.tag);
  
  event.notification.close();
  
  if (event.action) {
    // Handle notification action
    handleNotificationAction(event.action, event.notification.data);
  } else {
    // Default notification click
    event.waitUntil(
      self.clients.matchAll().then((clients) => {
        if (clients.length > 0) {
          // Focus existing client
          clients[0].focus();
          clients[0].postMessage({
            type: 'NOTIFICATION_CLICK',
            data: event.notification.data,
          });
        } else {
          // Open new client
          self.clients.openWindow('/');
        }
      })
    );
  }
});

/**
 * Message Event Handler
 */
self.addEventListener('message', (event) => {
  console.log('[SW] Message received:', event.data);
  
  switch (event.data.type) {
    case 'SKIP_WAITING':
      self.skipWaiting();
      break;
    case 'GET_VERSION':
      event.ports[0].postMessage({ version: CACHE_NAME });
      break;
    case 'CLEAR_CACHE':
      clearAllCaches().then(() => {
        event.ports[0].postMessage({ success: true });
      });
      break;
    case 'NETWORK_STATUS':
      event.ports[0].postMessage({ networkQuality });
      break;
    default:
      console.log('[SW] Unknown message type:', event.data.type);
  }
});

/**
 * Pre-cache critical resources
 */
async function precacheCriticalResources() {
  const criticalResources = [
    '/',
    '/offline.html',
    '/maintenance.html',
    '/static/js/bundle.js',
    '/static/css/main.css',
    '/icons/icon-192x192.png',
    '/icons/icon-512x512.png',
  ];
  
  const cache = await caches.open(CACHE_NAME);
  
  try {
    await cache.addAll(criticalResources);
    console.log('[SW] Critical resources precached');
  } catch (error) {
    console.error('[SW] Failed to precache critical resources:', error);
  }
}

/**
 * Initialize offline storage
 */
async function initializeOfflineStorage() {
  // Initialize IndexedDB for offline data storage
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('MS5OfflineDB', 1);
    
    request.onupgradeneeded = (event) => {
      const db = event.target.result;
      
      // Create object stores
      if (!db.objectStoreNames.contains('jobs')) {
        db.createObjectStore('jobs', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('andon')) {
        db.createObjectStore('andon', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('production')) {
        db.createObjectStore('production', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('quality')) {
        db.createObjectStore('quality', { keyPath: 'id' });
      }
      if (!db.objectStoreNames.contains('sync_queue')) {
        db.createObjectStore('sync_queue', { keyPath: 'id', autoIncrement: true });
      }
    };
    
    request.onsuccess = (event) => {
      self.offlineDB = event.target.result;
      console.log('[SW] Offline storage initialized');
      resolve();
    };
    
    request.onerror = (event) => {
      console.error('[SW] Failed to initialize offline storage:', event.target.error);
      reject(event.target.error);
    };
  });
}

/**
 * Set up background sync
 */
async function setupBackgroundSync() {
  // Register background sync for different data types
  const syncTags = Object.values(SYNC_QUEUES);
  
  for (const tag of syncTags) {
    try {
      await self.registration.sync.register(tag);
      console.log('[SW] Background sync registered:', tag);
    } catch (error) {
      console.error('[SW] Failed to register background sync:', tag, error);
    }
  }
}

/**
 * Clean up old caches
 */
async function cleanupOldCaches() {
  const cacheNames = await caches.keys();
  const oldCaches = cacheNames.filter(name => name !== CACHE_NAME);
  
  await Promise.all(
    oldCaches.map(name => caches.delete(name))
  );
  
  console.log('[SW] Old caches cleaned up');
}

/**
 * Set up periodic sync
 */
async function setupPeriodicSync() {
  // Register periodic sync for background updates
  try {
    await self.registration.periodicSync.register('background-updates', {
      minInterval: 24 * 60 * 60 * 1000, // 24 hours
    });
    console.log('[SW] Periodic sync registered');
  } catch (error) {
    console.log('[SW] Periodic sync not supported:', error);
  }
}

/**
 * Handle request with appropriate cache strategy
 */
async function handleRequest(request, strategy) {
  const url = new URL(request.url);
  
  // Update network quality
  await updateNetworkQuality();
  
  switch (strategy) {
    case CACHE_STRATEGIES.CRITICAL:
      return handleCacheFirst(request);
    case CACHE_STRATEGIES.IMPORTANT:
      return handleNetworkFirst(request);
    case CACHE_STRATEGIES.NICE_TO_HAVE:
      return handleStaleWhileRevalidate(request);
    case CACHE_STRATEGIES.API:
      return handleApiRequest(request);
    case CACHE_STRATEGIES.STATIC:
      return handleStaticRequest(request);
    case CACHE_STRATEGIES.CDN:
      return handleCdnRequest(request);
    default:
      return fetch(request);
  }
}

/**
 * Get cache strategy for URL
 */
function getCacheStrategy(url) {
  // API requests
  if (url.pathname.startsWith('/api/')) {
    return CACHE_STRATEGIES.API;
  }
  
  // Static assets
  if (url.pathname.match(/\.(js|css|png|jpg|jpeg|gif|svg|woff|woff2|ttf|eot)$/)) {
    return CACHE_STRATEGIES.STATIC;
  }
  
  // CDN resources
  if (url.hostname.includes('cdn.') || url.hostname.includes('static.')) {
    return CACHE_STRATEGIES.CDN;
  }
  
  // Critical pages
  if (url.pathname === '/' || url.pathname.startsWith('/dashboard')) {
    return CACHE_STRATEGIES.CRITICAL;
  }
  
  // Important pages
  if (url.pathname.startsWith('/jobs') || url.pathname.startsWith('/andon')) {
    return CACHE_STRATEGIES.IMPORTANT;
  }
  
  // Nice to have pages
  return CACHE_STRATEGIES.NICE_TO_HAVE;
}

/**
 * Cache-first strategy
 */
async function handleCacheFirst(request) {
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.error('[SW] Cache-first fetch failed:', error);
    throw error;
  }
}

/**
 * Network-first strategy
 */
async function handleNetworkFirst(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    console.log('[SW] Network-first fallback to cache');
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      return cachedResponse;
    }
    
    throw error;
  }
}

/**
 * Stale-while-revalidate strategy
 */
async function handleStaleWhileRevalidate(request) {
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);
  
  // Always fetch in background to update cache
  const networkResponsePromise = fetch(request)
    .then(response => {
      if (response.ok) {
        cache.put(request, response.clone());
      }
      return response;
    })
    .catch(error => {
      console.log('[SW] Background fetch failed:', error);
    });
  
  // Return cached response immediately if available
  if (cachedResponse) {
    return cachedResponse;
  }
  
  // Wait for network response if no cache
  return networkResponsePromise;
}

/**
 * Handle API requests with offline support
 */
async function handleApiRequest(request) {
  try {
    const response = await fetch(request);
    
    // Cache successful responses
    if (response.ok) {
      const cache = await caches.open(CACHE_NAME);
      cache.put(request, response.clone());
    }
    
    return response;
  } catch (error) {
    console.log('[SW] API request failed, checking cache');
    
    const cache = await caches.open(CACHE_NAME);
    const cachedResponse = await cache.match(request);
    
    if (cachedResponse) {
      // Queue for background sync
      await queueForBackgroundSync(request, SYNC_QUEUES.API_REQUESTS);
      return cachedResponse;
    }
    
    throw error;
  }
}

/**
 * Handle static asset requests
 */
async function handleStaticRequest(request) {
  const cache = await caches.open(CACHE_NAME);
  const cachedResponse = await cache.match(request);
  
  if (cachedResponse) {
    return cachedResponse;
  }
  
  try {
    const response = await fetch(request);
    if (response.ok) {
      cache.put(request, response.clone());
    }
    return response;
  } catch (error) {
    console.error('[SW] Static asset fetch failed:', error);
    throw error;
  }
}

/**
 * Handle CDN requests
 */
async function handleCdnRequest(request) {
  // Use stale-while-revalidate for CDN resources
  return handleStaleWhileRevalidate(request);
}

/**
 * Update network quality metrics
 */
async function updateNetworkQuality() {
  const start = Date.now();
  
  try {
    // Perform a quick health check
    const response = await fetch('/api/health', { method: 'HEAD' });
    const latency = Date.now() - start;
    
    networkQuality = {
      ...networkQuality,
      latency,
      isOnline: true,
      lastCheck: Date.now(),
    };
  } catch (error) {
    networkQuality = {
      ...networkQuality,
      isOnline: false,
      lastCheck: Date.now(),
    };
  }
}

/**
 * Queue request for background sync
 */
async function queueForBackgroundSync(request, queueName) {
  if (!self.offlineDB) return;
  
  const transaction = self.offlineDB.transaction(['sync_queue'], 'readwrite');
  const store = transaction.objectStore('sync_queue');
  
  const syncItem = {
    url: request.url,
    method: request.method,
    headers: Object.fromEntries(request.headers.entries()),
    body: await request.text(),
    timestamp: Date.now(),
    queue: queueName,
  };
  
  store.add(syncItem);
}

/**
 * Sync API requests
 */
async function syncApiRequests() {
  console.log('[SW] Syncing API requests');
  
  if (!self.offlineDB) return;
  
  const transaction = self.offlineDB.transaction(['sync_queue'], 'readwrite');
  const store = transaction.objectStore('sync_queue');
  const index = store.index('queue');
  const request = index.getAll(SYNC_QUEUES.API_REQUESTS);
  
  request.onsuccess = async (event) => {
    const syncItems = event.target.result;
    
    for (const item of syncItems) {
      try {
        const response = await fetch(item.url, {
          method: item.method,
          headers: item.headers,
          body: item.body,
        });
        
        if (response.ok) {
          // Remove from sync queue on success
          store.delete(item.id);
          console.log('[SW] API request synced:', item.url);
        }
      } catch (error) {
        console.error('[SW] Failed to sync API request:', item.url, error);
      }
    }
  };
}

/**
 * Sync Andon events
 */
async function syncAndonEvents() {
  console.log('[SW] Syncing Andon events');
  // Implementation for Andon event sync
}

/**
 * Sync production data
 */
async function syncProductionData() {
  console.log('[SW] Syncing production data');
  // Implementation for production data sync
}

/**
 * Sync quality checks
 */
async function syncQualityChecks() {
  console.log('[SW] Syncing quality checks');
  // Implementation for quality check sync
}

/**
 * Sync maintenance data
 */
async function syncMaintenanceData() {
  console.log('[SW] Syncing maintenance data');
  // Implementation for maintenance data sync
}

/**
 * Handle notification action
 */
function handleNotificationAction(action, data) {
  console.log('[SW] Handling notification action:', action);
  
  // Handle different notification actions
  switch (action) {
    case 'view':
      self.clients.openWindow(data.url || '/');
      break;
    case 'dismiss':
      // Notification already closed
      break;
    default:
      console.log('[SW] Unknown notification action:', action);
  }
}

/**
 * Clear all caches
 */
async function clearAllCaches() {
  const cacheNames = await caches.keys();
  await Promise.all(cacheNames.map(name => caches.delete(name)));
  console.log('[SW] All caches cleared');
}
