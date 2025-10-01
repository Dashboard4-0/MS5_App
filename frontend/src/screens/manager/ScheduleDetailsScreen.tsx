/**
 * MS5.0 Floor Dashboard - Schedule Details Screen
 * 
 * This screen provides detailed information about a specific production schedule
 * including job assignments, timeline, and resource allocation.
 */

import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ScrollView,
  RefreshControl,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { fetchScheduleDetails, updateSchedule } from '../../store/slices/productionSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { ProgressBar, MetricCard } from '../../components/common/DataVisualization';
import { StatusIndicator } from '../../components/common/RealTimeIndicators';
import { OfflineIndicator } from '../../components/common/OfflineSupport';
import usePermissions from '../../hooks/usePermissions';
import { formatDateTime, formatDuration } from '../../utils/formatters';

// Types
interface ScheduleDetailsProps {
  route: {
    params: {
      scheduleId: string;
    };
  };
  navigation: any;
}

interface ScheduleDetails {
  id: string;
  title: string;
  description: string;
  status: 'Draft' | 'Active' | 'Completed' | 'Cancelled';
  startDate: string;
  endDate: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  jobs: Array<{
    id: string;
    title: string;
    description: string;
    lineName: string;
    productName: string;
    targetQuantity: number;
    scheduledStart: string;
    scheduledEnd: string;
    status: 'Scheduled' | 'In Progress' | 'Completed' | 'Cancelled';
    priority: number;
    assignedTo: string;
    progress: number;
  }>;
  resources: {
    lines: Array<{
      id: string;
      name: string;
      utilization: number;
    }>;
    operators: Array<{
      id: string;
      name: string;
      role: string;
      utilization: number;
    }>;
  };
  metrics: {
    totalJobs: number;
    completedJobs: number;
    inProgressJobs: number;
    scheduledJobs: number;
    cancelledJobs: number;
    overallProgress: number;
    estimatedCompletion: string;
  };
}

