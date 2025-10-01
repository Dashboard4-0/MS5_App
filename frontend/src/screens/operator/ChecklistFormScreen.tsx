/**
 * MS5.0 Floor Dashboard - Checklist Form Screen
 * 
 * This screen allows operators to complete pre-start checklists
 * with validation, signatures, and real-time updates.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Switch,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { selectUser } from '../../store/slices/authSlice';
import { fetchChecklistTemplate, submitChecklist } from '../../store/slices/jobsSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import FormField from '../../components/common/FormField';
import { StatusIndicator } from '../../components/common/RealTimeIndicators';
import { formatDateTime } from '../../utils/formatters';

// Types
interface ChecklistFormProps {
  route: {
    params: {
      jobId: string;
      templateId: string;
    };
  };
  navigation: any;
}

interface ChecklistTemplate {
  id: string;
  name: string;
  description: string;
  items: ChecklistItem[];
  required_signature: boolean;
  created_at: string;
}

interface ChecklistItem {
  id: string;
  title: string;
  description: string;
  required: boolean;
  type: 'boolean' | 'text' | 'number' | 'select';
  options?: string[];
  min_value?: number;
  max_value?: number;
  validation_rules?: string[];
}

interface ChecklistResponse {
  item_id: string;
  value: any;
  completed: boolean;
  notes?: string;
}

const ChecklistFormScreen: React.FC<ChecklistFormProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector(selectUser);
  const { checklistTemplate, isLoading, isSubmitting } = useSelector((state: RootState) => state.jobs);
  
  const [template, setTemplate] = useState<ChecklistTemplate | null>(null);
  const [responses, setResponses] = useState<Map<string, ChecklistResponse>>(new Map());
  const [notes, setNotes] = useState('');
  const [signature, setSignature] = useState('');
  const [isValid, setIsValid] = useState(false);

  const { jobId, templateId } = route.params;

  useEffect(() => {
    loadChecklistTemplate();
  }, [templateId]);

  useEffect(() => {
    validateForm();
  }, [responses, notes, signature]);

  const loadChecklistTemplate = async () => {
    try {
      const result = await dispatch(fetchChecklistTemplate(templateId)).unwrap();
      setTemplate(result);
    } catch (error) {
      console.error('Failed to load checklist template:', error);
      Alert.alert('Error', 'Failed to load checklist template');
    }
  };

  const validateForm = () => {
    if (!template) {
      setIsValid(false);
      return;
    }

    const requiredItems = template.items.filter(item => item.required);
    const completedRequiredItems = requiredItems.filter(item => {
      const response = responses.get(item.id);
      return response && response.completed;
    });

    const allRequiredCompleted = completedRequiredItems.length === requiredItems.length;
    const signatureValid = !template.required_signature || signature.trim().length > 0;

    setIsValid(allRequiredCompleted && signatureValid);
  };

  const handleItemResponse = (itemId: string, value: any, completed: boolean, itemNotes?: string) => {
    const newResponses = new Map(responses);
    newResponses.set(itemId, {
      item_id: itemId,
      value,
      completed,
      notes: itemNotes,
    });
    setResponses(newResponses);
  };

  const handleSubmit = async () => {
    if (!isValid || !template) {
      Alert.alert('Error', 'Please complete all required items');
      return;
    }

    try {
      const submissionData = {
        job_id: jobId,
        template_id: templateId,
        responses: Array.from(responses.values()),
        notes,
        signature,
        completed_by: user?.id || '',
        completed_at: new Date().toISOString(),
      };

      await dispatch(submitChecklist(submissionData)).unwrap();
      Alert.alert(
        'Success',
        'Checklist submitted successfully',
        [
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to submit checklist');
    }
  };

  const renderChecklistItem = (item: ChecklistItem) => {
    const response = responses.get(item.id);

    switch (item.type) {
      case 'boolean':
        return (
          <View style={styles.checklistItem}>
            <View style={styles.itemHeader}>
              <Text style={styles.itemTitle}>
                {item.title}
                {item.required && <Text style={styles.required}> *</Text>}
              </Text>
              <Switch
                value={response?.value || false}
                onValueChange={(value) => handleItemResponse(item.id, value, value)}
                trackColor={{ false: '#E0E0E0', true: '#2196F3' }}
                thumbColor={response?.value ? '#FFFFFF' : '#FFFFFF'}
              />
            </View>
            <Text style={styles.itemDescription}>{item.description}</Text>
            {response?.value && (
              <StatusIndicator
                status="online"
                label="Completed"
                size="small"
              />
            )}
          </View>
        );

      case 'text':
        return (
          <View style={styles.checklistItem}>
            <FormField
              label={item.title}
              value={response?.value || ''}
              onChangeText={(value) => handleItemResponse(item.id, value, value.trim().length > 0)}
              placeholder={item.description}
              required={item.required}
              multiline
              numberOfLines={3}
            />
          </View>
        );

      case 'number':
        return (
          <View style={styles.checklistItem}>
            <FormField
              label={item.title}
              value={response?.value?.toString() || ''}
              onChangeText={(value) => {
                const numValue = parseFloat(value);
                const isValid = !isNaN(numValue) && 
                  (!item.min_value || numValue >= item.min_value) &&
                  (!item.max_value || numValue <= item.max_value);
                handleItemResponse(item.id, numValue, isValid);
              }}
              placeholder={item.description}
              required={item.required}
              keyboardType="numeric"
            />
            {(item.min_value || item.max_value) && (
              <Text style={styles.validationHint}>
                Range: {item.min_value || 'no min'} - {item.max_value || 'no max'}
              </Text>
            )}
          </View>
        );

      case 'select':
        return (
          <View style={styles.checklistItem}>
            <Text style={styles.itemTitle}>
              {item.title}
              {item.required && <Text style={styles.required}> *</Text>}
            </Text>
            <Text style={styles.itemDescription}>{item.description}</Text>
            <View style={styles.optionsContainer}>
              {item.options?.map((option, index) => (
                <TouchableOpacity
                  key={index}
                  style={[
                    styles.optionButton,
                    response?.value === option && styles.optionButtonSelected,
                  ]}
                  onPress={() => handleItemResponse(item.id, option, true)}
                >
                  <Text
                    style={[
                      styles.optionText,
                      response?.value === option && styles.optionTextSelected,
                    ]}
                  >
                    {option}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>
          </View>
        );

      default:
        return null;
    }
  };

  const getCompletionStatus = () => {
    if (!template) return { completed: 0, total: 0 };
    
    const totalItems = template.items.length;
    const completedItems = template.items.filter(item => {
      const response = responses.get(item.id);
      return response && response.completed;
    }).length;

    return { completed: completedItems, total: totalItems };
  };

  if (isLoading) {
    return <LoadingSpinner />;
  }

  if (!template) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Checklist template not found</Text>
      </View>
    );
  }

  const { completed, total } = getCompletionStatus();

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{template.name}</Text>
        <Text style={styles.subtitle}>{template.description}</Text>
        
        <View style={styles.progressContainer}>
          <Text style={styles.progressText}>
            {completed} of {total} items completed
          </Text>
          <View style={styles.progressBar}>
            <View
              style={[
                styles.progressFill,
                { width: `${(completed / total) * 100}%` },
              ]}
            />
          </View>
        </View>
      </View>

      {/* Checklist Items */}
      <View style={styles.itemsContainer}>
        {template.items.map((item, index) => (
          <Card key={item.id} style={styles.itemCard}>
            {renderChecklistItem(item)}
          </Card>
        ))}
      </View>

      {/* Additional Notes */}
      <Card style={styles.notesCard}>
        <Text style={styles.sectionTitle}>Additional Notes</Text>
        <FormField
          label="Notes"
          value={notes}
          onChangeText={setNotes}
          placeholder="Add any additional notes or observations..."
          multiline
          numberOfLines={4}
        />
      </Card>

      {/* Signature */}
      {template.required_signature && (
        <Card style={styles.signatureCard}>
          <Text style={styles.sectionTitle}>
            Digital Signature
            <Text style={styles.required}> *</Text>
          </Text>
          <FormField
            label="Signature"
            value={signature}
            onChangeText={setSignature}
            placeholder="Enter your full name to sign"
            required
          />
          <Text style={styles.signatureHint}>
            By signing, you confirm that you have completed this checklist accurately and truthfully.
          </Text>
        </Card>
      )}

      {/* Submit Button */}
      <View style={styles.submitContainer}>
        <Button
          title="Submit Checklist"
          onPress={handleSubmit}
          variant="primary"
          disabled={!isValid || isSubmitting}
          loading={isSubmitting}
        />
        
        {!isValid && (
          <Text style={styles.validationText}>
            Please complete all required items to submit
          </Text>
        )}
      </View>

      {/* Completion Status */}
      <View style={styles.statusContainer}>
        <StatusIndicator
          status={completed === total ? 'online' : 'warning'}
          label={completed === total ? 'All items completed' : 'Items pending'}
          size="small"
        />
      </View>
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    backgroundColor: '#FFFFFF',
    padding: 20,
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 4,
  },
  subtitle: {
    fontSize: 16,
    color: '#757575',
    marginBottom: 16,
  },
  progressContainer: {
    marginTop: 8,
  },
  progressText: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 8,
  },
  progressBar: {
    height: 4,
    backgroundColor: '#E0E0E0',
    borderRadius: 2,
  },
  progressFill: {
    height: 4,
    backgroundColor: '#2196F3',
    borderRadius: 2,
  },
  itemsContainer: {
    padding: 16,
  },
  itemCard: {
    marginBottom: 16,
    padding: 16,
  },
  checklistItem: {
    marginBottom: 16,
  },
  itemHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  itemTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    flex: 1,
  },
  required: {
    color: '#F44336',
  },
  itemDescription: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 8,
  },
  validationHint: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
  optionsContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginTop: 8,
  },
  optionButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 8,
    marginBottom: 8,
    borderRadius: 20,
    backgroundColor: '#F5F5F5',
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  optionButtonSelected: {
    backgroundColor: '#2196F3',
    borderColor: '#2196F3',
  },
  optionText: {
    fontSize: 14,
    color: '#757575',
  },
  optionTextSelected: {
    color: '#FFFFFF',
  },
  notesCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  signatureCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 12,
  },
  signatureHint: {
    fontSize: 12,
    color: '#757575',
    marginTop: 8,
    fontStyle: 'italic',
  },
  submitContainer: {
    padding: 16,
  },
  validationText: {
    fontSize: 14,
    color: '#F44336',
    textAlign: 'center',
    marginTop: 8,
  },
  statusContainer: {
    alignItems: 'center',
    paddingVertical: 16,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    textAlign: 'center',
    marginTop: 50,
  },
});

export default ChecklistFormScreen;
