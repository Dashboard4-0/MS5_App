/**
 * MS5.0 Floor Dashboard - Job Card Component
 * 
 * A card component for displaying job information with status indicators
 * and action buttons for job management.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
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
  progress?: number; // 0-100
  actual_quantity?: number;
  estimated_completion?: string;
}

interface JobCardProps {
  job: Job;
  onPress?: (job: Job) => void;
  onAccept?: (jobId: string) => void;
  onStart?: (jobId: string) => void;
  onComplete?: (jobId: string) => void;
  onCancel?: (jobId: string) => void;
  showActions?: boolean;
  compact?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const JobCard: React.FC<JobCardProps> = ({
  job,
  onPress,
  onAccept,
  onStart,
  onComplete,
  onCancel,
  showActions = true,
  compact = false,
  style,
  testID,
}) => {
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
      return `${durationMinutes}m`;
    }
    return `${durationHours}h`;
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

  const renderProgressBar = () => {
    if (job.status !== 'in_progress' || job.progress === undefined) return null;
    
    return (
      <View style={styles.progressContainer}>
        <View style={styles.progressBar}>
          <View
            style={[
              styles.progressFill,
              {
                width: `${job.progress}%`,
                backgroundColor: getStatusColor(job.status),
              },
            ]}
          />
        </View>
        <Text style={styles.progressText}>{job.progress}%</Text>
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
            title="Accept"
            variant="primary"
            size="small"
            onPress={() => onAccept?.(job.id)}
            style={styles.actionButton}
          />
        );
        break;
      case 'accepted':
        actions.push(
          <Button
            key="start"
            title="Start"
            variant="success"
            size="small"
            onPress={() => onStart?.(job.id)}
            style={styles.actionButton}
          />
        );
        break;
      case 'in_progress':
        actions.push(
          <Button
            key="complete"
            title="Complete"
            variant="success"
            size="small"
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
          title="Cancel"
          variant="outline"
          size="small"
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
    <TouchableOpacity
      style={[
        styles.container,
        compact && styles.compactContainer,
        style,
      ]}
      onPress={() => onPress?.(job)}
      disabled={!onPress}
      activeOpacity={0.7}
      testID={testID}
    >
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.titleContainer}>
          <Text style={styles.title} numberOfLines={1}>
            {job.title}
          </Text>
          <Text style={styles.description} numberOfLines={compact ? 1 : 2}>
            {job.description}
          </Text>
        </View>
        
        <View style={styles.statusContainer}>
          <StatusIndicator
            status={job.status === 'completed' ? 'success' :
                   job.status === 'in_progress' ? 'info' :
                   job.status === 'accepted' ? 'warning' :
                   job.status === 'cancelled' ? 'error' : 'info'}
            label={getStatusText(job.status)}
            size="small"
            variant="badge"
          />
        </View>
      </View>

      {/* Job Details */}
      <View style={styles.detailsContainer}>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Line:</Text>
          <Text style={styles.detailValue}>{job.line_name}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Product:</Text>
          <Text style={styles.detailValue}>{job.product_name}</Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Quantity:</Text>
          <Text style={styles.detailValue}>
            {job.actual_quantity ? `${job.actual_quantity} / ` : ''}{job.target_quantity}
          </Text>
        </View>
        
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Duration:</Text>
          <Text style={styles.detailValue}>
            {formatDuration(job.scheduled_start, job.scheduled_end)}
          </Text>
        </View>
      </View>

      {/* Priority */}
      <View style={styles.priorityContainer}>
        <View style={[styles.priorityDot, { backgroundColor: getPriorityColor(job.priority) }]} />
        <Text style={styles.priorityText}>
          {getPriorityText(job.priority)} Priority
        </Text>
      </View>

      {/* Progress Bar */}
      {renderProgressBar()}

      {/* Time Information */}
      <View style={styles.timeContainer}>
        <Text style={styles.timeLabel}>Start: {formatDateTime(job.scheduled_start)}</Text>
        {job.estimated_completion && (
          <Text style={styles.timeLabel}>
            ETA: {formatDateTime(job.estimated_completion)}
          </Text>
        )}
      </View>

      {/* Actions */}
      {renderActions()}
    </TouchableOpacity>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    borderRadius: 12,
    padding: SPACING.MEDIUM,
    marginBottom: SPACING.SMALL,
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 2,
  },
  compactContainer: {
    padding: SPACING.SMALL,
    marginBottom: SPACING.XS,
  },
  
  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
    marginBottom: SPACING.SMALL,
  },
  titleContainer: {
    flex: 1,
    marginRight: SPACING.SMALL,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: 2,
  },
  description: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    lineHeight: 18,
  },
  statusContainer: {
    alignItems: 'flex-end',
  },
  
  // Details
  detailsContainer: {
    marginBottom: SPACING.SMALL,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 2,
  },
  detailLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    fontWeight: '500',
  },
  detailValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    fontWeight: '600',
  },
  
  // Priority
  priorityContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  priorityDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.XS,
  },
  priorityText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    fontWeight: '500',
  },
  
  // Progress
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.SMALL,
  },
  progressBar: {
    flex: 1,
    height: 6,
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderRadius: 3,
    marginRight: SPACING.SMALL,
  },
  progressFill: {
    height: '100%',
    borderRadius: 3,
  },
  progressText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    fontWeight: '600',
    color: COLORS.TEXT.SECONDARY,
    minWidth: 35,
    textAlign: 'right',
  },
  
  // Time
  timeContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: SPACING.SMALL,
  },
  timeLabel: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
  },
  
  // Actions
  actionsContainer: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: SPACING.SMALL,
  },
  actionButton: {
    minWidth: 80,
  },
});

export default JobCard;