const ScheduleDetailsScreen: React.FC<ScheduleDetailsProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const { canManageSchedule } = usePermissions();
  const { scheduleDetails, isLoading } = useSelector((state: RootState) => state.production);
  const { isOnline } = useSelector((state: RootState) => state.offline);
  
  const [refreshing, setRefreshing] = useState(false);
  const [schedule, setSchedule] = useState<ScheduleDetails | null>(null);

  const { scheduleId } = route.params;

  const onRefresh = async () => {
    setRefreshing(true);
    try {
      const result = await dispatch(fetchScheduleDetails(scheduleId)).unwrap();
      setSchedule(result);
    } catch (error) {
      console.error('Failed to refresh schedule details:', error);
    }
    setRefreshing(false);
  };

  useEffect(() => {
    onRefresh();
  }, [scheduleId]);

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'Draft':
        return '#9E9E9E';
      case 'Active':
        return '#4CAF50';
      case 'Completed':
        return '#2196F3';
      case 'Cancelled':
        return '#F44336';
      default:
        return '#9E9E9E';
    }
  };

  const getJobStatusColor = (status: string) => {
    switch (status) {
      case 'Scheduled':
        return '#2196F3';
      case 'In Progress':
        return '#4CAF50';
      case 'Completed':
        return '#9E9E9E';
      case 'Cancelled':
        return '#F44336';
      default:
        return '#757575';
    }
  };

  const handleStatusUpdate = async (newStatus: string) => {
    if (!schedule) return;

    Alert.alert(
      'Update Schedule Status',
      `Are you sure you want to change the status to ${newStatus}?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Update',
          onPress: async () => {
            try {
              await dispatch(updateSchedule({
                id: scheduleId,
                status: newStatus,
              })).unwrap();
              Alert.alert('Success', 'Schedule status updated successfully');
              await onRefresh();
            } catch (error) {
              Alert.alert('Error', 'Failed to update schedule status');
            }
          },
        },
      ]
    );
  };

  const handleJobPress = (jobId: string) => {
    // Navigate to job details
    navigation.navigate('JobDetails', { jobId });
  };

  const getTimeRemaining = () => {
    if (!schedule) return null;
    
    const endTime = new Date(schedule.endDate);
    const now = new Date();
    
    if (now > endTime) return 'Overdue';
    
    const remaining = endTime.getTime() - now.getTime();
    const days = Math.floor(remaining / (1000 * 60 * 60 * 24));
    const hours = Math.floor((remaining % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
    
    return `${days}d ${hours}h`;
  };

  const renderJobItem = (job: any) => (
    <TouchableOpacity
      key={job.id}
      style={styles.jobItem}
      onPress={() => handleJobPress(job.id)}
    >
      <View style={styles.jobHeader}>
        <Text style={styles.jobTitle}>{job.title}</Text>
        <View style={[styles.jobStatusBadge, { backgroundColor: getJobStatusColor(job.status) }]}>
          <Text style={styles.jobStatusText}>{job.status}</Text>
        </View>
      </View>
      
      <Text style={styles.jobDescription}>{job.description}</Text>
      
      <View style={styles.jobDetails}>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>Line:</Text>
          <Text style={styles.jobDetailValue}>{job.lineName}</Text>
        </View>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>Product:</Text>
          <Text style={styles.jobDetailValue}>{job.productName}</Text>
        </View>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>Quantity:</Text>
          <Text style={styles.jobDetailValue}>{job.targetQuantity}</Text>
        </View>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>Start:</Text>
          <Text style={styles.jobDetailValue}>{formatDateTime(job.scheduledStart)}</Text>
        </View>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>End:</Text>
          <Text style={styles.jobDetailValue}>{formatDateTime(job.scheduledEnd)}</Text>
        </View>
        <View style={styles.jobDetailRow}>
          <Text style={styles.jobDetailLabel}>Assigned:</Text>
          <Text style={styles.jobDetailValue}>{job.assignedTo}</Text>
        </View>
      </View>
      
      {job.status === 'In Progress' && (
        <ProgressBar
          value={job.progress}
          maxValue={100}
          label="Progress"
          color="#2196F3"
          showValue
          showPercentage
        />
      )}
    </TouchableOpacity>
  );

  if (!canManageSchedule) {
    return (
      <View style={styles.container}>
        <Text style={styles.unauthorizedText}>
          You don't have permission to view this screen.
        </Text>
      </View>
    );
  }

  if (isLoading && !refreshing) {
    return <LoadingSpinner />;
  }

  if (!schedule) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Failed to load schedule details</Text>
        <Button title="Retry" onPress={onRefresh} />
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl refreshing={refreshing} onRefresh={onRefresh} />
      }
    >
      {/* Offline Indicator */}
      <OfflineIndicator
        isOffline={!isOnline}
        pendingSyncCount={0}
        showPendingCount={false}
      />

      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{schedule.title}</Text>
        <View style={styles.headerDetails}>
          <View style={[styles.statusBadge, { backgroundColor: getStatusColor(schedule.status) }]}>
            <Text style={styles.statusText}>{schedule.status}</Text>
          </View>
          <Text style={styles.createdBy}>Created by {schedule.createdBy}</Text>
        </View>
        <Text style={styles.description}>{schedule.description}</Text>
      </View>

      {/* Schedule Information */}
      <Card style={styles.infoCard}>
        <Text style={styles.sectionTitle}>Schedule Information</Text>
        
        <View style={styles.infoGrid}>
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Start Date:</Text>
            <Text style={styles.infoValue}>{formatDateTime(schedule.startDate)}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>End Date:</Text>
            <Text style={styles.infoValue}>{formatDateTime(schedule.endDate)}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Duration:</Text>
            <Text style={styles.infoValue}>
              {formatDuration(new Date(schedule.startDate), new Date(schedule.endDate))}
            </Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Time Remaining:</Text>
            <Text style={[styles.infoValue, getTimeRemaining() === 'Overdue' && styles.overdueText]}>
              {getTimeRemaining() || 'N/A'}
            </Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Created:</Text>
            <Text style={styles.infoValue}>{formatDateTime(schedule.createdAt)}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Last Updated:</Text>
            <Text style={styles.infoValue}>{formatDateTime(schedule.updatedAt)}</Text>
          </View>
        </View>
      </Card>

      {/* Schedule Metrics */}
      <Card style={styles.metricsCard}>
        <Text style={styles.sectionTitle}>Schedule Metrics</Text>
        
        <View style={styles.metricsGrid}>
          <MetricCard
            title="Total Jobs"
            value={schedule.metrics.totalJobs}
            color="#2196F3"
          />
          <MetricCard
            title="Completed"
            value={schedule.metrics.completedJobs}
            color="#4CAF50"
          />
          <MetricCard
            title="In Progress"
            value={schedule.metrics.inProgressJobs}
            color="#FF9800"
          />
          <MetricCard
            title="Scheduled"
            value={schedule.metrics.scheduledJobs}
            color="#9C27B0"
          />
        </View>

        <ProgressBar
          value={schedule.metrics.overallProgress}
          maxValue={100}
          label="Overall Progress"
          color="#2196F3"
          showValue
          showPercentage
        />

        <View style={styles.completionInfo}>
          <Text style={styles.completionLabel}>Estimated Completion:</Text>
          <Text style={styles.completionValue}>
            {formatDateTime(schedule.metrics.estimatedCompletion)}
          </Text>
        </View>
      </Card>

      {/* Resource Utilization */}
      <Card style={styles.resourcesCard}>
        <Text style={styles.sectionTitle}>Resource Utilization</Text>
        
        <Text style={styles.resourceSubtitle}>Production Lines</Text>
        {schedule.resources.lines.map((line) => (
          <View key={line.id} style={styles.resourceItem}>
            <Text style={styles.resourceName}>{line.name}</Text>
            <ProgressBar
              value={line.utilization}
              maxValue={100}
              label={`${Math.round(line.utilization)}%`}
              color={line.utilization >= 80 ? '#4CAF50' : line.utilization >= 60 ? '#FF9800' : '#F44336'}
              showValue
              showPercentage
            />
          </View>
        ))}
        
        <Text style={styles.resourceSubtitle}>Operators</Text>
        {schedule.resources.operators.map((operator) => (
          <View key={operator.id} style={styles.resourceItem}>
            <Text style={styles.resourceName}>{operator.name} ({operator.role})</Text>
            <ProgressBar
              value={operator.utilization}
              maxValue={100}
              label={`${Math.round(operator.utilization)}%`}
              color={operator.utilization >= 80 ? '#4CAF50' : operator.utilization >= 60 ? '#FF9800' : '#F44336'}
              showValue
              showPercentage
            />
          </View>
        ))}
      </Card>

      {/* Jobs List */}
      <Card style={styles.jobsCard}>
        <Text style={styles.sectionTitle}>Jobs ({schedule.jobs.length})</Text>
        
        {schedule.jobs.length > 0 ? (
          <View style={styles.jobsList}>
            {schedule.jobs.map(renderJobItem)}
          </View>
        ) : (
          <Text style={styles.emptyText}>No jobs assigned to this schedule</Text>
        )}
      </Card>

      {/* Action Buttons */}
      {canManageSchedule && (
        <View style={styles.actionsContainer}>
          {schedule.status === 'Draft' && (
            <Button
              title="Activate Schedule"
              onPress={() => handleStatusUpdate('Active')}
              variant="success"
              style={styles.actionButton}
            />
          )}
          
          {schedule.status === 'Active' && (
            <Button
              title="Complete Schedule"
              onPress={() => handleStatusUpdate('Completed')}
              variant="primary"
              style={styles.actionButton}
            />
          )}
          
          {(schedule.status === 'Draft' || schedule.status === 'Active') && (
            <Button
              title="Cancel Schedule"
              onPress={() => handleStatusUpdate('Cancelled')}
              variant="danger"
              style={styles.actionButton}
            />
          )}
        </View>
      )}
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
    marginBottom: 8,
  },
  headerDetails: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  createdBy: {
    fontSize: 14,
    color: '#757575',
  },
  description: {
    fontSize: 16,
    color: '#757575',
    lineHeight: 24,
  },
  unauthorizedText: {
    fontSize: 16,
    color: '#757575',
    textAlign: 'center',
    marginTop: 50,
  },
  errorText: {
    fontSize: 16,
    color: '#F44336',
    textAlign: 'center',
    marginTop: 50,
  },
  infoCard: {
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
  infoGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  infoItem: {
    width: '50%',
    marginBottom: 12,
  },
  infoLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  infoValue: {
    fontSize: 14,
    color: '#212121',
    marginTop: 2,
  },
  overdueText: {
    color: '#F44336',
    fontWeight: 'bold',
  },
  metricsCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  completionInfo: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#F0F0F0',
  },
  completionLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  completionValue: {
    fontSize: 14,
    color: '#212121',
    fontWeight: '500',
  },
  resourcesCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  resourceSubtitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    marginTop: 16,
    marginBottom: 8,
  },
  resourceItem: {
    marginBottom: 12,
  },
  resourceName: {
    fontSize: 14,
    color: '#212121',
    marginBottom: 4,
  },
  jobsCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  jobsList: {
    marginTop: 8,
  },
  jobItem: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    marginBottom: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  jobHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  jobTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
    flex: 1,
  },
  jobStatusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 8,
  },
  jobStatusText: {
    fontSize: 10,
    color: '#FFFFFF',
    fontWeight: '600',
  },
  jobDescription: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 12,
  },
  jobDetails: {
    marginBottom: 12,
  },
  jobDetailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  jobDetailLabel: {
    fontSize: 12,
    color: '#757575',
    fontWeight: '500',
  },
  jobDetailValue: {
    fontSize: 12,
    color: '#212121',
  },
  actionsContainer: {
    padding: 16,
  },
  actionButton: {
    marginVertical: 4,
  },
  emptyText: {
    fontSize: 16,
    color: '#9E9E9E',
    textAlign: 'center',
    marginTop: 20,
  },
});

export default ScheduleDetailsScreen;
