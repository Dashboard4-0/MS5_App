/**
 * MS5.0 Floor Dashboard - Job Details Component
 * 
 * A detailed view component for displaying comprehensive job information
 * with progress tracking and action buttons.
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  ViewStyle,
  TouchableOpacity,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import StatusIndicator from '../common/StatusIndicator';
import Button from '../common/Button';

// Types
interface Job {
  id: string;
  title: string;
  description: string;
  line_name: string;
  product_name: string;
  target_quantity: number;
  scheduled_start: string;
  scheduled_end: string;
  status: 'assigned' | 'accepted' | 'in_progress' | 'completed' | 'cancelled';
  priority: number;
  created_at: string;
  progress?: number;
  actual_quantity?: number;
  estimated_completion?: string;
  notes?: string;
  assigned_to?: string;
  created_by?: string;
  completed_at?: string;
  equipment_required?: string[];
  materials_required?: string[];
  quality_checks?: QualityCheck[];
}

interface QualityCheck {
  id: string;
  name: string;
  status: 'pending' | 'passed' | 'failed';
  completed_at?: string;
  notes?: string;
}

interface JobDetailsProps {
  job: Job;
  onAccept?: (jobId: string) => void;
  onStart?: (jobId: string) => void;
  onComplete?: (jobId: string) => void;
  onCancel?: (jobId: string) => void;
  onUpdateProgress?: (jobId: string, progress: number) => void;
  onAddNote?: (jobId: string, note: string) => void;
  showActions?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const JobDetails: React.FC<JobDetailsProps> = ({
  job,
  onAccept,
  onStart,
  onComplete,
  onCancel,
  onUpdateProgress,
  onAddNote,
  showActions = true,
  style,
  testID,
}) => {
  const [showNotes, setShowNotes] = useState(false);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'assigned':
        return COLORS.INFO;
      case 'accepted':
        return COLORS.WARNING;
      case 'in_progress':
        return COLORS.PRIMARY;
      case 'completed':
        return COLORS.SUCCESS;
      case 'cancelled':
        return COLORS.ERROR;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const getPriorityColor = (priority: number) => {
    if (priority >= 4) return COLORS.ERROR;
    if (priority >= 3) return COLORS.WARNING;
    if (priority >= 2) return COLORS.INFO;
    return COLORS.SUCCESS;
  };

  const getPriorityText = (priority: number) => {
    if (priority >= 4) return 'Critical';
    if (priority >= 3) return 'High';
    if (priority >= 2) return 'Medium';
    return 'Low';
  };

  const formatDateTime = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleString('en-US', {
      weekday: 'short',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const formatDuration = (start: string, end: string) => {
    const startDate = new Date(start);
    const endDate = new Date(end);
    const durationMs = endDate.getTime() - startDate.getTime();
    const durationHours = Math.round(durationMs / (1000 * 60 * 60));
    
    if (durationHours < 1) {
      const durationMinutes = Math.round(durationMs / (1000 * 60));
      return `${durationMinutes} minutes`;
    }
    if (durationHours < 24) {
      return `${durationHours} hours`;
    }
    const durationDays = Math.round(durationHours / 24);
    return `${durationDays} days`;
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'assigned':
        return 'Assigned';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  };

  const renderProgressSection = () => {
    if (job.status !== 'in_progress' && job.status !== 'completed') return null;
    
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Progress</Text>
        <View style={styles.progressContainer}>
          <View style={styles.progressBar}>
            <View
              style={[
                styles.progressFill,
                {
                  width: `${job.progress || 0}%`,
                  backgroundColor: getStatusColor(job.status),
                },
              ]}
            />
          </View>
          <Text style={styles.progressText}>{job.progress || 0}%</Text>
        </View>
        
        {job.actual_quantity !== undefined && (
          <View style={styles.quantityContainer}>
            <Text style={styles.quantityLabel}>Quantity Progress:</Text>
            <Text style={styles.quantityValue}>
              {job.actual_quantity} / {job.target_quantity}
            </Text>
          </View>
        )}
      </View>
    );
  };

  const renderQualityChecks = () => {
    if (!job.quality_checks || job.quality_checks.length === 0) return null;
    
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Quality Checks</Text>
        {job.quality_checks.map((check) => (
          <View key={check.id} style={styles.qualityCheckItem}>
            <StatusIndicator
              status={check.status === 'passed' ? 'success' :
                     check.status === 'failed' ? 'error' : 'warning'}
              size="small"
              variant="dot"
            />
            <Text style={styles.qualityCheckName}>{check.name}</Text>
            {check.completed_at && (
              <Text style={styles.qualityCheckTime}>
                {formatDateTime(check.completed_at)}
              </Text>
            )}
          </View>
        ))}
      </View>
    );
  };

  const renderEquipmentRequired = () => {
    if (!job.equipment_required || job.equipment_required.length === 0) return null;
    
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Equipment Required</Text>
        <View style={styles.equipmentList}>
          {job.equipment_required.map((equipment, index) => (
            <View key={index} style={styles.equipmentItem}>
              <Text style={styles.equipmentText}>{equipment}</Text>
            </View>
          ))}
        </View>
      </View>
    );
  };

  const renderMaterialsRequired = () => {
    if (!job.materials_required || job.materials_required.length === 0) return null;
    
    return (
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Materials Required</Text>
        <View style={styles.materialsList}>
          {job.materials_required.map((material, index) => (
            <View key={index} style={styles.materialItem}>
              <Text style={styles.materialText}>{material}</Text>
            </View>
          ))}
        </View>
      </View>
    );
  };

  const renderNotes = () => {
    if (!job.notes) return null;
    
    return (
      <View style={styles.section}>
        <View style={styles.notesHeader}>
          <Text style={styles.sectionTitle}>Notes</Text>
          <TouchableOpacity
            onPress={() => setShowNotes(!showNotes)}
            style={styles.toggleButton}
          >
            <Text style={styles.toggleButtonText}>
              {showNotes ? 'Hide' : 'Show'}
            </Text>
          </TouchableOpacity>
        </View>
        {showNotes && (
          <Text style={styles.notesText}>{job.notes}</Text>
        )}
      </View>
    );
  };

  const renderActions = () => {
    if (!showActions) return null;

    const actions = [];

    switch (job.status) {
      case 'assigned':
        actions.push(
          <Button
            key="accept"
            title="Accept Job"
            variant="primary"
            size="large"
            onPress={() => onAccept?.(job.id)}
            style={styles.actionButton}
          />
        );
        break;
      case 'accepted':
        actions.push(
          <Button
            key="start"
            title="Start Job"
            variant="success"
            size="large"
            onPress={() => onStart?.(job.id)}
            style={styles.actionButton}
          />
        );
        break;
      case 'in_progress':
        actions.push(
          <Button
            key="complete"
            title="Complete Job"
            variant="success"
            size="large"
            onPress={() => onComplete?.(job.id)}
            style={styles.actionButton}
          />
        );
        break;
    }

    // Add cancel button for non-completed jobs
    if (job.status !== 'completed' && job.status !== 'cancelled') {
      actions.push(
        <Button
          key="cancel"
          title="Cancel Job"
          variant="outline"
          size="large"
          onPress={() => onCancel?.(job.id)}
          style={styles.actionButton}
        />
      );
    }

    return actions.length > 0 ? (
      <View style={styles.actionsContainer}>
        {actions}
      </View>
    ) : null;
  };

  return (
    <ScrollView style={[styles.container, style]} testID={testID}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{job.title}</Text>
        <StatusIndicator
          status={job.status === 'completed' ? 'success' :
                 job.status === 'in_progress' ? 'info' :
                 job.status === 'accepted' ? 'warning' :
                 job.status === 'cancelled' ? 'error' : 'info'}
          label={getStatusText(job.status)}
          size="medium"
          variant="badge"
        />
      </View>

      {/* Description */}
      <View style={styles.section}>
        <Text style={styles.description}>{job.description}</Text>
      </View>

      {/* Job Information */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Job Information</Text>
        
        <View style={styles.infoGrid}>
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Line</Text>
            <Text style={styles.infoValue}>{job.line_name}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Product</Text>
            <Text style={styles.infoValue}>{job.product_name}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Target Quantity</Text>
            <Text style={styles.infoValue}>{job.target_quantity}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Priority</Text>
            <View style={styles.priorityContainer}>
              <View style={[styles.priorityDot, { backgroundColor: getPriorityColor(job.priority) }]} />
              <Text style={styles.priorityText}>{getPriorityText(job.priority)}</Text>
            </View>
          </View>
        </View>
      </View>

      {/* Schedule Information */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Schedule</Text>
        
        <View style={styles.scheduleItem}>
          <Text style={styles.scheduleLabel}>Start Time</Text>
          <Text style={styles.scheduleValue}>{formatDateTime(job.scheduled_start)}</Text>
        </View>
        
        <View style={styles.scheduleItem}>
          <Text style={styles.scheduleLabel}>End Time</Text>
          <Text style={styles.scheduleValue}>{formatDateTime(job.scheduled_end)}</Text>
        </View>
        
        <View style={styles.scheduleItem}>
          <Text style={styles.scheduleLabel}>Duration</Text>
          <Text style={styles.scheduleValue}>{formatDuration(job.scheduled_start, job.scheduled_end)}</Text>
        </View>
        
        {job.estimated_completion && (
          <View style={styles.scheduleItem}>
            <Text style={styles.scheduleLabel}>Estimated Completion</Text>
            <Text style={styles.scheduleValue}>{formatDateTime(job.estimated_completion)}</Text>
          </View>
        )}
      </View>

      {/* Progress Section */}
      {renderProgressSection()}

      {/* Quality Checks */}
      {renderQualityChecks()}

      {/* Equipment Required */}
      {renderEquipmentRequired()}

      {/* Materials Required */}
      {renderMaterialsRequired()}

      {/* Notes */}
      {renderNotes()}

      {/* Actions */}
      {renderActions()}
    </ScrollView>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
  },
  
  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.MEDIUM,
    paddingBottom: SPACING.MEDIUM,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.BORDER.DEFAULT,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    flex: 1,
    marginRight: SPACING.MEDIUM,
  },
  description: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.SECONDARY,
    lineHeight: 22,
  },
  
  // Sections
  section: {
    marginBottom: SPACING.LARGE,
  },
  sectionTitle: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.SMALL,
  },
  
  // Info Grid
  infoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  infoItem: {
    width: '48%',
    marginBottom: SPACING.SMALL,
  },
  infoLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginBottom: 2,
  },
  infoValue: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Priority
  priorityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  priorityDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.XS,
  },
  priorityText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Schedule
  scheduleItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  scheduleLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
  },
  scheduleValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Progress
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  progressBar: {
    flex: 1,
    height: 8,
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderRadius: 4,
    marginRight: SPACING.MEDIUM,
  },
  progressFill: {
    height: '100%',
    borderRadius: 4,
  },
  progressText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    minWidth: 50,
    textAlign: 'right',
  },
  quantityContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  quantityLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
  },
  quantityValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Quality Checks
  qualityCheckItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  qualityCheckName: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    flex: 1,
    marginLeft: SPACING.SMALL,
  },
  qualityCheckTime: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
  
  // Equipment & Materials
  equipmentList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  equipmentItem: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 6,
    paddingHorizontal: SPACING.SMALL,
    paddingVertical: SPACING.XS,
    marginRight: SPACING.SMALL,
    marginBottom: SPACING.SMALL,
  },
  equipmentText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
  },
  materialsList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  materialItem: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 6,
    paddingHorizontal: SPACING.SMALL,
    paddingVertical: SPACING.XS,
    marginRight: SPACING.SMALL,
    marginBottom: SPACING.SMALL,
  },
  materialText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Notes
  notesHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  toggleButton: {
    paddingHorizontal: SPACING.SMALL,
    paddingVertical: SPACING.XS,
  },
  toggleButtonText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.PRIMARY,
    fontWeight: '600',
  },
  notesText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    lineHeight: 18,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    padding: SPACING.SMALL,
    borderRadius: 6,
  },
  
  // Actions
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    marginTop: SPACING.LARGE,
    paddingTop: SPACING.LARGE,
    borderTopWidth: 1,
    borderTopColor: COLORS.BORDER.DEFAULT,
  },
  actionButton: {
    minWidth: 120,
  },
});

export default JobDetails;
