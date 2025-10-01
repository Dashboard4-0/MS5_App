/**
 * MS5.0 Floor Dashboard - UX Metrics React Hook
 * 
 * This hook provides easy integration of UX metrics with React components:
 * - Automatic journey step tracking
 * - Performance monitoring
 * - Error boundary integration
 * - Component lifecycle tracking
 */

import { useEffect, useRef, useCallback } from 'react';
import { uxMetricsService, trackJourneyStep, completeJourneyStep } from '@services/userExperienceMetricsService';

interface UseUXMetricsOptions {
  componentName: string;
  trackMount?: boolean;
  trackUnmount?: boolean;
  trackInteractions?: boolean;
  trackErrors?: boolean;
  customMetadata?: Record<string, any>;
}

interface UXMetricsHookReturn {
  trackStep: (stepId: string, stepName: string, success?: boolean, errorMessage?: string, metadata?: Record<string, any>) => void;
  completeStep: (stepId: string, success?: boolean, errorMessage?: string) => void;
  trackInteraction: (interactionType: string, metadata?: Record<string, any>) => void;
  trackError: (error: Error, context?: string) => void;
  trackPerformance: (operation: string, startTime: number, endTime?: number) => void;
  getCurrentMetrics: () => any;
}

/**
 * Hook for tracking UX metrics in React components
 */
export const useUXMetrics = (options: UseUXMetricsOptions): UXMetricsHookReturn => {
  const {
    componentName,
    trackMount = true,
    trackUnmount = true,
    trackInteractions = true,
    trackErrors = true,
    customMetadata = {},
  } = options;

  const mountTimeRef = useRef<number>(0);
  const stepCountRef = useRef<number>(0);

  // Track component mount
  useEffect(() => {
    if (trackMount) {
      mountTimeRef.current = performance.now();
      trackJourneyStep(
        `${componentName}_mount`,
        `${componentName} Component Mounted`,
        true,
        undefined,
        {
          component: componentName,
          mount_time: mountTimeRef.current,
          ...customMetadata,
        }
      );
    }

    // Track component unmount
    return () => {
      if (trackUnmount) {
        const unmountTime = performance.now();
        const mountDuration = unmountTime - mountTimeRef.current;
        
        completeJourneyStep(`${componentName}_mount`, true);
        trackJourneyStep(
          `${componentName}_unmount`,
          `${componentName} Component Unmounted`,
          true,
          undefined,
          {
            component: componentName,
            mount_duration: mountDuration,
            step_count: stepCountRef.current,
            ...customMetadata,
          }
        );
      }
    };
  }, [componentName, trackMount, trackUnmount, customMetadata]);

  // Track step function
  const trackStep = useCallback((
    stepId: string,
    stepName: string,
    success: boolean = true,
    errorMessage?: string,
    metadata: Record<string, any> = {}
  ) => {
    stepCountRef.current += 1;
    trackJourneyStep(
      `${componentName}_${stepId}`,
      `${componentName}: ${stepName}`,
      success,
      errorMessage,
      {
        component: componentName,
        step_number: stepCountRef.current,
        ...customMetadata,
        ...metadata,
      }
    );
  }, [componentName, customMetadata]);

  // Complete step function
  const completeStep = useCallback((
    stepId: string,
    success: boolean = true,
    errorMessage?: string
  ) => {
    completeJourneyStep(`${componentName}_${stepId}`, success, errorMessage);
  }, [componentName]);

  // Track interaction function
  const trackInteraction = useCallback((
    interactionType: string,
    metadata: Record<string, any> = {}
  ) => {
    if (trackInteractions) {
      trackStep(
        `interaction_${interactionType}`,
        `User Interaction: ${interactionType}`,
        true,
        undefined,
        {
          interaction_type: interactionType,
          ...metadata,
        }
      );
    }
  }, [trackStep, trackInteractions]);

  // Track error function
  const trackError = useCallback((
    error: Error,
    context?: string
  ) => {
    if (trackErrors) {
      trackStep(
        'error',
        `Error in ${componentName}`,
        false,
        error.message,
        {
          error_name: error.name,
          error_stack: error.stack,
          context: context || 'unknown',
          error_timestamp: Date.now(),
        }
      );
    }
  }, [trackStep, trackErrors]);

  // Track performance function
  const trackPerformance = useCallback((
    operation: string,
    startTime: number,
    endTime?: number
  ) => {
    const duration = (endTime || performance.now()) - startTime;
    trackStep(
      `performance_${operation}`,
      `Performance: ${operation}`,
      true,
      undefined,
      {
        operation,
        duration,
        start_time: startTime,
        end_time: endTime || performance.now(),
      }
    );
  }, [trackStep]);

  // Get current metrics function
  const getCurrentMetrics = useCallback(() => {
    return uxMetricsService.getCurrentUXMetrics();
  }, []);

  return {
    trackStep,
    completeStep,
    trackInteraction,
    trackError,
    trackPerformance,
    getCurrentMetrics,
  };
};

