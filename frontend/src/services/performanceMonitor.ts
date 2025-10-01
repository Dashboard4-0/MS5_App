/**
 * MS5.0 Floor Dashboard - Frontend Performance Monitoring Service
 * 
 * This module provides comprehensive performance monitoring with:
 * - Core Web Vitals tracking
 * - Bundle size monitoring
 * - Component performance analysis
 * - User experience metrics
 * - Real-time performance reporting
 */

import { logger } from '@utils/logger';

// Performance metrics interfaces
interface CoreWebVitals {
  lcp: number | null; // Largest Contentful Paint
  fid: number | null; // First Input Delay
  cls: number | null; // Cumulative Layout Shift
  fcp: number | null; // First Contentful Paint
  ttfb: number | null; // Time to First Byte
}

interface BundleMetrics {
  totalSize: number;
  jsSize: number;
  cssSize: number;
  imageSize: number;
  fontSize: number;
  chunkCount: number;
  compressionRatio: number;
}

interface ComponentMetrics {
  componentName: string;
  renderTime: number;
  mountTime: number;
  updateCount: number;
  memoryUsage: number;
  errorCount: number;
}

interface UserExperienceMetrics {
  pageLoadTime: number;
  timeToInteractive: number;
  firstMeaningfulPaint: number;
  domContentLoaded: number;
  windowLoad: number;
  navigationTiming: PerformanceNavigationTiming | null;
}

interface PerformanceReport {
  timestamp: number;
  coreWebVitals: CoreWebVitals;
  bundleMetrics: BundleMetrics;
  componentMetrics: ComponentMetrics[];
  userExperienceMetrics: UserExperienceMetrics;
  deviceInfo: {
    userAgent: string;
    connectionType: string;
    memory: number;
    cores: number;
  };
  performanceScore: number;
}

class FrontendPerformanceMonitor {
  private static instance: FrontendPerformanceMonitor;
  private metrics: PerformanceReport[] = [];
  private observers: Map<string, PerformanceObserver> = new Map();
  private componentMetrics: Map<string, ComponentMetrics> = new Map();
  private isMonitoring: boolean = false;
  private reportInterval: number = 30000; // 30 seconds
  private maxMetricsHistory: number = 100;

  private constructor() {
    this.initializeMonitoring();
  }

  static getInstance(): FrontendPerformanceMonitor {
    if (!FrontendPerformanceMonitor.instance) {
      FrontendPerformanceMonitor.instance = new FrontendPerformanceMonitor();
    }
    return FrontendPerformanceMonitor.instance;
  }

  /**
   * Initialize performance monitoring
   */
  private initializeMonitoring(): void {
    if (typeof window === 'undefined') {
      return; // Server-side rendering
    }

    try {
      this.setupCoreWebVitalsMonitoring();
      this.setupBundleMonitoring();
      this.setupUserExperienceMonitoring();
      this.setupComponentMonitoring();
      this.startPeriodicReporting();

      this.isMonitoring = true;
      logger.info('Frontend performance monitoring initialized');
    } catch (error) {
      logger.error('Failed to initialize performance monitoring', error);
    }
  }

  /**
   * Setup Core Web Vitals monitoring
   */
  private setupCoreWebVitalsMonitoring(): void {
    // Largest Contentful Paint (LCP)
    this.observePerformanceEntry('largest-contentful-paint', (entries) => {
      const lcp = entries[entries.length - 1];
      this.updateCoreWebVital('lcp', lcp.startTime);
    });

    // First Input Delay (FID)
    this.observePerformanceEntry('first-input', (entries) => {
      const fid = entries[0];
      this.updateCoreWebVital('fid', fid.processingStart - fid.startTime);
    });

    // Cumulative Layout Shift (CLS)
    let clsValue = 0;
    this.observePerformanceEntry('layout-shift', (entries) => {
      entries.forEach((entry) => {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      });
      this.updateCoreWebVital('cls', clsValue);
    });

    // First Contentful Paint (FCP)
    this.observePerformanceEntry('paint', (entries) => {
      const fcp = entries.find(entry => entry.name === 'first-contentful-paint');
      if (fcp) {
        this.updateCoreWebVital('fcp', fcp.startTime);
      }
    });

    // Time to First Byte (TTFB)
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    if (navigationEntry) {
      this.updateCoreWebVital('ttfb', navigationEntry.responseStart - navigationEntry.requestStart);
    }
  }

