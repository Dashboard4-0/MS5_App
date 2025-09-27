/**
 * MS5.0 Floor Dashboard - Escalation Tree Component
 * 
 * A component for displaying Andon escalation paths and status
 * with visual hierarchy and action buttons.
 */

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  TouchableOpacity,
  ViewStyle,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import StatusIndicator from '../common/StatusIndicator';
import Button from '../common/Button';

// Types
interface EscalationLevel {
  level: number;
  name: string;
  recipients: string[];
  delay_minutes: number;
  status: 'pending' | 'notified' | 'acknowledged' | 'escalated' | 'resolved';
  notified_at?: string;
  acknowledged_at?: string;
  acknowledged_by?: string;
  notes?: string;
}

interface EscalationEvent {
  id: string;
  event_id: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  escalation_levels: EscalationLevel[];
  current_level: number;
  status: 'active' | 'acknowledged' | 'escalated' | 'resolved';
  created_at: string;
  resolved_at?: string;
  resolved_by?: string;
}

interface EscalationTreeProps {
  escalation: EscalationEvent;
  onAcknowledge?: (escalationId: string, level: number) => void;
  onEscalate?: (escalationId: string, level: number) => void;
  onResolve?: (escalationId: string) => void;
  onAddNote?: (escalationId: string, level: number, note: string) => void;
  showActions?: boolean;
  compact?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const EscalationTree: React.FC<EscalationTreeProps> = ({
  escalation,
  onAcknowledge,
  onEscalate,
  onResolve,
  onAddNote,
  showActions = true,
  compact = false,
  style,
  testID,
}) => {
  const [expandedLevels, setExpandedLevels] = useState<Set<number>>(new Set([0]));

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'resolved':
        return COLORS.SUCCESS;
      case 'acknowledged':
        return COLORS.INFO;
      case 'escalated':
        return COLORS.WARNING;
      case 'notified':
        return COLORS.PRIMARY;
      case 'pending':
        return COLORS.TEXT.SECONDARY;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const getPriorityColor = (priority: string) => {
    switch (priority) {
      case 'critical':
        return COLORS.ERROR;
      case 'high':
        return COLORS.WARNING;
      case 'medium':
        return COLORS.INFO;
      case 'low':
        return COLORS.SUCCESS;
      default:
        return COLORS.TEXT.SECONDARY;
    }
  };

  const getStatusText = (status: string) => {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'notified':
        return 'Notified';
      case 'acknowledged':
        return 'Acknowledged';
      case 'escalated':
        return 'Escalated';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
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

  const formatDelay = (minutes: number) => {
    if (minutes < 60) {
      return `${minutes}m`;
    }
    const hours = Math.floor(minutes / 60);
    const remainingMinutes = minutes % 60;
    return remainingMinutes > 0 ? `${hours}h ${remainingMinutes}m` : `${hours}h`;
  };

  const toggleLevel = (level: number) => {
    const newExpanded = new Set(expandedLevels);
    if (newExpanded.has(level)) {
      newExpanded.delete(level);
    } else {
      newExpanded.add(level);
    }
    setExpandedLevels(newExpanded);
  };

  const renderLevel = (level: EscalationLevel, index: number) => {
    const isExpanded = expandedLevels.has(index);
    const isCurrentLevel = index === escalation.current_level;
    const isCompleted = level.status === 'resolved' || level.status === 'acknowledged';
    const canAcknowledge = level.status === 'notified' && showActions;
    const canEscalate = level.status === 'acknowledged' && showActions && index < escalation.escalation_levels.length - 1;

    return (
      <View key={level.level} style={styles.levelContainer}>
        {/* Level Header */}
        <TouchableOpacity
          style={[
            styles.levelHeader,
            isCurrentLevel && styles.currentLevel,
            isCompleted && styles.completedLevel,
            compact && styles.compactLevelHeader,
          ]}
          onPress={() => toggleLevel(index)}
          activeOpacity={0.7}
          testID={`${testID}-level-${level.level}`}
        >
          <View style={styles.levelInfo}>
            <View style={styles.levelTitle}>
              <Text style={[
                styles.levelName,
                isCurrentLevel && styles.currentLevelName,
                compact && styles.compactLevelName,
              ]}>
                Level {level.level}: {level.name}
              </Text>
              {isCurrentLevel && (
                <Text style={styles.currentIndicator}>CURRENT</Text>
              )}
            </View>
            
            <View style={styles.levelDetails}>
              <StatusIndicator
                status={level.status === 'resolved' ? 'success' :
                       level.status === 'acknowledged' ? 'info' :
                       level.status === 'escalated' ? 'warning' :
                       level.status === 'notified' ? 'info' : 'offline'}
                label={getStatusText(level.status)}
                size="small"
                variant="badge"
              />
              
              <Text style={styles.delayText}>
                {formatDelay(level.delay_minutes)} delay
              </Text>
            </View>
          </View>
          
          <Text style={styles.expandIcon}>
            {isExpanded ? '▼' : '▶'}
          </Text>
        </TouchableOpacity>

        {/* Level Details */}
        {isExpanded && (
          <View style={styles.levelDetails}>
            {/* Recipients */}
            <View style={styles.recipientsContainer}>
              <Text style={styles.recipientsTitle}>Recipients:</Text>
              <View style={styles.recipientsList}>
                {level.recipients.map((recipient, idx) => (
                  <View key={idx} style={styles.recipientItem}>
                    <Text style={styles.recipientText}>{recipient}</Text>
                  </View>
                ))}
              </View>
            </View>

            {/* Timestamps */}
            <View style={styles.timestampsContainer}>
              {level.notified_at && (
                <View style={styles.timestampItem}>
                  <Text style={styles.timestampLabel}>Notified:</Text>
                  <Text style={styles.timestampValue}>
                    {formatDateTime(level.notified_at)}
                  </Text>
                </View>
              )}
              
              {level.acknowledged_at && (
                <View style={styles.timestampItem}>
                  <Text style={styles.timestampLabel}>Acknowledged:</Text>
                  <Text style={styles.timestampValue}>
                    {formatDateTime(level.acknowledged_at)}
                  </Text>
                  {level.acknowledged_by && (
                    <Text style={styles.acknowledgedBy}>
                      by {level.acknowledged_by}
                    </Text>
                  )}
                </View>
              )}
            </View>

            {/* Notes */}
            {level.notes && (
              <View style={styles.notesContainer}>
                <Text style={styles.notesTitle}>Notes:</Text>
                <Text style={styles.notesText}>{level.notes}</Text>
              </View>
            )}

            {/* Actions */}
            {showActions && (
              <View style={styles.levelActions}>
                {canAcknowledge && (
                  <Button
                    title="Acknowledge"
                    variant="primary"
                    size="small"
                    onPress={() => onAcknowledge?.(escalation.id, level.level)}
                    style={styles.levelActionButton}
                    testID={`${testID}-acknowledge-${level.level}`}
                  />
                )}
                
                {canEscalate && (
                  <Button
                    title="Escalate"
                    variant="warning"
                    size="small"
                    onPress={() => onEscalate?.(escalation.id, level.level)}
                    style={styles.levelActionButton}
                    testID={`${testID}-escalate-${level.level}`}
                  />
                )}
              </View>
            )}
          </View>
        )}
      </View>
    );
  };

  return (
    <View style={[styles.container, style]} testID={testID}>
      {/* Header */}
      <View style={styles.header}>
        <View style={styles.headerInfo}>
          <Text style={styles.title}>Escalation Tree</Text>
          <StatusIndicator
            status={escalation.status === 'resolved' ? 'success' :
                   escalation.status === 'acknowledged' ? 'info' :
                   escalation.status === 'escalated' ? 'warning' : 'error'}
            label={escalation.status.toUpperCase()}
            size="small"
            variant="badge"
          />
        </View>
        
        <View style={styles.priorityContainer}>
          <View style={[
            styles.priorityDot,
            { backgroundColor: getPriorityColor(escalation.priority) }
          ]} />
          <Text style={styles.priorityText}>
            {escalation.priority.toUpperCase()} Priority
          </Text>
        </View>
      </View>

      {/* Escalation Levels */}
      <ScrollView style={styles.levelsContainer} showsVerticalScrollIndicator={false}>
        {escalation.escalation_levels.map((level, index) => renderLevel(level, index))}
      </ScrollView>

      {/* Global Actions */}
      {showActions && escalation.status === 'active' && (
        <View style={styles.globalActions}>
          <Button
            title="Resolve Escalation"
            variant="success"
            size="medium"
            onPress={() => onResolve?.(escalation.id)}
            style={styles.globalActionButton}
            testID={`${testID}-resolve-button`}
          />
        </View>
      )}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    borderRadius: 12,
    padding: SPACING.MEDIUM,
  },
  
  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
    paddingBottom: SPACING.MEDIUM,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.BORDER.DEFAULT,
  },
  headerInfo: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    marginRight: SPACING.MEDIUM,
  },
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
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Levels container
  levelsContainer: {
    maxHeight: 400,
  },
  
