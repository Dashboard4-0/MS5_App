/**
 * MS5.0 Floor Dashboard - Job List Component
 * 
 * A list component for displaying multiple jobs with filtering,
 * sorting, and action handling capabilities.
 */

import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  RefreshControl,
  ViewStyle,
  TouchableOpacity,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING } from '../../config/constants';
import JobCard from './JobCard';
import LoadingSpinner from '../common/LoadingSpinner';

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
}

interface JobListProps {
  jobs: Job[];
  loading?: boolean;
  refreshing?: boolean;
  onRefresh?: () => void;
  onJobPress?: (job: Job) => void;
  onJobAccept?: (jobId: string) => void;
  onJobStart?: (jobId: string) => void;
  onJobComplete?: (jobId: string) => void;
  onJobCancel?: (jobId: string) => void;
  filterByStatus?: string;
  sortBy?: 'priority' | 'scheduled_start' | 'created_at' | 'title';
  sortOrder?: 'asc' | 'desc';
  showActions?: boolean;
  compact?: boolean;
  emptyMessage?: string;
  style?: ViewStyle;
  testID?: string;
}

const JobList: React.FC<JobListProps> = ({
  jobs,
  loading = false,
  refreshing = false,
  onRefresh,
  onJobPress,
  onJobAccept,
  onJobStart,
  onJobComplete,
  onJobCancel,
  filterByStatus,
  sortBy = 'priority',
  sortOrder = 'desc',
  showActions = true,
  compact = false,
  emptyMessage = 'No jobs available',
  style,
  testID,
}) => {
  const [selectedJob, setSelectedJob] = useState<string | null>(null);

  // Filter and sort jobs
  const processedJobs = useMemo(() => {
    let filteredJobs = jobs;

    // Filter by status
    if (filterByStatus && filterByStatus !== 'all') {
      filteredJobs = filteredJobs.filter(job => job.status === filterByStatus);
    }

    // Sort jobs
    filteredJobs.sort((a, b) => {
      let aValue: any;
      let bValue: any;

      switch (sortBy) {
        case 'priority':
          aValue = a.priority;
          bValue = b.priority;
          break;
        case 'scheduled_start':
          aValue = new Date(a.scheduled_start).getTime();
          bValue = new Date(b.scheduled_start).getTime();
          break;
        case 'created_at':
          aValue = new Date(a.created_at).getTime();
          bValue = new Date(b.created_at).getTime();
          break;
        case 'title':
          aValue = a.title.toLowerCase();
          bValue = b.title.toLowerCase();
          break;
        default:
          return 0;
      }

      if (sortOrder === 'asc') {
        return aValue > bValue ? 1 : -1;
      } else {
        return aValue < bValue ? 1 : -1;
      }
    });

    return filteredJobs;
  }, [jobs, filterByStatus, sortBy, sortOrder]);

  const handleJobPress = (job: Job) => {
    setSelectedJob(job.id);
    onJobPress?.(job);
  };

  const handleJobAccept = (jobId: string) => {
    onJobAccept?.(jobId);
  };

  const handleJobStart = (jobId: string) => {
    onJobStart?.(jobId);
  };

  const handleJobComplete = (jobId: string) => {
    onJobComplete?.(jobId);
  };

  const handleJobCancel = (jobId: string) => {
    onJobCancel?.(jobId);
  };

  const renderJobCard = ({ item: job }: { item: Job }) => (
    <JobCard
      job={job}
      onPress={handleJobPress}
      onAccept={handleJobAccept}
      onStart={handleJobStart}
      onComplete={handleJobComplete}
      onCancel={handleJobCancel}
      showActions={showActions}
      compact={compact}
      testID={`${testID}-job-${job.id}`}
    />
  );

  const renderEmptyComponent = () => (
    <View style={styles.emptyContainer}>
      <Text style={styles.emptyText}>{emptyMessage}</Text>
    </View>
  );

  const renderHeader = () => {
    if (processedJobs.length === 0) return null;
    
    return (
      <View style={styles.header}>
        <Text style={styles.countText}>
          {processedJobs.length} job{processedJobs.length !== 1 ? 's' : ''}
        </Text>
        {filterByStatus && filterByStatus !== 'all' && (
          <Text style={styles.filterText}>
            Filtered by: {filterByStatus.replace('_', ' ')}
          </Text>
        )}
      </View>
    );
  };

  const renderFooter = () => {
    if (loading && processedJobs.length > 0) {
      return (
        <View style={styles.footer}>
          <LoadingSpinner size="small" message="Loading more jobs..." />
        </View>
      );
    }
    return null;
  };

  if (loading && processedJobs.length === 0) {
    return (
      <View style={[styles.container, style]} testID={testID}>
        <LoadingSpinner message="Loading jobs..." />
      </View>
    );
  }

  return (
    <View style={[styles.container, style]} testID={testID}>
      <FlatList
        data={processedJobs}
        renderItem={renderJobCard}
        keyExtractor={(item) => item.id}
        ListHeaderComponent={renderHeader}
        ListEmptyComponent={renderEmptyComponent}
        ListFooterComponent={renderFooter}
        refreshControl={
          onRefresh ? (
            <RefreshControl
              refreshing={refreshing}
              onRefresh={onRefresh}
              colors={[COLORS.PRIMARY]}
              tintColor={COLORS.PRIMARY}
            />
          ) : undefined
        }
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        ItemSeparatorComponent={() => <View style={styles.separator} />}
      />
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  listContent: {
    paddingBottom: SPACING.MEDIUM,
  },
  separator: {
    height: SPACING.SMALL,
  },
  
  // Header
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
    paddingHorizontal: SPACING.SMALL,
  },
  countText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    fontWeight: '600',
    color: COLORS.TEXT.PRIMARY,
  },
  filterText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    textTransform: 'capitalize',
  },
  
  // Empty state
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: SPACING.LARGE * 2,
  },
  emptyText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
  },
  
  // Footer
  footer: {
    paddingVertical: SPACING.MEDIUM,
    alignItems: 'center',
  },
});

export default JobList;
