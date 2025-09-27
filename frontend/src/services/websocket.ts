/**
 * MS5.0 Floor Dashboard - WebSocket Service
 * 
 * This service handles real-time communication with the MS5.0 backend
 * using WebSocket connections for live updates and notifications.
 */

import { WS_CONFIGURATION, WS_CONFIG } from '../config/api';
import { EVENT_TYPES } from '../config/constants';
import { logger } from '../utils/logger';

// Types
interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
  id?: string;
}

interface Subscription {
  id: string;
  type: string;
  filter?: any;
  callback: (data: any) => void;
}

interface ConnectionState {
  isConnected: boolean;
  isConnecting: boolean;
  reconnectAttempts: number;
  lastConnected?: Date;
  lastError?: string;
}

class WebSocketService {
  private ws: WebSocket | null = null;
  private url: string;
  private state: ConnectionState = {
    isConnected: false,
    isConnecting: false,
    reconnectAttempts: 0,
  };
  private subscriptions: Map<string, Subscription> = new Map();
  private messageQueue: WebSocketMessage[] = [];
  private heartbeatInterval: NodeJS.Timeout | null = null;
  private reconnectTimeout: NodeJS.Timeout | null = null;
  private listeners: Map<string, ((data: any) => void)[]> = new Map();

  constructor() {
    this.url = WS_CONFIGURATION.baseURL + '/ws';
    this.setupEventListeners();
  }

  private setupEventListeners(): void {
    // Listen for app state changes
    // TODO: Add app state listener for background/foreground
  }

