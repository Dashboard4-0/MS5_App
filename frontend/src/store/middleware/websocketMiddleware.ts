/**
 * MS5.0 Floor Dashboard - WebSocket Middleware
 * 
 * This middleware integrates the WebSocket service with the Redux store,
 * handling real-time updates and WebSocket state management.
 */

import { Middleware } from '@reduxjs/toolkit';
import { useDispatch, useSelector } from 'react-redux';
import { websocketService } from '../../services/websocketService';
import { RootState } from '../index';
import { AppDispatch } from '../index';

// WebSocket Action Types
export const WEBSOCKET_ACTIONS = {
  // Connection Management
  CONNECT: 'websocket/connect',
  DISCONNECT: 'websocket/disconnect',
  CONNECTION_STATUS_CHANGED: 'websocket/connectionStatusChanged',
  
  // Message Handling
  MESSAGE_RECEIVED: 'websocket/messageReceived',
  MESSAGE_SENT: 'websocket/messageSent',
  
  // Subscription Management
  SUBSCRIBE: 'websocket/subscribe',
  UNSUBSCRIBE: 'websocket/unsubscribe',
  SUBSCRIPTION_ADDED: 'websocket/subscriptionAdded',
  SUBSCRIPTION_REMOVED: 'websocket/subscriptionRemoved',
  
  // Error Handling
  ERROR: 'websocket/error',
  CLEAR_ERROR: 'websocket/clearError',
  
  // State Management
  UPDATE_STATE: 'websocket/updateState',
  RESET_STATE: 'websocket/resetState',
} as const;

// WebSocket Action Creators
export const websocketActions = {
  // Connection Management
  connect: () => ({ type: WEBSOCKET_ACTIONS.CONNECT }),
  disconnect: () => ({ type: WEBSOCKET_ACTIONS.DISCONNECT }),
  connectionStatusChanged: (isOnline: boolean) => ({
    type: WEBSOCKET_ACTIONS.CONNECTION_STATUS_CHANGED,
    payload: { isOnline },
  }),
  
  // Message Handling
  messageReceived: (message: any) => ({
    type: WEBSOCKET_ACTIONS.MESSAGE_RECEIVED,
    payload: { message },
  }),
  messageSent: (message: any) => ({
    type: WEBSOCKET_ACTIONS.MESSAGE_SENT,
    payload: { message },
  }),
  
  // Subscription Management
  subscribe: (event: string, callback: (data: any) => void) => ({
    type: WEBSOCKET_ACTIONS.SUBSCRIBE,
    payload: { event, callback },
  }),
  unsubscribe: (subscriptionId: string) => ({
    type: WEBSOCKET_ACTIONS.UNSUBSCRIBE,
    payload: { subscriptionId },
  }),
  subscriptionAdded: (subscription: any) => ({
    type: WEBSOCKET_ACTIONS.SUBSCRIPTION_ADDED,
    payload: { subscription },
  }),
  subscriptionRemoved: (subscriptionId: string) => ({
    type: WEBSOCKET_ACTIONS.SUBSCRIPTION_REMOVED,
    payload: { subscriptionId },
  }),
  
  // Error Handling
  error: (error: string) => ({
    type: WEBSOCKET_ACTIONS.ERROR,
    payload: { error },
  }),
  clearError: () => ({ type: WEBSOCKET_ACTIONS.CLEAR_ERROR }),
  
  // State Management
  updateState: (state: any) => ({
    type: WEBSOCKET_ACTIONS.UPDATE_STATE,
    payload: { state },
  }),
  resetState: () => ({ type: WEBSOCKET_ACTIONS.RESET_STATE }),
};

