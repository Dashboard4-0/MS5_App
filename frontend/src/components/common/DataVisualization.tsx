/**
 * MS5.0 Floor Dashboard - Data Visualization Components
 * 
 * Reusable data visualization components for charts, gauges,
 * and other graphical representations of production data.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
} from 'react-native';
import Svg, { Circle, Path, Text as SvgText, G } from 'react-native-svg';

const { width: screenWidth } = Dimensions.get('window');

// Types
export interface GaugeProps {
  value: number;
  maxValue?: number;
  size?: number;
  strokeWidth?: number;
  color?: string;
  backgroundColor?: string;
  showValue?: boolean;
  showPercentage?: boolean;
  label?: string;
  unit?: string;
}

export interface ProgressBarProps {
  value: number;
  maxValue?: number;
  height?: number;
  color?: string;
  backgroundColor?: string;
  showValue?: boolean;
  showPercentage?: boolean;
  label?: string;
  animated?: boolean;
}

export interface MetricCardProps {
  title: string;
  value: string | number;
  unit?: string;
  trend?: 'up' | 'down' | 'neutral';
  trendValue?: string;
  color?: string;
  icon?: string;
  onPress?: () => void;
}

// Circular Gauge Component
export const CircularGauge: React.FC<GaugeProps> = ({
  value,
  maxValue = 100,
  size = 120,
  strokeWidth = 8,
  color = '#2196F3',
  backgroundColor = '#E0E0E0',
  showValue = true,
  showPercentage = true,
  label,
  unit = '%',
}) => {
  const radius = (size - strokeWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const percentage = Math.min(Math.max((value / maxValue) * 100, 0), 100);
  const strokeDashoffset = circumference - (percentage / 100) * circumference;

  return (
    <View style={styles.gaugeContainer}>
      <Svg width={size} height={size} style={styles.gauge}>
        {/* Background Circle */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={backgroundColor}
          strokeWidth={strokeWidth}
          fill="none"
        />
        
        {/* Progress Circle */}
        <Circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          stroke={color}
          strokeWidth={strokeWidth}
          fill="none"
          strokeDasharray={circumference}
          strokeDashoffset={strokeDashoffset}
          strokeLinecap="round"
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
        />
        
        {/* Center Text */}
        {showValue && (
          <G>
            <SvgText
              x={size / 2}
              y={size / 2 - 8}
              fontSize="20"
              fontWeight="bold"
              textAnchor="middle"
              fill="#212121"
            >
              {Math.round(value)}
            </SvgText>
            {showPercentage && (
              <SvgText
                x={size / 2}
                y={size / 2 + 12}
                fontSize="12"
                textAnchor="middle"
                fill="#757575"
              >
                {unit}
              </SvgText>
            )}
          </G>
        )}
      </Svg>
      
      {label && (
        <Text style={styles.gaugeLabel}>{label}</Text>
      )}
    </View>
  );
};

// Progress Bar Component
export const ProgressBar: React.FC<ProgressBarProps> = ({
  value,
  maxValue = 100,
  height = 8,
  color = '#2196F3',
  backgroundColor = '#E0E0E0',
  showValue = true,
  showPercentage = true,
  label,
  animated = false,
}) => {
  const percentage = Math.min(Math.max((value / maxValue) * 100, 0), 100);

  return (
    <View style={styles.progressContainer}>
      {label && (
        <View style={styles.progressHeader}>
          <Text style={styles.progressLabel}>{label}</Text>
          {showValue && (
            <Text style={styles.progressValue}>
              {Math.round(value)}
              {showPercentage && ` (${Math.round(percentage)}%)`}
            </Text>
          )}
        </View>
      )}
      
      <View style={[styles.progressTrack, { height, backgroundColor }]}>
        <View
          style={[
            styles.progressFill,
            {
              width: `${percentage}%`,
              height,
              backgroundColor: color,
            },
          ]}
        />
      </View>
    </View>
  );
};

// Metric Card Component
export const MetricCard: React.FC<MetricCardProps> = ({
  title,
  value,
  unit,
  trend,
  trendValue,
  color = '#2196F3',
  icon,
  onPress,
}) => {
  const getTrendIcon = () => {
    switch (trend) {
      case 'up':
        return 'trending-up';
      case 'down':
        return 'trending-down';
      case 'neutral':
        return 'trending-flat';
      default:
        return null;
    }
  };

  const getTrendColor = () => {
    switch (trend) {
      case 'up':
        return '#4CAF50';
      case 'down':
        return '#F44336';
      case 'neutral':
        return '#757575';
      default:
        return '#757575';
    }
  };

  return (
    <View style={[styles.metricCard, onPress && styles.metricCardPressable]}>
      <View style={styles.metricHeader}>
        <Text style={styles.metricTitle}>{title}</Text>
        {icon && (
          <Text style={[styles.metricIcon, { color }]}>{icon}</Text>
        )}
      </View>
      
      <View style={styles.metricContent}>
        <Text style={[styles.metricValue, { color }]}>
          {value}
          {unit && <Text style={styles.metricUnit}>{unit}</Text>}
        </Text>
        
        {trend && trendValue && (
          <View style={styles.trendContainer}>
            <Text style={[styles.trendIcon, { color: getTrendColor() }]}>
              {getTrendIcon()}
            </Text>
            <Text style={[styles.trendValue, { color: getTrendColor() }]}>
              {trendValue}
            </Text>
          </View>
        )}
      </View>
    </View>
  );
};

