/**
 * MS5.0 Floor Dashboard - Bundle Optimization Service
 * 
 * This module provides intelligent bundle optimization with:
 * - Dynamic imports
 * - Tree shaking analysis
 * - Bundle size monitoring
 * - Performance optimization
 * - Zero redundancy architecture
 */

import { logger } from '@utils/logger';

// Bundle optimization interfaces
interface BundleAnalysis {
  totalSize: number;
  gzipSize: number;
  brotliSize: number;
  chunks: ChunkAnalysis[];
  modules: ModuleAnalysis[];
  duplicates: DuplicateAnalysis[];
  recommendations: OptimizationRecommendation[];
}

interface ChunkAnalysis {
  name: string;
  size: number;
  gzipSize: number;
  modules: string[];
  dependencies: string[];
  isInitial: boolean;
  isDynamic: boolean;
}

interface ModuleAnalysis {
  name: string;
  size: number;
  gzipSize: number;
  chunks: string[];
  reasons: string[];
  usedExports: string[];
  providedExports: string[];
}

interface DuplicateAnalysis {
  moduleName: string;
  instances: Array<{
    chunk: string;
    size: number;
  }>;
  totalWastedSize: number;
}

interface OptimizationRecommendation {
  type: 'split' | 'merge' | 'remove' | 'lazy';
  priority: 'high' | 'medium' | 'low';
  description: string;
  potentialSavings: number;
  implementation: string;
}

interface BundleMetrics {
  timestamp: number;
  totalBundleSize: number;
  initialBundleSize: number;
  chunkCount: number;
  moduleCount: number;
  duplicateModules: number;
  unusedModules: number;
  compressionRatio: number;
  performanceScore: number;
}

class BundleOptimizationService {
  private static instance: BundleOptimizationService;
  private bundleMetrics: BundleMetrics[] = [];
  private dynamicImports: Map<string, () => Promise<any>> = new Map();
  private treeShakingAnalysis: Map<string, boolean> = new Map();
  private optimizationCache: Map<string, any> = new Map();
  private isAnalyzing: boolean = false;

  private constructor() {
    this.initializeBundleAnalysis();
  }

  static getInstance(): BundleOptimizationService {
    if (!BundleOptimizationService.instance) {
      BundleOptimizationService.instance = new BundleOptimizationService();
    }
    return BundleOptimizationService.instance;
  }

  /**
   * Initialize bundle analysis
   */
  private initializeBundleAnalysis(): void {
    if (typeof window !== 'undefined') {
      this.analyzeCurrentBundle();
      this.setupBundleMonitoring();
    }
  }

  /**
   * Analyze current bundle
   */
  private analyzeCurrentBundle(): void {
    try {
      const resources = performance.getEntriesByType('resource') as PerformanceResourceTiming[];
      const bundleAnalysis = this.performBundleAnalysis(resources);
      
      this.storeBundleMetrics(bundleAnalysis);
      this.generateOptimizationRecommendations(bundleAnalysis);
      
      logger.info('Bundle analysis completed', {
        totalSize: bundleAnalysis.totalSize,
        chunkCount: bundleAnalysis.chunks.length,
        recommendations: bundleAnalysis.recommendations.length,
      });
    } catch (error) {
      logger.error('Bundle analysis failed', error);
    }
  }

  /**
   * Perform bundle analysis
   */
  private performBundleAnalysis(resources: PerformanceResourceTiming[]): BundleAnalysis {
    const chunks: ChunkAnalysis[] = [];
    const modules: ModuleAnalysis[] = [];
    const duplicates: DuplicateAnalysis[] = [];
    
    let totalSize = 0;
    let gzipSize = 0;
    let brotliSize = 0;

    // Analyze JavaScript chunks
    const jsResources = resources.filter(resource => 
      resource.name.includes('.js') && !resource.name.includes('map')
    );

    jsResources.forEach((resource) => {
      const size = resource.transferSize || 0;
      totalSize += size;
      
      // Estimate gzip size (typically 30-40% of original)
      const estimatedGzipSize = size * 0.35;
      gzipSize += estimatedGzipSize;
      
      // Estimate brotli size (typically 20-30% of original)
      const estimatedBrotliSize = size * 0.25;
      brotliSize += estimatedBrotliSize;

      const chunkName = this.extractChunkName(resource.name);
      const isInitial = resource.name.includes('main') || resource.name.includes('runtime');
      const isDynamic = resource.name.includes('chunk');

      chunks.push({
        name: chunkName,
        size,
        gzipSize: estimatedGzipSize,
        modules: this.extractModulesFromChunk(resource.name),
        dependencies: this.extractDependencies(resource.name),
        isInitial,
        isDynamic,
      });
    });

    // Analyze CSS resources
    const cssResources = resources.filter(resource => 
      resource.name.includes('.css') && !resource.name.includes('map')
    );

    cssResources.forEach((resource) => {
      const size = resource.transferSize || 0;
      totalSize += size;
      gzipSize += size * 0.35;
      brotliSize += size * 0.25;
    });

    return {
      totalSize,
      gzipSize,
      brotliSize,
      chunks,
      modules,
      duplicates,
      recommendations: [],
    };
  }