// WebSocket Middleware
export const websocketMiddleware: Middleware<{}, RootState, AppDispatch> = (store) => (next) => (action) => {
  const { type, payload } = action;

  switch (type) {
    case WEBSOCKET_ACTIONS.CONNECT:
      handleConnect(store);
      break;
      
    case WEBSOCKET_ACTIONS.DISCONNECT:
      handleDisconnect(store);
      break;
      
    case WEBSOCKET_ACTIONS.SUBSCRIBE:
      handleSubscribe(store, payload.event, payload.callback);
      break;
      
    case WEBSOCKET_ACTIONS.UNSUBSCRIBE:
      handleUnsubscribe(store, payload.subscriptionId);
      break;
      
    case WEBSOCKET_ACTIONS.MESSAGE_SENT:
      handleMessageSent(store, payload.message);
      break;
      
    case WEBSOCKET_ACTIONS.ERROR:
      handleError(store, payload.error);
      break;
      
    case WEBSOCKET_ACTIONS.CLEAR_ERROR:
      handleClearError(store);
      break;
      
    case WEBSOCKET_ACTIONS.RESET_STATE:
      handleResetState(store);
      break;
  }

  return next(action);
};

// WebSocket Event Handlers
const handleConnect = async (store: any) => {
  try {
    await websocketService.connect();
    
    // Update connection status
    store.dispatch(websocketActions.connectionStatusChanged(true));
    
    // Setup message handler
    websocketService.subscribe('*', (data: any) => {
      store.dispatch(websocketActions.messageReceived(data));
    });
    
    console.log('WebSocket connected successfully');
  } catch (error) {
    console.error('Failed to connect WebSocket:', error);
    store.dispatch(websocketActions.error('Failed to connect WebSocket'));
  }
};

const handleDisconnect = (store: any) => {
  try {
    websocketService.disconnect();
    store.dispatch(websocketActions.connectionStatusChanged(false));
    console.log('WebSocket disconnected');
  } catch (error) {
    console.error('Failed to disconnect WebSocket:', error);
    store.dispatch(websocketActions.error('Failed to disconnect WebSocket'));
  }
};

const handleSubscribe = (store: any, event: string, callback: (data: any) => void) => {
  try {
    const subscriptionId = websocketService.subscribe(event, callback);
    store.dispatch(websocketActions.subscriptionAdded({
      id: subscriptionId,
      event,
      callback,
    }));
    console.log(`Subscribed to WebSocket event: ${event}`);
  } catch (error) {
    console.error('Failed to subscribe to WebSocket event:', error);
    store.dispatch(websocketActions.error('Failed to subscribe to WebSocket event'));
  }
};

const handleUnsubscribe = (store: any, subscriptionId: string) => {
  try {
    websocketService.unsubscribe(subscriptionId);
    store.dispatch(websocketActions.subscriptionRemoved(subscriptionId));
    console.log(`Unsubscribed from WebSocket event: ${subscriptionId}`);
  } catch (error) {
    console.error('Failed to unsubscribe from WebSocket event:', error);
    store.dispatch(websocketActions.error('Failed to unsubscribe from WebSocket event'));
  }
};

const handleMessageSent = (store: any, message: any) => {
  try {
    websocketService.sendMessage(message);
    store.dispatch(websocketActions.messageSent(message));
    console.log('WebSocket message sent:', message);
  } catch (error) {
    console.error('Failed to send WebSocket message:', error);
    store.dispatch(websocketActions.error('Failed to send WebSocket message'));
  }
};

const handleError = (store: any, error: string) => {
  console.error('WebSocket error:', error);
  // Error is already dispatched by the action creator
};

const handleClearError = (store: any) => {
  console.log('WebSocket error cleared');
  // Error clearing is handled by the reducer
};

const handleResetState = (store: any) => {
  try {
    websocketService.reset();
    console.log('WebSocket state reset');
  } catch (error) {
    console.error('Failed to reset WebSocket state:', error);
    store.dispatch(websocketActions.error('Failed to reset WebSocket state'));
  }
};