  private generateSubscriptionId(): string {
    return `sub_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  private createWebSocket(): WebSocket {
    const ws = new WebSocket(this.url);
    
    ws.onopen = this.handleOpen.bind(this);
    ws.onmessage = this.handleMessage.bind(this);
    ws.onclose = this.handleClose.bind(this);
    ws.onerror = this.handleError.bind(this);
    
    return ws;
  }

  private handleOpen(): void {
    logger.info('WebSocket connected');
    
    this.state = {
      isConnected: true,
      isConnecting: false,
      reconnectAttempts: 0,
      lastConnected: new Date(),
    };

    // Start heartbeat
    this.startHeartbeat();
    
    // Process queued messages
    this.processMessageQueue();
    
    // Notify listeners
    this.notifyListeners('connection', { connected: true });
  }

  private handleMessage(event: MessageEvent): void {
    try {
      const message: WebSocketMessage = JSON.parse(event.data);
      logger.debug('WebSocket message received', { type: message.type });
      
      // Process message based on type
      this.processMessage(message);
      
    } catch (error) {
      logger.error('Failed to parse WebSocket message', error);
    }
  }

  private handleClose(event: CloseEvent): void {
    logger.info('WebSocket disconnected', { 
      code: event.code, 
      reason: event.reason 
    });
    
    this.state = {
      ...this.state,
      isConnected: false,
      isConnecting: false,
    };

    // Stop heartbeat
    this.stopHeartbeat();
    
    // Notify listeners
    this.notifyListeners('connection', { connected: false });
    
    // Attempt to reconnect
    this.scheduleReconnect();
  }

  private handleError(error: Event): void {
    logger.error('WebSocket error', error);
    
    this.state = {
      ...this.state,
      isConnecting: false,
      lastError: 'WebSocket connection error',
    };
    
    // Notify listeners
    this.notifyListeners('error', { error: 'Connection error' });
  }

  private processMessage(message: WebSocketMessage): void {
    // Handle different message types
    switch (message.type) {
      case EVENT_TYPES.LINE_STATUS_UPDATE:
        this.handleLineStatusUpdate(message.data);
        break;
      case EVENT_TYPES.EQUIPMENT_STATUS_CHANGE:
        this.handleEquipmentStatusChange(message.data);
        break;
      case EVENT_TYPES.DOWNTIME_EVENT:
        this.handleDowntimeEvent(message.data);
        break;
      case EVENT_TYPES.ANDON_ALERT:
        this.handleAndonAlert(message.data);
        break;
      case EVENT_TYPES.OEE_UPDATE:
        this.handleOEEUpdate(message.data);
        break;
      case EVENT_TYPES.JOB_UPDATE:
        this.handleJobUpdate(message.data);
        break;
      case EVENT_TYPES.SYSTEM_ALERT:
        this.handleSystemAlert(message.data);
        break;
      case 'escalation_event':
        this.handleEscalationEvent(message.data);
        break;
      case 'escalation_status_update':
        this.handleEscalationStatusUpdate(message.data);
        break;
      case 'escalation_reminder':
        this.handleEscalationReminder(message.data);
        break;
      case 'quality_update':
        this.handleQualityUpdate(message.data);
        break;
      case 'changeover_update':
        this.handleChangeoverUpdate(message.data);
        break;
      case 'subscription_confirmed':
        this.handleSubscriptionConfirmed(message.data);
        break;
      case 'unsubscription_confirmed':
        this.handleUnsubscriptionConfirmed(message.data);
        break;
      case 'pong':
        this.handlePong(message.data);
        break;
      case 'error':
        this.handleError(message.data);
        break;
      default:
        logger.warn('Unknown message type', { type: message.type });
    }
  }

  private handleLineStatusUpdate(data: any): void {
    this.notifyListeners('line_status_update', data);
    
    // Notify specific line subscribers
    this.notifySubscribers('line_status_update', data);
  }

  private handleEquipmentStatusChange(data: any): void {
    this.notifyListeners('equipment_status_change', data);
    
    // Notify specific equipment subscribers
    this.notifySubscribers('equipment_status_change', data);
  }

  private handleDowntimeEvent(data: any): void {
    this.notifyListeners('downtime_event', data);
    
    // Notify downtime subscribers
    this.notifySubscribers('downtime_event', data);
  }

  private handleAndonAlert(data: any): void {
    this.notifyListeners('andon_alert', data);
    
    // Notify Andon subscribers
    this.notifySubscribers('andon_alert', data);
  }

  private handleOEEUpdate(data: any): void {
    this.notifyListeners('oee_update', data);
    
    // Notify OEE subscribers
    this.notifySubscribers('oee_update', data);
  }

  private handleJobUpdate(data: any): void {
    this.notifyListeners('job_update', data);
    
    // Notify job subscribers
    this.notifySubscribers('job_update', data);
  }

  private handleSystemAlert(data: any): void {
    this.notifyListeners('system_alert', data);
    
    // Notify system alert subscribers
    this.notifySubscribers('system_alert', data);
  }

  private handleEscalationEvent(data: any): void {
    this.notifyListeners('escalation_event', data);
    
    // Notify escalation subscribers
    this.notifySubscribers('escalation_event', data);
  }

  private handleEscalationStatusUpdate(data: any): void {
    this.notifyListeners('escalation_status_update', data);
    
    // Notify escalation status subscribers
    this.notifySubscribers('escalation_status_update', data);
  }

  private handleEscalationReminder(data: any): void {
    this.notifyListeners('escalation_reminder', data);
    
    // Notify escalation reminder subscribers
    this.notifySubscribers('escalation_reminder', data);
  }

  private handleQualityUpdate(data: any): void {
    this.notifyListeners('quality_update', data);
    
    // Notify quality subscribers
    this.notifySubscribers('quality_update', data);
  }

  private handleChangeoverUpdate(data: any): void {
    this.notifyListeners('changeover_update', data);
    
    // Notify changeover subscribers
    this.notifySubscribers('changeover_update', data);
  }

  private handleSubscriptionConfirmed(data: any): void {
    this.notifyListeners('subscription_confirmed', data);
    logger.debug('Subscription confirmed', data);
  }

  private handleUnsubscriptionConfirmed(data: any): void {
    this.notifyListeners('unsubscription_confirmed', data);
    logger.debug('Unsubscription confirmed', data);
  }

  private handlePong(data: any): void {
    this.notifyListeners('pong', data);
    logger.debug('Pong received', data);
  }

  private handleError(data: any): void {
    this.notifyListeners('error', data);
    logger.error('WebSocket error message', data);
  }

  private notifyListeners(event: string, data: any): void {
    const listeners = this.listeners.get(event) || [];
    listeners.forEach(listener => {
      try {
        listener(data);
      } catch (error) {
        logger.error('Error in event listener', { event, error });
      }
    });
  }

  private notifySubscribers(type: string, data: any): void {
    this.subscriptions.forEach(subscription => {
      if (subscription.type === type) {
        try {
          subscription.callback(data);
        } catch (error) {
          logger.error('Error in subscription callback', { 
            subscriptionId: subscription.id, 
            error 
          });
        }
      }
    });
  }

  private startHeartbeat(): void {
    this.heartbeatInterval = setInterval(() => {
      if (this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'ping' }));
      }
    }, WS_CONFIG.heartbeatInterval);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  private scheduleReconnect(): void {
    if (this.state.reconnectAttempts >= WS_CONFIG.maxReconnectAttempts) {
      logger.error('Max reconnection attempts reached');
      return;
    }

    const delay = WS_CONFIG.reconnectInterval * Math.pow(2, this.state.reconnectAttempts);
    
    this.reconnectTimeout = setTimeout(() => {
      this.connect();
    }, delay);
  }

  private processMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift();
      if (message && this.ws && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(message));
      }
    }
  }

  // Public methods
  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      if (this.state.isConnected || this.state.isConnecting) {
        resolve();
        return;
      }

      this.state.isConnecting = true;
      
      try {
        this.ws = this.createWebSocket();
        
        // Set up connection timeout
        const timeout = setTimeout(() => {
          if (this.state.isConnecting) {
            this.state.isConnecting = false;
            reject(new Error('Connection timeout'));
          }
        }, 10000);

        // Override handleOpen to clear timeout
        const originalHandleOpen = this.handleOpen.bind(this);
        this.handleOpen = () => {
          clearTimeout(timeout);
          originalHandleOpen();
          resolve();
        };

        // Override handleError to clear timeout and reject
        const originalHandleError = this.handleError.bind(this);
        this.handleError = (error: Event) => {
          clearTimeout(timeout);
          originalHandleError(error);
          reject(error);
        };

      } catch (error) {
        this.state.isConnecting = false;
        reject(error);
      }
    });
  }

  disconnect(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    
    this.stopHeartbeat();
    
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    
    this.state = {
      isConnected: false,
      isConnecting: false,
      reconnectAttempts: 0,
    };
  }

  subscribe(type: string, callback: (data: any) => void, filter?: any): string {
    const id = this.generateSubscriptionId();
    
    this.subscriptions.set(id, {
      id,
      type,
      filter,
      callback,
    });
    
    logger.debug('WebSocket subscription created', { id, type });
    
    return id;
  }

  unsubscribe(id: string): void {
    if (this.subscriptions.delete(id)) {
      logger.debug('WebSocket subscription removed', { id });
    }
  }

  subscribeToLine(lineId: string, callback: (data: any) => void): string {
    return this.subscribe('line_status_update', callback, { line_id: lineId });
  }

  subscribeToEquipment(equipmentCode: string, callback: (data: any) => void): string {
    return this.subscribe('equipment_status_change', callback, { equipment_code: equipmentCode });
  }

  subscribeToAndon(callback: (data: any) => void): string {
    return this.subscribe('andon_alert', callback);
  }

  subscribeToOEE(callback: (data: any) => void): string {
    return this.subscribe('oee_update', callback);
  }

  subscribeToJobs(callback: (data: any) => void): string {
    return this.subscribe('job_update', callback);
  }

  subscribeToEscalations(callback: (data: any) => void): string {
    return this.subscribe('escalation_event', callback);
  }

  subscribeToQuality(callback: (data: any) => void): string {
    return this.subscribe('quality_update', callback);
  }

  subscribeToChangeover(callback: (data: any) => void): string {
    return this.subscribe('changeover_update', callback);
  }

  addEventListener(event: string, listener: (data: any) => void): void {
    const listeners = this.listeners.get(event) || [];
    listeners.push(listener);
    this.listeners.set(event, listeners);
  }

  removeEventListener(event: string, listener: (data: any) => void): void {
    const listeners = this.listeners.get(event) || [];
    const index = listeners.indexOf(listener);
    if (index > -1) {
      listeners.splice(index, 1);
      this.listeners.set(event, listeners);
    }
  }

  send(message: WebSocketMessage): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      // Queue message for later
      this.messageQueue.push(message);
    }
  }

  getConnectionState(): ConnectionState {
    return { ...this.state };
  }

  isConnected(): boolean {
    return this.state.isConnected;
  }

  getSubscriptionCount(): number {
    return this.subscriptions.size;
  }

  getQueuedMessageCount(): number {
    return this.messageQueue.length;
  }
}

// Export singleton instance
export const wsService = new WebSocketService();
export default wsService;
