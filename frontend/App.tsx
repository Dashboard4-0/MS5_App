/**
 * MS5.0 Floor Dashboard - Main App Component
 * 
 * This is the main entry point for the React Native application.
 * It sets up the Redux store, navigation, and global providers.
 */

import React, { useEffect } from 'react';
import { StatusBar, Platform } from 'react-native';
import { Provider } from 'react-redux';
import { PersistGate } from 'redux-persist/integration/react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { store, persistor } from './src/store';
import AppNavigator from './src/navigation/AppNavigator';
import { logger } from './src/utils/logger';

const App: React.FC = () => {
  useEffect(() => {
    // Initialize app
    logger.info('App started', { platform: Platform.OS });
    
    // Set up global error handling
    const originalConsoleError = console.error;
    console.error = (...args) => {
      logger.error('Console Error', { args });
      originalConsoleError(...args);
    };

    // Set up unhandled promise rejection handling
    const handleUnhandledRejection = (event: any) => {
      logger.error('Unhandled Promise Rejection', { reason: event.reason });
    };

    // Add event listeners
    if (Platform.OS === 'web') {
      window.addEventListener('unhandledrejection', handleUnhandledRejection);
    }

    // Cleanup
    return () => {
      if (Platform.OS === 'web') {
        window.removeEventListener('unhandledrejection', handleUnhandledRejection);
      }
    };
  }, []);

  return (
    <Provider store={store}>
      <PersistGate loading={null} persistor={persistor}>
        <SafeAreaProvider>
          <GestureHandlerRootView style={{ flex: 1 }}>
            <StatusBar
              barStyle="dark-content"
              backgroundColor="#FFFFFF"
              translucent={false}
            />
            <AppNavigator />
          </GestureHandlerRootView>
        </SafeAreaProvider>
      </PersistGate>
    </Provider>
  );
};

export default App;
