/**
 * MS5.0 Floor Dashboard - Offline Support Components
 * 
 * Components that handle offline functionality, data synchronization,
 * and offline mode indicators for the application.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Modal,
  ScrollView,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import NetInfo from '@react-native-community/netinfo';

// Types
export interface OfflineIndicatorProps {
  isOffline: boolean;
  pendingSyncCount?: number;
  onPress?: () => void;
  showPendingCount?: boolean;
}

export interface SyncStatusProps {
  isSyncing: boolean;
  lastSyncTime?: Date;
  syncProgress?: number;
  onRetry?: () => void;
}

export interface OfflineDataListProps {
  data: any[];
  onSyncItem?: (item: any) => void;
  onDeleteItem?: (item: any) => void;
  renderItem: (item: any) => React.ReactNode;
  emptyMessage?: string;
}

export interface OfflineModeModalProps {
  visible: boolean;
  onClose: () => void;
  onContinueOffline: () => void;
  onRetryConnection: () => void;
  pendingDataCount?: number;
}

// Offline Indicator Component
export const OfflineIndicator: React.FC<OfflineIndicatorProps> = ({
  isOffline,
  pendingSyncCount = 0,
  onPress,
  showPendingCount = true,
}) => {
  const [pulseAnim] = useState(new Animated.Value(1));

  useEffect(() => {
    if (isOffline) {
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
  }, [isOffline, pulseAnim]);

  if (!isOffline && pendingSyncCount === 0) {
    return null;
  }

  const content = (
    <View style={styles.indicatorContainer}>
      <Animated.View
        style={[
          styles.indicatorIcon,
          {
            backgroundColor: isOffline ? '#F44336' : '#FF9800',
            transform: [{ scale: pulseAnim }],
          },
        ]}
      >
        <Icon
          name={isOffline ? 'wifi-off' : 'sync'}
          size={16}
          color="#FFFFFF"
        />
      </Animated.View>
      
      <View style={styles.indicatorContent}>
        <Text style={styles.indicatorText}>
          {isOffline ? 'Offline Mode' : 'Syncing...'}
        </Text>
        
        {showPendingCount && pendingSyncCount > 0 && (
          <Text style={styles.pendingText}>
            {pendingSyncCount} pending sync
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

// Sync Status Component
export const SyncStatus: React.FC<SyncStatusProps> = ({
  isSyncing,
  lastSyncTime,
  syncProgress,
  onRetry,
}) => {
  const formatLastSync = (date: Date) => {
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

  return (
    <View style={styles.syncContainer}>
      <View style={styles.syncHeader}>
        <Icon
          name={isSyncing ? 'sync' : 'check-circle'}
          size={20}
          color={isSyncing ? '#2196F3' : '#4CAF50'}
        />
        <Text style={styles.syncTitle}>
          {isSyncing ? 'Syncing Data...' : 'Sync Complete'}
        </Text>
      </View>
      
      {isSyncing && syncProgress !== undefined && (
        <View style={styles.progressContainer}>
          <View style={styles.progressTrack}>
            <View
              style={[
                styles.progressFill,
                { width: `${syncProgress}%` },
              ]}
            />
          </View>
          <Text style={styles.progressText}>
            {Math.round(syncProgress)}%
          </Text>
        </View>
      )}
      
      {lastSyncTime && (
        <Text style={styles.lastSyncText}>
          Last sync: {formatLastSync(lastSyncTime)}
        </Text>
      )}
      
      {!isSyncing && onRetry && (
        <TouchableOpacity onPress={onRetry} style={styles.retryButton}>
          <Icon name="refresh" size={16} color="#2196F3" />
          <Text style={styles.retryText}>Retry Sync</Text>
        </TouchableOpacity>
      )}
    </View>
  );
};

// Offline Data List Component
export const OfflineDataList: React.FC<OfflineDataListProps> = ({
  data,
  onSyncItem,
  onDeleteItem,
  renderItem,
  emptyMessage = 'No offline data available',
}) => {
  const handleSyncItem = (item: any) => {
    if (onSyncItem) {
      onSyncItem(item);
    }
  };

  const handleDeleteItem = (item: any) => {
    Alert.alert(
      'Delete Offline Data',
      'Are you sure you want to delete this item? This action cannot be undone.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: () => onDeleteItem?.(item),
        },
      ]
    );
  };

  if (data.length === 0) {
    return (
      <View style={styles.emptyContainer}>
        <Icon name="cloud-off" size={48} color="#9E9E9E" />
        <Text style={styles.emptyText}>{emptyMessage}</Text>
      </View>
    );
  }

  return (
    <ScrollView style={styles.dataList}>
      {data.map((item, index) => (
        <View key={index} style={styles.dataItem}>
          <View style={styles.dataContent}>
            {renderItem(item)}
          </View>
          
          <View style={styles.dataActions}>
            {onSyncItem && (
              <TouchableOpacity
                onPress={() => handleSyncItem(item)}
                style={styles.actionButton}
              >
                <Icon name="sync" size={20} color="#2196F3" />
              </TouchableOpacity>
            )}
            
            {onDeleteItem && (
              <TouchableOpacity
                onPress={() => handleDeleteItem(item)}
                style={styles.actionButton}
              >
                <Icon name="delete" size={20} color="#F44336" />
              </TouchableOpacity>
            )}
          </View>
        </View>
      ))}
    </ScrollView>
  );
};

// Offline Mode Modal Component
export const OfflineModeModal: React.FC<OfflineModeModalProps> = ({
  visible,
  onClose,
  onContinueOffline,
  onRetryConnection,
  pendingDataCount = 0,
}) => {
  const [isConnected, setIsConnected] = useState(true);

  useEffect(() => {
    const unsubscribe = NetInfo.addEventListener(state => {
      setIsConnected(state.isConnected ?? false);
    });

    return () => unsubscribe();
  }, []);

  return (
    <Modal
      visible={visible}
      transparent
      animationType="slide"
      onRequestClose={onClose}
    >
      <View style={styles.modalOverlay}>
        <View style={styles.modalContent}>
          <View style={styles.modalHeader}>
            <Icon
              name={isConnected ? 'wifi' : 'wifi-off'}
              size={32}
              color={isConnected ? '#4CAF50' : '#F44336'}
            />
            <Text style={styles.modalTitle}>
              {isConnected ? 'Connection Restored' : 'Offline Mode'}
            </Text>
          </View>
          
          <Text style={styles.modalMessage}>
            {isConnected
              ? 'Your connection has been restored. You can now sync your offline data.'
              : 'You are currently offline. Some features may not be available.'}
          </Text>
          
          {pendingDataCount > 0 && (
            <View style={styles.pendingDataContainer}>
              <Icon name="cloud-queue" size={20} color="#FF9800" />
              <Text style={styles.pendingDataText}>
                {pendingDataCount} items pending sync
              </Text>
            </View>
          )}
          
          <View style={styles.modalActions}>
            {isConnected ? (
              <TouchableOpacity
                onPress={onRetryConnection}
                style={[styles.modalButton, styles.primaryButton]}
              >
                <Text style={styles.primaryButtonText}>Sync Data</Text>
              </TouchableOpacity>
            ) : (
              <TouchableOpacity
                onPress={onContinueOffline}
                style={[styles.modalButton, styles.primaryButton]}
              >
                <Text style={styles.primaryButtonText}>Continue Offline</Text>
              </TouchableOpacity>
            )}
            
            <TouchableOpacity
              onPress={onClose}
              style={[styles.modalButton, styles.secondaryButton]}
            >
              <Text style={styles.secondaryButtonText}>Close</Text>
            </TouchableOpacity>
          </View>
        </View>
      </View>
    </Modal>
  );
};

// Offline Capabilities Component
export const OfflineCapabilities: React.FC<{
  capabilities: string[];
  onPress?: () => void;
}> = ({ capabilities, onPress }) => {
  return (
    <View style={styles.capabilitiesContainer}>
      <Text style={styles.capabilitiesTitle}>Available Offline:</Text>
      {capabilities.map((capability, index) => (
        <View key={index} style={styles.capabilityItem}>
          <Icon name="check-circle" size={16} color="#4CAF50" />
          <Text style={styles.capabilityText}>{capability}</Text>
        </View>
      ))}
    </View>
  );
};

const styles = StyleSheet.create({
  indicatorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFF3E0',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 4,
    marginHorizontal: 16,
    marginVertical: 8,
  },
  indicatorIcon: {
    width: 24,
    height: 24,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 8,
  },
  indicatorContent: {
    flex: 1,
  },
  indicatorText: {
    fontSize: 14,
    fontWeight: '500',
    color: '#212121',
  },
  pendingText: {
    fontSize: 12,
    color: '#757575',
    marginTop: 2,
  },
  pressable: {
    // Add pressable styles if needed
  },
  syncContainer: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 8,
    margin: 16,
  },
  syncHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  syncTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginLeft: 8,
  },
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: '#E0E0E0',
    borderRadius: 2,
    marginRight: 8,
  },
  progressFill: {
    height: 4,
    backgroundColor: '#2196F3',
    borderRadius: 2,
  },
  progressText: {
    fontSize: 12,
    color: '#757575',
  },
  lastSyncText: {
    fontSize: 12,
    color: '#757575',
    marginBottom: 8,
  },
  retryButton: {
    flexDirection: 'row',
    alignItems: 'center',
    alignSelf: 'flex-start',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 4,
    backgroundColor: '#E3F2FD',
  },
  retryText: {
    fontSize: 12,
    color: '#2196F3',
    marginLeft: 4,
  },
  dataList: {
    flex: 1,
  },
  dataItem: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    padding: 16,
    marginHorizontal: 16,
    marginVertical: 4,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
    elevation: 2,
  },
  dataContent: {
    flex: 1,
  },
  dataActions: {
    flexDirection: 'row',
  },
  actionButton: {
    padding: 8,
    marginLeft: 8,
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    fontSize: 16,
    color: '#9E9E9E',
    marginTop: 16,
    textAlign: 'center',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    borderRadius: 12,
    padding: 24,
    margin: 20,
    maxWidth: 400,
    width: '100%',
  },
  modalHeader: {
    alignItems: 'center',
    marginBottom: 16,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212121',
    marginTop: 8,
    textAlign: 'center',
  },
  modalMessage: {
    fontSize: 16,
    color: '#757575',
    textAlign: 'center',
    marginBottom: 16,
    lineHeight: 24,
  },
  pendingDataContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FFF3E0',
    padding: 12,
    borderRadius: 8,
    marginBottom: 16,
  },
  pendingDataText: {
    fontSize: 14,
    color: '#FF9800',
    marginLeft: 8,
    fontWeight: '500',
  },
  modalActions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  modalButton: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginHorizontal: 4,
  },
  primaryButton: {
    backgroundColor: '#2196F3',
  },
  primaryButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '500',
  },
  secondaryButton: {
    backgroundColor: '#F5F5F5',
  },
  secondaryButtonText: {
    color: '#757575',
    fontSize: 16,
    fontWeight: '500',
  },
  capabilitiesContainer: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 8,
    margin: 16,
  },
  capabilitiesTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 12,
  },
  capabilityItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  capabilityText: {
    fontSize: 14,
    color: '#757575',
    marginLeft: 8,
  },
});

export default {
  OfflineIndicator,
  SyncStatus,
  OfflineDataList,
  OfflineModeModal,
  OfflineCapabilities,
};
