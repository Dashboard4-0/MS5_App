/**
 * MS5.0 Floor Dashboard - Enhanced WebSocket Service
 * 
 * Enterprise-grade WebSocket service for cosmic scale operations.
 * The nervous system of a starship - built for reliability and performance.
 * 
 * This service provides comprehensive real-time communication for factory data with:
 * - Automatic reconnection with exponential backoff
 * - Factory network optimization
 * - Offline support and message queuing
 * - Tablet-specific optimizations
 * - Health monitoring and diagnostics
 * - Priority-based message routing
 * - Advanced subscription management
 */

import { logger } from '../utils/logger';

// Enhanced WebSocket configuration interface
interface EnhancedWebSocketConfig {
  url: string;
  protocols?: string[];
  timeout: number;
  reconnectInterval: number;
  maxReconnectAttempts: number;
  heartbeatInterval: number;
  factoryNetwork: boolean;
  tabletOptimized: boolean;
  enableCompression: boolean;
  enableBatching: boolean;
  batchSize: number;
  batchTimeout: number;
  priorityQueue: boolean;
  healthMonitoring: boolean;
}

// Enhanced WebSocket message interface with priority support
interface EnhancedWebSocketMessage {
  type: string;
  data: any;
  timestamp: number;
  id?: string;
  priority?: number;
  retryCount?: number;
  filters?: Record<string, any>;
}

// Enhanced WebSocket event handlers interface
interface EnhancedWebSocketHandlers {
  onOpen?: () => void;
  onMessage?: (message: EnhancedWebSocketMessage) => void;
  onClose?: (event: CloseEvent) => void;
  onError?: (error: Event) => void;
  onReconnect?: (attempt: number) => void;
  onOffline?: () => void;
  onOnline?: () => void;
  onHealthUpdate?: (healthScore: number) => void;
  onBatchProcessed?: (batchSize: number) => void;
}

// WebSocket connection state with enhanced states
enum EnhancedWebSocketState {
  CONNECTING = 'connecting',
  CONNECTED = 'connected',
  DISCONNECTED = 'disconnected',
  RECONNECTING = 'reconnecting',
  OFFLINE = 'offline',
  ERROR = 'error',
  HEALTH_CHECK = 'health_check',
  BATCHING = 'batching'
}

// Message priority levels for intelligent routing
enum MessagePriority {
  CRITICAL = 1,  // System alerts, Andon events
  HIGH = 2,      // Production updates, OEE data
  NORMAL = 3,    // Regular status updates
  LOW = 4        // Heartbeats, diagnostics
}

// Subscription management interface
interface Subscription {
  id: string;
  eventType: string;
  callback: (data: any) => void;
  filters?: Record<string, any>;
  priority: MessagePriority;
  active: boolean;
  createdAt: number;
  lastActivity: number;
}

// Connection metrics interface
interface ConnectionMetrics {
  connectionId: string;
  connectedAt: number;
  lastActivity: number;
  messageCount: number;
  errorCount: number;
  bytesSent: number;
  bytesReceived: number;
  subscriptionCount: number;
  healthScore: number;
  latency: number;
  uptime: number;
}

/**
 * Enhanced WebSocket Service Class
 * 
 * Provides enterprise-grade WebSocket communication with factory-specific optimizations
 * and advanced features for cosmic scale operations.
 */
export class EnhancedWebSocketService {
  private ws: WebSocket | null = null;
  private config: EnhancedWebSocketConfig;
  private handlers: EnhancedWebSocketHandlers;
  private state: EnhancedWebSocketState = EnhancedWebSocketState.DISCONNECTED;
  private reconnectAttempts = 0;
  private reconnectTimer: NodeJS.Timeout | null = null;
  private heartbeatTimer: NodeJS.Timeout | null = null;
  private healthCheckTimer: NodeJS.Timeout | null = null;
  private batchTimer: NodeJS.Timeout | null = null;
  
  // Enhanced message management
  private messageQueue: EnhancedWebSocketMessage[] = [];
  private priorityQueue: Map<MessagePriority, EnhancedWebSocketMessage[]> = new Map();
  private messageBatch: EnhancedWebSocketMessage[] = [];
  private subscriptions: Map<string, Subscription> = new Map();
  
