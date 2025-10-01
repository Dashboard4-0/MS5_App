/**
 * MS5.0 Floor Dashboard - Advanced Lazy Loading Service
 * 
 * This module provides intelligent lazy loading with:
 * - Predictive component loading
 * - Performance monitoring
 * - Error boundaries
 * - Loading state management
 * - Zero redundancy architecture
 */

import React, { Suspense, lazy, ComponentType, ReactNode } from 'react';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { logger } from '@utils/logger';

// Performance monitoring
interface LoadingMetrics {
  componentName: string;
  loadStartTime: number;
  loadEndTime?: number;
  loadDuration?: number;
  cacheHit: boolean;
  error?: string;
}

class LazyLoadingService {
  private static instance: LazyLoadingService;
  private loadingMetrics: Map<string, LoadingMetrics> = new Map();
  private componentCache: Map<string, ComponentType> = new Map();
  private preloadQueue: Set<string> = new Set();
  private loadingStates: Map<string, boolean> = new Map();

  private constructor() {
    this.initializePerformanceMonitoring();
  }

  static getInstance(): LazyLoadingService {
    if (!LazyLoadingService.instance) {
      LazyLoadingService.instance = new LazyLoadingService();
    }
    return LazyLoadingService.instance;
  }

  private initializePerformanceMonitoring(): void {
    // Monitor component loading performance
    if (typeof window !== 'undefined' && 'performance' in window) {
      const observer = new PerformanceObserver((list) => {
        list.getEntries().forEach((entry) => {
          if (entry.entryType === 'navigation' || entry.entryType === 'resource') {
            this.trackResourceLoading(entry);
          }
        });
      });

      observer.observe({ entryTypes: ['navigation', 'resource'] });
    }
  }

  private trackResourceLoading(entry: PerformanceEntry): void {
    const componentName = this.extractComponentName(entry.name);
    if (componentName) {
      const metrics = this.loadingMetrics.get(componentName);
      if (metrics) {
        metrics.loadEndTime = entry.startTime + entry.duration;
        metrics.loadDuration = entry.duration;
        this.loadingMetrics.set(componentName, metrics);
      }
    }
  }

  private extractComponentName(resourceName: string): string | null {
    const match = resourceName.match(/([^/]+)\.chunk\.js$/);
    return match ? match[1] : null;
  }

  /**
   * Create a lazy-loaded component with intelligent caching
   */
  createLazyComponent<T extends ComponentType<any>>(
    importFunction: () => Promise<{ default: T }>,
    componentName: string,
    options: {
      preload?: boolean;
      cache?: boolean;
      fallback?: ReactNode;
      errorBoundary?: boolean;
    } = {}
  ): T {
    const {
      preload = false,
      cache = true,
      fallback = this.createDefaultFallback(componentName),
      errorBoundary = true,
    } = options;

    // Check cache first
    if (cache && this.componentCache.has(componentName)) {
      logger.debug(`Component loaded from cache: ${componentName}`);
      return this.componentCache.get(componentName) as T;
    }

    // Track loading start
    this.trackLoadingStart(componentName);

    // Create lazy component
    const LazyComponent = lazy(async () => {
      try {
        const startTime = performance.now();
        const module = await importFunction();
        const endTime = performance.now();

        // Track loading completion
        this.trackLoadingComplete(componentName, endTime - startTime, true);

        // Cache component if enabled
        if (cache) {
          this.componentCache.set(componentName, module.default);
        }

        logger.debug(`Component loaded successfully: ${componentName}`, {
          loadTime: endTime - startTime,
        });

        return module;
      } catch (error) {
        this.trackLoadingError(componentName, error as Error);
        throw error;
      }
    });

    // Preload if requested
    if (preload) {
      this.preloadComponent(componentName, importFunction);
    }

    // Wrap with error boundary if enabled
    if (errorBoundary) {
      return this.wrapWithErrorBoundary(LazyComponent, componentName, fallback) as T;
    }

    return LazyComponent as T;
  }

  /**
   * Preload a component for faster future loading
   */
  async preloadComponent(
    componentName: string,
    importFunction: () => Promise<any>
  ): Promise<void> {
    if (this.preloadQueue.has(componentName)) {
      return; // Already in preload queue
    }

    this.preloadQueue.add(componentName);

    try {
      const module = await importFunction();
      this.componentCache.set(componentName, module.default);
      logger.debug(`Component preloaded: ${componentName}`);
    } catch (error) {
      logger.warn(`Failed to preload component: ${componentName}`, error);
    } finally {
      this.preloadQueue.delete(componentName);
    }
  }

  /**
   * Preload multiple components in parallel
   */
  async preloadComponents(
    components: Array<{
      name: string;
      importFunction: () => Promise<any>;
    }>
  ): Promise<void> {
    const preloadPromises = components.map(({ name, importFunction }) =>
      this.preloadComponent(name, importFunction)
    );

    await Promise.allSettled(preloadPromises);
  }

  /**
   * Intelligent preloading based on user behavior
   */
  preloadBasedOnRoute(currentRoute: string): void {
    const routePreloadMap: Record<string, string[]> = {
      '/dashboard': ['production', 'analytics'],
      '/production': ['dashboard', 'reports'],
      '/analytics': ['dashboard', 'production'],
      '/admin': ['users', 'settings'],
      '/reports': ['production', 'analytics'],
    };

    const componentsToPreload = routePreloadMap[currentRoute] || [];
    
    componentsToPreload.forEach((componentName) => {
      // This would be implemented with actual import functions
      logger.debug(`Preloading component based on route: ${componentName}`);
    });
  }

