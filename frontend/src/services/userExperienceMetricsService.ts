/**
 * MS5.0 Floor Dashboard - User Experience Metrics Service
 * 
 * This module provides comprehensive UX monitoring with:
 * - Core Web Vitals tracking
 * - User journey analysis
 * - Performance metrics collection
 * - Real-time UX monitoring
 * - Zero redundancy architecture
 */

import { logger } from '@utils/logger';

// UX Metrics interfaces
interface CoreWebVitals {
  lcp: number | null; // Largest Contentful Paint
  fid: number | null; // First Input Delay
  cls: number | null; // Cumulative Layout Shift
  fcp: number | null; // First Contentful Paint
  ttfb: number | null; // Time to First Byte
  inp: number | null; // Interaction to Next Paint (new metric)
}

interface UserJourneyStep {
  step_id: string;
  step_name: string;
  start_time: number;
  end_time?: number;
  duration?: number;
  success: boolean;
  error_message?: string;
  metadata: Record<string, any>;
}

interface UserSession {
  session_id: string;
  user_id?: string;
  start_time: number;
  end_time?: number;
  duration?: number;
  steps: UserJourneyStep[];
  device_info: DeviceInfo;
  performance_score: number;
  completion_rate: number;
}

interface DeviceInfo {
  user_agent: string;
  screen_resolution: string;
  viewport_size: string;
  connection_type: string;
  memory: number;
  cores: number;
  platform: string;
  browser: string;
  browser_version: string;
}

interface UXMetrics {
  core_web_vitals: CoreWebVitals;
  user_journey: UserJourneyStep[];
  performance_score: number;
  accessibility_score: number;
  usability_score: number;
  timestamp: number;
}

interface PerformanceBudget {
  lcp_threshold: number; // 2.5s
  fid_threshold: number; // 100ms
  cls_threshold: number; // 0.1
  fcp_threshold: number; // 1.8s
  ttfb_threshold: number; // 600ms
  inp_threshold: number; // 200ms
}

class UserExperienceMetricsService {
  private static instance: UserExperienceMetricsService;
  private coreWebVitals: CoreWebVitals = {
    lcp: null,
    fid: null,
    cls: null,
    fcp: null,
    ttfb: null,
    inp: null,
  };
  private userSessions: Map<string, UserSession> = new Map();
  private currentSession: UserSession | null = null;
  private performanceBudgets: PerformanceBudget;
  private observers: Map<string, PerformanceObserver> = new Map();
  private isMonitoring: boolean = false;
  private metricsHistory: UXMetrics[] = [];
  private maxHistorySize: number = 1000;

  private constructor() {
    this.performanceBudgets = {
      lcp_threshold: 2500, // 2.5 seconds
      fid_threshold: 100,  // 100 milliseconds
      cls_threshold: 0.1,  // 0.1
      fcp_threshold: 1800, // 1.8 seconds
      ttfb_threshold: 600, // 600 milliseconds
      inp_threshold: 200,  // 200 milliseconds
    };
    
    this.initializeMonitoring();
  }

  static getInstance(): UserExperienceMetricsService {
    if (!UserExperienceMetricsService.instance) {
      UserExperienceMetricsService.instance = new UserExperienceMetricsService();
    }
    return UserExperienceMetricsService.instance;
  }

  /**
   * Initialize UX monitoring
   */
  private initializeMonitoring(): void {
    if (typeof window === 'undefined') {
      return; // Server-side rendering
    }

    try {
      this.setupCoreWebVitalsMonitoring();
      this.setupUserJourneyTracking();
      this.setupPerformanceMonitoring();
      this.startSession();

      this.isMonitoring = true;
      logger.info('User Experience Metrics monitoring initialized');
    } catch (error) {
      logger.error('Failed to initialize UX monitoring', error);
    }
  }