  // Network and performance monitoring
  private isOnline = navigator.onLine;
  private lastHeartbeat = 0;
  private connectionStartTime = 0;
  private messageCount = 0;
  private errorCount = 0;
  private bytesSent = 0;
  private bytesReceived = 0;
  private latency = 0;
  private healthScore = 1.0;
  
  // Factory-specific optimizations
  private factoryMode = false;
  private tabletMode = false;
  private compressionEnabled = false;
  private batchingEnabled = false;

  constructor(config: EnhancedWebSocketConfig, handlers: EnhancedWebSocketHandlers = {}) {
    this.config = {
      timeout: 30000,
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      heartbeatInterval: 30000,
      factoryNetwork: false,
      tabletOptimized: false,
      enableCompression: false,
      enableBatching: false,
      batchSize: 10,
      batchTimeout: 100,
      priorityQueue: true,
      healthMonitoring: true,
      ...config
    };
    
    this.handlers = handlers;
    this.factoryMode = this.config.factoryNetwork;
    this.tabletMode = this.config.tabletOptimized;
    this.compressionEnabled = this.config.enableCompression;
    this.batchingEnabled = this.config.enableBatching;
    
    // Initialize priority queues
    this.initializePriorityQueues();
    
    // Set up enhanced monitoring
    this.setupEnhancedMonitoring();
    
    logger.info('Enhanced WebSocket service initialized', {
      url: this.config.url,
      factoryMode: this.factoryMode,
      tabletMode: this.tabletMode,
      compressionEnabled: this.compressionEnabled,
      batchingEnabled: this.batchingEnabled
    });
  }

