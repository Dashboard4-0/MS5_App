/**
 * MS5.0 Floor Dashboard - Andon Button Component
 * 
 * A prominent button component for raising Andon alerts with
 * visual feedback and accessibility features.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  Animated,
  Vibration,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';

// Types
interface AndonButtonProps {
  onPress: () => void;
  disabled?: boolean;
  variant?: 'stop' | 'quality' | 'maintenance' | 'material' | 'general';
  size?: 'small' | 'medium' | 'large';
  showLabel?: boolean;
  animated?: boolean;
  vibrateOnPress?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const AndonButton: React.FC<AndonButtonProps> = ({
  onPress,
  disabled = false,
  variant = 'stop',
  size = 'large',
  showLabel = true,
  animated = true,
  vibrateOnPress = true,
  style,
  testID,
}) => {
  const [isPressed, setIsPressed] = useState(false);
  const [pulseAnim] = useState(new Animated.Value(1));
  const [glowAnim] = useState(new Animated.Value(0));

  // Pulse animation
  useEffect(() => {
    if (animated && !disabled) {
      const pulseAnimation = Animated.loop(
        Animated.sequence([
          Animated.timing(pulseAnim, {
            toValue: 1.1,
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
      pulseAnimation.start();
      return () => pulseAnimation.stop();
    }
  }, [animated, disabled, pulseAnim]);

  const getVariantConfig = () => {
    switch (variant) {
      case 'stop':
        return {
          backgroundColor: COLORS.ERROR,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'STOP',
          icon: '⏹',
          description: 'Emergency Stop',
        };
      case 'quality':
        return {
          backgroundColor: COLORS.WARNING,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'QUALITY',
          icon: '⚠',
          description: 'Quality Issue',
        };
      case 'maintenance':
        return {
          backgroundColor: COLORS.INFO,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'MAINT',
          icon: '🔧',
          description: 'Maintenance Required',
        };
      case 'material':
        return {
          backgroundColor: COLORS.SUCCESS,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'MATERIAL',
          icon: '📦',
          description: 'Material Issue',
        };
      case 'general':
        return {
          backgroundColor: COLORS.PRIMARY,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'ANDON',
          icon: '🚨',
          description: 'General Alert',
        };
      default:
        return {
          backgroundColor: COLORS.ERROR,
          textColor: COLORS.BACKGROUND.PRIMARY,
          label: 'STOP',
          icon: '⏹',
          description: 'Emergency Stop',
        };
    }
  };

  const getSizeConfig = () => {
    switch (size) {
      case 'small':
        return {
          buttonSize: 80,
          fontSize: TYPOGRAPHY.SIZES.SMALL,
          iconSize: 20,
          minHeight: TOUCH_TARGETS.MIN_SIZE,
        };
      case 'medium':
        return {
          buttonSize: 120,
          fontSize: TYPOGRAPHY.SIZES.MEDIUM,
          iconSize: 28,
          minHeight: TOUCH_TARGETS.RECOMMENDED_SIZE,
        };
      case 'large':
        return {
          buttonSize: 160,
          fontSize: TYPOGRAPHY.SIZES.LARGE,
          iconSize: 36,
          minHeight: TOUCH_TARGETS.LARGE_SIZE,
        };
      default:
        return {
          buttonSize: 160,
          fontSize: TYPOGRAPHY.SIZES.LARGE,
          iconSize: 36,
          minHeight: TOUCH_TARGETS.LARGE_SIZE,
        };
    }
  };

  const variantConfig = getVariantConfig();
  const sizeConfig = getSizeConfig();

  const handlePressIn = () => {
    setIsPressed(true);
    
    // Glow animation
    Animated.timing(glowAnim, {
      toValue: 1,
      duration: 150,
      useNativeDriver: true,
    }).start();
  };

  const handlePressOut = () => {
    setIsPressed(false);
    
    // Reset glow animation
    Animated.timing(glowAnim, {
      toValue: 0,
      duration: 150,
      useNativeDriver: true,
    }).start();
  };

  const handlePress = () => {
    if (disabled) return;
    
    if (vibrateOnPress) {
      Vibration.vibrate(100);
    }
    
    onPress();
  };

  const buttonStyle = [
    styles.button,
    {
      width: sizeConfig.buttonSize,
      height: sizeConfig.buttonSize,
      minHeight: sizeConfig.minHeight,
      backgroundColor: variantConfig.backgroundColor,
      borderRadius: sizeConfig.buttonSize / 2,
    },
    isPressed && styles.pressed,
    disabled && styles.disabled,
    style,
  ];

  const animatedStyle = {
    transform: [{ scale: pulseAnim }],
  };

  const glowStyle = {
    opacity: glowAnim,
    transform: [{ scale: glowAnim.interpolate({
      inputRange: [0, 1],
      outputRange: [1, 1.2],
    }) }],
  };

  return (
    <View style={styles.container} testID={testID}>
      <Animated.View style={[styles.glowContainer, glowStyle]}>
        <Animated.View style={animatedStyle}>
          <TouchableOpacity
            style={buttonStyle}
            onPress={handlePress}
            onPressIn={handlePressIn}
            onPressOut={handlePressOut}
            disabled={disabled}
            activeOpacity={0.8}
            testID={`${testID}-button`}
          >
            <View style={styles.buttonContent}>
              <Text style={[styles.icon, { fontSize: sizeConfig.iconSize }]}>
                {variantConfig.icon}
              </Text>
              {showLabel && (
                <Text style={[
                  styles.label,
                  {
                    fontSize: sizeConfig.fontSize,
                    color: variantConfig.textColor,
                  },
                ]}>
                  {variantConfig.label}
                </Text>
              )}
            </View>
          </TouchableOpacity>
        </Animated.View>
      </Animated.View>
      
      {showLabel && (
        <Text style={styles.description}>
          {variantConfig.description}
        </Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  
  // Glow effect
  glowContainer: {
    position: 'relative',
  },
  
  // Button
  button: {
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  pressed: {
    transform: [{ scale: 0.95 }],
    shadowOpacity: 0.5,
    elevation: 12,
  },
  disabled: {
    opacity: 0.5,
    shadowOpacity: 0.1,
    elevation: 2,
  },
  
  // Button content
  buttonContent: {
    alignItems: 'center',
    justifyContent: 'center',
  },
  icon: {
    marginBottom: SPACING.XS,
  },
  label: {
    fontWeight: '700',
    textAlign: 'center',
    letterSpacing: 1,
  },
  
  // Description
  description: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
    marginTop: SPACING.SMALL,
    fontWeight: '500',
  },
});

export default AndonButton;