/**
 * Hook for tracking API calls with UX metrics
 */
export const useAPITracking = (componentName: string) => {
  const { trackStep, completeStep, trackError } = useUXMetrics({
    componentName,
    customMetadata: { tracking_type: 'api' },
  });

  const trackAPICall = useCallback(async <T>(
    apiCall: () => Promise<T>,
    operation: string,
    metadata: Record<string, any> = {}
  ): Promise<T> => {
    const stepId = `api_${operation}`;
    const startTime = performance.now();
    
    try {
      trackStep(stepId, `API Call: ${operation}`, true, undefined, {
        operation,
        start_time: startTime,
        ...metadata,
      });

      const result = await apiCall();
      
      const endTime = performance.now();
      completeStep(stepId, true);
      
      trackStep(
        `${stepId}_success`,
        `API Success: ${operation}`,
        true,
        undefined,
        {
          operation,
          duration: endTime - startTime,
          success: true,
        }
      );

      return result;
    } catch (error) {
      const endTime = performance.now();
      completeStep(stepId, false, error instanceof Error ? error.message : 'Unknown error');
      
      trackError(error instanceof Error ? error : new Error(String(error)), `API: ${operation}`);
      
      throw error;
    }
  }, [trackStep, completeStep, trackError]);

  return { trackAPICall };
};

/**
 * Hook for tracking form interactions
 */
export const useFormTracking = (formName: string) => {
  const { trackStep, completeStep, trackInteraction } = useUXMetrics({
    componentName: formName,
    customMetadata: { tracking_type: 'form' },
  });

  const trackFormStart = useCallback((metadata: Record<string, any> = {}) => {
    trackStep('form_start', 'Form Started', true, undefined, {
      form_name: formName,
      ...metadata,
    });
  }, [trackStep, formName]);

  const trackFormSubmit = useCallback(async <T>(
    submitFunction: () => Promise<T>,
    metadata: Record<string, any> = {}
  ): Promise<T> => {
    const stepId = 'form_submit';
    const startTime = performance.now();
    
    try {
      trackStep(stepId, 'Form Submit', true, undefined, {
        form_name: formName,
        start_time: startTime,
        ...metadata,
      });

      const result = await submitFunction();
      
      const endTime = performance.now();
      completeStep(stepId, true);
      
      trackStep(
        'form_success',
        'Form Submit Success',
        true,
        undefined,
        {
          form_name: formName,
          duration: endTime - startTime,
          success: true,
        }
      );

      return result;
    } catch (error) {
      const endTime = performance.now();
      completeStep(stepId, false, error instanceof Error ? error.message : 'Unknown error');
      
      trackStep(
        'form_error',
        'Form Submit Error',
        false,
        error instanceof Error ? error.message : 'Unknown error',
        {
          form_name: formName,
          duration: endTime - startTime,
          error: error instanceof Error ? error.message : String(error),
        }
      );
      
      throw error;
    }
  }, [trackStep, completeStep, formName]);

  const trackFormField = useCallback((
    fieldName: string,
    action: 'focus' | 'blur' | 'change',
    metadata: Record<string, any> = {}
  ) => {
    trackInteraction(`form_field_${action}`, {
      form_name: formName,
      field_name: fieldName,
      action,
      ...metadata,
    });
  }, [trackInteraction, formName]);

  return {
    trackFormStart,
    trackFormSubmit,
    trackFormField,
  };
};

