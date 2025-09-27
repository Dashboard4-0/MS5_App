/**
 * MS5.0 Floor Dashboard - Push Notifications Hook
 * 
 * This hook provides push notification handling for Andon events,
 * system alerts, and other critical notifications.
 */

import { useEffect, useState, useCallback, useRef } from 'react';
import { useSelector, useDispatch } from 'react-redux';
import { RootState } from '../store';
import { addAndonEvent, updateAndonEvent } from '../store/slices/andonSlice';
import { updateEquipmentStatus } from '../store/slices/dashboardSlice';
import { logger } from '../utils/logger';
import { Platform, Alert, Vibration } from 'react-native';

interface UsePushNotificationsOptions {
  enableVibration?: boolean;
  enableSound?: boolean;
  enableVisual?: boolean;
  onNotificationReceived?: (notification: any) => void;
  onNotificationOpened?: (notification: any) => void;
  onPermissionGranted?: () => void;
  onPermissionDenied?: () => void;
}

interface UsePushNotificationsReturn {
  isSupported: boolean;
  isEnabled: boolean;
  hasPermission: boolean;
  requestPermission: () => Promise<boolean>;
  enable: () => void;
  disable: () => void;
  sendLocalNotification: (title: string, body: string, data?: any) => void;
  clearAllNotifications: () => void;
  getNotificationSettings: () => any;
}

