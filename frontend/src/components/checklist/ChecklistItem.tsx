/**
 * MS5.0 Floor Dashboard - Checklist Item Component
 * 
 * A component for individual checklist items with various input types
 * and validation for pre-start checklists and quality checks.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  TextStyle,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import Input from '../common/Input';

// Types
interface ChecklistItemData {
  id: string;
  item: string;
  required: boolean;
  type: 'checkbox' | 'text' | 'number' | 'select' | 'photo' | 'signature';
  options?: string[]; // For select type
  placeholder?: string;
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
    message?: string;
  };
  value?: any;
  notes?: string;
  photo?: string;
  signature?: string;
}

interface ChecklistItemProps {
  item: ChecklistItemData;
  onValueChange: (itemId: string, value: any) => void;
  onNotesChange?: (itemId: string, notes: string) => void;
  onPhotoCapture?: (itemId: string) => void;
  onSignatureCapture?: (itemId: string) => void;
  disabled?: boolean;
  showValidation?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const ChecklistItem: React.FC<ChecklistItemProps> = ({
  item,
  onValueChange,
  onNotesChange,
  onPhotoCapture,
  onSignatureCapture,
  disabled = false,
  showValidation = true,
  style,
  testID,
}) => {
  const [validationError, setValidationError] = React.useState<string | null>(null);

  const validateValue = (value: any): boolean => {
    if (!item.validation) return true;
    
    const { min, max, pattern, message } = item.validation;
    
    // Required validation
    if (item.required && (!value || value === '')) {
      setValidationError(message || 'This field is required');
      return false;
    }
    
    // Skip other validations if value is empty and not required
    if (!value || value === '') {
      setValidationError(null);
      return true;
    }
    
    // Number validation
    if (item.type === 'number' && typeof value === 'number') {
      if (min !== undefined && value < min) {
        setValidationError(message || `Value must be at least ${min}`);
        return false;
      }
      if (max !== undefined && value > max) {
        setValidationError(message || `Value must be at most ${max}`);
        return false;
      }
    }
    
    // Pattern validation
    if (pattern && typeof value === 'string') {
      const regex = new RegExp(pattern);
      if (!regex.test(value)) {
        setValidationError(message || 'Invalid format');
        return false;
      }
    }
    
    setValidationError(null);
    return true;
  };

  const handleValueChange = (value: any) => {
    if (validateValue(value)) {
      onValueChange(item.id, value);
    }
  };

  const renderCheckbox = () => (
    <TouchableOpacity
      style={[
        styles.checkbox,
        item.value && styles.checkboxChecked,
        disabled && styles.disabled,
      ]}
      onPress={() => !disabled && handleValueChange(!item.value)}
      disabled={disabled}
      testID={`${testID}-checkbox`}
    >
      {item.value && (
        <Text style={styles.checkmark}>✓</Text>
      )}
    </TouchableOpacity>
  );

  const renderTextInput = () => (
    <Input
      value={item.value || ''}
      onChangeText={(text) => handleValueChange(text)}
      placeholder={item.placeholder || 'Enter value'}
      error={showValidation ? validationError : undefined}
      disabled={disabled}
      style={styles.input}
      testID={`${testID}-text-input`}
    />
  );

  const renderNumberInput = () => (
    <Input
      value={item.value?.toString() || ''}
      onChangeText={(text) => {
        const numValue = parseFloat(text);
        handleValueChange(isNaN(numValue) ? '' : numValue);
      }}
      placeholder={item.placeholder || 'Enter number'}
      keyboardType="numeric"
      error={showValidation ? validationError : undefined}
      disabled={disabled}
      style={styles.input}
      testID={`${testID}-number-input`}
    />
  );

  const renderSelect = () => (
    <View style={styles.selectContainer}>
      <TouchableOpacity
        style={[
          styles.selectButton,
          disabled && styles.disabled,
        ]}
        onPress={() => {
          // This would typically open a picker modal
          // For now, we'll just show the current value
        }}
        disabled={disabled}
        testID={`${testID}-select-button`}
      >
        <Text style={[
          styles.selectText,
          !item.value && styles.placeholderText,
        ]}>
          {item.value || item.placeholder || 'Select option'}
        </Text>
        <Text style={styles.selectArrow}>▼</Text>
      </TouchableOpacity>
    </View>
  );

  const renderPhotoCapture = () => (
    <TouchableOpacity
      style={[
        styles.photoButton,
        item.photo && styles.photoButtonWithImage,
        disabled && styles.disabled,
      ]}
      onPress={() => !disabled && onPhotoCapture?.(item.id)}
      disabled={disabled}
      testID={`${testID}-photo-button`}
    >
      {item.photo ? (
        <View style={styles.photoContainer}>
          <Text style={styles.photoText}>📷 Photo Captured</Text>
          <Text style={styles.photoSubtext}>Tap to retake</Text>
        </View>
      ) : (
        <View style={styles.photoContainer}>
          <Text style={styles.photoIcon}>📷</Text>
          <Text style={styles.photoText}>Capture Photo</Text>
        </View>
      )}
    </TouchableOpacity>
  );

  const renderSignatureCapture = () => (
    <TouchableOpacity
      style={[
        styles.signatureButton,
        item.signature && styles.signatureButtonWithSignature,
        disabled && styles.disabled,
      ]}
      onPress={() => !disabled && onSignatureCapture?.(item.id)}
      disabled={disabled}
      testID={`${testID}-signature-button`}
    >
      {item.signature ? (
        <View style={styles.signatureContainer}>
          <Text style={styles.signatureText}>✍️ Signature Captured</Text>
          <Text style={styles.signatureSubtext}>Tap to re-sign</Text>
        </View>
      ) : (
        <View style={styles.signatureContainer}>
          <Text style={styles.signatureIcon}>✍️</Text>
          <Text style={styles.signatureText}>Add Signature</Text>
        </View>
      )}
    </TouchableOpacity>
  );

  const renderInput = () => {
    switch (item.type) {
      case 'checkbox':
        return renderCheckbox();
      case 'text':
        return renderTextInput();
      case 'number':
        return renderNumberInput();
      case 'select':
        return renderSelect();
      case 'photo':
        return renderPhotoCapture();
      case 'signature':
        return renderSignatureCapture();
      default:
        return renderTextInput();
    }
  };

  return (
    <View style={[styles.container, style]} testID={testID}>
      {/* Item Label */}
      <View style={styles.labelContainer}>
        <Text style={[
          styles.label,
          item.required && styles.requiredLabel,
          disabled && styles.disabledLabel,
        ]}>
          {item.item}
          {item.required && <Text style={styles.required}> *</Text>}
        </Text>
      </View>

      {/* Input */}
      <View style={styles.inputContainer}>
        {renderInput()}
      </View>

      {/* Notes */}
      {item.type !== 'checkbox' && (
        <Input
          value={item.notes || ''}
          onChangeText={(text) => onNotesChange?.(item.id, text)}
          placeholder="Add notes (optional)"
          variant="underlined"
          size="small"
          disabled={disabled}
          style={styles.notesInput}
          testID={`${testID}-notes-input`}
        />
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    marginBottom: SPACING.MEDIUM,
  },
  
  // Label
  labelContainer: {
    marginBottom: SPACING.SMALL,
  },
  label: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '500',
    color: COLORS.TEXT.PRIMARY,
  },
  requiredLabel: {
    fontWeight: '600',
  },
  required: {
    color: COLORS.ERROR,
  },
  disabledLabel: {
    color: COLORS.TEXT.DISABLED,
  },
  
  // Input container
  inputContainer: {
    marginBottom: SPACING.SMALL,
  },
  input: {
    marginBottom: 0,
  },
  
  // Checkbox
  checkbox: {
    width: 24,
    height: 24,
    borderRadius: 4,
    borderWidth: 2,
    borderColor: COLORS.BORDER.DEFAULT,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    alignItems: 'center',
    justifyContent: 'center',
  },
  checkboxChecked: {
    backgroundColor: COLORS.PRIMARY,
    borderColor: COLORS.PRIMARY,
  },
  checkmark: {
    color: COLORS.BACKGROUND.PRIMARY,
    fontSize: 16,
    fontWeight: 'bold',
  },
  
  // Select
  selectContainer: {
    marginBottom: SPACING.SMALL,
  },
  selectButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: SPACING.MEDIUM,
    paddingVertical: SPACING.SMALL,
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
    borderRadius: 8,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    minHeight: TOUCH_TARGETS.MIN_SIZE,
  },
  selectText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.PRIMARY,
    flex: 1,
  },
  placeholderText: {
    color: COLORS.TEXT.PLACEHOLDER,
  },
  selectArrow: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginLeft: SPACING.SMALL,
  },
  
  // Photo capture
  photoButton: {
    borderWidth: 2,
    borderColor: COLORS.BORDER.DEFAULT,
    borderStyle: 'dashed',
    borderRadius: 8,
    padding: SPACING.MEDIUM,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 80,
  },
  photoButtonWithImage: {
    borderColor: COLORS.SUCCESS,
    backgroundColor: COLORS.SUCCESS + '10',
  },
  photoContainer: {
    alignItems: 'center',
  },
  photoIcon: {
    fontSize: 24,
    marginBottom: SPACING.XS,
  },
  photoText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '500',
    color: COLORS.TEXT.PRIMARY,
  },
  photoSubtext: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    marginTop: 2,
  },
  
  // Signature capture
  signatureButton: {
    borderWidth: 2,
    borderColor: COLORS.BORDER.DEFAULT,
    borderStyle: 'dashed',
    borderRadius: 8,
    padding: SPACING.MEDIUM,
    alignItems: 'center',
    justifyContent: 'center',
    minHeight: 60,
  },
  signatureButtonWithSignature: {
    borderColor: COLORS.SUCCESS,
    backgroundColor: COLORS.SUCCESS + '10',
  },
  signatureContainer: {
    alignItems: 'center',
  },
  signatureIcon: {
    fontSize: 20,
    marginBottom: SPACING.XS,
  },
  signatureText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '500',
    color: COLORS.TEXT.PRIMARY,
  },
  signatureSubtext: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    marginTop: 2,
  },
  
  // Notes
  notesInput: {
    marginTop: SPACING.SMALL,
  },
  
  // Disabled state
  disabled: {
    opacity: 0.5,
  },
});

export default ChecklistItem;
