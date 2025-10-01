/**
 * MS5.0 Floor Dashboard - Web Entry Point
 * 
 * This is the web-specific entry point for React Native Web deployment.
 * It initializes the application for AKS deployment with tablet optimizations.
 */

import React from 'react';
import { createRoot } from 'react-dom/client';
import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from '../package.json';

// Register the main component
AppRegistry.registerComponent(appName, () => App);

// Get the root element
const rootElement = document.getElementById('root');

if (rootElement) {
  // Create React 18 root
  const root = createRoot(rootElement);
  
  // Render the app
  root.render(<App />);
  
  // Hide loading spinner after app renders
  const loadingSpinner = document.getElementById('loading-spinner');
  if (loadingSpinner) {
    loadingSpinner.style.display = 'none';
  }
} else {
  console.error('Root element not found');
}

// Register service worker for PWA functionality
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then((registration) => {
        console.log('SW registered: ', registration);
        
        // Handle updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          if (newWorker) {
            newWorker.addEventListener('statechange', () => {
              if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                // New content is available, prompt user to refresh
                if (confirm('New version available. Refresh to update?')) {
                  window.location.reload();
                }
              }
            });
          }
        });
      })
      .catch((registrationError) => {
        console.log('SW registration failed: ', registrationError);
      });
  });
}

// Performance monitoring
if ('performance' in window) {
  window.addEventListener('load', () => {
    setTimeout(() => {
      const perfData = performance.getEntriesByType('navigation')[0];
      if (perfData) {
        console.log('Page Load Performance:', {
          loadTime: perfData.loadEventEnd - perfData.loadEventStart,
          domContentLoaded: perfData.domContentLoadedEventEnd - perfData.domContentLoadedEventStart,
          firstPaint: performance.getEntriesByType('paint').find(entry => entry.name === 'first-paint')?.startTime,
          firstContentfulPaint: performance.getEntriesByType('paint').find(entry => entry.name === 'first-contentful-paint')?.startTime,
        });
      }
    }, 0);
  });
}

// Tablet-specific optimizations
if (window.innerWidth >= 768) {
  // Prevent zoom on double tap
  let lastTouchEnd = 0;
  document.addEventListener('touchend', (event) => {
    const now = (new Date()).getTime();
    if (now - lastTouchEnd <= 300) {
      event.preventDefault();
    }
    lastTouchEnd = now;
  }, false);
  
  // Optimize for landscape orientation
  if (window.innerHeight < window.innerWidth) {
    document.body.classList.add('landscape');
  }
  
  // Handle orientation changes
  window.addEventListener('orientationchange', () => {
    setTimeout(() => {
      if (window.innerHeight < window.innerWidth) {
        document.body.classList.add('landscape');
      } else {
        document.body.classList.remove('landscape');
      }
    }, 100);
  });
}

// Factory environment optimizations
if (process.env.FACTORY_NETWORK === 'true') {
  // Increase timeout for factory network conditions
  const originalFetch = window.fetch;
  window.fetch = (url, options = {}) => {
    const timeout = options.timeout || 30000; // 30 second timeout for factory networks
    const controller = new AbortController();
    
    const timeoutId = setTimeout(() => controller.abort(), timeout);
    
    return originalFetch(url, {
      ...options,
      signal: controller.signal,
    }).finally(() => {
      clearTimeout(timeoutId);
    });
  };
  
  // Add factory-specific CSS class
  document.body.classList.add('factory-environment');
}

// Export for testing
export default App;
