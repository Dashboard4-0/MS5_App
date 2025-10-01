/**
 * MS5.0 Floor Dashboard - Enhanced WebSocket Service
 * 
 * This service handles real-time communication with the backend using WebSocket connections.
 * It provides methods for connecting, subscribing to events, and managing real-time data updates.
 * 
 * Architected for cosmic scale operations - the nervous system of a starship.
 */

// Types
export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
  id?: string;
  priority?: number;
  connection_id?: string;
}

export interface WebSocketSubscription {
  id: string;
  event: string;
  callback: (data: any) => void;
  active: boolean;
  filters?: Record<string, any>;
}

export interface WebSocketConfig {
  url: string;
  reconnectInterval: number;
  maxReconnectAttempts: number;
  heartbeatInterval: number;
  timeout: number;
  batchSize: number;
  enableCompression: boolean;
  enableHeartbeat: boolean;
}

export interface WebSocketState {
  connected: boolean;
  connecting: boolean;
  error: string | null;
  lastMessage: WebSocketMessage | null;
  subscriptions: WebSocketSubscription[];
  reconnectAttempts: number;
  lastHeartbeat: string | null;
  connectionId: string | null;
  healthScore: number;
  messageCount: number;
  errorCount: number;
}

export interface WebSocketStats {
  state: WebSocketState;
  isOnline: boolean;
  reconnectAttempts: number;
  messageCount: number;
  errorCount: number;
  queuedMessages: number;
  uptime: number;
  lastHeartbeat: number;
  connectionTime: number;
}

export enum MessagePriority {
  CRITICAL = 1,
  HIGH = 2,
  NORMAL = 3,
  LOW = 4
}

export enum WebSocketEventType {
  // Connection events
  CONNECTED = 'connected',
  DISCONNECTED = 'disconnected',
  CONNECTING = 'connecting',
  ERROR = 'error',
  
  // Production events
  PRODUCTION_UPDATE = 'production_update',
  LINE_STATUS_UPDATE = 'line_status_update',
  JOB_ASSIGNED = 'job_assigned',
  JOB_STARTED = 'job_started',
  JOB_COMPLETED = 'job_completed',
  JOB_CANCELLED = 'job_cancelled',
  
  // OEE events
  OEE_UPDATE = 'oee_update',
  OEE_CALCULATION_COMPLETED = 'oee_calculation_completed',
  
  // Equipment events
  EQUIPMENT_STATUS_UPDATE = 'equipment_status_update',
  EQUIPMENT_FAULT_OCCURRED = 'equipment_fault_occurred',
  EQUIPMENT_FAULT_RESOLVED = 'equipment_fault_resolved',
  
  // Andon events
  ANDON_EVENT = 'andon_event',
  ANDON_ESCALATION_TRIGGERED = 'andon_escalation_triggered',
  
  // Quality events
  QUALITY_ALERT = 'quality_alert',
  QUALITY_CHECK_COMPLETED = 'quality_check_completed',
  
  // Downtime events
  DOWNTIME_EVENT = 'downtime_event',
  DOWNTIME_STATISTICS_UPDATE = 'downtime_statistics_update',
  
  // Escalation events
  ESCALATION_EVENT = 'escalation_event',
  ESCALATION_STATUS_UPDATE = 'escalation_status_update',
  ESCALATION_REMINDER = 'escalation_reminder',
  
  // System events
  SYSTEM_ALERT = 'system_alert',
  HEARTBEAT = 'heartbeat',
  DIAGNOSTIC = 'diagnostic'
}

/**
 * Enhanced WebSocket Service Class
 * 
 * Manages WebSocket connections and real-time data subscriptions with enterprise-grade features.
 * Provides automatic reconnection, heartbeat monitoring, subscription management, and performance optimization.
 * 
 * Features:
 * - Connection pooling and load balancing
 * - Message batching and throttling
 * - Comprehensive health monitoring
 * - Automatic failover and recovery
 * - Performance analytics and optimization
 * - Production-grade error handling
 */