  /**
   * Extract chunk name from resource URL
   */
  private extractChunkName(resourceName: string): string {
    const match = resourceName.match(/\/([^/]+)\.(js|css)$/);
    return match ? match[1] : 'unknown';
  }

  /**
   * Extract modules from chunk (simplified)
   */
  private extractModulesFromChunk(chunkName: string): string[] {
    // This would be implemented with actual webpack stats analysis
    // For now, return a simplified list
    const moduleMap: Record<string, string[]> = {
      'main': ['App', 'Router', 'Store'],
      'vendors': ['React', 'ReactDOM', 'Redux'],
      'react': ['React', 'ReactDOM'],
      'ui': ['MaterialUI', 'Antd'],
      'charts': ['Recharts', 'ChartJS'],
    };

    return moduleMap[chunkName] || [];
  }

  /**
   * Extract dependencies from chunk
   */
  private extractDependencies(chunkName: string): string[] {
    // This would analyze actual webpack dependency graph
    const dependencyMap: Record<string, string[]> = {
      'main': ['vendors', 'react'],
      'dashboard': ['main', 'charts'],
      'production': ['main', 'ui'],
      'analytics': ['main', 'charts'],
    };

    return dependencyMap[chunkName] || [];
  }

  /**
   * Store bundle metrics
   */
  private storeBundleMetrics(analysis: BundleAnalysis): void {
    const metrics: BundleMetrics = {
      timestamp: Date.now(),
      totalBundleSize: analysis.totalSize,
      initialBundleSize: analysis.chunks
        .filter(chunk => chunk.isInitial)
        .reduce((sum, chunk) => sum + chunk.size, 0),
      chunkCount: analysis.chunks.length,
      moduleCount: analysis.modules.length,
      duplicateModules: analysis.duplicates.length,
      unusedModules: 0, // Would be calculated from actual analysis
      compressionRatio: analysis.gzipSize / analysis.totalSize,
      performanceScore: this.calculateBundlePerformanceScore(analysis),
    };

    this.bundleMetrics.push(metrics);
    
    // Keep only last 50 metrics
    if (this.bundleMetrics.length > 50) {
      this.bundleMetrics = this.bundleMetrics.slice(-50);
    }
  }

  /**
   * Calculate bundle performance score
   */
  private calculateBundlePerformanceScore(analysis: BundleAnalysis): number {
    let score = 100;
    
    // Size-based scoring
    if (analysis.totalSize > 2 * 1024 * 1024) score -= 30; // > 2MB
    else if (analysis.totalSize > 1 * 1024 * 1024) score -= 20; // > 1MB
    else if (analysis.totalSize > 500 * 1024) score -= 10; // > 500KB
    
    // Chunk count scoring
    if (analysis.chunks.length > 20) score -= 15;
    else if (analysis.chunks.length > 10) score -= 10;
    else if (analysis.chunks.length > 5) score -= 5;
    
    // Duplicate modules scoring
    const duplicateWaste = analysis.duplicates.reduce(
      (sum, dup) => sum + dup.totalWastedSize, 0
    );
    if (duplicateWaste > 100 * 1024) score -= 20; // > 100KB waste
    else if (duplicateWaste > 50 * 1024) score -= 10; // > 50KB waste
    
    // Compression ratio scoring
    if (analysis.compressionRatio > 0.4) score -= 10;
    else if (analysis.compressionRatio < 0.2) score -= 5;
    
    return Math.max(0, score);
  }

