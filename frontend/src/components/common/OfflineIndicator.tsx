/**
 * MS5.0 Floor Dashboard - Offline Indicator Component
 * 
 * This component provides visual feedback for offline status with:
 * - Real-time connection status
 * - Sync progress indication
 * - Factory environment optimization
 * - Tablet-specific UI design
 * - Accessibility support
 */

import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet, Animated, TouchableOpacity, Dimensions } from 'react-native';
import { useOfflineSync } from '../../hooks/useOfflineSync';
import { useWebSocket } from '../../hooks/useWebSocket';
import { logger } from '../../utils/logger';

// Component props interface
interface OfflineIndicatorProps {
  onPress?: () => void;
  showDetails?: boolean;
  position?: 'top' | 'bottom';
  style?: any;
}

/**
 * Offline Indicator Component
 * 
 * Displays connection status and sync information
 */
export const OfflineIndicator: React.FC<OfflineIndicatorProps> = ({
  onPress,
  showDetails = false,
  position = 'top',
  style
}) => {
  // State management
  const [isVisible, setIsVisible] = useState(false);
  const [animation] = useState(new Animated.Value(0));
  const [pulseAnimation] = useState(new Animated.Value(1));

  // Hooks
  const offlineSync = useOfflineSync({
    storageKey: 'ms5_offline_data',
    syncInterval: 30000,
    maxRetries: 3,
    retryDelay: 1000,
    conflictResolution: 'server'
  });

  const webSocket = useWebSocket({
    url: process.env.WS_BASE_URL || 'wss://api.ms5dashboard.com/ws',
    factoryNetwork: true,
    tabletOptimized: true,
    autoConnect: true,
    reconnectOnFocus: true
  });

  // Animation effects
  useEffect(() => {
    if (isVisible) {
      Animated.timing(animation, {
        toValue: 1,
        duration: 300,
        useNativeDriver: true
      }).start();
    } else {
      Animated.timing(animation, {
        toValue: 0,
        duration: 300,
        useNativeDriver: true
      }).start();
    }
  }, [isVisible, animation]);

  // Pulse animation for syncing
  useEffect(() => {
    if (offlineSync.isSyncing) {
      const pulse = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnimation, {
            toValue: 1.2,
            duration: 1000,
            useNativeDriver: true
          }),
          Animated.timing(pulseAnimation, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true
          })
        ])
      );
      pulse.start();

      return () => pulse.stop();
    } else {
      Animated.timing(pulseAnimation, {
        toValue: 1,
        duration: 200,
        useNativeDriver: true
      }).start();
    }
  }, [offlineSync.isSyncing, pulseAnimation]);

  // Show/hide indicator based on status
  useEffect(() => {
    const shouldShow = !webSocket.isConnected || 
                      !offlineSync.isOnline || 
                      offlineSync.status.pendingItems > 0 ||
                      offlineSync.status.failedItems > 0 ||
                      offlineSync.isSyncing;

    setIsVisible(shouldShow);
  }, [
    webSocket.isConnected,
    offlineSync.isOnline,
    offlineSync.status.pendingItems,
    offlineSync.status.failedItems,
    offlineSync.isSyncing
  ]);

  // Get status information
  const getStatusInfo = () => {
    if (!webSocket.isConnected) {
      return {
        status: 'disconnected',
        message: 'WebSocket Disconnected',
        color: '#f44336',
        icon: '📡'
      };
    }

    if (!offlineSync.isOnline) {
      return {
        status: 'offline',
        message: 'Working Offline',
        color: '#ff9800',
        icon: '📴'
      };
    }

    if (offlineSync.isSyncing) {
      return {
        status: 'syncing',
        message: 'Syncing Data...',
        color: '#2196f3',
        icon: '🔄'
      };
    }

    if (offlineSync.status.failedItems > 0) {
      return {
        status: 'error',
        message: `${offlineSync.status.failedItems} Failed Items`,
        color: '#f44336',
        icon: '⚠️'
      };
    }

    if (offlineSync.status.pendingItems > 0) {
      return {
        status: 'pending',
        message: `${offlineSync.status.pendingItems} Pending`,
        color: '#ff9800',
        icon: '⏳'
      };
    }

    return {
      status: 'connected',
      message: 'Connected',
      color: '#4caf50',
      icon: '✅'
    };
  };

  const statusInfo = getStatusInfo();

  // Handle press
  const handlePress = () => {
    if (onPress) {
      onPress();
    } else {
      // Default action: retry sync
      if (offlineSync.status.failedItems > 0) {
        offlineSync.retryFailed();
      } else if (offlineSync.status.pendingItems > 0) {
        offlineSync.syncNow();
      }
    }
  };

  // Get detailed information
  const getDetailedInfo = () => {
    const info = [];
    
    if (offlineSync.status.pendingItems > 0) {
      info.push(`${offlineSync.status.pendingItems} items pending sync`);
    }
    
    if (offlineSync.status.failedItems > 0) {
      info.push(`${offlineSync.status.failedItems} items failed to sync`);
    }
    
    if (offlineSync.status.conflicts > 0) {
      info.push(`${offlineSync.status.conflicts} conflicts to resolve`);
    }
    
    if (offlineSync.lastSync > 0) {
      const lastSyncTime = new Date(offlineSync.lastSync).toLocaleTimeString();
      info.push(`Last sync: ${lastSyncTime}`);
    }
    
    return info;
  };

  if (!isVisible) {
    return null;
  }

  return (
    <Animated.View
      style={[
        styles.container,
        position === 'top' ? styles.topContainer : styles.bottomContainer,
        {
          opacity: animation,
          transform: [
            {
              translateY: animation.interpolate({
                inputRange: [0, 1],
                outputRange: position === 'top' ? [-50, 0] : [50, 0]
              })
            }
          ]
        },
        style
      ]}
    >
      <TouchableOpacity
        style={[
          styles.indicator,
          { backgroundColor: statusInfo.color }
        ]}
        onPress={handlePress}
        activeOpacity={0.8}
        accessible={true}
        accessibilityLabel={`Connection status: ${statusInfo.message}`}
        accessibilityHint="Tap to retry sync or view details"
      >
        <Animated.View
          style={[
            styles.iconContainer,
            {
              transform: [{ scale: pulseAnimation }]
            }
          ]}
        >
          <Text style={styles.icon}>{statusInfo.icon}</Text>
        </Animated.View>
        
        <View style={styles.textContainer}>
          <Text style={styles.message} numberOfLines={1}>
            {statusInfo.message}
          </Text>
          
          {showDetails && (
            <View style={styles.detailsContainer}>
              {getDetailedInfo().map((detail, index) => (
                <Text key={index} style={styles.detail} numberOfLines={1}>
                  {detail}
                </Text>
              ))}
            </View>
          )}
        </View>
        
        {offlineSync.isSyncing && (
          <View style={styles.syncIndicator}>
            <View style={styles.syncDot} />
          </View>
        )}
      </TouchableOpacity>
    </Animated.View>
  );
};

// Styles
const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    left: 0,
    right: 0,
    zIndex: 1000,
    paddingHorizontal: 16,
    paddingVertical: 8
  },
  topContainer: {
    top: 0
  },
  bottomContainer: {
    bottom: 0
  },
  indicator: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
    minHeight: 44 // Minimum touch target for tablets
  },
  iconContainer: {
    marginRight: 8,
    width: 24,
    height: 24,
    justifyContent: 'center',
    alignItems: 'center'
  },
  icon: {
    fontSize: 16,
    color: '#ffffff'
  },
  textContainer: {
    flex: 1,
    justifyContent: 'center'
  },
  message: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '500',
    lineHeight: 20
  },
  detailsContainer: {
    marginTop: 2
  },
  detail: {
    color: '#ffffff',
    fontSize: 12,
    opacity: 0.9,
    lineHeight: 16
  },
  syncIndicator: {
    marginLeft: 8,
    width: 16,
    height: 16,
    justifyContent: 'center',
    alignItems: 'center'
  },
  syncDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#ffffff',
    opacity: 0.8
  }
});

export default OfflineIndicator;