  /**
   * Setup bundle size monitoring
   */
  private setupBundleMonitoring(): void {
    const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
    
    let totalSize = 0;
    let jsSize = 0;
    let cssSize = 0;
    let imageSize = 0;
    let fontSize = 0;
    let chunkCount = 0;

    resources.forEach((resource) => {
      const size = resource.transferSize || 0;
      totalSize += size;

      if (resource.name.includes('.js')) {
        jsSize += size;
        if (resource.name.includes('chunk')) {
          chunkCount++;
        }
      } else if (resource.name.includes('.css')) {
        cssSize += size;
      } else if (resource.name.match(/\.(png|jpg|jpeg|gif|svg|webp)$/)) {
        imageSize += size;
      } else if (resource.name.match(/\.(woff|woff2|eot|ttf|otf)$/)) {
        fontSize += size;
      }
    });

    const compressionRatio = totalSize > 0 ? (totalSize - jsSize - cssSize) / totalSize : 0;

    this.updateBundleMetrics({
      totalSize,
      jsSize,
      cssSize,
      imageSize,
      fontSize,
      chunkCount,
      compressionRatio,
    });
  }

  /**
   * Setup user experience monitoring
   */
  private setupUserExperienceMonitoring(): void {
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    
    if (navigationEntry) {
      const userExperienceMetrics: UserExperienceMetrics = {
        pageLoadTime: navigationEntry.loadEventEnd - navigationEntry.fetchStart,
        timeToInteractive: this.calculateTimeToInteractive(),
        firstMeaningfulPaint: this.calculateFirstMeaningfulPaint(),
        domContentLoaded: navigationEntry.domContentLoadedEventEnd - navigationEntry.fetchStart,
        windowLoad: navigationEntry.loadEventEnd - navigationEntry.fetchStart,
        navigationTiming: navigationEntry,
      };

      this.updateUserExperienceMetrics(userExperienceMetrics);
    }
  }

  /**
   * Setup component performance monitoring
   */
  private setupComponentMonitoring(): void {
    // Monitor React component performance using React DevTools Profiler
    if (typeof window !== 'undefined' && (window as any).React) {
      this.setupReactProfiling();
    }
  }

  /**
   * Setup React profiling
   */
  private setupReactProfiling(): void {
    // This would integrate with React DevTools Profiler
    // For now, we'll use a simplified approach
    const originalCreateElement = (window as any).React.createElement;
    
    if (originalCreateElement) {
      (window as any).React.createElement = (...args: any[]) => {
        const startTime = performance.now();
        const result = originalCreateElement.apply(this, args);
        const endTime = performance.now();
        
        // Track component creation time
        const componentName = args[0]?.displayName || args[0]?.name || 'Unknown';
        this.trackComponentMetric(componentName, 'renderTime', endTime - startTime);
        
        return result;
      };
    }
  }

  /**
   * Observe performance entries
   */
  private observePerformanceEntry(
    entryType: string,
    callback: (entries: PerformanceEntry[]) => void
  ): void {
    try {
      const observer = new PerformanceObserver((list) => {
        callback(list.getEntries());
      });

      observer.observe({ entryTypes: [entryType] });
      this.observers.set(entryType, observer);
    } catch (error) {
      logger.warn(`Failed to observe ${entryType}`, error);
    }
  }

  /**
   * Update Core Web Vital metric
   */
  private updateCoreWebVital(metric: keyof CoreWebVitals, value: number): void {
    const currentReport = this.getCurrentReport();
    if (currentReport) {
      currentReport.coreWebVitals[metric] = value;
    }
  }

