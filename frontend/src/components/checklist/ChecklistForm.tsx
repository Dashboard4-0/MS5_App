/**
 * MS5.0 Floor Dashboard - Checklist Form Component
 * 
 * A form component for managing complete checklists with validation,
 * progress tracking, and submission handling.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ViewStyle,
  Alert,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import ChecklistItem from './ChecklistItem';
import Button from '../common/Button';
import LoadingSpinner from '../common/LoadingSpinner';

// Types
interface ChecklistTemplate {
  id: string;
  name: string;
  equipment_codes: string[];
  checklist_items: ChecklistItemData[];
  enabled: boolean;
  created_at: string;
}

interface ChecklistItemData {
  id: string;
  item: string;
  required: boolean;
  type: 'checkbox' | 'text' | 'number' | 'select' | 'photo' | 'signature';
  options?: string[];
  placeholder?: string;
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
    message?: string;
  };
}

interface ChecklistResponse {
  itemId: string;
  value: any;
  notes?: string;
  photo?: string;
  signature?: string;
  timestamp: string;
}

interface ChecklistFormProps {
  template: ChecklistTemplate;
  jobAssignmentId?: string;
  onComplete?: (responses: ChecklistResponse[]) => void;
  onSave?: (responses: ChecklistResponse[]) => void;
  initialResponses?: ChecklistResponse[];
  disabled?: boolean;
  showProgress?: boolean;
  autoSave?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const ChecklistForm: React.FC<ChecklistFormProps> = ({
  template,
  jobAssignmentId,
  onComplete,
  onSave,
  initialResponses = [],
  disabled = false,
  showProgress = true,
  autoSave = false,
  style,
  testID,
}) => {
  const [responses, setResponses] = useState<Record<string, ChecklistResponse>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

  // Initialize responses from initial data
  useEffect(() => {
    const initialData: Record<string, ChecklistResponse> = {};
    initialResponses.forEach(response => {
      initialData[response.itemId] = response;
    });
    setResponses(initialData);
  }, [initialResponses]);

  // Auto-save functionality
  useEffect(() => {
    if (autoSave && Object.keys(responses).length > 0) {
      const timeoutId = setTimeout(() => {
        handleSave();
      }, 2000); // Auto-save after 2 seconds of inactivity

      return () => clearTimeout(timeoutId);
    }
  }, [responses, autoSave]);

  const calculateProgress = (): number => {
    const totalItems = template.checklist_items.length;
    const completedItems = template.checklist_items.filter(item => {
      const response = responses[item.id];
      return response && response.value !== undefined && response.value !== '';
    }).length;
    
    return totalItems > 0 ? Math.round((completedItems / totalItems) * 100) : 0;
  };

  const validateForm = (): boolean => {
    const errors: Record<string, string> = {};
    let isValid = true;

    template.checklist_items.forEach(item => {
      const response = responses[item.id];
      
      // Check required fields
      if (item.required) {
        if (!response || response.value === undefined || response.value === '') {
          errors[item.id] = 'This field is required';
          isValid = false;
        }
      }

      // Check validation rules
      if (response && response.value !== undefined && response.value !== '') {
        const { validation } = item;
        if (validation) {
          const { min, max, pattern, message } = validation;
          
          // Number validation
          if (item.type === 'number' && typeof response.value === 'number') {
            if (min !== undefined && response.value < min) {
              errors[item.id] = message || `Value must be at least ${min}`;
              isValid = false;
            }
            if (max !== undefined && response.value > max) {
              errors[item.id] = message || `Value must be at most ${max}`;
              isValid = false;
            }
          }
          
          // Pattern validation
          if (pattern && typeof response.value === 'string') {
            const regex = new RegExp(pattern);
            if (!regex.test(response.value)) {
              errors[item.id] = message || 'Invalid format';
              isValid = false;
            }
          }
        }
      }
    });

    setValidationErrors(errors);
    return isValid;
  };

  const handleValueChange = (itemId: string, value: any) => {
    const newResponse: ChecklistResponse = {
      itemId,
      value,
      timestamp: new Date().toISOString(),
      ...responses[itemId], // Preserve existing notes, photo, signature
    };

    setResponses(prev => ({
      ...prev,
      [itemId]: newResponse,
    }));

    // Clear validation error for this item
    if (validationErrors[itemId]) {
      setValidationErrors(prev => {
        const newErrors = { ...prev };
        delete newErrors[itemId];
        return newErrors;
      });
    }
  };

  const handleNotesChange = (itemId: string, notes: string) => {
    const existingResponse = responses[itemId] || {
      itemId,
      value: undefined,
      timestamp: new Date().toISOString(),
    };

    setResponses(prev => ({
      ...prev,
      [itemId]: {
        ...existingResponse,
        notes,
      },
    }));
  };

  const handlePhotoCapture = (itemId: string) => {
    // This would typically open a camera interface
    // For now, we'll simulate photo capture
    Alert.alert(
      'Photo Capture',
      'Camera functionality would be implemented here',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Simulate Capture', 
          onPress: () => {
            const existingResponse = responses[itemId] || {
              itemId,
              value: undefined,
              timestamp: new Date().toISOString(),
            };

            setResponses(prev => ({
              ...prev,
              [itemId]: {
                ...existingResponse,
                photo: `photo_${itemId}_${Date.now()}.jpg`,
              },
            }));
          }
        },
      ]
    );
  };

  const handleSignatureCapture = (itemId: string) => {
    // This would typically open a signature pad
    // For now, we'll simulate signature capture
    Alert.alert(
      'Signature Capture',
      'Signature pad would be implemented here',
      [
        { text: 'Cancel', style: 'cancel' },
        { 
          text: 'Simulate Signature', 
          onPress: () => {
            const existingResponse = responses[itemId] || {
              itemId,
              value: undefined,
              timestamp: new Date().toISOString(),
            };

            setResponses(prev => ({
              ...prev,
              [itemId]: {
                ...existingResponse,
                signature: `signature_${itemId}_${Date.now()}.png`,
              },
            }));
          }
        },
      ]
    );
  };

  const handleSave = async () => {
    const responseArray = Object.values(responses);
    onSave?.(responseArray);
  };

  const handleComplete = async () => {
    if (!validateForm()) {
      Alert.alert(
        'Validation Error',
        'Please complete all required fields and fix any validation errors.',
        [{ text: 'OK' }]
      );
      return;
    }

    setIsSubmitting(true);
    
    try {
      const responseArray = Object.values(responses);
      await onComplete?.(responseArray);
    } catch (error) {
      Alert.alert(
        'Error',
        'Failed to complete checklist. Please try again.',
        [{ text: 'OK' }]
      );
    } finally {
      setIsSubmitting(false);
    }
  };

  const progress = calculateProgress();
  const canComplete = progress === 100 && validateForm();

  return (
    <View style={[styles.container, style]} testID={testID}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{template.name}</Text>
        {showProgress && (
          <View style={styles.progressContainer}>
            <Text style={styles.progressText}>{progress}% Complete</Text>
            <View style={styles.progressBar}>
              <View
                style={[
                  styles.progressFill,
                  { width: `${progress}%` }
                ]}
              />
            </View>
          </View>
        )}
      </View>

      {/* Checklist Items */}
      <ScrollView style={styles.itemsContainer} showsVerticalScrollIndicator={false}>
        {template.checklist_items.map((item) => (
          <ChecklistItem
            key={item.id}
            item={{
              ...item,
              value: responses[item.id]?.value,
              notes: responses[item.id]?.notes,
              photo: responses[item.id]?.photo,
              signature: responses[item.id]?.signature,
            }}
            onValueChange={handleValueChange}
            onNotesChange={handleNotesChange}
            onPhotoCapture={handlePhotoCapture}
            onSignatureCapture={handleSignatureCapture}
            disabled={disabled}
            showValidation={true}
            testID={`${testID}-item-${item.id}`}
          />
        ))}
      </ScrollView>

      {/* Actions */}
      <View style={styles.actionsContainer}>
        {onSave && (
          <Button
            title="Save Progress"
            variant="outline"
            size="large"
            onPress={handleSave}
            disabled={disabled || isSubmitting}
            style={styles.actionButton}
            testID={`${testID}-save-button`}
          />
        )}
        
        {onComplete && (
          <Button
            title="Complete Checklist"
            variant="primary"
            size="large"
            onPress={handleComplete}
            disabled={disabled || !canComplete || isSubmitting}
            loading={isSubmitting}
            style={styles.actionButton}
            testID={`${testID}-complete-button`}
          />
        )}
      </View>

      {/* Validation Summary */}
      {Object.keys(validationErrors).length > 0 && (
        <View style={styles.validationSummary}>
          <Text style={styles.validationTitle}>Please fix the following errors:</Text>
          {Object.entries(validationErrors).map(([itemId, error]) => {
            const item = template.checklist_items.find(i => i.id === itemId);
            return (
              <Text key={itemId} style={styles.validationError}>
                • {item?.item}: {error}
              </Text>
            );
          })}
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
  },
  
  // Header
  header: {
    padding: SPACING.MEDIUM,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.BORDER.DEFAULT,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.MEDIUM,
  },
  progressContainer: {
    marginTop: SPACING.SMALL,
  },
  progressText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginBottom: SPACING.XS,
  },
  progressBar: {
    height: 6,
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderRadius: 3,
  },
  progressFill: {
    height: '100%',
    backgroundColor: COLORS.PRIMARY,
    borderRadius: 3,
  },
  
  // Items container
  itemsContainer: {
    flex: 1,
    padding: SPACING.MEDIUM,
  },
  
  // Actions
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: SPACING.MEDIUM,
    borderTopWidth: 1,
    borderTopColor: COLORS.BORDER.DEFAULT,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
  },
  actionButton: {
    flex: 1,
    marginHorizontal: SPACING.XS,
  },
  
  // Validation summary
  validationSummary: {
    backgroundColor: COLORS.ERROR + '10',
    padding: SPACING.MEDIUM,
    margin: SPACING.MEDIUM,
    borderRadius: 8,
    borderLeftWidth: 4,
    borderLeftColor: COLORS.ERROR,
  },
  validationTitle: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.ERROR,
    marginBottom: SPACING.SMALL,
  },
  validationError: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.ERROR,
    marginBottom: SPACING.XS,
  },
});

export default ChecklistForm;
