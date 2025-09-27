/**
 * MS5.0 Floor Dashboard - Equipment Status Component
 * 
 * A component for displaying equipment status with real-time updates
 * and fault information for production line monitoring.
 */

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ViewStyle,
  ScrollView,
  TouchableOpacity,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import StatusIndicator from '../common/StatusIndicator';
import { useLineData } from '../../hooks';
import { logger } from '../../utils/logger';

// Types
interface Equipment {
  id: string;
  code: string;
  name: string;
  status: 'running' | 'stopped' | 'fault' | 'maintenance' | 'offline';
  speed: number; // RPM or similar
  targetSpeed: number;
  temperature?: number;
  pressure?: number;
  vibration?: number;
  faults: EquipmentFault[];
  lastUpdate: string;
}

interface EquipmentFault {
  id: string;
  code: string;
  description: string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  timestamp: string;
  acknowledged: boolean;
}

interface EquipmentStatusProps {
  equipment: Equipment[];
  onEquipmentPress?: (equipment: Equipment) => void;
  showDetails?: boolean;
  compact?: boolean;
  lineId?: string; // For real-time data
  enableRealTime?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const EquipmentStatus: React.FC<EquipmentStatusProps> = ({
  equipment,
  onEquipmentPress,
  showDetails = true,
  compact = false,
  lineId,
  enableRealTime = false,
  style,
  testID,
}) => {
  // Real-time data state
  const [realTimeEquipment, setRealTimeEquipment] = useState<Equipment[]>(equipment);

  // Use real-time data hook if enabled and lineId provided
  const { lineData, isConnected, lastUpdate } = useLineData({
    lineId: lineId || '',
    enableOEE: false,
    enableDowntime: false,
    enableAndon: false,
    autoSubscribe: enableRealTime && !!lineId,
  });

  // Update real-time equipment data when new data arrives
  useEffect(() => {
    if (enableRealTime && lineData.lineStatus) {
      // Update equipment status from real-time line data
      setRealTimeEquipment(prevEquipment => 
        prevEquipment.map(eq => {
          // Find matching equipment in real-time data
          const realTimeEq = lineData.lineStatus?.equipment?.find((rtEq: any) => rtEq.code === eq.code);
          if (realTimeEq) {
            return {
              ...eq,
              status: realTimeEq.status,
              speed: realTimeEq.speed || eq.speed,
              targetSpeed: realTimeEq.targetSpeed || eq.targetSpeed,
              temperature: realTimeEq.temperature,
              pressure: realTimeEq.pressure,
              vibration: realTimeEq.vibration,
              faults: realTimeEq.faults || eq.faults,
              lastUpdate: new Date().toISOString(),
            };
          }
          return eq;
        })
      );
      logger.debug('Equipment Status updated with real-time data', lineData.lineStatus);
    }
  }, [enableRealTime, lineData.lineStatus, lastUpdate]);

  // Use real-time data if enabled, otherwise use props
  const displayEquipment = enableRealTime ? realTimeEquipment : equipment;
  const getStatusColor = (status: string) => {
    switch (status) {
      case 'running':
        return COLORS.SUCCESS;
      case 'stopped':
        return COLORS.WARNING;
      case 'fault':
        return COLORS.ERROR;
      case 'maintenance':
        return COLORS.INFO;
      case 'offline':
        return COLORS.TEXT.DISABLED;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical':
        return COLORS.ERROR;
      case 'high':
        return COLORS.WARNING;
      case 'medium':
        return COLORS.INFO;
      case 'low':
        return COLORS.SUCCESS;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const formatValue = (value: number, unit: string = '') => {
    if (value >= 1000) {
      return `${(value / 1000).toFixed(1)}k${unit}`;
    }
    return `${Math.round(value)}${unit}`;
  };

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    return date.toLocaleTimeString('en-US', { 
      hour: '2-digit', 
      minute: '2-digit',
      second: '2-digit'
    });
  };

  const renderEquipmentCard = (equipment: Equipment) => {
    const statusColor = getStatusColor(equipment.status);
    const hasActiveFaults = equipment.faults.some(fault => !fault.acknowledged);
    const criticalFaults = equipment.faults.filter(fault => fault.severity === 'critical' && !fault.acknowledged);

    return (
      <TouchableOpacity
        key={equipment.id}
        style={[
          styles.equipmentCard,
          compact && styles.compactCard,
          hasActiveFaults && styles.faultCard,
          criticalFaults.length > 0 && styles.criticalCard,
        ]}
        onPress={() => onEquipmentPress?.(equipment)}
        disabled={!onEquipmentPress}
        activeOpacity={0.7}
        testID={`${testID}-equipment-${equipment.code}`}
      >
        {/* Header */}
        <View style={styles.cardHeader}>
          <View style={styles.equipmentInfo}>
            <Text style={styles.equipmentCode} numberOfLines={1}>
              {equipment.code}
            </Text>
            <Text style={styles.equipmentName} numberOfLines={1}>
              {equipment.name}
            </Text>
          </View>
          
          <StatusIndicator
            status={equipment.status === 'running' ? 'success' : 
                   equipment.status === 'stopped' ? 'warning' :
                   equipment.status === 'fault' ? 'error' :
                   equipment.status === 'maintenance' ? 'info' : 'offline'}
            size="small"
            variant="dot"
          />
        </View>

        {/* Status and Speed */}
        <View style={styles.statusRow}>
          <Text style={styles.statusText}>
            {equipment.status.charAt(0).toUpperCase() + equipment.status.slice(1)}
          </Text>
          <Text style={styles.speedText}>
            {formatValue(equipment.speed)} / {formatValue(equipment.targetSpeed)} RPM
          </Text>
        </View>

        {/* Progress bar for speed */}
        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View
              style={[
                styles.progressFill,
                {
                  width: `${Math.min((equipment.speed / equipment.targetSpeed) * 100, 100)}%`,
                  backgroundColor: statusColor,
                },
              ]}
            />
          </View>
          <Text style={styles.progressText}>
            {Math.round((equipment.speed / equipment.targetSpeed) * 100)}%
          </Text>
        </View>

        {/* Details */}
        {showDetails && !compact && (
          <View style={styles.detailsContainer}>
            {/* Sensor readings */}
            <View style={styles.sensorReadings}>
              {equipment.temperature && (
                <View style={styles.sensorItem}>
                  <Text style={styles.sensorLabel}>Temp</Text>
                  <Text style={styles.sensorValue}>{equipment.temperature}°C</Text>
                </View>
              )}
              {equipment.pressure && (
                <View style={styles.sensorItem}>
                  <Text style={styles.sensorLabel}>Press</Text>
                  <Text style={styles.sensorValue}>{equipment.pressure} bar</Text>
                </View>
              )}
              {equipment.vibration && (
                <View style={styles.sensorItem}>
                  <Text style={styles.sensorLabel}>Vib</Text>
                  <Text style={styles.sensorValue}>{equipment.vibration} mm/s</Text>
                </View>
              )}
            </View>

            {/* Faults */}
            {equipment.faults.length > 0 && (
              <View style={styles.faultsContainer}>
                <Text style={styles.faultsTitle}>
                  Active Faults ({equipment.faults.filter(f => !f.acknowledged).length})
                </Text>
                {equipment.faults.slice(0, 2).map((fault) => (
                  <View key={fault.id} style={styles.faultItem}>
                    <View style={[styles.faultDot, { backgroundColor: getSeverityColor(fault.severity) }]} />
                    <Text style={styles.faultText} numberOfLines={1}>
                      {fault.description}
                    </Text>
                    <Text style={styles.faultTime}>
                      {formatTime(fault.timestamp)}
                    </Text>
                  </View>
                ))}
                {equipment.faults.length > 2 && (
                  <Text style={styles.moreFaultsText}>
                    +{equipment.faults.length - 2} more faults
                  </Text>
                )}
              </View>
            )}
          </View>
        )}

        {/* Last update */}
        <Text style={styles.lastUpdate}>
          Updated: {formatTime(equipment.lastUpdate)}
        </Text>
      </TouchableOpacity>
    );
  };

  return (
    <View style={[styles.container, style]} testID={testID}>
      <View style={styles.header}>
        <Text style={styles.title}>Equipment Status</Text>
        {/* Connection status indicator */}
        {enableRealTime && (
          <View style={[styles.connectionIndicator, { backgroundColor: isConnected ? COLORS.SUCCESS : COLORS.ERROR }]} />
        )}
      </View>
      
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {displayEquipment.map(renderEquipmentCard)}
      </ScrollView>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    borderRadius: 12,
    padding: SPACING.MEDIUM,
    marginBottom: SPACING.MEDIUM,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  connectionIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  scrollContent: {
    paddingRight: SPACING.MEDIUM,
  },
  
  // Equipment card
  equipmentCard: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 8,
    padding: SPACING.MEDIUM,
    marginRight: SPACING.SMALL,
    minWidth: 200,
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
  },
  compactCard: {
    minWidth: 150,
    padding: SPACING.SMALL,
  },
  faultCard: {
    borderColor: COLORS.WARNING,
    borderWidth: 2,
  },
  criticalCard: {
    borderColor: COLORS.ERROR,
    borderWidth: 2,
  },
  
  // Card header
  cardHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.SMALL,
  },
  equipmentInfo: {
    flex: 1,
    marginRight: SPACING.SMALL,
  },
  equipmentCode: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: 2,
  },
  equipmentName: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
  
  // Status row
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  statusText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '500',
    color: COLORS.TEXT.PRIMARY,
  },
  speedText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
  
  // Progress bar
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  progressBar: {
    flex: 1,
    height: 6,
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderRadius: 3,
    marginRight: SPACING.SMALL,
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  progressText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    fontWeight: '500',
    color: COLORS.TEXT.SECONDARY,
    minWidth: 35,
    textAlign: 'right',
  },
  
  // Details
  detailsContainer: {
    marginBottom: SPACING.SMALL,
  },
  sensorReadings: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginBottom: SPACING.SMALL,
  },
  sensorItem: {
    alignItems: 'center',
  },
  sensorLabel: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    marginBottom: 2,
  },
  sensorValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Faults
  faultsContainer: {
    marginTop: SPACING.SMALL,
  },
  faultsTitle: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.XS,
  },
  faultItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 2,
  },
  faultDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    marginRight: SPACING.XS,
  },
  faultText: {
    flex: 1,
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.PRIMARY,
    marginRight: SPACING.XS,
  },
  faultTime: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
  moreFaultsText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    fontStyle: 'italic',
    marginTop: 2,
  },
  
  // Last update
  lastUpdate: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
  },
});

export default EquipmentStatus;