  /**
   * Setup Core Web Vitals monitoring
   */
  private setupCoreWebVitalsMonitoring(): void {
    // Largest Contentful Paint (LCP)
    this.observePerformanceEntry('largest-contentful-paint', (entries) => {
      const lcp = entries[entries.length - 1];
      this.coreWebVitals.lcp = lcp.startTime;
      this.recordCoreWebVital('lcp', lcp.startTime);
    });

    // First Input Delay (FID)
    this.observePerformanceEntry('first-input', (entries) => {
      const fid = entries[0];
      this.coreWebVitals.fid = fid.processingStart - fid.startTime;
      this.recordCoreWebVital('fid', this.coreWebVitals.fid);
    });

    // Cumulative Layout Shift (CLS)
    let clsValue = 0;
    this.observePerformanceEntry('layout-shift', (entries) => {
      entries.forEach((entry) => {
        if (!entry.hadRecentInput) {
          clsValue += entry.value;
        }
      });
      this.coreWebVitals.cls = clsValue;
      this.recordCoreWebVital('cls', clsValue);
    });

    // First Contentful Paint (FCP)
    this.observePerformanceEntry('paint', (entries) => {
      const fcp = entries.find(entry => entry.name === 'first-contentful-paint');
      if (fcp) {
        this.coreWebVitals.fcp = fcp.startTime;
        this.recordCoreWebVital('fcp', fcp.startTime);
      }
    });

    // Time to First Byte (TTFB)
    const navigationEntry = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
    if (navigationEntry) {
      this.coreWebVitals.ttfb = navigationEntry.responseStart - navigationEntry.requestStart;
      this.recordCoreWebVital('ttfb', this.coreWebVitals.ttfb);
    }

    // Interaction to Next Paint (INP) - New metric
    this.observePerformanceEntry('event', (entries) => {
      const inp = entries.find(entry => entry.name === 'click' || entry.name === 'keydown');
      if (inp) {
        this.coreWebVitals.inp = inp.processingStart - inp.startTime;
        this.recordCoreWebVital('inp', this.coreWebVitals.inp);
      }
    });
  }

  /**
   * Setup user journey tracking
   */
  private setupUserJourneyTracking(): void {
    // Track page views
    this.trackPageView();

    // Track user interactions
    this.trackUserInteractions();

    // Track form submissions
    this.trackFormSubmissions();

    // Track navigation
    this.trackNavigation();

    // Track errors
    this.trackErrors();
  }