export const usePushNotifications = (options: UsePushNotificationsOptions = {}): UsePushNotificationsReturn => {
  const {
    enableVibration = true,
    enableSound = true,
    enableVisual = true,
    onNotificationReceived,
    onNotificationOpened,
    onPermissionGranted,
    onPermissionDenied
  } = options;

  const dispatch = useDispatch();
  const { user } = useSelector((state: RootState) => state.auth);
  const [isSupported, setIsSupported] = useState(false);
  const [isEnabled, setIsEnabled] = useState(false);
  const [hasPermission, setHasPermission] = useState(false);
  
  const notificationHandlersRef = useRef<Map<string, (data: any) => void>>(new Map());
  const notificationQueueRef = useRef<any[]>([]);

  // Check if push notifications are supported
  useEffect(() => {
    const checkSupport = () => {
      // For React Native, we'll use a simple check
      // In a real implementation, you'd check for specific notification libraries
      const supported = Platform.OS === 'ios' || Platform.OS === 'android';
      setIsSupported(supported);
      logger.info('Push notification support checked', { supported, platform: Platform.OS });
    };

    checkSupport();
  }, []);

  // Request notification permission
  const requestPermission = useCallback(async (): Promise<boolean> => {
    if (!isSupported) {
      logger.warn('Push notifications not supported on this platform');
      return false;
    }

    try {
      // In a real implementation, you'd use a notification library like @react-native-firebase/messaging
      // For now, we'll simulate the permission request
      const granted = await new Promise<boolean>((resolve) => {
        Alert.alert(
          'Push Notifications',
          'Allow MS5.0 Floor Dashboard to send you push notifications for important alerts and updates?',
          [
            {
              text: 'Deny',
              onPress: () => resolve(false),
              style: 'cancel'
            },
            {
              text: 'Allow',
              onPress: () => resolve(true)
            }
          ]
        );
      });

      setHasPermission(granted);
      
      if (granted) {
        onPermissionGranted?.();
        logger.info('Push notification permission granted');
      } else {
        onPermissionDenied?.();
        logger.info('Push notification permission denied');
      }

      return granted;
    } catch (error) {
      logger.error('Failed to request push notification permission', error);
      return false;
    }
  }, [isSupported, onPermissionGranted, onPermissionDenied]);

  // Enable push notifications
  const enable = useCallback(() => {
    if (!hasPermission) {
      logger.warn('Cannot enable push notifications: no permission');
      return;
    }

    setIsEnabled(true);
    logger.info('Push notifications enabled');
  }, [hasPermission]);

  // Disable push notifications
  const disable = useCallback(() => {
    setIsEnabled(false);
    logger.info('Push notifications disabled');
  }, []);

  // Send local notification
  const sendLocalNotification = useCallback((title: string, body: string, data?: any) => {
    if (!isEnabled || !hasPermission) {
      logger.warn('Cannot send notification: not enabled or no permission');
      return;
    }

    try {
      // In a real implementation, you'd use a notification library
      // For now, we'll use React Native's Alert
      Alert.alert(title, body, [
        {
          text: 'OK',
          onPress: () => {
            if (data) {
              onNotificationOpened?.(data);
            }
          }
        }
      ]);

      // Vibrate if enabled
      if (enableVibration) {
        Vibration.vibrate([0, 250, 250, 250]);
      }

      logger.info('Local notification sent', { title, body, data });
    } catch (error) {
      logger.error('Failed to send local notification', error);
    }
  }, [isEnabled, hasPermission, enableVibration, onNotificationOpened]);

  // Clear all notifications
  const clearAllNotifications = useCallback(() => {
    try {
      // In a real implementation, you'd clear notifications from the notification center
      logger.info('All notifications cleared');
    } catch (error) {
      logger.error('Failed to clear notifications', error);
    }
  }, []);

  // Get notification settings
  const getNotificationSettings = useCallback(() => {
    return {
      isSupported,
      isEnabled,
      hasPermission,
      enableVibration,
      enableSound,
      enableVisual,
      platform: Platform.OS
    };
  }, [isSupported, isEnabled, hasPermission, enableVibration, enableSound, enableVisual]);

  // Handle Andon event notifications
  const handleAndonNotification = useCallback((data: any) => {
    if (!isEnabled) return;

    const { event_type, priority, equipment_code, description } = data;
    
    let title = 'Andon Alert';
    let body = description || 'Andon event detected';
    
    if (priority === 'critical') {
      title = '🚨 CRITICAL Andon Alert';
      body = `Equipment: ${equipment_code}\n${body}`;
    } else if (priority === 'high') {
      title = '⚠️ High Priority Andon';
      body = `Equipment: ${equipment_code}\n${body}`;
    }

    sendLocalNotification(title, body, data);
    onNotificationReceived?.(data);
  }, [isEnabled, sendLocalNotification, onNotificationReceived]);

  // Handle equipment status notifications
  const handleEquipmentNotification = useCallback((data: any) => {
    if (!isEnabled) return;

    const { equipment_code, status, fault_message } = data;
    
    if (status === 'fault' && fault_message) {
      const title = '🔧 Equipment Fault';
      const body = `Equipment: ${equipment_code}\nFault: ${fault_message}`;
      
      sendLocalNotification(title, body, data);
      onNotificationReceived?.(data);
    }
  }, [isEnabled, sendLocalNotification, onNotificationReceived]);

  // Handle system alert notifications
  const handleSystemAlert = useCallback((data: any) => {
    if (!isEnabled) return;

    const { alert_type, message, severity } = data;
    
    let title = 'System Alert';
    if (severity === 'critical') {
      title = '🚨 CRITICAL System Alert';
    } else if (severity === 'warning') {
      title = '⚠️ System Warning';
    }

    sendLocalNotification(title, message, data);
    onNotificationReceived?.(data);
  }, [isEnabled, sendLocalNotification, onNotificationReceived]);

  // Register notification handlers
  useEffect(() => {
    notificationHandlersRef.current.set('andon_event', handleAndonNotification);
    notificationHandlersRef.current.set('equipment_status', handleEquipmentNotification);
    notificationHandlersRef.current.set('system_alert', handleSystemAlert);

    return () => {
      notificationHandlersRef.current.clear();
    };
  }, [handleAndonNotification, handleEquipmentNotification, handleSystemAlert]);

  // Process queued notifications
  useEffect(() => {
    if (isEnabled && notificationQueueRef.current.length > 0) {
      const queuedNotifications = [...notificationQueueRef.current];
      notificationQueueRef.current = [];
      
      queuedNotifications.forEach(notification => {
        const handler = notificationHandlersRef.current.get(notification.type);
        if (handler) {
          handler(notification.data);
        }
      });
    }
  }, [isEnabled]);

  // Auto-request permission on mount
  useEffect(() => {
    if (isSupported && !hasPermission) {
      requestPermission();
    }
  }, [isSupported, hasPermission, requestPermission]);

  return {
    isSupported,
    isEnabled,
    hasPermission,
    requestPermission,
    enable,
    disable,
    sendLocalNotification,
    clearAllNotifications,
    getNotificationSettings
  };
};

export default usePushNotifications;