// WebSocket Reducer
export const websocketReducer = (state: any = {
  connected: false,
  connecting: false,
  error: null,
  subscriptions: [],
  lastMessage: null,
  lastSentMessage: null,
}, action: any) => {
  switch (action.type) {
    case WEBSOCKET_ACTIONS.CONNECTION_STATUS_CHANGED:
      return {
        ...state,
        connected: action.payload.isOnline,
        connecting: false,
        error: null,
      };
      
    case WEBSOCKET_ACTIONS.MESSAGE_RECEIVED:
      return {
        ...state,
        lastMessage: action.payload.message,
      };
      
    case WEBSOCKET_ACTIONS.MESSAGE_SENT:
      return {
        ...state,
        lastSentMessage: action.payload.message,
      };
      
    case WEBSOCKET_ACTIONS.SUBSCRIPTION_ADDED:
      return {
        ...state,
        subscriptions: [...state.subscriptions, action.payload.subscription],
      };
      
    case WEBSOCKET_ACTIONS.SUBSCRIPTION_REMOVED:
      return {
        ...state,
        subscriptions: state.subscriptions.filter(
          (sub: any) => sub.id !== action.payload.subscriptionId
        ),
      };
      
    case WEBSOCKET_ACTIONS.ERROR:
      return {
        ...state,
        error: action.payload.error,
        connecting: false,
      };
      
    case WEBSOCKET_ACTIONS.CLEAR_ERROR:
      return {
        ...state,
        error: null,
      };
      
    case WEBSOCKET_ACTIONS.UPDATE_STATE:
      return {
        ...state,
        ...action.payload.state,
      };
      
    case WEBSOCKET_ACTIONS.RESET_STATE:
      return {
        connected: false,
        connecting: false,
        error: null,
        subscriptions: [],
        lastMessage: null,
        lastSentMessage: null,
      };
      
    default:
      return state;
  }
};

// WebSocket Selectors
export const websocketSelectors = {
  isConnected: (state: RootState) => state.websocket?.connected || false,
  isConnecting: (state: RootState) => state.websocket?.connecting || false,
  error: (state: RootState) => state.websocket?.error || null,
  subscriptions: (state: RootState) => state.websocket?.subscriptions || [],
  lastMessage: (state: RootState) => state.websocket?.lastMessage || null,
  lastSentMessage: (state: RootState) => state.websocket?.lastSentMessage || null,
  connectionStatus: (state: RootState) => ({
    connected: state.websocket?.connected || false,
    connecting: state.websocket?.connecting || false,
    error: state.websocket?.error || null,
  }),
};

// WebSocket Hooks
export const useWebSocket = () => {
  const dispatch = useDispatch();
  const isConnected = useSelector(websocketSelectors.isConnected);
  const isConnecting = useSelector(websocketSelectors.isConnecting);
  const error = useSelector(websocketSelectors.error);
  const subscriptions = useSelector(websocketSelectors.subscriptions);
  const lastMessage = useSelector(websocketSelectors.lastMessage);
  const lastSentMessage = useSelector(websocketSelectors.lastSentMessage);

  const connect = useCallback(() => {
    dispatch(websocketActions.connect());
  }, [dispatch]);

  const disconnect = useCallback(() => {
    dispatch(websocketActions.disconnect());
  }, [dispatch]);

  const subscribe = useCallback((event: string, callback: (data: any) => void) => {
    dispatch(websocketActions.subscribe(event, callback));
  }, [dispatch]);

  const unsubscribe = useCallback((subscriptionId: string) => {
    dispatch(websocketActions.unsubscribe(subscriptionId));
  }, [dispatch]);

  const sendMessage = useCallback((message: any) => {
    dispatch(websocketActions.messageSent(message));
  }, [dispatch]);

  const clearError = useCallback(() => {
    dispatch(websocketActions.clearError());
  }, [dispatch]);

  const reset = useCallback(() => {
    dispatch(websocketActions.resetState());
  }, [dispatch]);

  return {
    // State
    isConnected,
    isConnecting,
    error,
    subscriptions,
    lastMessage,
    lastSentMessage,
    
    // Actions
    connect,
    disconnect,
    subscribe,
    unsubscribe,
    sendMessage,
    clearError,
    reset,
  };
};