  /**
   * Setup performance monitoring
   */
  private setupPerformanceMonitoring(): void {
    // Monitor resource loading
    this.observePerformanceEntry('resource', (entries) => {
      entries.forEach((entry) => {
        this.trackResourceLoading(entry as PerformanceResourceTiming);
      });
    });

    // Monitor long tasks
    this.observePerformanceEntry('longtask', (entries) => {
      entries.forEach((entry) => {
        this.trackLongTask(entry);
      });
    });
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
   * Record Core Web Vital metric
   */
  private recordCoreWebVital(metric: keyof CoreWebVitals, value: number): void {
    try {
      // Send to analytics service
      this.sendToAnalytics('core_web_vital', {
        metric,
        value,
        threshold: this.performanceBudgets[`${metric}_threshold` as keyof PerformanceBudget],
        passed: this.checkPerformanceBudget(metric, value),
        timestamp: Date.now(),
      });

      logger.debug(`Core Web Vital recorded: ${metric}`, { value });
    } catch (error) {
      logger.error(`Failed to record Core Web Vital: ${metric}`, error);
    }
  }

  /**
   * Check if metric passes performance budget
   */
  private checkPerformanceBudget(metric: keyof CoreWebVitals, value: number): boolean {
    const threshold = this.performanceBudgets[`${metric}_threshold` as keyof PerformanceBudget];
    return value <= threshold;
  }

  /**
   * Start user session
   */
  private startSession(): void {
    const sessionId = this.generateSessionId();
    const deviceInfo = this.getDeviceInfo();

    this.currentSession = {
      session_id: sessionId,
      start_time: Date.now(),
      steps: [],
      device_info: deviceInfo,
      performance_score: 0,
      completion_rate: 0,
    };

    this.userSessions.set(sessionId, this.currentSession);

    // Track session start
    this.trackJourneyStep('session_start', 'Session Started', true);

    logger.info('User session started', { sessionId });
  }

  /**
   * End user session
   */
  private endSession(): void {
    if (!this.currentSession) return;

    this.currentSession.end_time = Date.now();
    this.currentSession.duration = this.currentSession.end_time - this.currentSession.start_time;
    this.currentSession.performance_score = this.calculatePerformanceScore();
    this.currentSession.completion_rate = this.calculateCompletionRate();

    // Track session end
    this.trackJourneyStep('session_end', 'Session Ended', true);

    // Send session data to analytics
    this.sendToAnalytics('user_session', this.currentSession);

    logger.info('User session ended', {
      sessionId: this.currentSession.session_id,
      duration: this.currentSession.duration,
      performanceScore: this.currentSession.performance_score,
    });

    this.currentSession = null;
  }

  /**
   * Track user journey step
   */
  trackJourneyStep(
    stepId: string,
    stepName: string,
    success: boolean,
    errorMessage?: string,
    metadata: Record<string, any> = {}
  ): void {
    if (!this.currentSession) return;

    const step: UserJourneyStep = {
      step_id: stepId,
      step_name: stepName,
      start_time: Date.now(),
      success,
      error_message: errorMessage,
      metadata,
    };

    this.currentSession.steps.push(step);

    logger.debug('Journey step tracked', {
      stepId,
      stepName,
      success,
      sessionId: this.currentSession.session_id,
    });
  }

  /**
   * Complete user journey step
   */
  completeJourneyStep(stepId: string, success: boolean = true, errorMessage?: string): void {
    if (!this.currentSession) return;

    const step = this.currentSession.steps.find(s => s.step_id === stepId);
    if (step) {
      step.end_time = Date.now();
      step.duration = step.end_time - step.start_time;
      step.success = success;
      if (errorMessage) {
        step.error_message = errorMessage;
      }
    }
  }

  /**
   * Track page view
   */
  private trackPageView(): void {
    this.trackJourneyStep('page_view', 'Page View', true, undefined, {
      url: window.location.href,
      referrer: document.referrer,
      title: document.title,
    });
  }

  /**
   * Track user interactions
   */
  private trackUserInteractions(): void {
    // Track clicks
    document.addEventListener('click', (event) => {
      const target = event.target as HTMLElement;
      this.trackJourneyStep('user_click', 'User Click', true, undefined, {
        element: target.tagName,
        id: target.id,
        className: target.className,
        text: target.textContent?.substring(0, 100),
      });
    });

    // Track form interactions
    document.addEventListener('input', (event) => {
      const target = event.target as HTMLInputElement;
      this.trackJourneyStep('form_input', 'Form Input', true, undefined, {
        element: target.tagName,
        type: target.type,
        name: target.name,
        value_length: target.value.length,
      });
    });

    // Track keyboard interactions
    document.addEventListener('keydown', (event) => {
      this.trackJourneyStep('keyboard_input', 'Keyboard Input', true, undefined, {
        key: event.key,
        code: event.code,
        ctrlKey: event.ctrlKey,
        shiftKey: event.shiftKey,
        altKey: event.altKey,
      });
    });
  }

  /**
   * Track form submissions
   */
  private trackFormSubmissions(): void {
    document.addEventListener('submit', (event) => {
      const form = event.target as HTMLFormElement;
      this.trackJourneyStep('form_submit', 'Form Submit', true, undefined, {
        formId: form.id,
        formClass: form.className,
        action: form.action,
        method: form.method,
        fieldCount: form.elements.length,
      });
    });
  }

  /**
   * Track navigation
   */
  private trackNavigation(): void {
    // Track beforeunload
    window.addEventListener('beforeunload', () => {
      this.endSession();
    });

    // Track popstate (back/forward navigation)
    window.addEventListener('popstate', () => {
      this.trackJourneyStep('navigation', 'Navigation', true, undefined, {
        type: 'popstate',
        url: window.location.href,
      });
    });
  }

  /**
   * Track errors
   */
  private trackErrors(): void {
    // Track JavaScript errors
    window.addEventListener('error', (event) => {
      this.trackJourneyStep('javascript_error', 'JavaScript Error', false, event.message, {
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        stack: event.error?.stack,
      });
    });

    // Track unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.trackJourneyStep('promise_rejection', 'Promise Rejection', false, event.reason, {
        reason: event.reason,
      });
    });
  }

  /**
   * Track resource loading
   */
  private trackResourceLoading(entry: PerformanceResourceTiming): void {
    this.trackJourneyStep('resource_load', 'Resource Load', true, undefined, {
      name: entry.name,
      duration: entry.duration,
      size: entry.transferSize,
      type: this.getResourceType(entry.name),
    });
  }

  /**
   * Track long tasks
   */
  private trackLongTask(entry: PerformanceEntry): void {
    this.trackJourneyStep('long_task', 'Long Task', false, 'Long task detected', {
      duration: entry.duration,
      startTime: entry.startTime,
    });
  }

  /**
   * Get resource type from URL
   */
  private getResourceType(url: string): string {
    if (url.includes('.js')) return 'javascript';
    if (url.includes('.css')) return 'stylesheet';
    if (url.match(/\.(png|jpg|jpeg|gif|svg|webp)$/)) return 'image';
    if (url.match(/\.(woff|woff2|eot|ttf|otf)$/)) return 'font';
    return 'other';
  }

  /**
   * Get device information
   */
  private getDeviceInfo(): DeviceInfo {
    const connection = (navigator as any).connection;
    const memory = (performance as any).memory;

    return {
      user_agent: navigator.userAgent,
      screen_resolution: `${screen.width}x${screen.height}`,
      viewport_size: `${window.innerWidth}x${window.innerHeight}`,
      connection_type: connection?.effectiveType || 'unknown',
      memory: memory?.jsHeapSizeLimit || 0,
      cores: navigator.hardwareConcurrency || 0,
      platform: navigator.platform,
      browser: this.getBrowserInfo().name,
      browser_version: this.getBrowserInfo().version,
    };
  }

  /**
   * Get browser information
   */
  private getBrowserInfo(): { name: string; version: string } {
    const userAgent = navigator.userAgent;
    
    if (userAgent.includes('Chrome')) {
      const match = userAgent.match(/Chrome\/(\d+)/);
      return { name: 'Chrome', version: match ? match[1] : 'unknown' };
    } else if (userAgent.includes('Firefox')) {
      const match = userAgent.match(/Firefox\/(\d+)/);
      return { name: 'Firefox', version: match ? match[1] : 'unknown' };
    } else if (userAgent.includes('Safari')) {
      const match = userAgent.match(/Version\/(\d+)/);
      return { name: 'Safari', version: match ? match[1] : 'unknown' };
    } else if (userAgent.includes('Edge')) {
      const match = userAgent.match(/Edge\/(\d+)/);
      return { name: 'Edge', version: match ? match[1] : 'unknown' };
    }
    
    return { name: 'Unknown', version: 'unknown' };
  }

  /**
   * Calculate performance score
   */
  private calculatePerformanceScore(): number {
    let score = 100;
    
    // LCP scoring (0-25 points)
    if (this.coreWebVitals.lcp !== null) {
      if (this.coreWebVitals.lcp > 4000) score -= 25;
      else if (this.coreWebVitals.lcp > 2500) score -= 15;
      else if (this.coreWebVitals.lcp > 2000) score -= 10;
    }
    
    // FID scoring (0-25 points)
    if (this.coreWebVitals.fid !== null) {
      if (this.coreWebVitals.fid > 300) score -= 25;
      else if (this.coreWebVitals.fid > 100) score -= 15;
      else if (this.coreWebVitals.fid > 50) score -= 10;
    }
    
    // CLS scoring (0-25 points)
    if (this.coreWebVitals.cls !== null) {
      if (this.coreWebVitals.cls > 0.25) score -= 25;
      else if (this.coreWebVitals.cls > 0.1) score -= 15;
      else if (this.coreWebVitals.cls > 0.05) score -= 10;
    }
    
    // FCP scoring (0-25 points)
    if (this.coreWebVitals.fcp !== null) {
      if (this.coreWebVitals.fcp > 3000) score -= 25;
      else if (this.coreWebVitals.fcp > 1800) score -= 15;
      else if (this.coreWebVitals.fcp > 1200) score -= 10;
    }
    
    return Math.max(0, score);
  }

  /**
   * Calculate completion rate
   */
  private calculateCompletionRate(): number {
    if (!this.currentSession || this.currentSession.steps.length === 0) return 0;
    
    const successfulSteps = this.currentSession.steps.filter(step => step.success).length;
    return (successfulSteps / this.currentSession.steps.length) * 100;
  }

  /**
   * Generate session ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Send data to analytics service
   */
  private sendToAnalytics(event: string, data: any): void {
    try {
      // This would integrate with actual analytics service (Google Analytics, Mixpanel, etc.)
      if (typeof window !== 'undefined' && (window as any).gtag) {
        (window as any).gtag('event', event, data);
      }
      
      logger.debug('Analytics event sent', { event, data });
    } catch (error) {
      logger.error('Failed to send analytics event', error);
    }
  }

  /**
   * Get current UX metrics
   */
  getCurrentUXMetrics(): UXMetrics {
    return {
      core_web_vitals: { ...this.coreWebVitals },
      user_journey: this.currentSession?.steps || [],
      performance_score: this.calculatePerformanceScore(),
      accessibility_score: this.calculateAccessibilityScore(),
      usability_score: this.calculateUsabilityScore(),
      timestamp: Date.now(),
    };
  }

  /**
   * Calculate accessibility score
   */
  private calculateAccessibilityScore(): number {
    // This would implement actual accessibility testing
    // For now, return a placeholder score
    return 85;
  }

  /**
   * Calculate usability score
   */
  private calculateUsabilityScore(): number {
    if (!this.currentSession) return 0;
    
    const totalSteps = this.currentSession.steps.length;
    const successfulSteps = this.currentSession.steps.filter(step => step.success).length;
    
    return totalSteps > 0 ? (successfulSteps / totalSteps) * 100 : 0;
  }

  /**
   * Get user session report
   */
  getUserSessionReport(sessionId: string): UserSession | null {
    return this.userSessions.get(sessionId) || null;
  }

  /**
   * Get all user sessions
   */
  getAllUserSessions(): UserSession[] {
    return Array.from(this.userSessions.values());
  }

  /**
   * Get UX performance report
   */
  getUXPerformanceReport(): {
    core_web_vitals: CoreWebVitals;
    performance_score: number;
    session_count: number;
    avg_session_duration: number;
    completion_rate: number;
    top_issues: string[];
  } {
    const sessions = this.getAllUserSessions();
    const avgSessionDuration = sessions.length > 0 
      ? sessions.reduce((sum, session) => sum + (session.duration || 0), 0) / sessions.length 
      : 0;
    
    const avgCompletionRate = sessions.length > 0
      ? sessions.reduce((sum, session) => sum + session.completion_rate, 0) / sessions.length
      : 0;

    const topIssues = this.identifyTopIssues();

    return {
      core_web_vitals: { ...this.coreWebVitals },
      performance_score: this.calculatePerformanceScore(),
      session_count: sessions.length,
      avg_session_duration: avgSessionDuration,
      completion_rate: avgCompletionRate,
      top_issues: topIssues,
    };
  }

  /**
   * Identify top UX issues
   */
  private identifyTopIssues(): string[] {
    const issues: string[] = [];

    if (this.coreWebVitals.lcp && this.coreWebVitals.lcp > this.performanceBudgets.lcp_threshold) {
      issues.push('Slow Largest Contentful Paint');
    }

    if (this.coreWebVitals.fid && this.coreWebVitals.fid > this.performanceBudgets.fid_threshold) {
      issues.push('High First Input Delay');
    }

    if (this.coreWebVitals.cls && this.coreWebVitals.cls > this.performanceBudgets.cls_threshold) {
      issues.push('High Cumulative Layout Shift');
    }

    if (this.coreWebVitals.fcp && this.coreWebVitals.fcp > this.performanceBudgets.fcp_threshold) {
      issues.push('Slow First Contentful Paint');
    }

    return issues;
  }

  /**
   * Stop UX monitoring
   */
  stopMonitoring(): void {
    this.isMonitoring = false;
    
    // Disconnect observers
    this.observers.forEach(observer => observer.disconnect());
    this.observers.clear();
    
    // End current session
    this.endSession();
    
    logger.info('UX monitoring stopped');
  }

  /**
   * Check if monitoring is active
   */
  isActive(): boolean {
    return this.isMonitoring;
  }
}

// Export singleton instance
export const uxMetricsService = UserExperienceMetricsService.getInstance();

// Export convenience functions
export const trackJourneyStep = uxMetricsService.trackJourneyStep.bind(uxMetricsService);
export const completeJourneyStep = uxMetricsService.completeJourneyStep.bind(uxMetricsService);
export const getCurrentUXMetrics = uxMetricsService.getCurrentUXMetrics.bind(uxMetricsService);
export const getUXPerformanceReport = uxMetricsService.getUXPerformanceReport.bind(uxMetricsService);

// Export types
export type {
  CoreWebVitals,
  UserJourneyStep,
  UserSession,
  DeviceInfo,
  UXMetrics,
  PerformanceBudget,
};
