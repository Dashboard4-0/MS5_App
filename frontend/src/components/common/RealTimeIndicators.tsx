/**
 * MS5.0 Floor Dashboard - Real-time Status Indicator
 * 
 * A component that displays real-time status information with
 * automatic updates and visual indicators for different states.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Animated,
  TouchableOpacity,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';

// Types
export interface StatusIndicatorProps {
  status: 'online' | 'offline' | 'warning' | 'error' | 'maintenance';
  label?: string;
  lastUpdated?: Date;
  showTimestamp?: boolean;
  animated?: boolean;
  size?: 'small' | 'medium' | 'large';
  onPress?: () => void;
}

export interface RealTimeBadgeProps {
  count: number;
  type: 'andon' | 'alerts' | 'notifications';
  maxCount?: number;
  animated?: boolean;
  onPress?: () => void;
}

export interface ConnectionStatusProps {
  isOnline: boolean;
  lastSync?: Date;
  showSyncStatus?: boolean;
  onRetry?: () => void;
}

// Status Indicator Component
export const StatusIndicator: React.FC<StatusIndicatorProps> = ({
  status,
  label,
  lastUpdated,
  showTimestamp = true,
  animated = true,
  size = 'medium',
  onPress,
}) => {
  const [pulseAnim] = useState(new Animated.Value(1));

  useEffect(() => {
    if (animated && status === 'online') {
      const pulse = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: 1000,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: 1000,
            useNativeDriver: true,
          }),
        ])
      );
      pulse.start();
      return () => pulse.stop();
    }
  }, [animated, status, pulseAnim]);

  const getStatusColor = () => {
    switch (status) {
      case 'online':
        return '#4CAF50';
      case 'offline':
        return '#9E9E9E';
      case 'warning':
        return '#FF9800';
      case 'error':
        return '#F44336';
      case 'maintenance':
        return '#2196F3';
      default:
        return '#9E9E9E';
    }
  };

  const getStatusIcon = () => {
    switch (status) {
      case 'online':
        return 'check-circle';
      case 'offline':
        return 'offline-bolt';
      case 'warning':
        return 'warning';
      case 'error':
        return 'error';
      case 'maintenance':
        return 'build';
      default:
        return 'help';
    }
  };

  const getSizeStyles = () => {
    switch (size) {
      case 'small':
        return { iconSize: 16, fontSize: 12 };
      case 'large':
        return { iconSize: 24, fontSize: 16 };
      default:
        return { iconSize: 20, fontSize: 14 };
    }
  };

  const { iconSize, fontSize } = getSizeStyles();

  const formatTimestamp = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const minutes = Math.floor(diff / 60000);
    
    if (minutes < 1) return 'Just now';
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    return `${days}d ago`;
  };

  const content = (
    <View style={styles.statusContainer}>
      <Animated.View
        style={[
          styles.statusIconContainer,
          { transform: [{ scale: pulseAnim }] },
        ]}
      >
        <Icon
          name={getStatusIcon()}
          size={iconSize}
          color={getStatusColor()}
        />
      </Animated.View>
      
      <View style={styles.statusContent}>
        {label && (
          <Text style={[styles.statusLabel, { fontSize }]}>
            {label}
          </Text>
        )}
        
        {showTimestamp && lastUpdated && (
          <Text style={[styles.statusTimestamp, { fontSize: fontSize - 2 }]}>
            {formatTimestamp(lastUpdated)}
          </Text>
        )}
      </View>
    </View>
  );

  if (onPress) {
    return (
      <TouchableOpacity onPress={onPress} style={styles.pressable}>
        {content}
      </TouchableOpacity>
    );
  }

  return content;
};

// Real-time Badge Component
export const RealTimeBadge: React.FC<RealTimeBadgeProps> = ({
  count,
  type,
  maxCount = 99,
  animated = true,
  onPress,
}) => {
  const [scaleAnim] = useState(new Animated.Value(1));

  useEffect(() => {
    if (animated && count > 0) {
      const scale = Animated.sequence([
        Animated.timing(scaleAnim, {
          toValue: 1.3,
          duration: 200,
          useNativeDriver: true,
        }),
        Animated.timing(scaleAnim, {
          toValue: 1,
          duration: 200,
          useNativeDriver: true,
        }),
      ]);
      scale.start();
    }
  }, [count, animated, scaleAnim]);

  const getBadgeColor = () => {
    switch (type) {
      case 'andon':
        return '#F44336';
      case 'alerts':
        return '#FF9800';
      case 'notifications':
        return '#2196F3';
      default:
        return '#757575';
    }
  };

  const displayCount = count > maxCount ? `${maxCount}+` : count.toString();

  const badge = (
    <Animated.View
      style={[
        styles.badge,
        {
          backgroundColor: getBadgeColor(),
          transform: [{ scale: scaleAnim }],
        },
      ]}
    >
      <Text style={styles.badgeText}>{displayCount}</Text>
    </Animated.View>
  );

  if (onPress) {
    return (
      <TouchableOpacity onPress={onPress} style={styles.badgeContainer}>
        {badge}
      </TouchableOpacity>
    );
  }

  return badge;
};

// Connection Status Component
export const ConnectionStatus: React.FC<ConnectionStatusProps> = ({
  isOnline,
  lastSync,
  showSyncStatus = true,
  onRetry,
}) => {
  const [syncAnim] = useState(new Animated.Value(0));

  useEffect(() => {
    if (isOnline && showSyncStatus) {
      const sync = Animated.loop(
        Animated.sequence([
          Animated.timing(syncAnim, {
            toValue: 1,
            duration: 2000,
            useNativeDriver: true,
          }),
          Animated.timing(syncAnim, {
            toValue: 0,
            duration: 2000,
            useNativeDriver: true,
          }),
        ])
      );
      sync.start();
      return () => sync.stop();
    }
  }, [isOnline, showSyncStatus, syncAnim]);

  const formatLastSync = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const seconds = Math.floor(diff / 1000);
    
    if (seconds < 60) return `${seconds}s ago`;
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    return `${hours}h ago`;
  };

  return (
    <View style={styles.connectionContainer}>
      <StatusIndicator
        status={isOnline ? 'online' : 'offline'}
        label={isOnline ? 'Connected' : 'Offline'}
        lastUpdated={lastSync}
        size="small"
        animated={isOnline}
      />
      
      {showSyncStatus && isOnline && lastSync && (
        <View style={styles.syncContainer}>
          <Animated.View
            style={[
              styles.syncIcon,
              {
                opacity: syncAnim,
              },
            ]}
          >
            <Icon name="sync" size={12} color="#4CAF50" />
          </Animated.View>
          <Text style={styles.syncText}>
            Last sync: {formatLastSync(lastSync)}
          </Text>
        </View>
      )}
      
      {!isOnline && onRetry && (
        <TouchableOpacity onPress={onRetry} style={styles.retryButton}>
          <Icon name="refresh" size={16} color="#2196F3" />
          <Text style={styles.retryText}>Retry</Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

// Live Data Indicator Component
export const LiveDataIndicator: React.FC<{
  isLive: boolean;
  updateInterval?: number;
  onPress?: () => void;
}> = ({ isLive, updateInterval = 5000, onPress }) => {
  const [pulseAnim] = useState(new Animated.Value(1));

  useEffect(() => {
    if (isLive) {
      const pulse = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.2,
            duration: updateInterval / 2,
            useNativeDriver: true,
          }),
          Animated.timing(pulseAnim, {
            toValue: 1,
            duration: updateInterval / 2,
            useNativeDriver: true,
          }),
        ])
      );
      pulse.start();
      return () => pulse.stop();
    }
  }, [isLive, updateInterval, pulseAnim]);

  const content = (
    <View style={styles.liveContainer}>
      <Animated.View
        style={[
          styles.liveIndicator,
          {
            backgroundColor: isLive ? '#4CAF50' : '#9E9E9E',
            transform: [{ scale: pulseAnim }],
          },
        ]}
      />
      <Text style={styles.liveText}>
        {isLive ? 'LIVE' : 'PAUSED'}
      </Text>
    </View>
  );

  if (onPress) {
    return (
      <TouchableOpacity onPress={onPress} style={styles.livePressable}>
        {content}
      </TouchableOpacity>
    );
  }

  return content;
};

const styles = StyleSheet.create({
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  statusIconContainer: {
    marginRight: 8,
  },
  statusContent: {
    flex: 1,
  },
  statusLabel: {
    color: '#212121',
    fontWeight: '500',
  },
  statusTimestamp: {
    color: '#757575',
    marginTop: 2,
  },
  pressable: {
    // Add pressable styles if needed
  },
  badge: {
    minWidth: 20,
    height: 20,
    borderRadius: 10,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 6,
  },
  badgeText: {
    color: '#FFFFFF',
    fontSize: 12,
    fontWeight: 'bold',
  },
  badgeContainer: {
    // Add container styles if needed
  },
  connectionContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  syncContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginLeft: 8,
  },
  syncIcon: {
    marginRight: 4,
  },
  syncText: {
    fontSize: 12,
    color: '#757575',
  },
  retryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 4,
    backgroundColor: '#E3F2FD',
  },
  retryText: {
    fontSize: 12,
    color: '#2196F3',
    marginLeft: 4,
  },
  liveContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  liveIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: 6,
  },
  liveText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#212121',
  },
  livePressable: {
    // Add pressable styles if needed
  },
});

export default {
  StatusIndicator,
  RealTimeBadge,
  ConnectionStatus,
  LiveDataIndicator,
};