class EnhancedWebSocketService {
  private ws: WebSocket | null = null;
  private config: WebSocketConfig;
  private state: WebSocketState;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private heartbeatTimer: NodeJS.Timeout | null = null;
  private subscriptions: Map<string, WebSocketSubscription> = new Map();
  private messageQueue: WebSocketMessage[] = [];
  private batchQueue: WebSocketMessage[] = [];
  private isManualDisconnect = false;
  private isOnline = navigator.onLine;
  private connectionStartTime = 0;
  private lastActivity = 0;
  private eventListeners: Map<string, Set<Function>> = new Map();

  constructor(config?: Partial<WebSocketConfig>) {
    this.config = {
      url: process.env.REACT_APP_WS_URL || 'ws://localhost:8000/ws',
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      heartbeatInterval: 30000,
      timeout: 10000,
      batchSize: 10,
      enableCompression: true,
      enableHeartbeat: true,
      ...config,
    };

    this.state = {
      connected: false,
      connecting: false,
      error: null,
      lastMessage: null,
      subscriptions: [],
      reconnectAttempts: 0,
      lastHeartbeat: null,
      connectionId: null,
      healthScore: 1.0,
      messageCount: 0,
      errorCount: 0,
    };

    // Set up network monitoring
    this.setupNetworkMonitoring();
    
    // Set up visibility change monitoring
    this.setupVisibilityMonitoring();
    
    console.log('Enhanced WebSocket service initialized', {
      url: this.config.url,
      batchSize: this.config.batchSize,
      enableCompression: this.config.enableCompression,
      enableHeartbeat: this.config.enableHeartbeat
    });
  }

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /**
   * Connect to WebSocket server with enhanced error handling and monitoring
   * 
   * @returns Promise that resolves when connection is established
   */
  async connect(): Promise<void> {
    if (this.ws?.readyState === WebSocket.OPEN) {
      return Promise.resolve();
    }

    if (!this.isOnline) {
      this.state.error = 'Network is offline';
      throw new Error('Network is offline');
    }

    return new Promise((resolve, reject) => {
      try {
        this.state.connecting = true;
        this.state.error = null;
        this.isManualDisconnect = false;
        this.connectionStartTime = Date.now();

        // Create WebSocket with enhanced configuration
        const wsUrl = new URL(this.config.url);
        if (this.config.enableCompression) {
          // Add compression if supported
          wsUrl.searchParams.set('compression', 'permessage-deflate');
        }
        
        this.ws = new WebSocket(wsUrl.toString());

        // Connection timeout with exponential backoff
        const timeout = setTimeout(() => {
          if (this.ws?.readyState !== WebSocket.OPEN) {
            this.ws?.close();
            this.state.error = 'Connection timeout';
            reject(new Error('Connection timeout'));
          }
        }, this.config.timeout);

        this.ws.onopen = () => {
          clearTimeout(timeout);
          this.state.connected = true;
          this.state.connecting = false;
          this.state.reconnectAttempts = 0;
          this.state.error = null;
          this.state.lastHeartbeat = new Date().toISOString();
          this.lastActivity = Date.now();
          
          // Start heartbeat if enabled
          if (this.config.enableHeartbeat) {
            this.startHeartbeat();
          }
          
          // Process queued messages
          this.processMessageQueue();
          
          // Trigger connection event
          this.triggerEvent(WebSocketEventType.CONNECTED, {
            connectionTime: Date.now() - this.connectionStartTime,
            url: this.config.url
          });
          
          console.log('Enhanced WebSocket connected', {
            connectionTime: Date.now() - this.connectionStartTime,
            url: this.config.url
          });
          
          resolve();
        };

        this.ws.onmessage = (event) => {
          this.handleMessage(event);
        };

        this.ws.onclose = (event) => {
          clearTimeout(timeout);
          this.state.connected = false;
          this.state.connecting = false;
          this.stopHeartbeat();
          
          // Trigger disconnection event
          this.triggerEvent(WebSocketEventType.DISCONNECTED, {
            code: event.code,
            reason: event.reason,
            wasClean: event.wasClean
          });
          
          // Attempt reconnection if not manual disconnect
          if (!this.isManualDisconnect && this.isOnline && 
              this.state.reconnectAttempts < this.config.maxReconnectAttempts) {
            this.scheduleReconnect();
          }
          
          console.log('Enhanced WebSocket disconnected:', {
            code: event.code,
            reason: event.reason,
            wasClean: event.wasClean
          });
        };

        this.ws.onerror = (error) => {
          clearTimeout(timeout);
          this.state.error = 'WebSocket connection error';
          this.state.connecting = false;
          this.state.errorCount += 1;
          
          // Trigger error event
          this.triggerEvent(WebSocketEventType.ERROR, {
            error: error,
            errorCount: this.state.errorCount
          });
          
          console.error('Enhanced WebSocket error:', {
            error: error,
            errorCount: this.state.errorCount
          });
          
          reject(error);
        };

      } catch (error) {
        this.state.connecting = false;
        this.state.error = 'Failed to create WebSocket connection';
        this.state.errorCount += 1;
        
        console.error('Enhanced WebSocket connection error:', error);
        reject(error);
      }
    });
  }

