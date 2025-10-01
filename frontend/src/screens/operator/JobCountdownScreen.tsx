/**
 * MS5.0 Floor Dashboard - Job Countdown Screen
 * 
 * This screen displays a countdown timer for job start/end times
 * with real-time updates and production monitoring.
 */

import React, { useState, useEffect, useRef } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Animated,
} from 'react-native';
import { useSelector, useDispatch } from 'react-redux';
import { RootState, AppDispatch } from '../../store';
import { selectUser } from '../../store/slices/authSlice';
import { fetchJobDetails, updateJobStatus } from '../../store/slices/jobsSlice';
import Card from '../../components/common/Card';
import Button from '../../components/common/Button';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { CircularGauge, ProgressBar } from '../../components/common/DataVisualization';
import { StatusIndicator, LiveDataIndicator } from '../../components/common/RealTimeIndicators';
import { formatDateTime, formatDuration } from '../../utils/formatters';
import { JobStatus } from '../../config/constants';

// Types
interface JobCountdownProps {
  route: {
    params: {
      jobId: string;
    };
  };
  navigation: any;
}

interface CountdownState {
  days: number;
  hours: number;
  minutes: number;
  seconds: number;
  total: number;
}

interface JobDetails {
  id: string;
  title: string;
  line_name: string;
  product_name: string;
  target_quantity: number;
  current_quantity: number;
  scheduled_start: string;
  scheduled_end: string;
  actual_start?: string;
  actual_end?: string;
  status: JobStatus;
  current_speed: number;
  speed_target: number;
}

