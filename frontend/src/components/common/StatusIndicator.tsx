/**
 * MS5.0 Floor Dashboard - Status Indicator Component
 * 
 * A reusable status indicator component for displaying various states
 * with customizable colors, icons, and animations.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  ViewStyle,
  TextStyle,
  Animated,
  Easing,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING } from '../../config/constants';

// Types
interface StatusIndicatorProps {
  status: 'online' | 'offline' | 'warning' | 'error' | 'success' | 'info' | 'loading';
  label?: string;
  size?: 'small' | 'medium' | 'large';
  variant?: 'dot' | 'badge' | 'pill' | 'outline';
  showLabel?: boolean;
  animated?: boolean;
  style?: ViewStyle;
  labelStyle?: TextStyle;
  testID?: string;
}

const StatusIndicator: React.FC<StatusIndicatorProps> = ({
  status,
  label,
  size = 'medium',
  variant = 'dot',
  showLabel = true,
  animated = false,
  style,
  labelStyle,
  testID,
}) => {
  const animatedValue = React.useRef(new Animated.Value(0)).current;

  React.useEffect(() => {
    if (animated && status === 'loading') {
      const animation = Animated.loop(
        Animated.sequence([
          Animated.timing(animatedValue, {
            toValue: 1,
            duration: 1000,
            easing: Easing.linear,
            useNativeDriver: true,
          }),
          Animated.timing(animatedValue, {
            toValue: 0,
            duration: 1000,
            easing: Easing.linear,
            useNativeDriver: true,
          }),
        ])
      );
      animation.start();
      return () => animation.stop();
    }
  }, [animated, status, animatedValue]);

  const getStatusColor = () => {
    switch (status) {
      case 'online':
      case 'success':
        return COLORS.SUCCESS;
      case 'offline':
      case 'error':
        return COLORS.ERROR;
      case 'warning':
        return COLORS.WARNING;
      case 'info':
        return COLORS.INFO;
      case 'loading':
        return COLORS.PRIMARY;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const getStatusLabel = () => {
    if (label) return label;
    
    switch (status) {
      case 'online':
        return 'Online';
      case 'offline':
        return 'Offline';
      case 'warning':
        return 'Warning';
      case 'error':
        return 'Error';
      case 'success':
        return 'Success';
      case 'info':
        return 'Info';
      case 'loading':
        return 'Loading';
      default:
        return 'Unknown';
    }
  };

  const getIndicatorSize = () => {
    switch (size) {
      case 'small':
        return 8;
      case 'medium':
        return 12;
      case 'large':
        return 16;
      default:
        return 12;
    }
  };

  const getTextSize = () => {
    switch (size) {
      case 'small':
        return TYPOGRAPHY.SIZES.XS;
      case 'medium':
        return TYPOGRAPHY.SIZES.SMALL;
      case 'large':
        return TYPOGRAPHY.SIZES.MEDIUM;
      default:
        return TYPOGRAPHY.SIZES.SMALL;
    }
  };

  const indicatorSize = getIndicatorSize();
  const textSize = getTextSize();
  const statusColor = getStatusColor();
  const statusLabel = getStatusLabel();

  const containerStyles = [
    styles.container,
    variant === 'badge' && styles.badgeContainer,
    variant === 'pill' && styles.pillContainer,
    variant === 'outline' && styles.outlineContainer,
    style,
  ];

  const indicatorStyles = [
    styles.indicator,
    styles[variant],
    {
      width: indicatorSize,
      height: indicatorSize,
      borderRadius: variant === 'pill' ? indicatorSize / 2 : indicatorSize / 2,
      backgroundColor: statusColor,
    },
    variant === 'outline' && {
      backgroundColor: 'transparent',
      borderWidth: 2,
      borderColor: statusColor,
    },
    animated && status === 'loading' && {
      opacity: animatedValue,
    },
  ];

  const labelStyles = [
    styles.label,
    {
      fontSize: textSize,
      color: statusColor,
    },
    labelStyle,
  ];

  const renderIndicator = () => {
    if (animated && status === 'loading') {
      return (
        <Animated.View style={indicatorStyles} />
      );
    }
    
    return <View style={indicatorStyles} />;
  };

  return (
    <View style={containerStyles} testID={testID}>
      {renderIndicator()}
      {showLabel && (
        <Text style={labelStyles} numberOfLines={1}>
          {statusLabel}
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  
  // Indicator styles
  indicator: {
    marginRight: SPACING.XS,
  },
  dot: {
    // Default dot style
  },
  badge: {
    paddingHorizontal: SPACING.XS,
    paddingVertical: 2,
    borderRadius: 4,
    minWidth: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pill: {
    paddingHorizontal: SPACING.SMALL,
    paddingVertical: 4,
    borderRadius: 12,
    minWidth: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  outline: {
    // Outline style handled in dynamic styles
  },
  
  // Container variants
  badgeContainer: {
    // Badge container styles
  },
  pillContainer: {
    // Pill container styles
  },
  outlineContainer: {
    // Outline container styles
  },
  
  // Label styles
  label: {
    fontWeight: '500',
    textTransform: 'capitalize',
  },
});

export default StatusIndicator;