// WebSocket Event Types
export const WEBSOCKET_EVENTS = {
  // Production Events
  PRODUCTION_LINE_UPDATED: 'production_line_updated',
  PRODUCTION_SCHEDULE_UPDATED: 'production_schedule_updated',
  JOB_ASSIGNMENT_UPDATED: 'job_assignment_updated',
  PRODUCTION_METRICS_UPDATED: 'production_metrics_updated',
  
  // OEE Events
  OEE_DATA_UPDATED: 'oee_data_updated',
  OEE_CALCULATION_COMPLETED: 'oee_calculation_completed',
  OEE_TREND_UPDATED: 'oee_trend_updated',
  
  // Equipment Events
  EQUIPMENT_STATUS_UPDATED: 'equipment_status_updated',
  EQUIPMENT_FAULT_OCCURRED: 'equipment_fault_occurred',
  EQUIPMENT_FAULT_RESOLVED: 'equipment_fault_resolved',
  MAINTENANCE_SCHEDULE_UPDATED: 'maintenance_schedule_updated',
  
  // Andon Events
  ANDON_EVENT_CREATED: 'andon_event_created',
  ANDON_EVENT_UPDATED: 'andon_event_updated',
  ANDON_EVENT_RESOLVED: 'andon_event_resolved',
  ANDON_ESCALATION_TRIGGERED: 'andon_escalation_triggered',
  
  // Quality Events
  QUALITY_CHECK_COMPLETED: 'quality_check_completed',
  QUALITY_INSPECTION_COMPLETED: 'quality_inspection_completed',
  QUALITY_DEFECT_REPORTED: 'quality_defect_reported',
  QUALITY_ALERT_TRIGGERED: 'quality_alert_triggered',
  
  // Dashboard Events
  DASHBOARD_DATA_UPDATED: 'dashboard_data_updated',
  REAL_TIME_METRICS_UPDATED: 'real_time_metrics_updated',
  
  // System Events
  SYSTEM_HEALTH_UPDATED: 'system_health_updated',
  USER_SESSION_UPDATED: 'user_session_updated',
  NOTIFICATION_RECEIVED: 'notification_received',
  
  // Generic Events
  DATA_UPDATED: 'data_updated',
  ERROR_OCCURRED: 'error_occurred',
  HEARTBEAT: 'heartbeat',
} as const;

// WebSocket Message Types
export interface WebSocketMessage {
  type: string;
  data: any;
  timestamp: string;
  id?: string;
  source?: string;
  target?: string;
}

// WebSocket Event Handlers
export const createWebSocketEventHandlers = (dispatch: AppDispatch) => {
  const handlers: Record<string, (data: any) => void> = {};

  // Generic event handler that dispatches a message received action
  // Specific slice actions will be handled by the individual slices
  Object.keys(WEBSOCKET_EVENTS).forEach(eventKey => {
    const event = WEBSOCKET_EVENTS[eventKey as keyof typeof WEBSOCKET_EVENTS];
    handlers[event] = (data) => {
      dispatch(websocketActions.messageReceived({
        type: event,
        data,
        timestamp: new Date().toISOString(),
      }));
    };
  });

  return handlers;
};

// WebSocket Service Integration
export const initializeWebSocketIntegration = (store: any) => {
  const dispatch = store.dispatch;
  
  // Create event handlers
  const eventHandlers = createWebSocketEventHandlers(dispatch);
  
  // Subscribe to all events
  Object.keys(eventHandlers).forEach(event => {
    websocketService.subscribe(event, eventHandlers[event]);
  });
  
  // Setup connection status monitoring
  websocketService.addNetworkListener((isOnline: boolean) => {
    dispatch(websocketActions.connectionStatusChanged(isOnline));
  });
  
  console.log('WebSocket integration initialized');
};

// Export default
export default websocketMiddleware;