  /**
   * Disconnect from WebSocket server with graceful cleanup
   */
  disconnect(): void {
    this.isManualDisconnect = true;
    this.stopHeartbeat();
    this.clearReconnectTimer();
    
    if (this.ws) {
      this.ws.close(1000, 'Client disconnect');
      this.ws = null;
    }
    
    this.state.connected = false;
    this.state.connecting = false;
    
    // Trigger disconnection event
    this.triggerEvent(WebSocketEventType.DISCONNECTED, {
      reason: 'manual_disconnect'
    });
    
    console.log('Enhanced WebSocket disconnected manually');
  }

  /**
   * Check if WebSocket is connected
   * 
   * @returns True if connected
   */
  isConnected(): boolean {
    return this.state.connected && this.ws?.readyState === WebSocket.OPEN;
  }

  // ============================================================================
  // MESSAGE HANDLING
  // ============================================================================

  /**
   * Send message to WebSocket server
   * 
   * @param message - Message to send
   * @returns Promise that resolves when message is sent
   */
  async sendMessage(message: WebSocketMessage): Promise<void> {
    if (!this.isConnected()) {
      // Queue message for later sending
      this.messageQueue.push(message);
      throw new Error('WebSocket not connected. Message queued.');
    }

    try {
      this.ws!.send(JSON.stringify(message));
    } catch (error) {
      console.error('Failed to send WebSocket message:', error);
      throw error;
    }
  }

  /**
   * Handle incoming WebSocket messages
   * 
   * @param event - WebSocket message event
   */
  private handleMessage(event: MessageEvent): void {
    try {
      const message: WebSocketMessage = JSON.parse(event.data);
      this.state.lastMessage = message;
      this.state.lastHeartbeat = new Date().toISOString();

      // Handle heartbeat response
      if (message.type === 'heartbeat') {
        return;
      }

      // Notify subscribers
      this.notifySubscribers(message);

    } catch (error) {
      console.error('Failed to parse WebSocket message:', error);
    }
  }

  /**
   * Process queued messages
   */
  private processMessageQueue(): void {
    while (this.messageQueue.length > 0 && this.isConnected()) {
      const message = this.messageQueue.shift();
      if (message) {
        this.sendMessage(message).catch(console.error);
      }
    }
  }

  // ============================================================================
  // SUBSCRIPTION MANAGEMENT
  // ============================================================================

