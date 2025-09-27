/**
 * MS5.0 Floor Dashboard - OEE Gauge Component
 * 
 * A circular gauge component for displaying OEE metrics with
 * color-coded performance indicators and breakdown values.
 */

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ViewStyle,
  TextStyle,
  Dimensions,
} from 'react-native';
import Svg, { Circle, Text as SvgText, G } from 'react-native-svg';
import { COLORS, TYPOGRAPHY, SPACING } from '../../config/constants';
import { useLineData } from '../../hooks';
import { logger } from '../../utils/logger';

// Types
interface OEEGaugeProps {
  oee?: number; // 0-1 value
  availability?: number; // 0-1 value
  performance?: number; // 0-1 value
  quality?: number; // 0-1 value
  lineId?: string; // For real-time data
  equipmentCode?: string; // For equipment-specific data
  size?: number;
  strokeWidth?: number;
  showBreakdown?: boolean;
  showTarget?: boolean;
  targetOEE?: number;
  enableRealTime?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const { width: screenWidth } = Dimensions.get('window');

const OEEGauge: React.FC<OEEGaugeProps> = ({
  oee: propOEE,
  availability: propAvailability,
  performance: propPerformance,
  quality: propQuality,
  lineId,
  equipmentCode,
  size = 200,
  strokeWidth = 20,
  showBreakdown = true,
  showTarget = true,
  targetOEE = 0.85,
  enableRealTime = false,
  style,
  testID,
}) => {
  // Real-time data state
  const [realTimeData, setRealTimeData] = useState({
    oee: propOEE || 0,
    availability: propAvailability || 0,
    performance: propPerformance || 0,
    quality: propQuality || 0,
  });

  // Use real-time data hook if enabled and lineId provided
  const { lineData, isConnected, lastUpdate } = useLineData({
    lineId: lineId || '',
    enableOEE: enableRealTime,
    autoSubscribe: enableRealTime && !!lineId,
  });

  // Update real-time data when new data arrives
  useEffect(() => {
    if (enableRealTime && lineData.oee.length > 0) {
      const latestOEE = lineData.oee[lineData.oee.length - 1];
      setRealTimeData({
        oee: latestOEE.oee || 0,
        availability: latestOEE.availability || 0,
        performance: latestOEE.performance || 0,
        quality: latestOEE.quality || 0,
      });
      logger.debug('OEE Gauge updated with real-time data', latestOEE);
    }
  }, [enableRealTime, lineData.oee, lastUpdate]);

  // Use real-time data if enabled, otherwise use props
  const oee = enableRealTime ? realTimeData.oee : (propOEE || 0);
  const availability = enableRealTime ? realTimeData.availability : (propAvailability || 0);
  const performance = enableRealTime ? realTimeData.performance : (propPerformance || 0);
  const quality = enableRealTime ? realTimeData.quality : (propQuality || 0);
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const strokeDasharray = circumference;
  const strokeDashoffset = circumference - (oee * circumference);

  const getOEEColor = (value: number) => {
    if (value >= 0.85) return COLORS.SUCCESS;
    if (value >= 0.70) return COLORS.WARNING;
    return COLORS.ERROR;
  };

  const getPerformanceColor = (value: number) => {
    if (value >= 0.9) return COLORS.SUCCESS;
    if (value >= 0.8) return COLORS.WARNING;
    return COLORS.ERROR;
  };

  const formatPercentage = (value: number) => {
    return Math.round(value * 100);
  };

  const oeeColor = getOEEColor(oee);
  const centerX = size / 2;
  const centerY = size / 2;

  return (
    <View style={[styles.container, { width: size, height: size }, style]} testID={testID}>
      {/* Connection status indicator */}
      {enableRealTime && (
        <View style={[styles.connectionIndicator, { backgroundColor: isConnected ? COLORS.SUCCESS : COLORS.ERROR }]} />
      )}
      
      <Svg width={size} height={size}>
        {/* Background circle */}
        <Circle
          cx={centerX}
          cy={centerY}
          r={radius}
          stroke={COLORS.BACKGROUND.SECONDARY}
          strokeWidth={strokeWidth}
          fill="transparent"
        />
        
        {/* Progress circle */}
        <Circle
          cx={centerX}
          cy={centerY}
          r={radius}
          stroke={oeeColor}
          strokeWidth={strokeWidth}
          fill="transparent"
          strokeDasharray={strokeDasharray}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          transform={`rotate(-90 ${centerX} ${centerY})`}
        />
        
        {/* Target line */}
        {showTarget && (
          <Circle
            cx={centerX}
            cy={centerY}
            r={radius - strokeWidth / 2 - 5}
            stroke={COLORS.TEXT.SECONDARY}
            strokeWidth={2}
            fill="transparent"
            strokeDasharray="5,5"
            opacity={0.5}
          />
        )}
        
        {/* Center text */}
        <SvgText
          x={centerX}
          y={centerY - 10}
          fontSize={TYPOGRAPHY.SIZES.LARGE}
          fontWeight="700"
          fill={COLORS.TEXT.PRIMARY}
          textAnchor="middle"
        >
          {formatPercentage(oee)}%
        </SvgText>
        
        <SvgText
          x={centerX}
          y={centerY + 10}
          fontSize={TYPOGRAPHY.SIZES.SMALL}
          fontWeight="500"
          fill={COLORS.TEXT.SECONDARY}
          textAnchor="middle"
        >
          OEE
        </SvgText>
      </Svg>
      
      {/* Breakdown metrics */}
      {showBreakdown && (
        <View style={styles.breakdown}>
          <View style={styles.metricRow}>
            <View style={[styles.metricDot, { backgroundColor: getPerformanceColor(availability) }]} />
            <Text style={styles.metricLabel}>Availability</Text>
            <Text style={[styles.metricValue, { color: getPerformanceColor(availability) }]}>
              {formatPercentage(availability)}%
            </Text>
          </View>
          
          <View style={styles.metricRow}>
            <View style={[styles.metricDot, { backgroundColor: getPerformanceColor(performance) }]} />
            <Text style={styles.metricLabel}>Performance</Text>
            <Text style={[styles.metricValue, { color: getPerformanceColor(performance) }]}>
              {formatPercentage(performance)}%
            </Text>
          </View>
          
          <View style={styles.metricRow}>
            <View style={[styles.metricDot, { backgroundColor: getPerformanceColor(quality) }]} />
            <Text style={styles.metricLabel}>Quality</Text>
            <Text style={[styles.metricValue, { color: getPerformanceColor(quality) }]}>
              {formatPercentage(quality)}%
            </Text>
          </View>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
    position: 'relative',
  },
  connectionIndicator: {
    position: 'absolute',
    top: 8,
    right: 8,
    width: 8,
    height: 8,
    borderRadius: 4,
    zIndex: 1,
  },
  breakdown: {
    marginTop: SPACING.MEDIUM,
    width: '100%',
  },
  metricRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.XS,
  },
  metricDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.SMALL,
  },
  metricLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    flex: 1,
  },
  metricValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
  },
});

export default OEEGauge;
