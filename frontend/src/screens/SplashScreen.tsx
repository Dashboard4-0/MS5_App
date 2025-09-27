/**
 * MS5.0 Floor Dashboard - Splash Screen
 * 
 * This screen is displayed while the app is initializing
 * and checking authentication status.
 */

import React, { useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  ActivityIndicator,
  Image,
} from 'react-native';

const SplashScreen: React.FC = () => {
  useEffect(() => {
    // TODO: Add app initialization logic
    // - Check for stored authentication tokens
    // - Validate token expiry
    // - Initialize offline data sync
    // - Set up push notifications
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        {/* App Logo */}
        <View style={styles.logoContainer}>
          <View style={styles.logo}>
            <Text style={styles.logoText}>MS5.0</Text>
          </View>
        </View>

        {/* App Title */}
        <Text style={styles.title}>Floor Dashboard</Text>
        <Text style={styles.subtitle}>Factory Management System</Text>

        {/* Loading Indicator */}
        <View style={styles.loadingContainer}>
          <ActivityIndicator size="large" color="#2196F3" />
          <Text style={styles.loadingText}>Initializing...</Text>
        </View>
      </View>

      {/* Footer */}
      <View style={styles.footer}>
        <Text style={styles.footerText}>MS5.0 Floor Dashboard v1.0.0</Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#2196F3',
    justifyContent: 'center',
    alignItems: 'center',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingHorizontal: 40,
  },
  logoContainer: {
    marginBottom: 40,
  },
  logo: {
    width: 120,
    height: 120,
    borderRadius: 60,
    backgroundColor: '#FFFFFF',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  logoText: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#2196F3',
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#FFFFFF',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 18,
    color: '#E3F2FD',
    marginBottom: 60,
    textAlign: 'center',
  },
  loadingContainer: {
    alignItems: 'center',
  },
  loadingText: {
    fontSize: 16,
    color: '#E3F2FD',
    marginTop: 16,
  },
  footer: {
    paddingBottom: 40,
  },
  footerText: {
    fontSize: 14,
    color: '#E3F2FD',
    textAlign: 'center',
  },
});

export default SplashScreen;
