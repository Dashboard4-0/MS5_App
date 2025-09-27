/**
 * MS5.0 Floor Dashboard - WebSocket Hook
 * 
 * This hook provides easy access to WebSocket functionality for real-time data
 * with automatic connection management, subscription handling, and error recovery.
 */

import { useEffect, useRef, useCallback, useState } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store';
import wsService from '../services/websocket';
import { logger } from '../utils/logger';

interface UseWebSocketOptions {
  autoConnect?: boolean;
  reconnectOnMount?: boolean;
  onConnect?: () => void;
  onDisconnect?: () => void;
  onError?: (error: string) => void;
}

interface UseWebSocketReturn {
  isConnected: boolean;
  isConnecting: boolean;
  connectionState: any;
  connect: () => Promise<void>;
  disconnect: () => void;
  subscribe: (type: string, callback: (data: any) => void, filter?: any) => string;
  unsubscribe: (id: string) => void;
  send: (message: any) => void;
  getSubscriptionCount: () => number;
  getQueuedMessageCount: () => number;
}

export const useWebSocket = (options: UseWebSocketOptions = {}): UseWebSocketReturn => {
  const {
    autoConnect = true,
    reconnectOnMount = true,
    onConnect,
    onDisconnect,
    onError
  } = options;

  const dispatch = useDispatch();
  const { isAuthenticated, user } = useSelector((state: RootState) => state.auth);
  const [isConnected, setIsConnected] = useState(false);
  const [isConnecting, setIsConnecting] = useState(false);
  const [connectionState, setConnectionState] = useState(wsService.getConnectionState());
  
  const subscriptionsRef = useRef<Map<string, string>>(new Map());
  const callbacksRef = useRef<Map<string, (data: any) => void>>(new Map());

  // Update connection state
  const updateConnectionState = useCallback(() => {
    const state = wsService.getConnectionState();
    setConnectionState(state);
    setIsConnected(state.isConnected);
    setIsConnecting(state.isConnecting);
  }, []);

  // Handle connection events
  const handleConnect = useCallback(() => {
    updateConnectionState();
    onConnect?.();
    logger.info('WebSocket connected via hook');
  }, [updateConnectionState, onConnect]);

  const handleDisconnect = useCallback(() => {
    updateConnectionState();
    onDisconnect?.();
    logger.info('WebSocket disconnected via hook');
  }, [updateConnectionState, onDisconnect]);

  const handleError = useCallback((error: any) => {
    updateConnectionState();
    onError?.(error.error || 'WebSocket connection error');
    logger.error('WebSocket error via hook', error);
  }, [updateConnectionState, onError]);

  // Connect to WebSocket
  const connect = useCallback(async () => {
    if (!isAuthenticated || !user) {
      logger.warn('Cannot connect WebSocket: user not authenticated');
      return;
    }

    try {
      setIsConnecting(true);
      await wsService.connect();
      updateConnectionState();
    } catch (error) {
      logger.error('Failed to connect WebSocket', error);
      setIsConnecting(false);
      throw error;
    }
  }, [isAuthenticated, user, updateConnectionState]);

  // Disconnect from WebSocket
  const disconnect = useCallback(() => {
    // Unsubscribe from all subscriptions
    subscriptionsRef.current.forEach((subscriptionId) => {
      wsService.unsubscribe(subscriptionId);
    });
    subscriptionsRef.current.clear();
    callbacksRef.current.clear();

    wsService.disconnect();
    updateConnectionState();
  }, [updateConnectionState]);

  // Subscribe to WebSocket events
  const subscribe = useCallback((type: string, callback: (data: any) => void, filter?: any): string => {
    const subscriptionId = wsService.subscribe(type, callback, filter);
    subscriptionsRef.current.set(type, subscriptionId);
    callbacksRef.current.set(subscriptionId, callback);
    
    logger.debug('WebSocket subscription created via hook', { type, subscriptionId });
    return subscriptionId;
  }, []);

  // Unsubscribe from WebSocket events
  const unsubscribe = useCallback((id: string) => {
    wsService.unsubscribe(id);
    subscriptionsRef.current.delete(id);
    callbacksRef.current.delete(id);
    
    logger.debug('WebSocket subscription removed via hook', { id });
  }, []);

  // Send message via WebSocket
  const send = useCallback((message: any) => {
    wsService.send(message);
  }, []);

  // Get subscription count
  const getSubscriptionCount = useCallback(() => {
    return wsService.getSubscriptionCount();
  }, []);

  // Get queued message count
  const getQueuedMessageCount = useCallback(() => {
    return wsService.getQueuedMessageCount();
  }, []);

  // Setup event listeners
  useEffect(() => {
    wsService.addEventListener('connection', handleConnect);
    wsService.addEventListener('error', handleError);

    return () => {
      wsService.removeEventListener('connection', handleConnect);
      wsService.removeEventListener('error', handleError);
    };
  }, [handleConnect, handleError]);

  // Auto-connect on mount if authenticated
  useEffect(() => {
    if (autoConnect && isAuthenticated && user && reconnectOnMount) {
      connect().catch((error) => {
        logger.error('Auto-connect failed', error);
      });
    }

    return () => {
      if (autoConnect) {
        disconnect();
      }
    };
  }, [autoConnect, isAuthenticated, user, reconnectOnMount, connect, disconnect]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      disconnect();
    };
  }, [disconnect]);

  return {
    isConnected,
    isConnecting,
    connectionState,
    connect,
    disconnect,
    subscribe,
    unsubscribe,
    send,
    getSubscriptionCount,
    getQueuedMessageCount,
  };
};

export default useWebSocket;