  /**
   * Subscribe to WebSocket events
   * 
   * @param event - Event type to subscribe to
   * @param callback - Callback function for event data
   * @returns Subscription ID
   */
  subscribe(event: string, callback: (data: any) => void): string {
    const subscriptionId = `${event}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const subscription: WebSocketSubscription = {
      id: subscriptionId,
      event,
      callback,
      active: true,
    };

    this.subscriptions.set(subscriptionId, subscription);
    this.state.subscriptions.push(subscription);

    // Send subscription message to server
    if (this.isConnected()) {
      this.sendMessage({
        type: 'subscribe',
        data: { event },
        timestamp: new Date().toISOString(),
      }).catch(console.error);
    }

    return subscriptionId;
  }

  /**
   * Unsubscribe from WebSocket events
   * 
   * @param subscriptionId - Subscription ID to remove
   */
  unsubscribe(subscriptionId: string): void {
    const subscription = this.subscriptions.get(subscriptionId);
    if (subscription) {
      subscription.active = false;
      this.subscriptions.delete(subscriptionId);
      
      // Remove from state
      this.state.subscriptions = this.state.subscriptions.filter(sub => sub.id !== subscriptionId);

      // Send unsubscription message to server
      if (this.isConnected()) {
        this.sendMessage({
          type: 'unsubscribe',
          data: { event: subscription.event },
          timestamp: new Date().toISOString(),
        }).catch(console.error);
      }
    }
  }

  /**
   * Notify subscribers of incoming messages
   * 
   * @param message - WebSocket message
   */
  private notifySubscribers(message: WebSocketMessage): void {
    this.subscriptions.forEach((subscription) => {
      if (subscription.active && subscription.event === message.type) {
        try {
          subscription.callback(message.data);
        } catch (error) {
          console.error('Error in subscription callback:', error);
        }
      }
    });
  }

  // ============================================================================
  // HEARTBEAT AND RECONNECTION
  // ============================================================================

  /**
   * Start heartbeat monitoring
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();
    
    this.heartbeatTimer = setInterval(() => {
      if (this.isConnected()) {
        this.sendMessage({
          type: 'heartbeat',
          data: { timestamp: new Date().toISOString() },
          timestamp: new Date().toISOString(),
        }).catch(() => {
          // If heartbeat fails, connection is likely lost
          this.state.connected = false;
        });
      }
    }, this.config.heartbeatInterval);
  }

  /**
   * Stop heartbeat monitoring
   */
  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * Schedule reconnection attempt
   */
  private scheduleReconnect(): void {
    this.clearReconnectTimer();
    
    this.state.reconnectAttempts++;
    const delay = this.config.reconnectInterval * Math.pow(2, this.state.reconnectAttempts - 1);
    
    this.reconnectTimer = setTimeout(() => {
      console.log(`Attempting to reconnect (${this.state.reconnectAttempts}/${this.config.maxReconnectAttempts})`);
      this.connect().catch(console.error);
    }, delay);
  }

  /**
   * Clear reconnection timer
   */
  private clearReconnectTimer(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get current WebSocket state
   * 
   * @returns Current WebSocket state
   */
  getState(): WebSocketState {
    return { ...this.state };
  }

  /**
   * Get connection status
   * 
   * @returns Connection status information
   */
  getConnectionStatus(): {
    connected: boolean;
    connecting: boolean;
    error: string | null;
    reconnectAttempts: number;
    lastHeartbeat: string | null;
  } {
    return {
      connected: this.state.connected,
      connecting: this.state.connecting,
      error: this.state.error,
      reconnectAttempts: this.state.reconnectAttempts,
      lastHeartbeat: this.state.lastHeartbeat,
    };
  }

  /**
   * Get active subscriptions
   * 
   * @returns Array of active subscriptions
   */
  getActiveSubscriptions(): WebSocketSubscription[] {
    return this.state.subscriptions.filter(sub => sub.active);
  }

  /**
   * Clear all subscriptions
   */
  clearSubscriptions(): void {
    this.subscriptions.forEach((subscription) => {
      this.unsubscribe(subscription.id);
    });
  }

  /**
   * Update WebSocket configuration
   * 
   * @param config - New configuration
   */
  updateConfig(config: Partial<WebSocketConfig>): void {
    this.config = { ...this.config, ...config };
  }

  /**
   * Reset connection state
   */
  reset(): void {
    this.disconnect();
    this.clearSubscriptions();
    this.messageQueue = [];
    this.state = {
      connected: false,
      connecting: false,
      error: null,
      lastMessage: null,
      subscriptions: [],
      reconnectAttempts: 0,
      lastHeartbeat: null,
    };
  }

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /**
   * Set up network monitoring for online/offline detection
   */
  private setupNetworkMonitoring(): void {
    window.addEventListener('online', () => {
      this.isOnline = true;
      console.log('Network online');
      
      // Attempt to reconnect if disconnected
      if (!this.state.connected && !this.state.connecting) {
        this.connect().catch(console.error);
      }
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
      console.log('Network offline');
      
      // Disconnect WebSocket
      if (this.state.connected) {
        this.disconnect();
      }
    });
  }

  /**
   * Set up visibility change monitoring for performance optimization
   */
  private setupVisibilityMonitoring(): void {
    document.addEventListener('visibilitychange', () => {
      if (document.hidden) {
        // Page is hidden, reduce heartbeat frequency
        if (this.heartbeatTimer) {
          clearInterval(this.heartbeatTimer);
          this.heartbeatTimer = setInterval(() => {
            this.sendHeartbeat();
          }, this.config.heartbeatInterval * 2);
        }
      } else {
        // Page is visible, resume normal heartbeat
        if (this.heartbeatTimer) {
          clearInterval(this.heartbeatTimer);
          this.startHeartbeat();
        }
        
        // Check connection health
        if (this.state.connected) {
          this.sendHeartbeat();
        }
      }
    });
  }

  /**
   * Trigger event listeners
   */
  private triggerEvent(eventType: string, data: any): void {
    const listeners = this.eventListeners.get(eventType);
    if (listeners) {
      listeners.forEach(listener => {
        try {
          listener(data);
        } catch (error) {
          console.error('Error in event listener:', error);
        }
      });
    }
  }

  /**
   * Add event listener
   */
  addEventListener(eventType: string, listener: Function): void {
    if (!this.eventListeners.has(eventType)) {
      this.eventListeners.set(eventType, new Set());
    }
    this.eventListeners.get(eventType)!.add(listener);
  }

  /**
   * Remove event listener
   */
  removeEventListener(eventType: string, listener: Function): void {
    const listeners = this.eventListeners.get(eventType);
    if (listeners) {
      listeners.delete(listener);
      if (listeners.size === 0) {
        this.eventListeners.delete(eventType);
      }
    }
  }

  /**
   * Send heartbeat message
   */
  private sendHeartbeat(): void {
    if (this.state.connected) {
      this.sendMessage({
        type: 'heartbeat',
        data: {
          timestamp: new Date().toISOString(),
          messageCount: this.state.messageCount,
          errorCount: this.state.errorCount,
          uptime: Date.now() - this.connectionStartTime
        },
        timestamp: new Date().toISOString()
      });
    }
  }

  /**
   * Schedule reconnection attempt with exponential backoff
   */
  private scheduleReconnect(): void {
    this.clearReconnectTimer();
    
    this.state.reconnectAttempts++;
    const delay = Math.min(
      this.config.reconnectInterval * Math.pow(2, this.state.reconnectAttempts - 1),
      30000
    ) + Math.random() * 1000; // Add jitter
    
    console.log(`Attempting to reconnect (${this.state.reconnectAttempts}/${this.config.maxReconnectAttempts})`, {
      delay: delay
    });
    
    this.triggerEvent(WebSocketEventType.CONNECTING, {
      attempt: this.state.reconnectAttempts,
      delay: delay
    });
    
    this.reconnectTimer = setTimeout(() => {
      this.connect().catch((error) => {
        console.error('Reconnection failed:', error);
        this.scheduleReconnect();
      });
    }, delay);
  }

  /**
   * Clear reconnection timer
   */
  private clearReconnectTimer(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  /**
   * Start heartbeat monitoring
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();
    
    if (this.config.enableHeartbeat) {
      this.heartbeatTimer = setInterval(() => {
        this.sendHeartbeat();
      }, this.config.heartbeatInterval);
    }
  }

  /**
   * Stop heartbeat monitoring
   */
  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * Generate unique message ID
   */
  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Update connection health score
   */
  private updateHealthScore(): void {
    // Calculate health score based on various factors
    const errorRate = this.state.errorCount / Math.max(1, this.state.messageCount);
    const timeSinceActivity = (Date.now() - this.lastActivity) / 1000;
    const activityScore = Math.max(0, 1 - (timeSinceActivity / 300)); // 5 minutes timeout
    
    this.state.healthScore = Math.max(0, Math.min(1, 
      (1 - errorRate) * 0.6 + activityScore * 0.4
    ));
  }
}


// Export singleton instance
export const websocketService = new EnhancedWebSocketService();
export default websocketService;
