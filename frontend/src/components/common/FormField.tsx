/**
 * MS5.0 Floor Dashboard - Form Field Component
 * 
 * A reusable form field component with validation, error handling,
 * and consistent styling across the application.
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  StyleSheet,
  TouchableOpacity,
  TextInputProps,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';

export interface FormFieldProps extends TextInputProps {
  label: string;
  error?: string;
  required?: boolean;
  icon?: string;
  rightIcon?: string;
  onRightIconPress?: () => void;
  containerStyle?: any;
  inputStyle?: any;
  labelStyle?: any;
  errorStyle?: any;
}

const FormField: React.FC<FormFieldProps> = ({
  label,
  error,
  required = false,
  icon,
  rightIcon,
  onRightIconPress,
  containerStyle,
  inputStyle,
  labelStyle,
  errorStyle,
  ...textInputProps
}) => {
  const [isFocused, setIsFocused] = useState(false);

  const handleFocus = () => {
    setIsFocused(true);
    textInputProps.onFocus?.();
  };

  const handleBlur = () => {
    setIsFocused(false);
    textInputProps.onBlur?.();
  };

  return (
    <View style={[styles.container, containerStyle]}>
      {/* Label */}
      <View style={styles.labelContainer}>
        <Text style={[styles.label, labelStyle]}>
          {label}
          {required && <Text style={styles.required}> *</Text>}
        </Text>
      </View>

      {/* Input Container */}
      <View
        style={[
          styles.inputContainer,
          isFocused && styles.inputContainerFocused,
          error && styles.inputContainerError,
        ]}
      >
        {/* Left Icon */}
        {icon && (
          <Icon
            name={icon}
            size={20}
            color={isFocused ? '#2196F3' : '#757575'}
            style={styles.leftIcon}
          />
        )}

        {/* Text Input */}
        <TextInput
          {...textInputProps}
          style={[
            styles.input,
            icon && styles.inputWithIcon,
            rightIcon && styles.inputWithRightIcon,
            inputStyle,
          ]}
          onFocus={handleFocus}
          onBlur={handleBlur}
          placeholderTextColor="#9E9E9E"
        />

        {/* Right Icon */}
        {rightIcon && (
          <TouchableOpacity
            onPress={onRightIconPress}
            style={styles.rightIconContainer}
            disabled={!onRightIconPress}
          >
            <Icon
              name={rightIcon}
              size={20}
              color={onRightIconPress ? '#2196F3' : '#757575'}
            />
          </TouchableOpacity>
        )}
      </View>

      {/* Error Message */}
      {error && (
        <View style={styles.errorContainer}>
          <Icon name="error" size={16} color="#F44336" />
          <Text style={[styles.errorText, errorStyle]}>{error}</Text>
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: 16,
  },
  labelContainer: {
    marginBottom: 8,
  },
  label: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
  },
  required: {
    color: '#F44336',
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#E0E0E0',
    borderRadius: 8,
    backgroundColor: '#FFFFFF',
    minHeight: 48,
  },
  inputContainerFocused: {
    borderColor: '#2196F3',
    borderWidth: 2,
  },
  inputContainerError: {
    borderColor: '#F44336',
  },
  leftIcon: {
    marginLeft: 12,
    marginRight: 8,
  },
  input: {
    flex: 1,
    fontSize: 16,
    color: '#212121',
    paddingVertical: 12,
    paddingHorizontal: 12,
  },
  inputWithIcon: {
    paddingLeft: 0,
  },
  inputWithRightIcon: {
    paddingRight: 0,
  },
  rightIconContainer: {
    padding: 12,
  },
  errorContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 4,
  },
  errorText: {
    fontSize: 14,
    color: '#F44336',
    marginLeft: 4,
  },
});

export default FormField;
