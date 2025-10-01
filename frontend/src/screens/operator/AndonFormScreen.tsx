/**
 * MS5.0 Floor Dashboard - Andon Form Screen
 * 
 * This screen allows operators to create Andon events for production
 * issues with categorization, priority, and escalation settings.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  Alert,
  Image,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { selectUser } from '../../store/slices/authSlice';
import { createAndonEvent } from '../../store/slices/andonSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import FormField from '../../components/common/FormField';
import { StatusIndicator } from '../../components/common/RealTimeIndicators';
import { formatDateTime } from '../../utils/formatters';

// Types
interface AndonFormProps {
  route: {
    params: {
      lineId: string;
    };
  };
  navigation: any;
}

interface AndonCategory {
  id: string;
  name: string;
  description: string;
  icon: string;
  color: string;
  escalation_levels: number;
}

interface AndonPriority {
  id: string;
  name: string;
  level: number;
  color: string;
  response_time_minutes: number;
}

interface AndonFormData {
  category_id: string;
  priority_id: string;
  title: string;
  description: string;
  line_id: string;
  equipment_code?: string;
  location?: string;
  reported_by: string;
  reported_at: string;
  attachments?: string[];
  notes?: string;
}

const AndonFormScreen: React.FC<AndonFormProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector(selectUser);
  const { isCreating } = useSelector((state: RootState) => state.andon);
  
  const [formData, setFormData] = useState<AndonFormData>({
    category_id: '',
    priority_id: '',
    title: '',
    description: '',
    line_id: route.params.lineId,
    equipment_code: '',
    location: '',
    reported_by: user?.id || '',
    reported_at: new Date().toISOString(),
    attachments: [],
    notes: '',
  });
  
  const [selectedCategory, setSelectedCategory] = useState<AndonCategory | null>(null);
  const [selectedPriority, setSelectedPriority] = useState<AndonPriority | null>(null);
  const [isValid, setIsValid] = useState(false);

  // Mock data - in real app, this would come from API
  const categories: AndonCategory[] = [
    {
      id: 'quality',
      name: 'Quality Issue',
      description: 'Product quality problems',
      icon: '🔍',
      color: '#F44336',
      escalation_levels: 3,
    },
    {
      id: 'equipment',
      name: 'Equipment Failure',
      description: 'Machine or equipment malfunction',
      icon: '⚙️',
      color: '#FF9800',
      escalation_levels: 2,
    },
    {
      id: 'safety',
      name: 'Safety Concern',
      description: 'Safety hazards or incidents',
      icon: '⚠️',
      color: '#F44336',
      escalation_levels: 1,
    },
    {
      id: 'material',
      name: 'Material Issue',
      description: 'Raw material problems',
      icon: '📦',
      color: '#2196F3',
      escalation_levels: 2,
    },
    {
      id: 'process',
      name: 'Process Issue',
      description: 'Production process problems',
      icon: '🔄',
      color: '#9C27B0',
      escalation_levels: 2,
    },
  ];

  const priorities: AndonPriority[] = [
    {
      id: 'critical',
      name: 'Critical',
      level: 1,
      color: '#F44336',
      response_time_minutes: 5,
    },
    {
      id: 'high',
      name: 'High',
      level: 2,
      color: '#FF9800',
      response_time_minutes: 15,
    },
    {
      id: 'medium',
      name: 'Medium',
      level: 3,
      color: '#2196F3',
      response_time_minutes: 30,
    },
    {
      id: 'low',
      name: 'Low',
      level: 4,
      color: '#4CAF50',
      response_time_minutes: 60,
    },
  ];

  useEffect(() => {
    validateForm();
  }, [formData, selectedCategory, selectedPriority]);

  const validateForm = () => {
    const isValid = 
      formData.title.trim().length > 0 &&
      formData.description.trim().length > 0 &&
      selectedCategory !== null &&
      selectedPriority !== null;
    
    setIsValid(isValid);
  };

  const handleInputChange = (field: keyof AndonFormData, value: string) => {
    setFormData(prev => ({
      ...prev,
      [field]: value,
    }));
  };

  const handleCategorySelect = (category: AndonCategory) => {
    setSelectedCategory(category);
    setFormData(prev => ({
      ...prev,
      category_id: category.id,
    }));
  };

  const handlePrioritySelect = (priority: AndonPriority) => {
    setSelectedPriority(priority);
    setFormData(prev => ({
      ...prev,
      priority_id: priority.id,
    }));
  };

  const handleSubmit = async () => {
    if (!isValid) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    try {
      await dispatch(createAndonEvent(formData)).unwrap();
      Alert.alert(
        'Success',
        'Andon event created successfully',
        [
          {
            text: 'OK',
            onPress: () => navigation.goBack(),
          },
        ]
      );
    } catch (error) {
      Alert.alert('Error', 'Failed to create Andon event');
    }
  };

  const renderCategoryCard = (category: AndonCategory) => {
    const isSelected = selectedCategory?.id === category.id;
    
    return (
      <TouchableOpacity
        key={category.id}
        style={[
          styles.categoryCard,
          isSelected && styles.categoryCardSelected,
          { borderColor: category.color },
        ]}
        onPress={() => handleCategorySelect(category)}
      >
        <View style={styles.categoryHeader}>
          <Text style={styles.categoryIcon}>{category.icon}</Text>
          <Text style={[
            styles.categoryName,
            isSelected && styles.categoryNameSelected,
          ]}>
            {category.name}
          </Text>
        </View>
        <Text style={styles.categoryDescription}>{category.description}</Text>
        <Text style={styles.escalationLevels}>
          {category.escalation_levels} escalation levels
        </Text>
      </TouchableOpacity>
    );
  };

  const renderPriorityCard = (priority: AndonPriority) => {
    const isSelected = selectedPriority?.id === priority.id;
    
    return (
      <TouchableOpacity
        key={priority.id}
        style={[
          styles.priorityCard,
          isSelected && styles.priorityCardSelected,
          { borderColor: priority.color },
        ]}
        onPress={() => handlePrioritySelect(priority)}
      >
        <View style={styles.priorityHeader}>
          <View style={[
            styles.priorityIndicator,
            { backgroundColor: priority.color },
          ]} />
          <Text style={[
            styles.priorityName,
            isSelected && styles.priorityNameSelected,
          ]}>
            {priority.name}
          </Text>
        </View>
        <Text style={styles.responseTime}>
          Response time: {priority.response_time_minutes} minutes
        </Text>
      </TouchableOpacity>
    );
  };

  return (
    <ScrollView style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Create Andon Event</Text>
        <Text style={styles.subtitle}>
          Report a production issue for immediate attention
        </Text>
      </View>

      {/* Basic Information */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Basic Information</Text>
        
        <FormField
          label="Title"
          value={formData.title}
          onChangeText={(value) => handleInputChange('title', value)}
          placeholder="Brief description of the issue"
          required
        />
        
        <FormField
          label="Description"
          value={formData.description}
          onChangeText={(value) => handleInputChange('description', value)}
          placeholder="Detailed description of the issue"
          multiline
          numberOfLines={4}
          required
        />
        
        <FormField
          label="Equipment Code"
          value={formData.equipment_code || ''}
          onChangeText={(value) => handleInputChange('equipment_code', value)}
          placeholder="Equipment code (if applicable)"
        />
        
        <FormField
          label="Location"
          value={formData.location || ''}
          onChangeText={(value) => handleInputChange('location', value)}
          placeholder="Specific location on the line"
        />
      </Card>

      {/* Category Selection */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>
          Issue Category
          <Text style={styles.required}> *</Text>
        </Text>
        <Text style={styles.sectionDescription}>
          Select the type of issue you're reporting
        </Text>
        
        <View style={styles.categoriesContainer}>
          {categories.map(renderCategoryCard)}
        </View>
      </Card>

      {/* Priority Selection */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>
          Priority Level
          <Text style={styles.required}> *</Text>
        </Text>
        <Text style={styles.sectionDescription}>
          How urgent is this issue?
        </Text>
        
        <View style={styles.prioritiesContainer}>
          {priorities.map(renderPriorityCard)}
        </View>
      </Card>

      {/* Additional Information */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Additional Information</Text>
        
        <FormField
          label="Notes"
          value={formData.notes || ''}
          onChangeText={(value) => handleInputChange('notes', value)}
          placeholder="Any additional notes or observations"
          multiline
          numberOfLines={3}
        />
      </Card>

      {/* Escalation Information */}
      {selectedCategory && selectedPriority && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Escalation Information</Text>
          
          <View style={styles.escalationInfo}>
            <View style={styles.escalationItem}>
              <Text style={styles.escalationLabel}>Category:</Text>
              <Text style={styles.escalationValue}>{selectedCategory.name}</Text>
            </View>
            
            <View style={styles.escalationItem}>
              <Text style={styles.escalationLabel}>Priority:</Text>
              <Text style={[
                styles.escalationValue,
                { color: selectedPriority.color },
              ]}>
                {selectedPriority.name}
              </Text>
            </View>
            
            <View style={styles.escalationItem}>
              <Text style={styles.escalationLabel}>Response Time:</Text>
              <Text style={styles.escalationValue}>
                {selectedPriority.response_time_minutes} minutes
              </Text>
            </View>
            
            <View style={styles.escalationItem}>
              <Text style={styles.escalationLabel}>Escalation Levels:</Text>
              <Text style={styles.escalationValue}>
                {selectedCategory.escalation_levels}
              </Text>
            </View>
          </View>
        </Card>
      )}

      {/* Submit Button */}
      <View style={styles.submitContainer}>
        <Button
          title="Create Andon Event"
          onPress={handleSubmit}
          variant="primary"
          disabled={!isValid || isCreating}
          loading={isCreating}
        />
        
        {!isValid && (
          <Text style={styles.validationText}>
            Please complete all required fields to create the event
          </Text>
        )}
      </View>

      {/* Status Indicator */}
      <View style={styles.statusContainer}>
        <StatusIndicator
          status={isValid ? 'online' : 'warning'}
          label={isValid ? 'Ready to submit' : 'Form incomplete'}
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
  },
  sectionCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 8,
  },
  sectionDescription: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 16,
  },
  required: {
    color: '#F44336',
  },
  categoriesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  categoryCard: {
    width: '48%',
    padding: 16,
    marginBottom: 12,
    borderRadius: 8,
    borderWidth: 2,
    backgroundColor: '#FFFFFF',
  },
  categoryCardSelected: {
    backgroundColor: '#E3F2FD',
  },
  categoryHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  categoryIcon: {
    fontSize: 24,
    marginRight: 8,
  },
  categoryName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
  },
  categoryNameSelected: {
    color: '#2196F3',
  },
  categoryDescription: {
    fontSize: 12,
    color: '#757575',
    marginBottom: 4,
  },
  escalationLevels: {
    fontSize: 10,
    color: '#9E9E9E',
  },
  prioritiesContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  priorityCard: {
    width: '48%',
    padding: 16,
    marginBottom: 12,
    borderRadius: 8,
    borderWidth: 2,
    backgroundColor: '#FFFFFF',
  },
  priorityCardSelected: {
    backgroundColor: '#E3F2FD',
  },
  priorityHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: 8,
  },
  priorityIndicator: {
    width: 12,
    height: 12,
    borderRadius: 6,
    marginRight: 8,
  },
  priorityName: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
  },
  priorityNameSelected: {
    color: '#2196F3',
  },
  responseTime: {
    fontSize: 12,
    color: '#757575',
  },
  escalationInfo: {
    marginTop: 8,
  },
  escalationItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  escalationLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  escalationValue: {
    fontSize: 14,
    color: '#212121',
    fontWeight: '500',
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
});

export default AndonFormScreen;
