/**
 * MS5.0 Floor Dashboard - Workbox Configuration
 * 
 * This configuration defines the service worker behavior for:
 * - Offline-first architecture
 * - Factory environment optimization
 * - Tablet-specific caching strategies
 * - Real-time data synchronization
 */

module.exports = {
  // Service worker file configuration
  swDest: 'build/sw.js',
  globDirectory: 'build',
  globPatterns: [
    '**/*.{html,js,css,png,jpg,jpeg,gif,svg,ico,woff,woff2,ttf,eot}',
    '**/*.{json,xml,txt}',
  ],
  
  // Cache configuration for different resource types
  runtimeCaching: [
    // API calls - Network first with fallback to cache
    {
      urlPattern: /^https:\/\/api\.ms5dashboard\.com\/.*$/,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'api-cache',
        expiration: {
          maxEntries: 100,
          maxAgeSeconds: 60 * 60 * 24, // 24 hours
        },
        cacheableResponse: {
          statuses: [0, 200, 201, 202, 204],
        },
        networkTimeoutSeconds: 10,
        plugins: [
          {
            cacheKeyWillBeUsed: async ({ request }) => {
              // Include query parameters in cache key
              return `${request.url}?${Date.now()}`;
            },
          },
        ],
      },
    },
    
    // WebSocket connections - Stale while revalidate
    {
      urlPattern: /^wss:\/\/api\.ms5dashboard\.com\/.*$/,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'websocket-cache',
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 60 * 5, // 5 minutes
        },
      },
    },
    
    // Static assets - Cache first
    {
      urlPattern: /\.(?:png|jpg|jpeg|gif|svg|ico|webp)$/,
      handler: 'CacheFirst',
      options: {
        cacheName: 'images-cache',
        expiration: {
          maxEntries: 1000,
          maxAgeSeconds: 60 * 60 * 24 * 30, // 30 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    
    // Fonts - Cache first
    {
      urlPattern: /\.(?:woff|woff2|ttf|eot)$/,
      handler: 'CacheFirst',
      options: {
        cacheName: 'fonts-cache',
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 60 * 60 * 24 * 365, // 1 year
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    
    // JavaScript and CSS - Stale while revalidate
    {
      urlPattern: /\.(?:js|css)$/,
      handler: 'StaleWhileRevalidate',
      options: {
        cacheName: 'static-resources',
        expiration: {
          maxEntries: 100,
          maxAgeSeconds: 60 * 60 * 24 * 7, // 7 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    
    // HTML files - Network first
    {
      urlPattern: /\.(?:html)$/,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'html-cache',
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 60 * 60 * 24, // 24 hours
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
    
    // JSON data files - Network first with longer cache
    {
      urlPattern: /\.(?:json)$/,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'data-cache',
        expiration: {
          maxEntries: 200,
          maxAgeSeconds: 60 * 60 * 24 * 7, // 7 days
        },
        cacheableResponse: {
          statuses: [0, 200],
        },
      },
    },
  ],
  
  // Navigation fallback configuration
  navigateFallback: '/index.html',
  navigateFallbackDenylist: [
    /^\/api\//,
    /^\/ws\//,
    /^\/admin\//,
    /^\/health/,
    /^\/ready/,
    /^\/live/,
  ],
  
  // Skip waiting and claim clients immediately
  skipWaiting: true,
  clientsClaim: true,
  
  // Maximum file size to cache
  maximumFileSizeToCacheInBytes: 5 * 1024 * 1024, // 5MB
  
  // Cleanup old caches
  cleanupOutdatedCaches: true,
  
  // Custom service worker template
  swTemplate: `
    import { precacheAndRoute, cleanupOutdatedCaches } from 'workbox-precaching';
    import { clientsClaim, skipWaiting } from 'workbox-core';
    import { registerRoute } from 'workbox-routing';
    import { NetworkFirst, CacheFirst, StaleWhileRevalidate } from 'workbox-strategies';
    import { ExpirationPlugin } from 'workbox-expiration';
    import { CacheableResponsePlugin } from 'workbox-cacheable-response';
    
    // Skip waiting and claim clients
    skipWaiting();
    clientsClaim();
    
    // Cleanup outdated caches
    cleanupOutdatedCaches();
    
    // Precache and route static assets
    precacheAndRoute(self.__WB_MANIFEST);
    
    // Custom event handlers for factory environment
    self.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
      }
      
      if (event.data && event.data.type === 'GET_VERSION') {
        event.ports[0].postMessage({
          version: '1.0.0',
          buildTime: new Date().toISOString(),
        });
      }
      
      if (event.data && event.data.type === 'CLEAR_CACHE') {
        caches.keys().then((cacheNames) => {
          return Promise.all(
            cacheNames.map((cacheName) => {
              return caches.delete(cacheName);
            })
          );
        }).then(() => {
          event.ports[0].postMessage({ success: true });
        });
      }
    });
    
    // Background sync for offline data
    self.addEventListener('sync', (event) => {
      if (event.tag === 'background-sync') {
        event.waitUntil(doBackgroundSync());
      }
    });
    
    // Push notifications for factory alerts
    self.addEventListener('push', (event) => {
      if (event.data) {
        const data = event.data.json();
        const options = {
          body: data.body,
          icon: '/icons/icon-192x192.png',
          badge: '/icons/badge-72x72.png',
          vibrate: [200, 100, 200],
          data: data.data,
          actions: [
            {
              action: 'view',
              title: 'View Details',
              icon: '/icons/view-icon.png',
            },
            {
              action: 'dismiss',
              title: 'Dismiss',
              icon: '/icons/dismiss-icon.png',
            },
          ],
        };
        
        event.waitUntil(
          self.registration.showNotification(data.title, options)
        );
      }
    });
    
    // Notification click handler
    self.addEventListener('notificationclick', (event) => {
      event.notification.close();
      
      if (event.action === 'view') {
        event.waitUntil(
          clients.openWindow(event.notification.data.url || '/')
        );
      }
    });
    
    // Helper function for background sync
    async function doBackgroundSync() {
      try {
        // Sync offline data when connection is restored
        const response = await fetch('/api/sync/offline-data', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            timestamp: Date.now(),
            action: 'sync',
          }),
        });
        
        if (response.ok) {
          console.log('Background sync completed successfully');
        }
      } catch (error) {
        console.error('Background sync failed:', error);
      }
    }
    
    // Custom fetch handler for factory network conditions
    self.addEventListener('fetch', (event) => {
      // Handle factory network timeouts
      if (event.request.url.includes('/api/')) {
        const timeoutPromise = new Promise((resolve) => {
          setTimeout(() => {
            resolve(new Response('Network timeout', { status: 408 }));
          }, 10000); // 10 second timeout
        });
        
        event.respondWith(
          Promise.race([fetch(event.request), timeoutPromise])
        );
      }
    });
  `,
};