  /**
   * Connect to WebSocket server with enhanced error handling and factory optimizations
   */
  public connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.state === EnhancedWebSocketState.CONNECTED) {
        resolve();
        return;
      }

      if (!this.isOnline) {
        this.state = EnhancedWebSocketState.OFFLINE;
        reject(new Error('Network is offline'));
        return;
      }

      this.state = EnhancedWebSocketState.CONNECTING;
      this.connectionStartTime = Date.now();

      try {
        // Create WebSocket connection with enhanced configuration
        const ws = new WebSocket(this.config.url, this.config.protocols);
        
        // Set up connection timeout with factory-specific adjustments
        const timeoutDuration = this.factoryMode ? this.config.timeout * 2 : this.config.timeout;
        const timeoutTimer = setTimeout(() => {
          if (ws.readyState === WebSocket.CONNECTING) {
            ws.close();
            reject(new Error('Connection timeout'));
          }
        }, timeoutDuration);

        // Connection opened with enhanced logging
        ws.onopen = (event) => {
          clearTimeout(timeoutTimer);
          this.state = EnhancedWebSocketState.CONNECTED;
          this.reconnectAttempts = 0;
          this.connectionStartTime = Date.now();
          this.healthScore = 1.0;
          
          logger.info('Enhanced WebSocket connected', {
            url: this.config.url,
            connectionTime: Date.now() - this.connectionStartTime,
            factoryMode: this.factoryMode,
            tabletMode: this.tabletMode
          });

          // Start enhanced monitoring
          this.startHeartbeat();
          this.startHealthMonitoring();
          
          // Process queued messages with priority
          this.processPriorityQueue();
          
          // Process message batch if enabled
          if (this.batchingEnabled) {
            this.startBatching();
          }
          
          // Call handler
          this.handlers.onOpen?.();
          
          resolve();
        };

        // Enhanced message handling with compression and batching support
        ws.onmessage = (event) => {
          try {
            const message: EnhancedWebSocketMessage = JSON.parse(event.data);
            this.messageCount++;
            this.bytesReceived += event.data.length;
            this.lastHeartbeat = Date.now();
            
            // Calculate latency for health monitoring
            if (message.type === 'pong') {
              this.latency = Date.now() - message.timestamp;
              this.updateHealthScore();
            }
            
            // Handle heartbeat responses
            if (message.type === 'heartbeat') {
              return;
            }
            
            logger.debug('Enhanced WebSocket message received', {
              type: message.type,
              messageCount: this.messageCount,
              latency: this.latency,
              priority: message.priority
            });
            
            // Process subscriptions
            this.processSubscriptions(message);
            
            this.handlers.onMessage?.(message);
          } catch (error) {
            logger.error('Enhanced WebSocket message parse error', { error });
            this.errorCount++;
            this.updateHealthScore();
          }
        };

        // Enhanced connection closed handling
        ws.onclose = (event) => {
          clearTimeout(timeoutTimer);
          this.stopHeartbeat();
          this.stopHealthMonitoring();
          this.stopBatching();
          
          logger.info('Enhanced WebSocket connection closed', {
            code: event.code,
            reason: event.reason,
            wasClean: event.wasClean,
            uptime: Date.now() - this.connectionStartTime
          });
          
          this.state = EnhancedWebSocketState.DISCONNECTED;
          this.handlers.onClose?.(event);
          
          // Attempt reconnection with enhanced logic
          if (!event.wasClean && this.isOnline) {
            this.attemptEnhancedReconnect();
          }
        };

        // Enhanced error handling
        ws.onerror = (event) => {
          clearTimeout(timeoutTimer);
          this.errorCount++;
          this.updateHealthScore();
          
          logger.error('Enhanced WebSocket connection error', {
            errorCount: this.errorCount,
            state: this.state,
            healthScore: this.healthScore
          });
          
          this.state = EnhancedWebSocketState.ERROR;
          this.handlers.onError?.(event);
          
          reject(new Error('Enhanced WebSocket connection failed'));
        };

        this.ws = ws;
      } catch (error) {
        this.state = EnhancedWebSocketState.ERROR;
        logger.error('Enhanced WebSocket connection error', { error });
        reject(error);
      }
    });
  }

  /**
   * Disconnect from WebSocket server with graceful shutdown
   */
  public disconnect(): void {
    this.stopHeartbeat();
    this.stopHealthMonitoring();
    this.stopBatching();
    this.clearReconnectTimer();
    
    if (this.ws) {
      this.ws.close(1000, 'Client disconnect');
      this.ws = null;
    }
    
    this.state = EnhancedWebSocketState.DISCONNECTED;
    logger.info('Enhanced WebSocket disconnected');
  }

  /**
   * Send message with priority-based routing and enhanced features
   */
  public send(message: EnhancedWebSocketMessage, priority: MessagePriority = MessagePriority.NORMAL): void {
    if (this.state === EnhancedWebSocketState.CONNECTED && this.ws) {
      try {
        const enhancedMessage: EnhancedWebSocketMessage = {
          ...message,
          timestamp: Date.now(),
          id: message.id || this.generateMessageId(),
          priority: priority,
          retryCount: message.retryCount || 0
        };
        
        // Add to batch if batching is enabled
        if (this.batchingEnabled && priority !== MessagePriority.CRITICAL) {
          this.addToBatch(enhancedMessage);
          return;
        }
        
        // Send immediately for critical messages or when batching is disabled
        this.sendMessage(enhancedMessage);
        
        logger.debug('Enhanced WebSocket message sent', {
          type: message.type,
          id: enhancedMessage.id,
          priority: priority,
          batchEnabled: this.batchingEnabled
        });
      } catch (error) {
        logger.error('Enhanced WebSocket send error', { error });
        this.queueMessage(message, priority);
      }
    } else {
      this.queueMessage(message, priority);
    }
  }

  /**
   * Subscribe to specific event types with advanced filtering
   */
  public subscribe(eventType: string, callback: (data: any) => void, filters?: Record<string, any>, priority: MessagePriority = MessagePriority.NORMAL): string {
    const subscriptionId = this.generateSubscriptionId();
    const subscription: Subscription = {
      id: subscriptionId,
      eventType,
      callback,
      filters,
      priority,
      active: true,
      createdAt: Date.now(),
      lastActivity: Date.now()
    };
    
    this.subscriptions.set(subscriptionId, subscription);
    
    logger.info('Enhanced WebSocket subscription created', {
      subscriptionId,
      eventType,
      filters,
      priority
    });
    
    return subscriptionId;
  }

  /**
   * Unsubscribe from specific event type
   */
  public unsubscribe(subscriptionId: string): void {
    const subscription = this.subscriptions.get(subscriptionId);
    if (subscription) {
      subscription.active = false;
      this.subscriptions.delete(subscriptionId);
      
      logger.info('Enhanced WebSocket subscription removed', {
        subscriptionId,
        eventType: subscription.eventType
      });
    }
  }

  /**
   * Send heartbeat with enhanced monitoring
   */
  public sendHeartbeat(): void {
    if (this.state === EnhancedWebSocketState.CONNECTED) {
      const heartbeatMessage: EnhancedWebSocketMessage = {
        type: 'heartbeat',
        data: {
          timestamp: Date.now(),
          messageCount: this.messageCount,
          errorCount: this.errorCount,
          uptime: Date.now() - this.connectionStartTime,
          healthScore: this.healthScore,
          latency: this.latency,
          subscriptionCount: this.subscriptions.size
        },
        timestamp: Date.now()
      };
      
      this.send(heartbeatMessage, MessagePriority.LOW);
    }
  }

  /**
   * Get enhanced connection state
   */
  public getState(): EnhancedWebSocketState {
    return this.state;
  }

  /**
   * Get comprehensive connection statistics
   */
  public getStats(): ConnectionMetrics {
    return {
      connectionId: this.generateConnectionId(),
      connectedAt: this.connectionStartTime,
      lastActivity: this.lastHeartbeat,
      messageCount: this.messageCount,
      errorCount: this.errorCount,
      bytesSent: this.bytesSent,
      bytesReceived: this.bytesReceived,
      subscriptionCount: this.subscriptions.size,
      healthScore: this.healthScore,
      latency: this.latency,
      uptime: Date.now() - this.connectionStartTime
    };
  }

  /**
   * Get health score for monitoring
   */
  public getHealthScore(): number {
    return this.healthScore;
  }

  /**
   * Initialize priority queues for message routing
   */
  private initializePriorityQueues(): void {
    this.priorityQueue.set(MessagePriority.CRITICAL, []);
    this.priorityQueue.set(MessagePriority.HIGH, []);
    this.priorityQueue.set(MessagePriority.NORMAL, []);
    this.priorityQueue.set(MessagePriority.LOW, []);
  }

  /**
   * Set up enhanced monitoring for factory operations
   */
  private setupEnhancedMonitoring(): void {
    // Enhanced network monitoring
    window.addEventListener('online', () => {
      this.isOnline = true;
      logger.info('Enhanced WebSocket: Network online');
      
      if (this.state === EnhancedWebSocketState.OFFLINE) {
        this.handlers.onOnline?.();
        this.connect();
      }
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
      logger.info('Enhanced WebSocket: Network offline');
      
      this.state = EnhancedWebSocketState.OFFLINE;
      this.handlers.onOffline?.();
      this.disconnect();
    });

    // Enhanced visibility change monitoring
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
        if (this.state === EnhancedWebSocketState.CONNECTED) {
          this.sendHeartbeat();
        }
      }
    });

    // Factory-specific optimizations
    if (this.factoryMode) {
      this.setupFactoryOptimizations();
    }

    // Tablet-specific optimizations
    if (this.tabletMode) {
      this.setupTabletOptimizations();
    }
  }

  /**
   * Set up factory-specific optimizations
   */
  private setupFactoryOptimizations(): void {
    // Reduce heartbeat frequency for factory networks
    this.config.heartbeatInterval = Math.max(this.config.heartbeatInterval, 60000);
    
    // Increase timeout for factory networks
    this.config.timeout = Math.max(this.config.timeout, 60000);
    
    // Enable batching for factory networks
    this.batchingEnabled = true;
    
    logger.info('Factory optimizations enabled', {
      heartbeatInterval: this.config.heartbeatInterval,
      timeout: this.config.timeout,
      batchingEnabled: this.batchingEnabled
    });
  }

  /**
   * Set up tablet-specific optimizations
   */
  private setupTabletOptimizations(): void {
    // Reduce message frequency for tablets
    this.config.batchSize = Math.min(this.config.batchSize, 5);
    
    // Increase batch timeout for tablets
    this.config.batchTimeout = Math.max(this.config.batchTimeout, 200);
    
    // Enable compression for tablets
    this.compressionEnabled = true;
    
    logger.info('Tablet optimizations enabled', {
      batchSize: this.config.batchSize,
      batchTimeout: this.config.batchTimeout,
      compressionEnabled: this.compressionEnabled
    });
  }

  /**
   * Attempt enhanced reconnection with factory-specific logic
   */
  private attemptEnhancedReconnect(): void {
    if (this.reconnectAttempts >= this.config.maxReconnectAttempts) {
      logger.error('Enhanced WebSocket: Max reconnection attempts reached');
      this.state = EnhancedWebSocketState.ERROR;
      return;
    }

    if (!this.isOnline) {
      this.state = EnhancedWebSocketState.OFFLINE;
      return;
    }

    this.state = EnhancedWebSocketState.RECONNECTING;
    this.reconnectAttempts++;

    // Enhanced exponential backoff with factory-specific adjustments
    const baseDelay = this.factoryMode ? this.config.reconnectInterval * 2 : this.config.reconnectInterval;
    const delay = Math.min(
      baseDelay * Math.pow(2, this.reconnectAttempts - 1),
      this.factoryMode ? 120000 : 60000  // Max 2 minutes for factory, 1 minute for standard
    ) + Math.random() * 1000;

    logger.info('Enhanced WebSocket: Attempting to reconnect', {
      attempt: this.reconnectAttempts,
      delay: delay,
      factoryMode: this.factoryMode
    });

    this.handlers.onReconnect?.(this.reconnectAttempts);

    this.reconnectTimer = setTimeout(() => {
      this.connect().catch((error) => {
        logger.error('Enhanced WebSocket: Reconnection failed', { error });
        this.attemptEnhancedReconnect();
      });
    }, delay);
  }

  /**
   * Start heartbeat with enhanced monitoring
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();
    
    const interval = this.factoryMode ? 
      Math.max(this.config.heartbeatInterval, 60000) : 
      this.config.heartbeatInterval;
    
    this.heartbeatTimer = setInterval(() => {
      this.sendHeartbeat();
    }, interval);
  }

  /**
   * Stop heartbeat timer
   */
  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * Start health monitoring
   */
  private startHealthMonitoring(): void {
    if (!this.config.healthMonitoring) return;
    
    this.stopHealthMonitoring();
    
    this.healthCheckTimer = setInterval(() => {
      this.performHealthCheck();
    }, 30000); // Check every 30 seconds
  }

  /**
   * Stop health monitoring
   */
  private stopHealthMonitoring(): void {
    if (this.healthCheckTimer) {
      clearInterval(this.healthCheckTimer);
      this.healthCheckTimer = null;
    }
  }

  /**
   * Perform comprehensive health check
   */
  private performHealthCheck(): void {
    const timeSinceLastActivity = Date.now() - this.lastHeartbeat;
    
    // Check for stale connection
    if (timeSinceLastActivity > 300000) { // 5 minutes
      logger.warning('Enhanced WebSocket: Stale connection detected', {
        timeSinceLastActivity,
        healthScore: this.healthScore
      });
      this.updateHealthScore();
    }
    
    // Update health score
    this.updateHealthScore();
    
    // Notify handlers of health update
    this.handlers.onHealthUpdate?.(this.healthScore);
  }

  /**
   * Update health score based on various metrics
   */
  private updateHealthScore(): void {
    let score = 1.0;
    
    // Reduce score based on error rate
    if (this.messageCount > 0) {
      const errorRate = this.errorCount / this.messageCount;
      score -= errorRate * 0.5;
    }
    
    // Reduce score based on latency
    if (this.latency > 1000) { // More than 1 second
      score -= Math.min((this.latency - 1000) / 10000, 0.3);
    }
    
    // Reduce score based on time since last activity
    const timeSinceLastActivity = Date.now() - this.lastHeartbeat;
    if (timeSinceLastActivity > 60000) { // More than 1 minute
      score -= Math.min(timeSinceLastActivity / 300000, 0.2);
    }
    
    this.healthScore = Math.max(0, Math.min(1, score));
  }

  /**
   * Start message batching
   */
  private startBatching(): void {
    if (!this.batchingEnabled) return;
    
    this.stopBatching();
    
    this.batchTimer = setInterval(() => {
      this.processBatch();
    }, this.config.batchTimeout);
  }

  /**
   * Stop message batching
   */
  private stopBatching(): void {
    if (this.batchTimer) {
      clearInterval(this.batchTimer);
      this.batchTimer = null;
    }
  }

  /**
   * Add message to batch
   */
  private addToBatch(message: EnhancedWebSocketMessage): void {
    this.messageBatch.push(message);
    
    // Process batch if it reaches the size limit
    if (this.messageBatch.length >= this.config.batchSize) {
      this.processBatch();
    }
  }

  /**
   * Process message batch
   */
  private processBatch(): void {
    if (this.messageBatch.length === 0) return;
    
    const batch = [...this.messageBatch];
    this.messageBatch = [];
    
    // Send batch as single message
    const batchMessage: EnhancedWebSocketMessage = {
      type: 'batch',
      data: {
        messages: batch,
        batchSize: batch.length,
        timestamp: Date.now()
      },
      timestamp: Date.now()
    };
    
    this.sendMessage(batchMessage);
    
    this.handlers.onBatchProcessed?.(batch.length);
    
    logger.debug('Enhanced WebSocket: Batch processed', {
      batchSize: batch.length
    });
  }

  /**
   * Process priority queue
   */
  private processPriorityQueue(): void {
    // Process messages in priority order
    for (const priority of [MessagePriority.CRITICAL, MessagePriority.HIGH, MessagePriority.NORMAL, MessagePriority.LOW]) {
      const queue = this.priorityQueue.get(priority);
      if (queue && queue.length > 0) {
        const message = queue.shift();
        if (message) {
          this.sendMessage(message);
        }
      }
    }
  }

  /**
   * Process subscriptions for incoming messages
   */
  private processSubscriptions(message: EnhancedWebSocketMessage): void {
    this.subscriptions.forEach((subscription) => {
      if (!subscription.active) return;
      
      // Check if message matches subscription
      if (message.type === subscription.eventType) {
        // Apply filters if present
        if (subscription.filters && !this.matchesFilters(message.data, subscription.filters)) {
          return;
        }
        
        // Update subscription activity
        subscription.lastActivity = Date.now();
        
        // Call callback
        try {
          subscription.callback(message.data);
        } catch (error) {
          logger.error('Enhanced WebSocket: Subscription callback error', {
            subscriptionId: subscription.id,
            eventType: subscription.eventType,
            error
          });
        }
      }
    });
  }

  /**
   * Check if message data matches filters
   */
  private matchesFilters(data: any, filters: Record<string, any>): boolean {
    for (const [key, value] of Object.entries(filters)) {
      if (data[key] !== value) {
        return false;
      }
    }
    return true;
  }

  /**
   * Send message directly to WebSocket
   */
  private sendMessage(message: EnhancedWebSocketMessage): void {
    if (!this.ws || this.state !== EnhancedWebSocketState.CONNECTED) {
      return;
    }
    
    try {
      const messageString = JSON.stringify(message);
      this.ws.send(messageString);
      this.bytesSent += messageString.length;
    } catch (error) {
      logger.error('Enhanced WebSocket: Send message error', { error });
      this.errorCount++;
      this.updateHealthScore();
    }
  }

  /**
   * Queue message with priority
   */
  private queueMessage(message: EnhancedWebSocketMessage, priority: MessagePriority = MessagePriority.NORMAL): void {
    const queue = this.priorityQueue.get(priority);
    if (queue) {
      queue.push(message);
    }
    
    // Limit queue size
    if (this.messageQueue.length > 100) {
      this.messageQueue.shift();
    }
    
    logger.debug('Enhanced WebSocket: Message queued', {
      type: message.type,
      priority: priority,
      queueSize: this.messageQueue.length
    });
  }

  /**
   * Clear reconnect timer
   */
  private clearReconnectTimer(): void {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  /**
   * Generate unique message ID
   */
  private generateMessageId(): string {
    return `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate unique subscription ID
   */
  private generateSubscriptionId(): string {
    return `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate unique connection ID
   */
  private generateConnectionId(): string {
    return `conn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

/**
 * Enhanced WebSocket Service Factory
 * 
 * Creates configured enhanced WebSocket service instances for different environments
 */
export class EnhancedWebSocketServiceFactory {
  /**
   * Create factory-optimized WebSocket service
   */
  public static createFactoryService(
    url: string,
    handlers: EnhancedWebSocketHandlers = {}
  ): EnhancedWebSocketService {
    return new EnhancedWebSocketService({
      url,
      timeout: 60000,
      reconnectInterval: 2000,
      maxReconnectAttempts: 15,
      heartbeatInterval: 60000,
      factoryNetwork: true,
      tabletOptimized: false,
      enableCompression: true,
      enableBatching: true,
      batchSize: 15,
      batchTimeout: 50,
      priorityQueue: true,
      healthMonitoring: true
    }, handlers);
  }

  /**
   * Create tablet-optimized WebSocket service
   */
  public static createTabletService(
    url: string,
    handlers: EnhancedWebSocketHandlers = {}
  ): EnhancedWebSocketService {
    return new EnhancedWebSocketService({
      url,
      timeout: 30000,
      reconnectInterval: 5000,
      maxReconnectAttempts: 8,
      heartbeatInterval: 45000,
      factoryNetwork: false,
      tabletOptimized: true,
      enableCompression: true,
      enableBatching: true,
      batchSize: 5,
      batchTimeout: 200,
      priorityQueue: true,
      healthMonitoring: true
    }, handlers);
  }

  /**
   * Create standard WebSocket service
   */
  public static createStandardService(
    url: string,
    handlers: EnhancedWebSocketHandlers = {}
  ): EnhancedWebSocketService {
    return new EnhancedWebSocketService({
      url,
      timeout: 30000,
      reconnectInterval: 5000,
      maxReconnectAttempts: 10,
      heartbeatInterval: 30000,
      factoryNetwork: false,
      tabletOptimized: false,
      enableCompression: false,
      enableBatching: false,
      batchSize: 10,
      batchTimeout: 100,
      priorityQueue: true,
      healthMonitoring: true
    }, handlers);
  }

  /**
   * Create high-performance WebSocket service for critical operations
   */
  public static createHighPerformanceService(
    url: string,
    handlers: EnhancedWebSocketHandlers = {}
  ): EnhancedWebSocketService {
    return new EnhancedWebSocketService({
      url,
      timeout: 15000,
      reconnectInterval: 1000,
      maxReconnectAttempts: 20,
      heartbeatInterval: 15000,
      factoryNetwork: true,
      tabletOptimized: false,
      enableCompression: true,
      enableBatching: true,
      batchSize: 20,
      batchTimeout: 25,
      priorityQueue: true,
      healthMonitoring: true
    }, handlers);
  }
}

// Export enhanced service instances
export const enhancedWebSocketService = EnhancedWebSocketServiceFactory.createFactoryService(
  process.env.WS_BASE_URL || 'wss://api.ms5dashboard.com/ws',
  {
    onOpen: () => logger.info('Enhanced WebSocket connection opened'),
    onClose: (event) => logger.info('Enhanced WebSocket connection closed', { event }),
    onError: (error) => logger.error('Enhanced WebSocket error', { error }),
    onReconnect: (attempt) => logger.info('Enhanced WebSocket reconnecting', { attempt }),
    onOffline: () => logger.info('Enhanced WebSocket offline'),
    onOnline: () => logger.info('Enhanced WebSocket online'),
    onHealthUpdate: (healthScore) => logger.debug('Enhanced WebSocket health update', { healthScore }),
    onBatchProcessed: (batchSize) => logger.debug('Enhanced WebSocket batch processed', { batchSize })
  }
);

// Export legacy service for backward compatibility
export const webSocketService = enhancedWebSocketService;

// Export types and enums for external use
export { 
  EnhancedWebSocketService, 
  EnhancedWebSocketConfig, 
  EnhancedWebSocketMessage, 
  EnhancedWebSocketHandlers, 
  EnhancedWebSocketState, 
  MessagePriority, 
  Subscription, 
  ConnectionMetrics 
};

export default enhancedWebSocketService;