/**
 * Hook for tracking navigation
 */
export const useNavigationTracking = (componentName: string) => {
  const { trackStep, trackInteraction } = useUXMetrics({
    componentName,
    customMetadata: { tracking_type: 'navigation' },
  });

  const trackNavigation = useCallback((
    from: string,
    to: string,
    method: 'click' | 'programmatic' | 'back' | 'forward' = 'click',
    metadata: Record<string, any> = {}
  ) => {
    trackStep(
      'navigation',
      `Navigation: ${from} → ${to}`,
      true,
      undefined,
      {
        from,
        to,
        method,
        ...metadata,
      }
    );
  }, [trackStep]);

  const trackNavigationClick = useCallback((
    target: string,
    destination: string,
    metadata: Record<string, any> = {}
  ) => {
    trackInteraction('navigation_click', {
      target,
      destination,
      ...metadata,
    });
  }, [trackInteraction]);

  return {
    trackNavigation,
    trackNavigationClick,
  };
};

/**
 * Hook for tracking user engagement
 */
export const useEngagementTracking = (componentName: string) => {
  const { trackStep, trackInteraction } = useUXMetrics({
    componentName,
    customMetadata: { tracking_type: 'engagement' },
  });

  const trackEngagement = useCallback((
    engagementType: 'view' | 'interact' | 'scroll' | 'hover' | 'focus',
    target: string,
    duration?: number,
    metadata: Record<string, any> = {}
  ) => {
    trackStep(
      `engagement_${engagementType}`,
      `User Engagement: ${engagementType}`,
      true,
      undefined,
      {
        engagement_type: engagementType,
        target,
        duration,
        ...metadata,
      }
    );
  }, [trackStep]);

  const trackScroll = useCallback((
    scrollPercentage: number,
    target: string,
    metadata: Record<string, any> = {}
  ) => {
    trackEngagement('scroll', target, undefined, {
      scroll_percentage: scrollPercentage,
      ...metadata,
    });
  }, [trackEngagement]);

  const trackHover = useCallback((
    target: string,
    duration: number,
    metadata: Record<string, any> = {}
  ) => {
    trackEngagement('hover', target, duration, metadata);
  }, [trackEngagement]);

  return {
    trackEngagement,
    trackScroll,
    trackHover,
  };
};

/**
 * Error boundary component for automatic error tracking
 */
export const UXErrorBoundary: React.FC<{
  children: React.ReactNode;
  componentName: string;
  fallback?: React.ComponentType<{ error: Error; resetError: () => void }>;
}> = ({ children, componentName, fallback: Fallback }) => {
  const { trackError } = useUXMetrics({
    componentName: `${componentName}_ErrorBoundary`,
    customMetadata: { error_boundary: true },
  });

  const [error, setError] = React.useState<Error | null>(null);

  const resetError = useCallback(() => {
    setError(null);
  }, []);

  useEffect(() => {
    if (error) {
      trackError(error, 'Error Boundary');
    }
  }, [error, trackError]);

  if (error) {
    if (Fallback) {
      return <Fallback error={error} resetError={resetError} />;
    }
    
    return (
      <div style={{ padding: '20px', border: '1px solid #ff6b6b', borderRadius: '4px' }}>
        <h2>Something went wrong</h2>
        <p>{error.message}</p>
        <button onClick={resetError}>Try again</button>
      </div>
    );
  }

  return <>{children}</>;
};

// Export all hooks and components
export {
  useUXMetrics,
  useAPITracking,
  useFormTracking,
  useNavigationTracking,
  useEngagementTracking,
  UXErrorBoundary,
};
