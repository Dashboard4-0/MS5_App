/**
 * MS5.0 Floor Dashboard - Job Details Screen
 * 
 * This screen displays detailed information about a specific job
 * including production data, checklist items, and job actions.
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
import { selectUser } from '../../store/slices/authSlice';
import { fetchJobDetails, updateJobStatus } from '../../store/slices/jobsSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar, MetricCard } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator } from '../../components/common/RealTimeIndicators';
import { formatDateTime, formatDuration } from '../../utils/formatters';
import { JobStatus } from '../../config/constants';

// Types
interface JobDetailsProps {
  route: {
    params: {
      jobId: string;
    };
  };
  navigation: any;
}

interface JobDetails {
  id: string;
  title: string;
  description: string;
  line_name: string;
  product_name: string;
  target_quantity: number;
  current_quantity: number;
  scheduled_start: string;
  scheduled_end: string;
  actual_start?: string;
  actual_end?: string;
  status: JobStatus;
  priority: number;
  oee_target: number;
  current_oee: number;
  quality_target: number;
  current_quality: number;
  speed_target: number;
  current_speed: number;
  created_at: string;
  updated_at: string;
  assigned_to: string;
  checklist_items: ChecklistItem[];
  notes: string;
}

interface ChecklistItem {
  id: string;
  title: string;
  description: string;
  completed: boolean;
  completed_at?: string;
  completed_by?: string;
}

const JobDetailsScreen: React.FC<JobDetailsProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector(selectUser);
  const { jobDetails, isLoading, error } = useSelector((state: RootState) => state.jobs);
  
  const [refreshing, setRefreshing] = useState(false);
  const [job, setJob] = useState<JobDetails | null>(null);

  const { jobId } = route.params;

  useEffect(() => {
    loadJobDetails();
  }, [jobId]);

  const loadJobDetails = async () => {
    try {
      const result = await dispatch(fetchJobDetails(jobId)).unwrap();
      setJob(result);
    } catch (error) {
      console.error('Failed to load job details:', error);
      Alert.alert('Error', 'Failed to load job details');
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadJobDetails();
    setRefreshing(false);
  };

  const handleStatusUpdate = async (newStatus: JobStatus) => {
    try {
      await dispatch(updateJobStatus({ jobId, status: newStatus })).unwrap();
      Alert.alert('Success', `Job status updated to ${newStatus}`);
      await loadJobDetails();
    } catch (error) {
      Alert.alert('Error', 'Failed to update job status');
    }
  };

  const getStatusColor = (status: JobStatus): string => {
    switch (status) {
      case JobStatus.ASSIGNED:
        return '#FF9800';
      case JobStatus.ACCEPTED:
        return '#2196F3';
      case JobStatus.IN_PROGRESS:
        return '#4CAF50';
      case JobStatus.COMPLETED:
        return '#9E9E9E';
      case JobStatus.CANCELLED:
        return '#F44336';
      default:
        return '#757575';
    }
  };

  const getStatusText = (status: JobStatus): string => {
    switch (status) {
      case JobStatus.ASSIGNED:
        return 'Assigned';
      case JobStatus.ACCEPTED:
        return 'Accepted';
      case JobStatus.IN_PROGRESS:
        return 'In Progress';
      case JobStatus.COMPLETED:
        return 'Completed';
      case JobStatus.CANCELLED:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  };

  const getActionButtons = () => {
    if (!job) return null;

    switch (job.status) {
      case JobStatus.ASSIGNED:
        return (
          <Button
            title="Accept Job"
            onPress={() => handleStatusUpdate(JobStatus.ACCEPTED)}
            variant="primary"
            style={styles.actionButton}
          />
        );
      case JobStatus.ACCEPTED:
        return (
          <Button
            title="Start Job"
            onPress={() => handleStatusUpdate(JobStatus.IN_PROGRESS)}
            variant="success"
            style={styles.actionButton}
          />
        );
      case JobStatus.IN_PROGRESS:
        return (
          <View style={styles.actionButtonsContainer}>
            <Button
              title="Complete Job"
              onPress={() => handleStatusUpdate(JobStatus.COMPLETED)}
              variant="primary"
              style={styles.actionButton}
            />
            <Button
              title="Pause Job"
              onPress={() => Alert.alert('Pause', 'Pause functionality coming soon')}
              variant="outline"
              style={styles.actionButton}
            />
          </View>
        );
      default:
        return null;
    }
  };

  const getProgressPercentage = () => {
    if (!job) return 0;
    return Math.min((job.current_quantity / job.target_quantity) * 100, 100);
  };

  const getTimeRemaining = () => {
    if (!job || !job.actual_start) return null;
    
    const startTime = new Date(job.actual_start);
    const endTime = new Date(job.scheduled_end);
    const now = new Date();
    
    if (now > endTime) return 'Overdue';
    
    const remaining = endTime.getTime() - now.getTime();
    const hours = Math.floor(remaining / (1000 * 60 * 60));
    const minutes = Math.floor((remaining % (1000 * 60 * 60)) / (1000 * 60));
    
    return `${hours}h ${minutes}m`;
  };

  if (isLoading && !refreshing) {
    return <LoadingSpinner />;
  }

  if (!job) {
    return (
      <View style={styles.container}>
        <Text style={styles.errorText}>Job not found</Text>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.container}
      refreshControl={
        <RefreshControl
          refreshing={refreshing}
          onRefresh={handleRefresh}
          colors={['#2196F3']}
          tintColor="#2196F3"
        />
      }
    >
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{job.title}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor(job.status) }]}>
          <Text style={styles.statusText}>{getStatusText(job.status)}</Text>
        </View>
      </View>

      {/* Job Description */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Description</Text>
        <Text style={styles.description}>{job.description}</Text>
      </Card>

      {/* Production Metrics */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Production Metrics</Text>
        
        <View style={styles.metricsGrid}>
          <MetricCard
            title="Progress"
            value={`${job.current_quantity}/${job.target_quantity}`}
            unit="units"
            color="#2196F3"
          />
          
          <MetricCard
            title="OEE"
            value={`${Math.round(job.current_oee * 100)}%`}
            trend={job.current_oee >= job.oee_target ? 'up' : 'down'}
            trendValue={`Target: ${Math.round(job.oee_target * 100)}%`}
            color="#4CAF50"
          />
          
          <MetricCard
            title="Quality"
            value={`${Math.round(job.current_quality * 100)}%`}
            trend={job.current_quality >= job.quality_target ? 'up' : 'down'}
            trendValue={`Target: ${Math.round(job.quality_target * 100)}%`}
            color="#FF9800"
          />
          
          <MetricCard
            title="Speed"
            value={job.current_speed}
            unit="units/min"
            trend={job.current_speed >= job.speed_target ? 'up' : 'down'}
            trendValue={`Target: ${job.speed_target}`}
            color="#9C27B0"
          />
        </View>

        {/* Progress Bar */}
        <ProgressBar
          value={job.current_quantity}
          maxValue={job.target_quantity}
          label="Production Progress"
          color="#2196F3"
          showValue
          showPercentage
        />
      </Card>

      {/* OEE Gauge */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Overall Equipment Effectiveness</Text>
        <View style={styles.gaugeContainer}>
          <CircularGauge
            value={job.current_oee * 100}
            maxValue={100}
            size={150}
            color={job.current_oee >= job.oee_target ? '#4CAF50' : '#FF9800'}
            label="Current OEE"
            showValue
            showPercentage
          />
        </View>
      </Card>

      {/* Job Information */}
      <Card style={styles.sectionCard}>
        <Text style={styles.sectionTitle}>Job Information</Text>
        
        <View style={styles.infoGrid}>
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Line:</Text>
            <Text style={styles.infoValue}>{job.line_name}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Product:</Text>
            <Text style={styles.infoValue}>{job.product_name}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Priority:</Text>
            <Text style={styles.infoValue}>Level {job.priority}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Assigned To:</Text>
            <Text style={styles.infoValue}>{job.assigned_to}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Scheduled Start:</Text>
            <Text style={styles.infoValue}>{formatDateTime(job.scheduled_start)}</Text>
          </View>
          
          <View style={styles.infoItem}>
            <Text style={styles.infoLabel}>Scheduled End:</Text>
            <Text style={styles.infoValue}>{formatDateTime(job.scheduled_end)}</Text>
          </View>
          
          {job.actual_start && (
            <View style={styles.infoItem}>
              <Text style={styles.infoLabel}>Actual Start:</Text>
              <Text style={styles.infoValue}>{formatDateTime(job.actual_start)}</Text>
            </View>
          )}
          
          {job.actual_end && (
            <View style={styles.infoItem}>
              <Text style={styles.infoLabel}>Actual End:</Text>
              <Text style={styles.infoValue}>{formatDateTime(job.actual_end)}</Text>
            </View>
          )}
          
          {getTimeRemaining() && (
            <View style={styles.infoItem}>
              <Text style={styles.infoLabel}>Time Remaining:</Text>
              <Text style={[styles.infoValue, getTimeRemaining() === 'Overdue' && styles.overdueText]}>
                {getTimeRemaining()}
              </Text>
            </View>
          )}
        </View>
      </Card>

      {/* Checklist Items */}
      {job.checklist_items && job.checklist_items.length > 0 && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Pre-start Checklist</Text>
          
          {job.checklist_items.map((item, index) => (
            <View key={item.id} style={styles.checklistItem}>
              <View style={styles.checklistItemContent}>
                <Text style={styles.checklistItemTitle}>{item.title}</Text>
                <Text style={styles.checklistItemDescription}>{item.description}</Text>
                {item.completed && item.completed_at && (
                  <Text style={styles.checklistItemCompleted}>
                    Completed by {item.completed_by} at {formatDateTime(item.completed_at)}
                  </Text>
                )}
              </View>
              
              <View style={styles.checklistItemStatus}>
                <StatusIndicator
                  status={item.completed ? 'online' : 'offline'}
                  size="small"
                />
              </View>
            </View>
          ))}
        </Card>
      )}

      {/* Notes */}
      {job.notes && (
        <Card style={styles.sectionCard}>
          <Text style={styles.sectionTitle}>Notes</Text>
          <Text style={styles.notes}>{job.notes}</Text>
        </Card>
      )}

      {/* Action Buttons */}
      {getActionButtons() && (
        <View style={styles.actionsContainer}>
          {getActionButtons()}
        </View>
      )}

      {/* Live Data Indicator */}
      <View style={styles.liveIndicatorContainer}>
        <LiveDataIndicator isLive={job.status === JobStatus.IN_PROGRESS} />
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
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212121',
    flex: 1,
  },
  statusBadge: {
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 16,
  },
  statusText: {
    fontSize: 12,
    color: '#FFFFFF',
    fontWeight: '600',
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
    marginBottom: 12,
  },
  description: {
    fontSize: 16,
    color: '#757575',
    lineHeight: 24,
  },
  metricsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    justifyContent: 'space-between',
  },
  gaugeContainer: {
    alignItems: 'center',
    paddingVertical: 20,
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
  checklistItem: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
  },
  checklistItemContent: {
    flex: 1,
  },
  checklistItemTitle: {
    fontSize: 16,
    fontWeight: '500',
    color: '#212121',
  },
  checklistItemDescription: {
    fontSize: 14,
    color: '#757575',
    marginTop: 2,
  },
  checklistItemCompleted: {
    fontSize: 12,
    color: '#4CAF50',
    marginTop: 4,
  },
  checklistItemStatus: {
    marginLeft: 12,
  },
  notes: {
    fontSize: 16,
    color: '#757575',
    lineHeight: 24,
  },
  actionsContainer: {
    padding: 16,
  },
  actionButtonsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  actionButton: {
    marginVertical: 4,
  },
  liveIndicatorContainer: {
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

export default JobDetailsScreen;
