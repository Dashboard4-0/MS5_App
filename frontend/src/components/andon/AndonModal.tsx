/**
 * MS5.0 Floor Dashboard - Andon Modal Component
 * 
 * A modal component for creating and managing Andon events with
 * form validation and priority selection.
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  Alert,
  ViewStyle,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import Modal from '../common/Modal';
import Input from '../common/Input';
import Button from '../common/Button';
import StatusIndicator from '../common/StatusIndicator';

// Types
interface AndonEvent {
  event_type: 'stop' | 'quality' | 'maintenance' | 'material';
  priority: 'low' | 'medium' | 'high' | 'critical';
  description: string;
  equipment_code?: string;
  line_id?: string;
  reported_by?: string;
  notes?: string;
}

interface AndonModalProps {
  visible: boolean;
  onClose: () => void;
  onSubmit: (event: AndonEvent) => void;
  equipmentCode?: string;
  lineId?: string;
  reportedBy?: string;
  defaultEventType?: AndonEvent['event_type'];
  defaultPriority?: AndonEvent['priority'];
  style?: ViewStyle;
  testID?: string;
}

const AndonModal: React.FC<AndonModalProps> = ({
  visible,
  onClose,
  onSubmit,
  equipmentCode,
  lineId,
  reportedBy,
  defaultEventType,
  defaultPriority,
  style,
  testID,
}) => {
  const [eventType, setEventType] = useState<AndonEvent['event_type']>(defaultEventType || 'stop');
  const [priority, setPriority] = useState<AndonEvent['priority']>(defaultPriority || 'high');
  const [description, setDescription] = useState('');
  const [notes, setNotes] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const eventTypeOptions = [
    { key: 'stop', label: 'Stop', icon: '⏹', color: COLORS.ERROR },
    { key: 'quality', label: 'Quality', icon: '⚠', color: COLORS.WARNING },
    { key: 'maintenance', label: 'Maintenance', icon: '🔧', color: COLORS.INFO },
    { key: 'material', label: 'Material', icon: '📦', color: COLORS.SUCCESS },
  ];

  const priorityOptions = [
    { key: 'low', label: 'Low', color: COLORS.SUCCESS },
    { key: 'medium', label: 'Medium', color: COLORS.WARNING },
    { key: 'high', label: 'High', color: COLORS.ERROR },
    { key: 'critical', label: 'Critical', color: COLORS.ERROR },
  ];

  const getPriorityColor = (priorityKey: string) => {
    const option = priorityOptions.find(opt => opt.key === priorityKey);
    return option?.color || COLORS.TEXT.SECONDARY;
  };

  const getEventTypeIcon = (typeKey: string) => {
    const option = eventTypeOptions.find(opt => opt.key === typeKey);
    return option?.icon || '🚨';
  };

  const handleSubmit = async () => {
    if (!description.trim()) {
      Alert.alert('Validation Error', 'Please provide a description for the Andon event.');
      return;
    }

    setIsSubmitting(true);

    try {
      const event: AndonEvent = {
        event_type: eventType,
        priority,
        description: description.trim(),
        equipment_code: equipmentCode,
        line_id: lineId,
        reported_by: reportedBy,
        notes: notes.trim() || undefined,
      };

      await onSubmit(event);
      
      // Reset form
      setDescription('');
      setNotes('');
      setEventType(defaultEventType || 'stop');
      setPriority(defaultPriority || 'high');
      
      onClose();
    } catch (error) {
      Alert.alert('Error', 'Failed to create Andon event. Please try again.');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleCancel = () => {
    if (description.trim() || notes.trim()) {
      Alert.alert(
        'Discard Changes',
        'Are you sure you want to discard your changes?',
        [
          { text: 'Keep Editing', style: 'cancel' },
          { 
            text: 'Discard', 
            style: 'destructive',
            onPress: () => {
              setDescription('');
              setNotes('');
              onClose();
            }
          },
        ]
      );
    } else {
      onClose();
    }
  };

  const renderEventTypeSelector = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Event Type</Text>
      <View style={styles.optionsGrid}>
        {eventTypeOptions.map((option) => (
          <Button
            key={option.key}
            title={`${option.icon} ${option.label}`}
            variant={eventType === option.key ? 'primary' : 'outline'}
            size="medium"
            onPress={() => setEventType(option.key as AndonEvent['event_type'])}
            style={styles.optionButton}
            testID={`${testID}-event-type-${option.key}`}
          />
        ))}
      </View>
    </View>
  );

  const renderPrioritySelector = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Priority Level</Text>
      <View style={styles.priorityContainer}>
        {priorityOptions.map((option) => (
          <Button
            key={option.key}
            title={option.label}
            variant={priority === option.key ? 'primary' : 'outline'}
            size="small"
            onPress={() => setPriority(option.key as AndonEvent['priority'])}
            style={[
              styles.priorityButton,
              { borderColor: getPriorityColor(option.key) }
            ]}
            testID={`${testID}-priority-${option.key}`}
          />
        ))}
      </View>
    </View>
  );

  const renderEventInfo = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Event Information</Text>
      
      <Input
        label="Description *"
        value={description}
        onChangeText={setDescription}
        placeholder="Describe the issue or event"
        multiline
        numberOfLines={3}
        required
        style={styles.input}
        testID={`${testID}-description-input`}
      />
      
      <Input
        label="Additional Notes"
        value={notes}
        onChangeText={setNotes}
        placeholder="Add any additional details (optional)"
        multiline
        numberOfLines={2}
        style={styles.input}
        testID={`${testID}-notes-input`}
      />
    </View>
  );

  const renderEventSummary = () => (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>Event Summary</Text>
      <View style={styles.summaryCard}>
        <View style={styles.summaryRow}>
          <Text style={styles.summaryLabel}>Type:</Text>
          <View style={styles.summaryValue}>
            <Text style={styles.summaryIcon}>{getEventTypeIcon(eventType)}</Text>
            <Text style={styles.summaryText}>
              {eventTypeOptions.find(opt => opt.key === eventType)?.label}
            </Text>
          </View>
        </View>
        
        <View style={styles.summaryRow}>
          <Text style={styles.summaryLabel}>Priority:</Text>
          <StatusIndicator
            status={priority === 'critical' || priority === 'high' ? 'error' : 
                   priority === 'medium' ? 'warning' : 'success'}
            label={priorityOptions.find(opt => opt.key === priority)?.label || priority}
            size="small"
            variant="badge"
          />
        </View>
        
        {equipmentCode && (
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Equipment:</Text>
            <Text style={styles.summaryText}>{equipmentCode}</Text>
          </View>
        )}
        
        {lineId && (
          <View style={styles.summaryRow}>
            <Text style={styles.summaryLabel}>Line:</Text>
            <Text style={styles.summaryText}>{lineId}</Text>
          </View>
        )}
      </View>
    </View>
  );

  return (
    <Modal
      visible={visible}
      onClose={handleCancel}
      title="Create Andon Event"
      size="large"
      showCloseButton={true}
      closeOnBackdropPress={false}
      style={style}
      testID={testID}
    >
      <ScrollView style={styles.content} showsVerticalScrollIndicator={false}>
        {renderEventTypeSelector()}
        {renderPrioritySelector()}
        {renderEventInfo()}
        {renderEventSummary()}
      </ScrollView>
      
      <View style={styles.actions}>
        <Button
          title="Cancel"
          variant="outline"
          size="large"
          onPress={handleCancel}
          style={styles.actionButton}
          testID={`${testID}-cancel-button`}
        />
        
        <Button
          title="Create Andon Event"
          variant="primary"
          size="large"
          onPress={handleSubmit}
          loading={isSubmitting}
          disabled={!description.trim() || isSubmitting}
          style={styles.actionButton}
          testID={`${testID}-submit-button`}
        />
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  content: {
    flex: 1,
    paddingBottom: SPACING.MEDIUM,
  },
  
  // Sections
  section: {
    marginBottom: SPACING.LARGE,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.MEDIUM,
  },
  
  // Event type selector
  optionsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  optionButton: {
    width: '48%',
    marginBottom: SPACING.SMALL,
  },
  
  // Priority selector
  priorityContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  priorityButton: {
    flex: 1,
    marginHorizontal: SPACING.XS,
  },
  
  // Inputs
  input: {
    marginBottom: SPACING.MEDIUM,
  },
  
  // Summary
  summaryCard: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 8,
    padding: SPACING.MEDIUM,
  },
  summaryRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  summaryLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    fontWeight: '500',
  },
  summaryValue: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  summaryIcon: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    marginRight: SPACING.XS,
  },
  summaryText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    fontWeight: '600',
  },
  
  // Actions
  actions: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingTop: SPACING.MEDIUM,
    borderTopWidth: 1,
    borderTopColor: COLORS.BORDER.DEFAULT,
  },
  actionButton: {
    flex: 1,
    marginHorizontal: SPACING.XS,
  },
});

export default AndonModal;
