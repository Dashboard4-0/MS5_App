/**
 * MS5.0 Floor Dashboard - Job Status Filter Component
 * 
 * A filter component for filtering jobs by status with visual indicators
 * and count badges for each status category.
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
import StatusIndicator from '../common/StatusIndicator';

// Types
interface JobStatusFilterProps {
  selectedStatus: string;
  onStatusChange: (status: string) => void;
  statusCounts?: Record<string, number>;
  showAll?: boolean;
  compact?: boolean;
  style?: ViewStyle;
  testID?: string;
}

const JobStatusFilter: React.FC<JobStatusFilterProps> = ({
  selectedStatus,
  onStatusChange,
  statusCounts = {},
  showAll = true,
  compact = false,
  style,
  testID,
}) => {
  const statusOptions = [
    { key: 'all', label: 'All', color: COLORS.TEXT.SECONDARY },
    { key: 'assigned', label: 'Assigned', color: COLORS.INFO },
    { key: 'accepted', label: 'Accepted', color: COLORS.WARNING },
    { key: 'in_progress', label: 'In Progress', color: COLORS.PRIMARY },
    { key: 'completed', label: 'Completed', color: COLORS.SUCCESS },
    { key: 'cancelled', label: 'Cancelled', color: COLORS.ERROR },
  ];

  const filteredOptions = showAll ? statusOptions : statusOptions.slice(1);

  const getStatusIndicatorStatus = (statusKey: string) => {
    switch (statusKey) {
      case 'assigned':
        return 'info';
      case 'accepted':
        return 'warning';
      case 'in_progress':
        return 'info';
      case 'completed':
        return 'success';
      case 'cancelled':
        return 'error';
      default:
        return 'info';
    }
  };

  const renderStatusOption = (option: { key: string; label: string; color: string }) => {
    const isSelected = selectedStatus === option.key;
    const count = statusCounts[option.key] || 0;
    const showCount = count > 0;

    return (
      <TouchableOpacity
        key={option.key}
        style={[
          styles.option,
          compact && styles.compactOption,
          isSelected && styles.selectedOption,
        ]}
        onPress={() => onStatusChange(option.key)}
        activeOpacity={0.7}
        testID={`${testID}-option-${option.key}`}
      >
        <View style={styles.optionContent}>
          {option.key !== 'all' && (
            <StatusIndicator
              status={getStatusIndicatorStatus(option.key)}
              size="small"
              variant="dot"
              showLabel={false}
            />
          )}
          
          <Text
            style={[
              styles.optionLabel,
              compact && styles.compactOptionLabel,
              isSelected && styles.selectedOptionLabel,
              { color: isSelected ? COLORS.PRIMARY : option.color },
            ]}
          >
            {option.label}
          </Text>
          
          {showCount && (
            <View style={[
              styles.countBadge,
              isSelected && styles.selectedCountBadge,
            ]}>
              <Text style={[
                styles.countText,
                isSelected && styles.selectedCountText,
              ]}>
                {count}
              </Text>
            </View>
          )}
        </View>
      </TouchableOpacity>
    );
  };

  return (
    <View style={[styles.container, compact && styles.compactContainer, style]} testID={testID}>
      {filteredOptions.map(renderStatusOption)}
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    borderRadius: 8,
    padding: 4,
    marginBottom: SPACING.MEDIUM,
  },
  compactContainer: {
    padding: 2,
    marginBottom: SPACING.SMALL,
  },
  
  // Option styles
  option: {
    flex: 1,
    borderRadius: 6,
    paddingVertical: SPACING.SMALL,
    paddingHorizontal: SPACING.MEDIUM,
    marginHorizontal: 2,
    minHeight: TOUCH_TARGETS.MIN_SIZE,
    alignItems: 'center',
    justifyContent: 'center',
  },
  compactOption: {
    paddingVertical: SPACING.XS,
    paddingHorizontal: SPACING.SMALL,
    marginHorizontal: 1,
  },
  selectedOption: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    shadowColor: COLORS.PRIMARY,
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.2,
    shadowRadius: 4,
    elevation: 2,
  },
  
  // Option content
  optionContent: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  optionLabel: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    fontWeight: '600',
    marginLeft: SPACING.XS,
  },
  compactOptionLabel: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    marginLeft: 4,
  },
  selectedOptionLabel: {
    fontWeight: '700',
  },
  
  // Count badge
  countBadge: {
    backgroundColor: COLORS.BACKGROUND.DISABLED,
    borderRadius: 10,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginLeft: SPACING.XS,
    minWidth: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  selectedCountBadge: {
    backgroundColor: COLORS.PRIMARY,
  },
  countText: {
    fontSize: TYPOGRAPHY.SIZES.XS,
    fontWeight: '600',
    color: COLORS.TEXT.SECONDARY,
  },
  selectedCountText: {
    color: COLORS.BACKGROUND.PRIMARY,
  },
});

export default JobStatusFilter;
