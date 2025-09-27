/**
 * MS5.0 Floor Dashboard - My Jobs Screen
 * 
 * This screen displays the operator's assigned jobs with status filtering
 * and job management actions.
 */

import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  RefreshControl,
  TouchableOpacity,
  Alert,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { selectUser } from '../../store/slices/authSlice';
import { fetchMyJobs, acceptJob, startJob, completeJob } from '../../store/slices/jobsSlice';
import { JobStatus } from '../../config/constants';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { formatDateTime } from '../../utils/formatters';

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
  status: JobStatus;
  priority: number;
  created_at: string;
}

const MyJobsScreen: React.FC = () => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector(selectUser);
  const { jobs, isLoading, error } = useSelector((state: RootState) => state.jobs);
  
  const [selectedStatus, setSelectedStatus] = useState<JobStatus | 'all'>('all');
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadJobs();
  }, []);

  const loadJobs = async () => {
    try {
      await dispatch(fetchMyJobs()).unwrap();
    } catch (error) {
      console.error('Failed to load jobs:', error);
    }
  };

  const handleRefresh = async () => {
    setRefreshing(true);
    await loadJobs();
    setRefreshing(false);
  };

  const handleAcceptJob = async (jobId: string) => {
    try {
      await dispatch(acceptJob(jobId)).unwrap();
      Alert.alert('Success', 'Job accepted successfully');
    } catch (error) {
      Alert.alert('Error', 'Failed to accept job');
    }
  };

  const handleStartJob = async (jobId: string) => {
    try {
      await dispatch(startJob(jobId)).unwrap();
      Alert.alert('Success', 'Job started successfully');
    } catch (error) {
      Alert.alert('Error', 'Failed to start job');
    }
  };

  const handleCompleteJob = async (jobId: string) => {
    try {
      await dispatch(completeJob(jobId)).unwrap();
      Alert.alert('Success', 'Job completed successfully');
    } catch (error) {
      Alert.alert('Error', 'Failed to complete job');
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

  const getActionButton = (job: Job) => {
    switch (job.status) {
      case JobStatus.ASSIGNED:
        return (
          <Button
            title="Accept Job"
            onPress={() => handleAcceptJob(job.id)}
            variant="primary"
            size="small"
          />
        );
      case JobStatus.ACCEPTED:
        return (
          <Button
            title="Start Job"
            onPress={() => handleStartJob(job.id)}
            variant="success"
            size="small"
          />
        );
      case JobStatus.IN_PROGRESS:
        return (
          <Button
            title="Complete Job"
            onPress={() => handleCompleteJob(job.id)}
            variant="primary"
            size="small"
          />
        );
      default:
        return null;
    }
  };

  const filteredJobs = jobs.filter(job => 
    selectedStatus === 'all' || job.status === selectedStatus
  );

  const renderJobItem = ({ item: job }: { item: Job }) => (
    <Card
      style={styles.jobCard}
      onPress={() => {
        // TODO: Navigate to job details
      }}
    >
      <View style={styles.jobHeader}>
        <Text style={styles.jobTitle}>{job.title}</Text>
        <View style={[styles.statusBadge, { backgroundColor: getStatusColor(job.status) }]}>
          <Text style={styles.statusText}>{getStatusText(job.status)}</Text>
        </View>
      </View>
      
      <Text style={styles.jobDescription}>{job.description}</Text>
      
      <View style={styles.jobDetails}>
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
          <Text style={styles.detailValue}>{job.target_quantity}</Text>
        </View>
        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>Start Time:</Text>
          <Text style={styles.detailValue}>{formatDateTime(job.scheduled_start)}</Text>
        </View>
      </View>
      
      {getActionButton(job) && (
        <View style={styles.actionContainer}>
          {getActionButton(job)}
        </View>
      )}
    </Card>
  );

  const renderStatusFilter = () => (
    <View style={styles.filterContainer}>
      <TouchableOpacity
        style={[
          styles.filterButton,
          selectedStatus === 'all' && styles.filterButtonActive
        ]}
        onPress={() => setSelectedStatus('all')}
      >
        <Text style={[
          styles.filterButtonText,
          selectedStatus === 'all' && styles.filterButtonTextActive
        ]}>
          All
        </Text>
      </TouchableOpacity>
      
      {Object.values(JobStatus).map(status => (
        <TouchableOpacity
          key={status}
          style={[
            styles.filterButton,
            selectedStatus === status && styles.filterButtonActive
          ]}
          onPress={() => setSelectedStatus(status)}
        >
          <Text style={[
            styles.filterButtonText,
            selectedStatus === status && styles.filterButtonTextActive
          ]}>
            {getStatusText(status)}
          </Text>
        </TouchableOpacity>
      ))}
    </View>
  );

  if (isLoading && !refreshing) {
    return <LoadingSpinner />;
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>My Jobs</Text>
        <Text style={styles.headerSubtitle}>
          Welcome back, {user?.first_name || user?.username}
        </Text>
      </View>
      
      {renderStatusFilter()}
      
      <FlatList
        data={filteredJobs}
        renderItem={renderJobItem}
        keyExtractor={(item) => item.id}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={handleRefresh}
            colors={['#2196F3']}
            tintColor="#2196F3"
          />
        }
        contentContainerStyle={styles.listContainer}
        showsVerticalScrollIndicator={false}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyText}>No jobs found</Text>
            <Text style={styles.emptySubtext}>
              {selectedStatus === 'all' 
                ? 'You have no assigned jobs'
                : `No jobs with status: ${getStatusText(selectedStatus as JobStatus)}`
              }
            </Text>
          </View>
        }
      />
    </View>
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
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 4,
  },
  headerSubtitle: {
    fontSize: 16,
    color: '#757575',
  },
  filterContainer: {
    flexDirection: 'row',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#FFFFFF',
    borderBottomWidth: 1,
    borderBottomColor: '#E0E0E0',
  },
  filterButton: {
    paddingHorizontal: 16,
    paddingVertical: 8,
    marginRight: 8,
    borderRadius: 20,
    backgroundColor: '#F5F5F5',
  },
  filterButtonActive: {
    backgroundColor: '#2196F3',
  },
  filterButtonText: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  filterButtonTextActive: {
    color: '#FFFFFF',
  },
  listContainer: {
    padding: 16,
  },
  jobCard: {
    marginBottom: 16,
    padding: 16,
  },
  jobHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  jobTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    flex: 1,
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
  jobDescription: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 12,
  },
  jobDetails: {
    marginBottom: 12,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  detailLabel: {
    fontSize: 14,
    color: '#757575',
    fontWeight: '500',
  },
  detailValue: {
    fontSize: 14,
    color: '#212121',
  },
  actionContainer: {
    alignItems: 'flex-end',
  },
  emptyContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    fontSize: 18,
    color: '#757575',
    fontWeight: '500',
    marginBottom: 8,
  },
  emptySubtext: {
    fontSize: 14,
    color: '#9E9E9E',
    textAlign: 'center',
  },
});

export default MyJobsScreen;
