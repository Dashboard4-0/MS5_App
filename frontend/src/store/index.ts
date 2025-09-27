/**
 * MS5.0 Floor Dashboard - Redux Store Configuration
 * 
 * This file configures the Redux store with all slices and middleware
 * for state management across the application.
 */

import { configureStore, combineReducers } from '@reduxjs/toolkit';
import { persistStore, persistReducer } from 'redux-persist';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER } from 'redux-persist';

// Import slices
import authSlice from './slices/authSlice';
import productionSlice from './slices/productionSlice';
import jobsSlice from './slices/jobsSlice';
import dashboardSlice from './slices/dashboardSlice';
import andonSlice from './slices/andonSlice';
import oeeSlice from './slices/oeeSlice';
import equipmentSlice from './slices/equipmentSlice';
import reportsSlice from './slices/reportsSlice';
import qualitySlice from './slices/qualitySlice';
import settingsSlice from './slices/settingsSlice';
import offlineSlice from './slices/offlineSlice';

// Persist configuration
const persistConfig = {
  key: 'root',
  storage: AsyncStorage,
  whitelist: ['auth', 'settings', 'offline'], // Only persist these slices
  blacklist: ['production', 'jobs', 'dashboard', 'andon', 'oee', 'equipment', 'reports', 'quality'], // Don't persist these
};

// Root reducer
const rootReducer = combineReducers({
  auth: authSlice,
  production: productionSlice,
  jobs: jobsSlice,
  dashboard: dashboardSlice,
  andon: andonSlice,
  oee: oeeSlice,
  equipment: equipmentSlice,
  reports: reportsSlice,
  quality: qualitySlice,
  settings: settingsSlice,
  offline: offlineSlice,
});

// Persisted reducer
const persistedReducer = persistReducer(persistConfig, rootReducer);

// Configure store
export const store = configureStore({
  reducer: persistedReducer,
  middleware: (getDefaultMiddleware) =>
    getDefaultMiddleware({
      serializableCheck: {
        ignoredActions: [FLUSH, REHYDRATE, PAUSE, PERSIST, PURGE, REGISTER],
      },
    }),
  devTools: __DEV__,
});

// Create persistor
export const persistor = persistStore(store);

// Export types
export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

// Export store and persistor
export default store;