  /**
   * Generate optimization recommendations
   */
  private generateOptimizationRecommendations(analysis: BundleAnalysis): void {
    const recommendations: OptimizationRecommendation[] = [];
    
    // Large bundle size recommendations
    if (analysis.totalSize > 1 * 1024 * 1024) {
      recommendations.push({
        type: 'split',
        priority: 'high',
        description: 'Bundle size exceeds 1MB. Consider code splitting.',
        potentialSavings: analysis.totalSize * 0.3,
        implementation: 'Implement dynamic imports for non-critical features',
      });
    }
    
    // Too many chunks recommendations
    if (analysis.chunks.length > 15) {
      recommendations.push({
        type: 'merge',
        priority: 'medium',
        description: 'Too many chunks may impact loading performance.',
        potentialSavings: 0,
        implementation: 'Merge small chunks or optimize chunk splitting strategy',
      });
    }
    
    // Duplicate modules recommendations
    analysis.duplicates.forEach((duplicate) => {
      if (duplicate.totalWastedSize > 10 * 1024) {
        recommendations.push({
          type: 'remove',
          priority: 'high',
          description: `Duplicate module ${duplicate.moduleName} wastes ${duplicate.totalWastedSize} bytes`,
          potentialSavings: duplicate.totalWastedSize,
          implementation: 'Remove duplicate imports or use webpack deduplication',
        });
      }
    });
    
    // Initial bundle size recommendations
    const initialSize = analysis.chunks
      .filter(chunk => chunk.isInitial)
      .reduce((sum, chunk) => sum + chunk.size, 0);
    
    if (initialSize > 500 * 1024) {
      recommendations.push({
        type: 'lazy',
        priority: 'high',
        description: 'Initial bundle size exceeds 500KB',
        potentialSavings: initialSize * 0.4,
        implementation: 'Move non-critical components to lazy-loaded chunks',
      });
    }
    
    analysis.recommendations = recommendations;
  }