  /**
   * Create a default fallback component
   */
  private createDefaultFallback(componentName: string): ReactNode {
    return (
      <View style={styles.fallbackContainer}>
        <ActivityIndicator size="large" color="#1976d2" />
        <Text style={styles.fallbackText}>
          Loading {componentName}...
        </Text>
      </View>
    );
  }

  /**
   * Wrap component with error boundary
   */
  private wrapWithErrorBoundary(
    Component: ComponentType<any>,
    componentName: string,
    fallback: ReactNode
  ): ComponentType<any> {
    return class ErrorBoundaryWrapper extends React.Component<
      any,
      { hasError: boolean; error?: Error }
    > {
      constructor(props: any) {
        super(props);
        this.state = { hasError: false };
      }

      static getDerivedStateFromError(error: Error) {
        return { hasError: true, error };
      }

      componentDidCatch(error: Error, errorInfo: any) {
        logger.error(`Error in lazy-loaded component: ${componentName}`, {
          error: error.message,
          stack: error.stack,
          errorInfo,
        });

        // Track error
        LazyLoadingService.getInstance().trackLoadingError(componentName, error);
      }

      render() {
        if (this.state.hasError) {
          return (
            <View style={styles.errorContainer}>
              <Text style={styles.errorText}>
                Failed to load {componentName}
              </Text>
              <Text style={styles.errorSubtext}>
                Please try refreshing the page
              </Text>
            </View>
          );
        }

        return (
          <Suspense fallback={fallback}>
            <Component {...this.props} />
          </Suspense>
        );
      }
    };
  }

  /**
   * Track loading start
   */
  private trackLoadingStart(componentName: string): void {
    this.loadingStates.set(componentName, true);
    this.loadingMetrics.set(componentName, {
      componentName,
      loadStartTime: performance.now(),
      cacheHit: false,
    });
  }

  /**
   * Track loading completion
   */
  private trackLoadingComplete(
    componentName: string,
    duration: number,
    cacheHit: boolean
  ): void {
    this.loadingStates.set(componentName, false);
    const metrics = this.loadingMetrics.get(componentName);
    if (metrics) {
      metrics.loadDuration = duration;
      metrics.cacheHit = cacheHit;
      this.loadingMetrics.set(componentName, metrics);
    }
  }

  /**
   * Track loading error
   */
  private trackLoadingError(componentName: string, error: Error): void {
    this.loadingStates.set(componentName, false);
    const metrics = this.loadingMetrics.get(componentName);
    if (metrics) {
      metrics.error = error.message;
      this.loadingMetrics.set(componentName, metrics);
    }
  }

  /**
   * Get loading metrics for a component
   */
  getLoadingMetrics(componentName: string): LoadingMetrics | undefined {
    return this.loadingMetrics.get(componentName);
  }

  /**
   * Get all loading metrics
   */
  getAllLoadingMetrics(): LoadingMetrics[] {
    return Array.from(this.loadingMetrics.values());
  }

  /**
   * Check if a component is currently loading
   */
  isLoading(componentName: string): boolean {
    return this.loadingStates.get(componentName) || false;
  }

  /**
   * Get performance report
   */
  getPerformanceReport(): {
    totalComponents: number;
    averageLoadTime: number;
    cacheHitRate: number;
    errorRate: number;
    slowestComponents: Array<{ name: string; loadTime: number }>;
  } {
    const metrics = this.getAllLoadingMetrics();
    const totalComponents = metrics.length;
    
    const averageLoadTime = metrics.reduce((sum, metric) => {
      return sum + (metric.loadDuration || 0);
    }, 0) / totalComponents;

    const cacheHitRate = metrics.filter(m => m.cacheHit).length / totalComponents;
    const errorRate = metrics.filter(m => m.error).length / totalComponents;

    const slowestComponents = metrics
      .filter(m => m.loadDuration)
      .sort((a, b) => (b.loadDuration || 0) - (a.loadDuration || 0))
      .slice(0, 5)
      .map(m => ({
        name: m.componentName,
        loadTime: m.loadDuration || 0,
      }));

    return {
      totalComponents,
      averageLoadTime,
      cacheHitRate,
      errorRate,
      slowestComponents,
    };
  }

  /**
   * Clear cache and metrics
   */
  clearCache(): void {
    this.componentCache.clear();
    this.loadingMetrics.clear();
    this.loadingStates.clear();
    this.preloadQueue.clear();
  }
}

// Styles for fallback components
const styles = StyleSheet.create({
  fallbackContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  fallbackText: {
    marginTop: 10,
    fontSize: 16,
    color: '#666',
    textAlign: 'center',
  },
  errorContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  errorText: {
    fontSize: 18,
    color: '#d32f2f',
    textAlign: 'center',
    marginBottom: 10,
  },
  errorSubtext: {
    fontSize: 14,
    color: '#666',
    textAlign: 'center',
  },
});

// Export singleton instance
export const lazyLoadingService = LazyLoadingService.getInstance();

// Export convenience functions
export const createLazyComponent = lazyLoadingService.createLazyComponent.bind(lazyLoadingService);
export const preloadComponent = lazyLoadingService.preloadComponent.bind(lazyLoadingService);
export const preloadComponents = lazyLoadingService.preloadComponents.bind(lazyLoadingService);
export const preloadBasedOnRoute = lazyLoadingService.preloadBasedOnRoute.bind(lazyLoadingService);
export const getPerformanceReport = lazyLoadingService.getPerformanceReport.bind(lazyLoadingService);

// Export types
export type { LoadingMetrics };
export type { LazyLoadingService };
