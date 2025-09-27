/**
 * MS5.0 Floor Dashboard - Offline Screen
 * 
 * This screen is displayed when the app is offline
 * and provides information about offline capabilities.
 */

import React from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
} from 'react-native';
import Button from '../components/common/Button';
import Card from '../components/common/Card';

const OfflineScreen: React.FC = () => {
  const handleRetry = () => {
    // TODO: Implement retry connection logic
    console.log('Retry connection');
  };

  const handleOfflineMode = () => {
    // TODO: Navigate to offline mode
    console.log('Continue in offline mode');
  };

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        {/* Offline Icon */}
        <View style={styles.iconContainer}>
          <View style={styles.icon}>
            <Text style={styles.iconText}>📡</Text>
          </View>
        </View>

        {/* Title and Message */}
        <Text style={styles.title}>No Internet Connection</Text>
        <Text style={styles.message}>
          You're currently offline. Some features may not be available.
        </Text>

        {/* Offline Features */}
        <Card style={styles.featuresCard}>
          <Text style={styles.featuresTitle}>Available Offline:</Text>
          <View style={styles.featuresList}>
            <Text style={styles.featureItem}>• View cached data</Text>
            <Text style={styles.featureItem}>• Complete checklists</Text>
            <Text style={styles.featureItem}>• View job assignments</Text>
            <Text style={styles.featureItem}>• Access saved reports</Text>
          </View>
        </Card>

        {/* Action Buttons */}
        <View style={styles.buttonsContainer}>
          <Button
            title="Retry Connection"
            onPress={handleRetry}
            style={styles.retryButton}
          />
          
          <Button
            title="Continue Offline"
            onPress={handleOfflineMode}
            style={styles.offlineButton}
            variant="outline"
          />
        </View>
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>
          Data will sync automatically when connection is restored
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    maxWidth: 400,
    width: '100%',
  },
  iconContainer: {
    marginBottom: 30,
  },
  icon: {
    width: 80,
    height: 80,
    borderRadius: 40,
    backgroundColor: '#FF9800',
    justifyContent: 'center',
    alignItems: 'center',
  },
  iconText: {
    fontSize: 40,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
    textAlign: 'center',
  },
  message: {
    fontSize: 16,
    color: '#666',
    marginBottom: 30,
    textAlign: 'center',
    lineHeight: 24,
  },
  featuresCard: {
    width: '100%',
    padding: 20,
    marginBottom: 30,
  },
  featuresTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 12,
  },
  featuresList: {
    paddingLeft: 8,
  },
  featureItem: {
    fontSize: 16,
    color: '#666',
    marginBottom: 8,
    lineHeight: 24,
  },
  buttonsContainer: {
    width: '100%',
    gap: 12,
  },
  retryButton: {
    marginBottom: 8,
  },
  offlineButton: {
    marginBottom: 8,
  },
  footer: {
    paddingBottom: 20,
  },
  footerText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    fontStyle: 'italic',
  },
});

export default OfflineScreen;
