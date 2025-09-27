/**
 * MS5.0 Floor Dashboard - Loading Spinner Component
 * 
 * A reusable loading spinner component with customizable message
 * for displaying loading states throughout the application.
 */

import React from 'react';
import {
  View,
  ActivityIndicator,
  Text,
  StyleSheet,
  ViewStyle,
  TextStyle,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING } from '../../config/constants';

// Types
interface LoadingSpinnerProps {
  message?: string;
  size?: 'small' | 'large';
  color?: string;
  style?: ViewStyle;
  textStyle?: TextStyle;
  showMessage?: boolean;
  testID?: string;
}

const LoadingSpinner: React.FC<LoadingSpinnerProps> = ({
  message = 'Loading...',
  size = 'large',
  color = COLORS.PRIMARY,
  style,
  textStyle,
  showMessage = true,
  testID,
}) => {
  return (
    <View style={[styles.container, style]} testID={testID}>
      <ActivityIndicator size={size} color={color} />
      {showMessage && (
        <Text style={[styles.message, textStyle]}>{message}</Text>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: SPACING.MEDIUM,
  },
  message: {
    marginTop: SPACING.SMALL,
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
  },
});

export default LoadingSpinner;
