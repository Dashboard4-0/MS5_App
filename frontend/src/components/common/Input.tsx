/**
 * MS5.0 Floor Dashboard - Input Component
 * 
 * A reusable input component with various styles and validation
 * optimized for tablet use with proper touch targets.
 */

import React, { useState, forwardRef } from 'react';
import {
  View,
  TextInput,
  Text,
  StyleSheet,
  ViewStyle,
  TextStyle,
  TextInputProps,
  TouchableOpacity,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';

// Types
interface InputProps extends TextInputProps {
  label?: string;
  error?: string;
  helperText?: string;
  variant?: 'outlined' | 'filled' | 'underlined';
  size?: 'small' | 'medium' | 'large';
  disabled?: boolean;
  required?: boolean;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
  onRightIconPress?: () => void;
  containerStyle?: ViewStyle;
  inputStyle?: TextStyle;
  labelStyle?: TextStyle;
  testID?: string;
}

const Input = forwardRef<TextInput, InputProps>(({
  label,
  error,
  helperText,
  variant = 'outlined',
  size = 'medium',
  disabled = false,
  required = false,
  leftIcon,
  rightIcon,
  onRightIconPress,
  containerStyle,
  inputStyle,
  labelStyle,
  testID,
  ...props
}, ref) => {
  const [isFocused, setIsFocused] = useState(false);

  const containerStyles = [
    styles.container,
    containerStyle,
  ];

  const inputContainerStyles = [
    styles.inputContainer,
    styles[variant],
    styles[size],
    isFocused && styles.focused,
    error && styles.error,
    disabled && styles.disabled,
  ];

  const inputStyles = [
    styles.input,
    styles[`${size}Input`],
    disabled && styles.disabledInput,
    inputStyle,
  ];

  const labelStyles = [
    styles.label,
    styles[`${size}Label`],
    error && styles.errorLabel,
    disabled && styles.disabledLabel,
    labelStyle,
  ];

  const renderLabel = () => {
    if (!label) return null;
    
    return (
      <Text style={labelStyles}>
        {label}
        {required && <Text style={styles.required}> *</Text>}
      </Text>
    );
  };

  const renderLeftIcon = () => {
    if (!leftIcon) return null;
    
    return (
      <View style={styles.leftIconContainer}>
        {leftIcon}
      </View>
    );
  };

  const renderRightIcon = () => {
    if (!rightIcon) return null;
    
    if (onRightIconPress) {
      return (
        <TouchableOpacity
          style={styles.rightIconContainer}
          onPress={onRightIconPress}
          disabled={disabled}
        >
          {rightIcon}
        </TouchableOpacity>
      );
    }
    
    return (
      <View style={styles.rightIconContainer}>
        {rightIcon}
      </View>
    );
  };

  const renderError = () => {
    if (!error) return null;
    
    return (
      <Text style={styles.errorText}>{error}</Text>
    );
  };

  const renderHelperText = () => {
    if (!helperText || error) return null;
    
    return (
      <Text style={styles.helperText}>{helperText}</Text>
    );
  };

  return (
    <View style={containerStyles} testID={testID}>
      {renderLabel()}
      <View style={inputContainerStyles}>
        {renderLeftIcon()}
        <TextInput
          ref={ref}
          style={inputStyles}
          onFocus={() => setIsFocused(true)}
          onBlur={() => setIsFocused(false)}
          editable={!disabled}
          placeholderTextColor={COLORS.TEXT.PLACEHOLDER}
          {...props}
        />
        {renderRightIcon()}
      </View>
      {renderError()}
      {renderHelperText()}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    marginBottom: SPACING.SMALL,
  },
  
  // Label styles
  label: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.XS,
  },
  smallLabel: {
    fontSize: TYPOGRAPHY.SIZES.XS,
  },
  mediumLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
  },
  largeLabel: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
  },
  required: {
    color: COLORS.ERROR,
  },
  
  // Input container styles
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
  },
  
  // Variants
  outlined: {
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
  },
  filled: {
    borderWidth: 0,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
  },
  underlined: {
    borderWidth: 0,
    borderBottomWidth: 1,
    borderRadius: 0,
    backgroundColor: 'transparent',
  },
  
  // Sizes
  small: {
    minHeight: TOUCH_TARGETS.MIN_SIZE,
    paddingHorizontal: SPACING.SMALL,
  },
  medium: {
    minHeight: TOUCH_TARGETS.RECOMMENDED_SIZE,
    paddingHorizontal: SPACING.MEDIUM,
  },
  large: {
    minHeight: TOUCH_TARGETS.LARGE_SIZE,
    paddingHorizontal: SPACING.LARGE,
  },
  
  // States
  focused: {
    borderColor: COLORS.PRIMARY,
    shadowColor: COLORS.PRIMARY,
    shadowOffset: {
      width: 0,
      height: 0,
    },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 2,
  },
  error: {
    borderColor: COLORS.ERROR,
  },
  disabled: {
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderColor: COLORS.BORDER.DISABLED,
  },
  
  // Input styles
  input: {
    flex: 1,
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.PRIMARY,
    paddingVertical: 0, // Remove default padding
  },
  smallInput: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
  },
  mediumInput: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
  },
  largeInput: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
  },
  disabledInput: {
    color: COLORS.TEXT.DISABLED,
  },
  
  // Icon styles
  leftIconContainer: {
    marginRight: SPACING.SMALL,
    alignItems: 'center',
    justifyContent: 'center',
  },
  rightIconContainer: {
    marginLeft: SPACING.SMALL,
    alignItems: 'center',
    justifyContent: 'center',
  },
  
  // Text styles
  errorText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.ERROR,
    marginTop: SPACING.XS,
  },
  helperText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginTop: SPACING.XS,
  },
  errorLabel: {
    color: COLORS.ERROR,
  },
  disabledLabel: {
    color: COLORS.TEXT.DISABLED,
  },
});

Input.displayName = 'Input';

export default Input;
