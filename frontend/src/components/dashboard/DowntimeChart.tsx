/**
 * MS5.0 Floor Dashboard - Downtime Chart Component
 * 
 * A chart component for displaying downtime data with historical trends
 * and top downtime reasons breakdown.
 */

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ViewStyle,
  ScrollView,
  Dimensions,
} from 'react-native';
import Svg, { Rect, Text as SvgText, G, Line, Circle } from 'react-native-svg';
import { COLORS, TYPOGRAPHY, SPACING } from '../../config/constants';
import { useLineData } from '../../hooks';
import { logger } from '../../utils/logger';

// Types
interface DowntimeData {
  timestamp: string;
  duration: number; // minutes
  reason: string;
  category: 'planned' | 'unplanned' | 'changeover' | 'maintenance';
}

interface DowntimeReason {
  reason: string;
  count: number;
  totalDuration: number; // minutes
  percentage: number;
}

interface DowntimeChartProps {
  data: DowntimeData[];
  topReasons: DowntimeReason[];
  timeRange?: 'hour' | 'shift' | 'day' | 'week';
  showTrend?: boolean;
  showReasons?: boolean;
  lineId?: string; // For real-time data
  enableRealTime?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const { width: screenWidth } = Dimensions.get('window');
const chartWidth = screenWidth - (SPACING.LARGE * 2);
const chartHeight = 200;
const barWidth = 20;
const maxBars = 12;

const DowntimeChart: React.FC<DowntimeChartProps> = ({
  data,
  topReasons,
  timeRange = 'shift',
  showTrend = true,
  showReasons = true,
  lineId,
  enableRealTime = false,
  style,
  testID,
}) => {
  // Real-time data state
  const [realTimeData, setRealTimeData] = useState<DowntimeData[]>(data);
  const [realTimeTopReasons, setRealTimeTopReasons] = useState<DowntimeReason[]>(topReasons);

  // Use real-time data hook if enabled and lineId provided
  const { lineData, isConnected, lastUpdate } = useLineData({
    lineId: lineId || '',
    enableOEE: false,
    enableDowntime: true,
    enableAndon: false,
    autoSubscribe: enableRealTime && !!lineId,
  });

  // Update real-time downtime data when new data arrives
  useEffect(() => {
    if (enableRealTime && lineData.downtimeEvents.length > 0) {
      // Convert real-time downtime events to chart data
      const newDowntimeData = lineData.downtimeEvents.map((event: any) => ({
        timestamp: event.timestamp,
        duration: event.duration || 0,
        reason: event.reason || 'Unknown',
        category: event.category || 'unplanned',
      }));
      
      // Update data with latest events (keep last 12 for chart)
      setRealTimeData(prevData => {
        const combined = [...prevData, ...newDowntimeData];
        return combined.slice(-12); // Keep last 12 events
      });

      // Calculate top reasons from real-time data
      const reasonMap = new Map<string, { count: number; totalDuration: number }>();
      newDowntimeData.forEach(event => {
        const existing = reasonMap.get(event.reason) || { count: 0, totalDuration: 0 };
        reasonMap.set(event.reason, {
          count: existing.count + 1,
          totalDuration: existing.totalDuration + event.duration,
        });
      });

      const totalDuration = Array.from(reasonMap.values()).reduce((sum, r) => sum + r.totalDuration, 0);
      const newTopReasons = Array.from(reasonMap.entries())
        .map(([reason, stats]) => ({
          reason,
          count: stats.count,
          totalDuration: stats.totalDuration,
          percentage: totalDuration > 0 ? (stats.totalDuration / totalDuration) * 100 : 0,
        }))
        .sort((a, b) => b.totalDuration - a.totalDuration)
        .slice(0, 5);

      setRealTimeTopReasons(newTopReasons);
      logger.debug('Downtime Chart updated with real-time data', { newDowntimeData, newTopReasons });
    }
  }, [enableRealTime, lineData.downtimeEvents, lastUpdate]);

  // Use real-time data if enabled, otherwise use props
  const displayData = enableRealTime ? realTimeData : data;
  const displayTopReasons = enableRealTime ? realTimeTopReasons : topReasons;
  const getCategoryColor = (category: string) => {
    switch (category) {
      case 'unplanned':
        return COLORS.ERROR;
      case 'planned':
        return COLORS.INFO;
      case 'changeover':
        return COLORS.WARNING;
      case 'maintenance':
        return COLORS.SUCCESS;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const formatDuration = (minutes: number) => {
    if (minutes < 60) {
      return `${Math.round(minutes)}m`;
    }
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = Math.round(minutes % 60);
    return `${hours}h${remainingMinutes > 0 ? ` ${remainingMinutes}m` : ''}`;
  };

  const formatTime = (timestamp: string) => {
    const date = new Date(timestamp);
    switch (timeRange) {
      case 'hour':
        return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
      case 'shift':
        return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
      case 'day':
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      case 'week':
        return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
      default:
        return date.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
    }
  };

  // Process data for chart
  const processedData = displayData.slice(-maxBars).map((item, index) => ({
    ...item,
    x: (index * chartWidth) / Math.min(displayData.length, maxBars),
    height: Math.min((item.duration / 60) * 2, chartHeight - 40), // Scale to chart height
    color: getCategoryColor(item.category),
  }));

  const maxDuration = Math.max(...processedData.map(item => item.duration), 1);

  return (
    <View style={[styles.container, style]} testID={testID}>
      <View style={styles.header}>
        <Text style={styles.title}>Downtime Analysis</Text>
        {/* Connection status indicator */}
        {enableRealTime && (
          <View style={[styles.connectionIndicator, { backgroundColor: isConnected ? COLORS.SUCCESS : COLORS.ERROR }]} />
        )}
      </View>
      
      {/* Chart */}
      <View style={styles.chartContainer}>
        <Svg width={chartWidth} height={chartHeight}>
          {/* Grid lines */}
          {[0, 0.25, 0.5, 0.75, 1].map((ratio, index) => (
            <Line
              key={index}
              x1={0}
              y1={chartHeight - 40 - (ratio * (chartHeight - 40))}
              x2={chartWidth}
              y2={chartHeight - 40 - (ratio * (chartHeight - 40))}
              stroke={COLORS.BORDER.DEFAULT}
              strokeWidth={1}
              strokeDasharray="2,2"
              opacity={0.5}
            />
          ))}
          
          {/* Bars */}
          {processedData.map((item, index) => (
            <G key={index}>
              <Rect
                x={item.x - barWidth / 2}
                y={chartHeight - 40 - item.height}
                width={barWidth}
                height={item.height}
                fill={item.color}
                opacity={0.8}
              />
              
              {/* Duration label */}
              <SvgText
                x={item.x}
                y={chartHeight - 40 - item.height - 5}
                fontSize={TYPOGRAPHY.SIZES.XS}
                fontWeight="500"
                fill={COLORS.TEXT.PRIMARY}
                textAnchor="middle"
              >
                {formatDuration(item.duration)}
              </SvgText>
            </G>
          ))}
          
          {/* Trend line */}
          {showTrend && processedData.length > 1 && (
            <Line
              x1={processedData[0].x}
              y1={chartHeight - 40 - processedData[0].height}
              x2={processedData[processedData.length - 1].x}
              y2={chartHeight - 40 - processedData[processedData.length - 1].height}
              stroke={COLORS.PRIMARY}
              strokeWidth={2}
              strokeDasharray="5,5"
            />
          )}
        </Svg>
        
        {/* X-axis labels */}
        <View style={styles.xAxisLabels}>
          {processedData.map((item, index) => (
            <Text key={index} style={styles.xAxisLabel}>
              {formatTime(item.timestamp)}
            </Text>
          ))}
        </View>
      </View>
      
      {/* Top reasons */}
      {showReasons && displayTopReasons.length > 0 && (
        <View style={styles.reasonsContainer}>
          <Text style={styles.reasonsTitle}>Top Downtime Reasons</Text>
          <ScrollView horizontal showsHorizontalScrollIndicator={false}>
            {displayTopReasons.map((reason, index) => (
              <View key={index} style={styles.reasonItem}>
                <View style={[styles.reasonBar, { width: `${reason.percentage}%` }]} />
                <Text style={styles.reasonText} numberOfLines={1}>
                  {reason.reason}
                </Text>
                <Text style={styles.reasonStats}>
                  {reason.count} times • {formatDuration(reason.totalDuration)}
                </Text>
              </View>
            ))}
          </ScrollView>
        </View>
      )}
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
  chartContainer: {
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
  },
  xAxisLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: chartWidth,
    marginTop: SPACING.SMALL,
  },
  xAxisLabel: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
  },
  reasonsContainer: {
    marginTop: SPACING.MEDIUM,
  },
  reasonsTitle: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.SMALL,
  },
  reasonItem: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 8,
    padding: SPACING.SMALL,
    marginRight: SPACING.SMALL,
    minWidth: 120,
    position: 'relative',
  },
  reasonBar: {
    position: 'absolute',
    top: 0,
    left: 0,
    height: 4,
    backgroundColor: COLORS.PRIMARY,
    borderRadius: 2,
  },
  reasonText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '500',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: 2,
  },
  reasonStats: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
});

export default DowntimeChart;