// Line Chart Component (Simplified)
export const LineChart: React.FC<{
  data: number[];
  labels?: string[];
  height?: number;
  color?: string;
  showGrid?: boolean;
  showValues?: boolean;
}> = ({
  data,
  labels,
  height = 200,
  color = '#2196F3',
  showGrid = true,
  showValues = false,
}) => {
  if (!data || data.length === 0) {
    return (
      <View style={[styles.chartContainer, { height }]}>
        <Text style={styles.chartEmptyText}>No data available</Text>
      </View>
    );
  }

  const maxValue = Math.max(...data);
  const minValue = Math.min(...data);
  const range = maxValue - minValue;
  const chartWidth = screenWidth - 40;
  const chartHeight = height - 40;
  const stepX = chartWidth / (data.length - 1);
  const stepY = chartHeight / range;

  // Generate path for line
  const pathData = data
    .map((value, index) => {
      const x = index * stepX;
      const y = chartHeight - (value - minValue) * stepY;
      return `${index === 0 ? 'M' : 'L'} ${x} ${y}`;
    })
    .join(' ');

  return (
    <View style={[styles.chartContainer, { height }]}>
      <Svg width={chartWidth} height={chartHeight}>
        {/* Grid Lines */}
        {showGrid && (
          <G>
            {[0, 0.25, 0.5, 0.75, 1].map((ratio) => (
              <Path
                key={ratio}
                d={`M 0 ${chartHeight * ratio} L ${chartWidth} ${chartHeight * ratio}`}
                stroke="#E0E0E0"
                strokeWidth={1}
              />
            ))}
          </G>
        )}
        
        {/* Data Line */}
        <Path
          d={pathData}
          stroke={color}
          strokeWidth={2}
          fill="none"
          strokeLinecap="round"
          strokeLinejoin="round"
        />
        
        {/* Data Points */}
        {data.map((value, index) => {
          const x = index * stepX;
          const y = chartHeight - (value - minValue) * stepY;
          return (
            <Circle
              key={index}
              cx={x}
              cy={y}
              r={4}
              fill={color}
            />
          );
        })}
        
        {/* Values */}
        {showValues && (
          <G>
            {data.map((value, index) => {
              const x = index * stepX;
              const y = chartHeight - (value - minValue) * stepY - 10;
              return (
                <SvgText
                  key={index}
                  x={x}
                  y={y}
                  fontSize="12"
                  textAnchor="middle"
                  fill="#757575"
                >
                  {Math.round(value)}
                </SvgText>
              );
            })}
          </G>
        )}
      </Svg>
      
      {/* Labels */}
      {labels && (
        <View style={styles.chartLabels}>
          {labels.map((label, index) => (
            <Text key={index} style={styles.chartLabel}>
              {label}
            </Text>
          ))}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  gaugeContainer: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  gauge: {
    alignSelf: 'center',
  },
  gaugeLabel: {
    fontSize: 14,
    color: '#757575',
    marginTop: 8,
    textAlign: 'center',
  },
  progressContainer: {
    marginVertical: 8,
  },
  progressHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 4,
  },
  progressLabel: {
    fontSize: 14,
    color: '#212121',
    fontWeight: '500',
  },
  progressValue: {
    fontSize: 14,
    color: '#757575',
  },
  progressTrack: {
    borderRadius: 4,
    overflow: 'hidden',
  },
  progressFill: {
    borderRadius: 4,
  },
  metricCard: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 16,
    margin: 8,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  metricCardPressable: {
    // Add pressable styles if needed
  },
  metricHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  metricTitle: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  metricIcon: {
    fontSize: 20,
  },
  metricContent: {
    alignItems: 'flex-start',
  },
  metricValue: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  metricUnit: {
    fontSize: 16,
    fontWeight: 'normal',
  },
  trendContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  trendIcon: {
    fontSize: 16,
    marginRight: 4,
  },
  trendValue: {
    fontSize: 12,
    fontWeight: '500',
  },
  chartContainer: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    padding: 20,
    margin: 8,
  },
  chartEmptyText: {
    fontSize: 16,
    color: '#9E9E9E',
    textAlign: 'center',
    marginTop: 50,
  },
  chartLabels: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  chartLabel: {
    fontSize: 12,
    color: '#757575',
    textAlign: 'center',
  },
});

export default {
  CircularGauge,
  ProgressBar,
  MetricCard,
  LineChart,
};