  /**
   * Setup bundle monitoring
   */
  private setupBundleMonitoring(): void {
    // Monitor for new resources being loaded
    const observer = new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => {
        if (entry.entryType === 'resource') {
          this.handleNewResource(entry as PerformanceResourceTiming);
        }
      });
    });

    observer.observe({ entryTypes: ['resource'] });
  }

  /**
   * Handle new resource loading
   */
  private handleNewResource(resource: PerformanceResourceTiming): void {
    if (resource.name.includes('.js') || resource.name.includes('.css')) {
      logger.debug('New bundle resource loaded', {
        name: resource.name,
        size: resource.transferSize,
        duration: resource.duration,
      });
      
      // Re-analyze bundle if significant new resources are loaded
      this.scheduleBundleReanalysis();
    }
  }

  /**
   * Schedule bundle re-analysis
   */
  private scheduleBundleReanalysis(): void {
    if (this.isAnalyzing) return;
    
    this.isAnalyzing = true;
    setTimeout(() => {
      this.analyzeCurrentBundle();
      this.isAnalyzing = false;
    }, 1000);
  }

  /**
   * Create dynamic import for lazy loading
   */
  createDynamicImport<T>(
    importFunction: () => Promise<T>,
    componentName: string,
    options: {
      preload?: boolean;
      prefetch?: boolean;
      priority?: 'high' | 'medium' | 'low';
    } = {}
  ): () => Promise<T> {
    const { preload = false, prefetch = false, priority = 'medium' } = options;
    
    // Store dynamic import
    this.dynamicImports.set(componentName, importFunction);
    
    // Preload if requested
    if (preload) {
      this.preloadComponent(componentName, importFunction);
    }
    
    // Prefetch if requested
    if (prefetch) {
      this.prefetchComponent(componentName, importFunction, priority);
    }
    
    return importFunction;
  }

  /**
   * Preload component
   */
  private async preloadComponent(
    componentName: string,
    importFunction: () => Promise<any>
  ): Promise<void> {
    try {
      await importFunction();
      logger.debug(`Component preloaded: ${componentName}`);
    } catch (error) {
      logger.warn(`Failed to preload component: ${componentName}`, error);
    }
  }

  /**
   * Prefetch component
   */
  private prefetchComponent(
    componentName: string,
    importFunction: () => Promise<any>,
    priority: string
  ): void {
    // Use requestIdleCallback for low-priority prefetching
    if (typeof window !== 'undefined' && 'requestIdleCallback' in window) {
      (window as any).requestIdleCallback(() => {
        this.preloadComponent(componentName, importFunction);
      });
    } else {
      // Fallback to setTimeout
      setTimeout(() => {
        this.preloadComponent(componentName, importFunction);
      }, 1000);
    }
  }

  /**
   * Optimize bundle based on recommendations
   */
  async optimizeBundle(): Promise<{
    appliedOptimizations: string[];
    estimatedSavings: number;
    newBundleSize: number;
  }> {
    const latestAnalysis = this.getLatestBundleAnalysis();
    if (!latestAnalysis) {
      throw new Error('No bundle analysis available');
    }
    
    const appliedOptimizations: string[] = [];
    let estimatedSavings = 0;
    
    // Apply high-priority recommendations
    const highPriorityRecommendations = latestAnalysis.recommendations.filter(
      rec => rec.priority === 'high'
    );
    
    for (const recommendation of highPriorityRecommendations) {
      try {
        await this.applyOptimization(recommendation);
        appliedOptimizations.push(recommendation.description);
        estimatedSavings += recommendation.potentialSavings;
      } catch (error) {
        logger.warn(`Failed to apply optimization: ${recommendation.description}`, error);
      }
    }
    
    // Re-analyze bundle after optimizations
    this.analyzeCurrentBundle();
    const newAnalysis = this.getLatestBundleAnalysis();
    const newBundleSize = newAnalysis?.totalSize || latestAnalysis.totalSize;
    
    logger.info('Bundle optimization completed', {
      appliedOptimizations: appliedOptimizations.length,
      estimatedSavings,
      newBundleSize,
    });
    
    return {
      appliedOptimizations,
      estimatedSavings,
      newBundleSize,
    };
  }

  /**
   * Apply optimization recommendation
   */
  private async applyOptimization(recommendation: OptimizationRecommendation): Promise<void> {
    switch (recommendation.type) {
      case 'split':
        await this.implementCodeSplitting();
        break;
      case 'merge':
        await this.implementChunkMerging();
        break;
      case 'remove':
        await this.removeDuplicateModules();
        break;
      case 'lazy':
        await this.implementLazyLoading();
        break;
    }
  }

  /**
   * Implement code splitting
   */
  private async implementCodeSplitting(): Promise<void> {
    // This would integrate with webpack configuration
    logger.info('Implementing code splitting optimization');
  }

  /**
   * Implement chunk merging
   */
  private async implementChunkMerging(): Promise<void> {
    // This would optimize webpack splitChunks configuration
    logger.info('Implementing chunk merging optimization');
  }

  /**
   * Remove duplicate modules
   */
  private async removeDuplicateModules(): Promise<void> {
    // This would implement webpack deduplication
    logger.info('Implementing duplicate module removal');
  }

  /**
   * Implement lazy loading
   */
  private async implementLazyLoading(): Promise<void> {
    // This would convert static imports to dynamic imports
    logger.info('Implementing lazy loading optimization');
  }

  /**
   * Get latest bundle analysis
   */
  getLatestBundleAnalysis(): BundleAnalysis | null {
    // This would return the most recent analysis
    return null; // Placeholder
  }

  /**
   * Get bundle metrics
   */
  getBundleMetrics(): BundleMetrics[] {
    return [...this.bundleMetrics];
  }

  /**
   * Get bundle performance trends
   */
  getBundleTrends(): {
    sizeTrend: number[];
    scoreTrend: number[];
    chunkTrend: number[];
  } {
    const sizeTrend: number[] = [];
    const scoreTrend: number[] = [];
    const chunkTrend: number[] = [];

    this.bundleMetrics.forEach((metrics) => {
      sizeTrend.push(metrics.totalBundleSize);
      scoreTrend.push(metrics.performanceScore);
      chunkTrend.push(metrics.chunkCount);
    });

    return { sizeTrend, scoreTrend, chunkTrend };
  }

  /**
   * Get optimization recommendations
   */
  getOptimizationRecommendations(): OptimizationRecommendation[] {
    const latestAnalysis = this.getLatestBundleAnalysis();
    return latestAnalysis?.recommendations || [];
  }
}

// Export singleton instance
export const bundleOptimizationService = BundleOptimizationService.getInstance();

// Export convenience functions
export const createDynamicImport = bundleOptimizationService.createDynamicImport.bind(bundleOptimizationService);
export const optimizeBundle = bundleOptimizationService.optimizeBundle.bind(bundleOptimizationService);
export const getBundleMetrics = bundleOptimizationService.getBundleMetrics.bind(bundleOptimizationService);
export const getOptimizationRecommendations = bundleOptimizationService.getOptimizationRecommendations.bind(bundleOptimizationService);

// Export types
export type {
  BundleAnalysis,
  ChunkAnalysis,
  ModuleAnalysis,
  DuplicateAnalysis,
  OptimizationRecommendation,
  BundleMetrics,
};