const JobCountdownScreen: React.FC<JobCountdownProps> = ({ route, navigation }) => {
  const dispatch = useDispatch<AppDispatch>();
  const user = useSelector(selectUser);
  const { jobDetails, isLoading } = useSelector((state: RootState) => state.jobs);
  
  const [job, setJob] = useState<JobDetails | null>(null);
  const [countdown, setCountdown] = useState<CountdownState>({
    days: 0,
    hours: 0,
    minutes: 0,
    seconds: 0,
    total: 0,
  });
  const [isActive, setIsActive] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  
  const intervalRef = useRef<NodeJS.Timeout | null>(null);
  const pulseAnim = useRef(new Animated.Value(1)).current;

  const { jobId } = route.params;

  useEffect(() => {
    loadJobDetails();
    
    // Start pulse animation
    const pulse = Animated.loop(
      Animated.sequence([
        Animated.timing(pulseAnim, {
          toValue: 1.1,
          duration: 1000,
          useNativeDriver: true,
        }),
        Animated.timing(pulseAnim, {
          toValue: 1,
          duration: 1000,
          useNativeDriver: true,
        }),
      ])
    );
    pulse.start();

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
      pulse.stop();
    };
  }, []);

  useEffect(() => {
    if (job) {
      startCountdown();
    }
  }, [job]);

  const loadJobDetails = async () => {
    try {
      const result = await dispatch(fetchJobDetails(jobId)).unwrap();
      setJob(result);
    } catch (error) {
      console.error('Failed to load job details:', error);
      Alert.alert('Error', 'Failed to load job details');
    }
  };

  const startCountdown = () => {
    if (!job) return;

    const targetTime = job.status === JobStatus.ACCEPTED 
      ? new Date(job.scheduled_start).getTime()
      : new Date(job.scheduled_end).getTime();

    const updateCountdown = () => {
      const now = new Date().getTime();
      const difference = targetTime - now;

      if (difference > 0) {
        const days = Math.floor(difference / (1000 * 60 * 60 * 24));
        const hours = Math.floor((difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60));
        const minutes = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60));
        const seconds = Math.floor((difference % (1000 * 60)) / 1000);

        setCountdown({
          days,
          hours,
          minutes,
          seconds,
          total: difference,
        });
        setIsActive(true);
      } else {
        setCountdown({
          days: 0,
          hours: 0,
          minutes: 0,
          seconds: 0,
          total: 0,
        });
        setIsActive(false);
        
        if (job.status === JobStatus.ACCEPTED) {
          Alert.alert(
            'Job Start Time',
            'The scheduled start time has been reached. You can now start the job.',
            [
              {
                text: 'Start Job',
                onPress: () => handleStartJob(),
              },
              {
                text: 'Cancel',
                style: 'cancel',
              },
            ]
          );
        } else if (job.status === JobStatus.IN_PROGRESS) {
          Alert.alert(
            'Job End Time',
            'The scheduled end time has been reached. You can complete the job.',
            [
              {
                text: 'Complete Job',
                onPress: () => handleCompleteJob(),
              },
              {
                text: 'Continue',
                style: 'cancel',
              },
            ]
          );
        }
      }
    };

    updateCountdown();
    intervalRef.current = setInterval(updateCountdown, 1000);
  };

  const handleStartJob = async () => {
    try {
      await dispatch(updateJobStatus({ jobId, status: JobStatus.IN_PROGRESS })).unwrap();
      Alert.alert('Success', 'Job started successfully');
      await loadJobDetails();
    } catch (error) {
      Alert.alert('Error', 'Failed to start job');
    }
  };

  const handleCompleteJob = async () => {
    try {
      await dispatch(updateJobStatus({ jobId, status: JobStatus.COMPLETED })).unwrap();
      Alert.alert('Success', 'Job completed successfully');
      navigation.goBack();
    } catch (error) {
      Alert.alert('Error', 'Failed to complete job');
    }
  };

  const handlePauseResume = () => {
    if (isPaused) {
      setIsPaused(false);
      startCountdown();
    } else {
      setIsPaused(true);
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }
    }
  };

  const getCountdownTitle = () => {
    if (!job) return '';
    
    switch (job.status) {
      case JobStatus.ACCEPTED:
        return 'Job Start Countdown';
      case JobStatus.IN_PROGRESS:
        return 'Job End Countdown';
      default:
        return 'Countdown';
    }
  };

  const getCountdownSubtitle = () => {
    if (!job) return '';
    
    switch (job.status) {
      case JobStatus.ACCEPTED:
        return `Job starts at ${formatDateTime(job.scheduled_start)}`;
      case JobStatus.IN_PROGRESS:
        return `Job ends at ${formatDateTime(job.scheduled_end)}`;
      default:
        return '';
    }
  };

  const getProgressPercentage = () => {
    if (!job) return 0;
    return Math.min((job.current_quantity / job.target_quantity) * 100, 100);
  };

  const getSpeedEfficiency = () => {
    if (!job) return 0;
    return Math.min((job.current_speed / job.speed_target) * 100, 100);
  };

  if (isLoading) {
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
    <View style={styles.container}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>{job.title}</Text>
        <Text style={styles.subtitle}>{job.line_name} - {job.product_name}</Text>
      </View>

      {/* Countdown Display */}
      <Card style={styles.countdownCard}>
        <Text style={styles.countdownTitle}>{getCountdownTitle()}</Text>
        <Text style={styles.countdownSubtitle}>{getCountdownSubtitle()}</Text>
        
        <Animated.View
          style={[
            styles.countdownContainer,
            { transform: [{ scale: pulseAnim }] },
          ]}
        >
          {countdown.days > 0 && (
            <View style={styles.timeUnit}>
              <Text style={styles.timeValue}>{countdown.days}</Text>
              <Text style={styles.timeLabel}>Days</Text>
            </View>
          )}
          
          <View style={styles.timeUnit}>
            <Text style={styles.timeValue}>{countdown.hours.toString().padStart(2, '0')}</Text>
            <Text style={styles.timeLabel}>Hours</Text>
          </View>
          
          <View style={styles.timeUnit}>
            <Text style={styles.timeValue}>{countdown.minutes.toString().padStart(2, '0')}</Text>
            <Text style={styles.timeLabel}>Minutes</Text>
          </View>
          
          <View style={styles.timeUnit}>
            <Text style={styles.timeValue}>{countdown.seconds.toString().padStart(2, '0')}</Text>
            <Text style={styles.timeLabel}>Seconds</Text>
          </View>
        </Animated.View>

        {/* Status Indicator */}
        <View style={styles.statusContainer}>
          <StatusIndicator
            status={isActive ? 'online' : 'offline'}
            label={isActive ? 'Active' : 'Inactive'}
            animated={isActive}
          />
        </View>
      </Card>

      {/* Production Progress */}
      <Card style={styles.progressCard}>
        <Text style={styles.sectionTitle}>Production Progress</Text>
        
        <View style={styles.progressContainer}>
          <CircularGauge
            value={getProgressPercentage()}
            maxValue={100}
            size={120}
            color="#2196F3"
            label="Progress"
            showValue
            showPercentage
          />
          
          <View style={styles.progressInfo}>
            <Text style={styles.progressText}>
              {job.current_quantity} / {job.target_quantity} units
            </Text>
            <Text style={styles.progressSubtext}>
              {Math.round(getProgressPercentage())}% complete
            </Text>
          </View>
        </View>

        <ProgressBar
          value={job.current_quantity}
          maxValue={job.target_quantity}
          label="Production Progress"
          color="#2196F3"
          showValue
          showPercentage
        />
      </Card>

      {/* Speed Monitoring */}
      <Card style={styles.speedCard}>
        <Text style={styles.sectionTitle}>Speed Monitoring</Text>
        
        <View style={styles.speedContainer}>
          <CircularGauge
            value={getSpeedEfficiency()}
            maxValue={100}
            size={100}
            color={getSpeedEfficiency() >= 100 ? '#4CAF50' : '#FF9800'}
            label="Speed Efficiency"
            showValue
            showPercentage
          />
          
          <View style={styles.speedInfo}>
            <Text style={styles.speedText}>
              {job.current_speed} / {job.speed_target} units/min
            </Text>
            <Text style={styles.speedSubtext}>
              {Math.round(getSpeedEfficiency())}% of target
            </Text>
          </View>
        </View>
      </Card>

      {/* Action Buttons */}
      <View style={styles.actionsContainer}>
        {job.status === JobStatus.ACCEPTED && (
          <Button
            title="Start Job Now"
            onPress={handleStartJob}
            variant="success"
            style={styles.actionButton}
          />
        )}
        
        {job.status === JobStatus.IN_PROGRESS && (
          <Button
            title="Complete Job"
            onPress={handleCompleteJob}
            variant="primary"
            style={styles.actionButton}
          />
        )}
        
        <Button
          title={isPaused ? 'Resume Countdown' : 'Pause Countdown'}
          onPress={handlePauseResume}
          variant="outline"
          style={styles.actionButton}
        />
      </View>

      {/* Live Data Indicator */}
      <View style={styles.liveIndicatorContainer}>
        <LiveDataIndicator isLive={isActive && !isPaused} />
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  header: {
    padding: 20,
    backgroundColor: '#FFFFFF',
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
  countdownCard: {
    margin: 16,
    padding: 20,
    alignItems: 'center',
  },
  countdownTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 4,
  },
  countdownSubtitle: {
    fontSize: 14,
    color: '#757575',
    marginBottom: 20,
    textAlign: 'center',
  },
  countdownContainer: {
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  timeUnit: {
    alignItems: 'center',
    marginHorizontal: 8,
  },
  timeValue: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#2196F3',
    minWidth: 60,
    textAlign: 'center',
  },
  timeLabel: {
    fontSize: 12,
    color: '#757575',
    marginTop: 4,
  },
  statusContainer: {
    marginTop: 10,
  },
  progressCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
    marginBottom: 16,
    textAlign: 'center',
  },
  progressContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 20,
  },
  progressInfo: {
    marginLeft: 20,
  },
  progressText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#212121',
  },
  progressSubtext: {
    fontSize: 14,
    color: '#757575',
    marginTop: 4,
  },
  speedCard: {
    margin: 16,
    marginTop: 8,
    padding: 16,
  },
  speedContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  speedInfo: {
    marginLeft: 20,
  },
  speedText: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#212121',
  },
  speedSubtext: {
    fontSize: 14,
    color: '#757575',
    marginTop: 4,
  },
  actionsContainer: {
    padding: 16,
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

export default JobCountdownScreen;