  /**
   * Update bundle metrics
   */
  private updateBundleMetrics(metrics: BundleMetrics): void {
    const currentReport = this.getCurrentReport();
    if (currentReport) {
      currentReport.bundleMetrics = metrics;
    }
  }

  /**
   * Update user experience metrics
   */
  private updateUserExperienceMetrics(metrics: UserExperienceMetrics): void {
    const currentReport = this.getCurrentReport();
    if (currentReport) {
      currentReport.userExperienceMetrics = metrics;
    }
  }

  /**
   * Track component metric
   */
  trackComponentMetric(
    componentName: string,
    metricType: keyof ComponentMetrics,
    value: number
  ): void {
    let metrics = this.componentMetrics.get(componentName);
    if (!metrics) {
      metrics = {
        componentName,
        renderTime: 0,
        mountTime: 0,
        updateCount: 0,
        memoryUsage: 0,
        errorCount: 0,
      };
    }

    if (metricType === 'updateCount') {
      metrics[metricType]++;
    } else {
      metrics[metricType] = value;
    }

    this.componentMetrics.set(componentName, metrics);
  }

  /**
   * Get current performance report
   */
  private getCurrentReport(): PerformanceReport {
    if (this.metrics.length === 0) {
      this.metrics.push(this.createEmptyReport());
    }
    return this.metrics[this.metrics.length - 1];
  }

  /**
   * Create empty performance report
   */
  private createEmptyReport(): PerformanceReport {
    return {
      timestamp: Date.now(),
      coreWebVitals: {
        lcp: null,
        fid: null,
        cls: null,
        fcp: null,
        ttfb: null,
      },
      bundleMetrics: {
        totalSize: 0,
        jsSize: 0,
        cssSize: 0,
        imageSize: 0,
        fontSize: 0,
        chunkCount: 0,
        compressionRatio: 0,
      },
      componentMetrics: [],
      userExperienceMetrics: {
        pageLoadTime: 0,
        timeToInteractive: 0,
        firstMeaningfulPaint: 0,
        domContentLoaded: 0,
        windowLoad: 0,
        navigationTiming: null,
      },
      deviceInfo: this.getDeviceInfo(),
      performanceScore: 0,
    };
  }

  /**
   * Get device information
   */
  private getDeviceInfo(): PerformanceReport['deviceInfo'] {
    const connection = (navigator as any).connection;
    const memory = (performance as any).memory;

    return {
      userAgent: navigator.userAgent,
      connectionType: connection?.effectiveType || 'unknown',
      memory: memory?.jsHeapSizeLimit || 0,
      cores: navigator.hardwareConcurrency || 0,
    };
  }

  /**
   * Calculate Time to Interactive
   */
  private calculateTimeToInteractive(): number {
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    if (!navigationEntry) return 0;

    // Simplified TTI calculation
    return navigationEntry.domContentLoadedEventEnd - navigationEntry.fetchStart;
  }

  /**
   * Calculate First Meaningful Paint
   */
  private calculateFirstMeaningfulPaint(): number {
    const paintEntries = performance.getEntriesByType('paint');
    const fmp = paintEntries.find(entry => entry.name === 'first-meaningful-paint');
    return fmp ? fmp.startTime : 0;
  }