  // Level container
  levelContainer: {
    marginBottom: SPACING.SMALL,
    borderWidth: 1,
    borderColor: COLORS.BORDER.DEFAULT,
    borderRadius: 8,
    overflow: 'hidden',
  },
  
  // Level header
  levelHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: SPACING.MEDIUM,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
  },
  compactLevelHeader: {
    padding: SPACING.SMALL,
  },
  currentLevel: {
    backgroundColor: COLORS.PRIMARY + '20',
    borderColor: COLORS.PRIMARY,
  },
  completedLevel: {
    backgroundColor: COLORS.SUCCESS + '10',
    borderColor: COLORS.SUCCESS,
  },
  
  // Level info
  levelInfo: {
    flex: 1,
  },
  levelTitle: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.XS,
  },
  levelName: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    flex: 1,
  },
  compactLevelName: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
  },
  currentLevelName: {
    color: COLORS.PRIMARY,
  },
  currentIndicator: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    fontWeight: '700',
    color: COLORS.PRIMARY,
    backgroundColor: COLORS.PRIMARY + '20',
    paddingHorizontal: SPACING.XS,
    paddingVertical: 2,
    borderRadius: 4,
    marginLeft: SPACING.SMALL,
  },
  levelDetails: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  delayText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    marginLeft: SPACING.SMALL,
  },
  expandIcon: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginLeft: SPACING.SMALL,
  },
  
  // Level details
  levelDetails: {
    padding: SPACING.MEDIUM,
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
  },
  recipientsContainer: {
    marginBottom: SPACING.MEDIUM,
  },
  recipientsTitle: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.XS,
  },
  recipientsList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  recipientItem: {
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 4,
    paddingHorizontal: SPACING.SMALL,
    paddingVertical: SPACING.XS,
    marginRight: SPACING.XS,
    marginBottom: SPACING.XS,
  },
  recipientText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.PRIMARY,
  },
  
  // Timestamps
  timestampsContainer: {
    marginBottom: SPACING.MEDIUM,
  },
  timestampItem: {
    flexDirection: 'row',
    alignItems: 'center',
    marginBottom: SPACING.XS,
  },
  timestampLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginRight: SPACING.SMALL,
    minWidth: 100,
  },
  timestampValue: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    fontWeight: '500',
  },
  acknowledgedBy: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    color: COLORS.TEXT.SECONDARY,
    marginLeft: SPACING.SMALL,
  },
  
  // Notes
  notesContainer: {
    marginBottom: SPACING.MEDIUM,
  },
  notesTitle: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.XS,
  },
  notesText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.PRIMARY,
    lineHeight: 18,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    padding: SPACING.SMALL,
    borderRadius: 4,
  },
  
  // Level actions
  levelActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
  },
  levelActionButton: {
    marginLeft: SPACING.SMALL,
    minWidth: 100,
  },
  
  // Global actions
  globalActions: {
    marginTop: SPACING.MEDIUM,
    paddingTop: SPACING.MEDIUM,
    borderTopWidth: 1,
    borderTopColor: COLORS.BORDER.DEFAULT,
    alignItems: 'center',
  },
  globalActionButton: {
    minWidth: 150,
  },
});

export default EscalationTree;