  /**
   * Calculate performance score
   */
  private calculatePerformanceScore(report: PerformanceReport): number {
    const { coreWebVitals, userExperienceMetrics } = report;
    
    let score = 100;
    
    // LCP scoring (0-25 points)
    if (coreWebVitals.lcp !== null) {
      if (coreWebVitals.lcp > 4000) score -= 25;
      else if (coreWebVitals.lcp > 2500) score -= 15;
      else if (coreWebVitals.lcp > 2000) score -= 10;
    }
    
    // FID scoring (0-25 points)
    if (coreWebVitals.fid !== null) {
      if (coreWebVitals.fid > 300) score -= 25;
      else if (coreWebVitals.fid > 100) score -= 15;
      else if (coreWebVitals.fid > 50) score -= 10;
    }
    
    // CLS scoring (0-25 points)
    if (coreWebVitals.cls !== null) {
      if (coreWebVitals.cls > 0.25) score -= 25;
      else if (coreWebVitals.cls > 0.1) score -= 15;
      else if (coreWebVitals.cls > 0.05) score -= 10;
    }
    
    // Page load time scoring (0-25 points)
    if (userExperienceMetrics.pageLoadTime > 5000) score -= 25;
    else if (userExperienceMetrics.pageLoadTime > 3000) score -= 15;
    else if (userExperienceMetrics.pageLoadTime > 2000) score -= 10;
    
    return Math.max(0, score);
  }

  /**
   * Start periodic reporting
   */
  private startPeriodicReporting(): void {
    setInterval(() => {
      this.generatePerformanceReport();
    }, this.reportInterval);
  }

  /**
   * Generate performance report
   */
  generatePerformanceReport(): PerformanceReport {
    const currentReport = this.getCurrentReport();
    
    // Update component metrics
    currentReport.componentMetrics = Array.from(this.componentMetrics.values());
    
    // Calculate performance score
    currentReport.performanceScore = this.calculatePerformanceScore(currentReport);
    
    // Store report
    this.metrics.push({ ...currentReport });
    
    // Limit history size
    if (this.metrics.length > this.maxMetricsHistory) {
      this.metrics = this.metrics.slice(-this.maxMetricsHistory);
    }
    
    // Log performance report
    logger.info('Performance report generated', {
      score: currentReport.performanceScore,
      lcp: currentReport.coreWebVitals.lcp,
      fid: currentReport.coreWebVitals.fid,
      cls: currentReport.coreWebVitals.cls,
    });
    
    return currentReport;
  }

  /**
   * Get performance metrics
   */
  getPerformanceMetrics(): PerformanceReport[] {
    return [...this.metrics];
  }

  /**
   * Get latest performance report
   */
  getLatestReport(): PerformanceReport | null {
    return this.metrics.length > 0 ? this.metrics[this.metrics.length - 1] : null;
  }

  /**
   * Get performance trends
   */
  getPerformanceTrends(): {
    scoreTrend: number[];
    lcpTrend: number[];
    fidTrend: number[];
    clsTrend: number[];
  } {
    const scoreTrend: number[] = [];
    const lcpTrend: number[] = [];
    const fidTrend: number[] = [];
    const clsTrend: number[] = [];

    this.metrics.forEach((report) => {
      scoreTrend.push(report.performanceScore);
      lcpTrend.push(report.coreWebVitals.lcp || 0);
      fidTrend.push(report.coreWebVitals.fid || 0);
      clsTrend.push(report.coreWebVitals.cls || 0);
    });

    return { scoreTrend, lcpTrend, fidTrend, clsTrend };
  }

  /**
   * Stop monitoring
   */
  stopMonitoring(): void {
    this.observers.forEach((observer) => {
      observer.disconnect();
    });
    this.observers.clear();
    this.isMonitoring = false;
    logger.info('Performance monitoring stopped');
  }

  /**
   * Check if monitoring is active
   */
  isActive(): boolean {
    return this.isMonitoring;
  }
}

// Export singleton instance
export const performanceMonitor = FrontendPerformanceMonitor.getInstance();

// Export convenience functions
export const trackComponentMetric = performanceMonitor.trackComponentMetric.bind(performanceMonitor);
export const generatePerformanceReport = performanceMonitor.generatePerformanceReport.bind(performanceMonitor);
export const getPerformanceMetrics = performanceMonitor.getPerformanceMetrics.bind(performanceMonitor);
export const getLatestReport = performanceMonitor.getLatestReport.bind(performanceMonitor);

// Export types
export type {
  CoreWebVitals,
  BundleMetrics,
  ComponentMetrics,
  UserExperienceMetrics,
  PerformanceReport,
};
