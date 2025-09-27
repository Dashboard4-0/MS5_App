/**
 * MS5.0 Floor Dashboard - Settings Redux Slice
 * 
 * This slice manages application settings including user preferences,
 * theme settings, notification preferences, and system configuration.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface UserPreferences {
  theme: 'light' | 'dark' | 'auto';
  language: string;
  timezone: string;
  dateFormat: string;
  timeFormat: '12h' | '24h';
  currency: string;
  units: 'metric' | 'imperial';
}

interface NotificationSettings {
  pushNotifications: boolean;
  emailNotifications: boolean;
  smsNotifications: boolean;
  andonAlerts: boolean;
  maintenanceAlerts: boolean;
  qualityAlerts: boolean;
  downtimeAlerts: boolean;
  reportAlerts: boolean;
  soundEnabled: boolean;
  vibrationEnabled: boolean;
}

interface DashboardSettings {
  defaultView: 'overview' | 'production' | 'oee' | 'andon' | 'quality';
  refreshInterval: number; // seconds
  autoRefresh: boolean;
  showCharts: boolean;
  chartType: 'line' | 'bar' | 'pie' | 'area';
  gridSize: 'small' | 'medium' | 'large';
  showTooltips: boolean;
  showLegends: boolean;
}

interface SystemSettings {
  apiEndpoint: string;
  websocketEndpoint: string;
  debugMode: boolean;
  logLevel: 'error' | 'warn' | 'info' | 'debug';
  cacheEnabled: boolean;
  cacheTimeout: number; // minutes
  offlineMode: boolean;
  syncInterval: number; // minutes
}

interface SettingsState {
  // User preferences
  userPreferences: UserPreferences;
  preferencesLoading: boolean;
  preferencesError: string | null;
  
  // Notification settings
  notificationSettings: NotificationSettings;
  notificationsLoading: boolean;
  notificationsError: string | null;
  
  // Dashboard settings
  dashboardSettings: DashboardSettings;
  dashboardLoading: boolean;
  dashboardError: string | null;
  
  // System settings
  systemSettings: SystemSettings;
  systemLoading: boolean;
  systemError: string | null;
  
  // UI State
  isInitialized: boolean;
  lastSync: string | null;
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
}

// Initial state
const initialState: SettingsState = {
  userPreferences: {
    theme: 'auto',
    language: 'en',
    timezone: 'UTC',
    dateFormat: 'YYYY-MM-DD',
    timeFormat: '24h',
    currency: 'USD',
    units: 'metric',
  },
  preferencesLoading: false,
  preferencesError: null,
  
  notificationSettings: {
    pushNotifications: true,
    emailNotifications: true,
    smsNotifications: false,
    andonAlerts: true,
    maintenanceAlerts: true,
    qualityAlerts: true,
    downtimeAlerts: true,
    reportAlerts: false,
    soundEnabled: true,
    vibrationEnabled: true,
  },
  notificationsLoading: false,
  notificationsError: null,
  
  dashboardSettings: {
    defaultView: 'overview',
    refreshInterval: 30,
    autoRefresh: true,
    showCharts: true,
    chartType: 'line',
    gridSize: 'medium',
    showTooltips: true,
    showLegends: true,
  },
  dashboardLoading: false,
  dashboardError: null,
  
  systemSettings: {
    apiEndpoint: process.env.REACT_APP_API_URL || 'http://localhost:8000',
    websocketEndpoint: process.env.REACT_APP_WS_URL || 'ws://localhost:8000/ws',
    debugMode: __DEV__,
    logLevel: 'info',
    cacheEnabled: true,
    cacheTimeout: 15,
    offlineMode: false,
    syncInterval: 5,
  },
  systemLoading: false,
  systemError: null,
  
  isInitialized: false,
  lastSync: null,
  
  actionLoading: false,
  actionError: null,
};

// Async thunks
export const fetchUserPreferences = createAsyncThunk(
  'settings/fetchUserPreferences',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.get('/api/v1/settings/preferences');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch user preferences');
    }
  }
);

export const updateUserPreferences = createAsyncThunk(
  'settings/updateUserPreferences',
  async (preferences: Partial<UserPreferences>, { rejectWithValue }) => {
    try {
      const response = await apiService.put('/api/v1/settings/preferences', preferences);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update user preferences');
    }
  }
);

export const fetchNotificationSettings = createAsyncThunk(
  'settings/fetchNotificationSettings',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.get('/api/v1/settings/notifications');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch notification settings');
    }
  }
);

export const updateNotificationSettings = createAsyncThunk(
  'settings/updateNotificationSettings',
  async (settings: Partial<NotificationSettings>, { rejectWithValue }) => {
    try {
      const response = await apiService.put('/api/v1/settings/notifications', settings);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update notification settings');
    }
  }
);

export const fetchDashboardSettings = createAsyncThunk(
  'settings/fetchDashboardSettings',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.get('/api/v1/settings/dashboard');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch dashboard settings');
    }
  }
);

export const updateDashboardSettings = createAsyncThunk(
  'settings/updateDashboardSettings',
  async (settings: Partial<DashboardSettings>, { rejectWithValue }) => {
    try {
      const response = await apiService.put('/api/v1/settings/dashboard', settings);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update dashboard settings');
    }
  }
);

export const fetchSystemSettings = createAsyncThunk(
  'settings/fetchSystemSettings',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.get('/api/v1/settings/system');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch system settings');
    }
  }
);

export const updateSystemSettings = createAsyncThunk(
  'settings/updateSystemSettings',
  async (settings: Partial<SystemSettings>, { rejectWithValue }) => {
    try {
      const response = await apiService.put('/api/v1/settings/system', settings);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update system settings');
    }
  }
);

export const resetSettings = createAsyncThunk(
  'settings/resetSettings',
  async (_, { rejectWithValue }) => {
    try {
      await apiService.post('/api/v1/settings/reset');
      return true;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to reset settings');
    }
  }
);

export const exportSettings = createAsyncThunk(
  'settings/exportSettings',
  async (_, { rejectWithValue }) => {
    try {
      const response = await apiService.get('/api/v1/settings/export');
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to export settings');
    }
  }
);

export const importSettings = createAsyncThunk(
  'settings/importSettings',
  async (settingsData: any, { rejectWithValue }) => {
    try {
      const response = await apiService.post('/api/v1/settings/import', settingsData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to import settings');
    }
  }
);

// Slice
const settingsSlice = createSlice({
  name: 'settings',
  initialState,
  reducers: {
    // Clear errors
    clearPreferencesError: (state) => {
      state.preferencesError = null;
    },
    clearNotificationsError: (state) => {
      state.notificationsError = null;
    },
    clearDashboardError: (state) => {
      state.dashboardError = null;
    },
    clearSystemError: (state) => {
      state.systemError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearAllErrors: (state) => {
      state.preferencesError = null;
      state.notificationsError = null;
      state.dashboardError = null;
      state.systemError = null;
      state.actionError = null;
    },
    
    // Local updates (for immediate UI feedback)
    updateUserPreferencesLocal: (state, action: PayloadAction<Partial<UserPreferences>>) => {
      state.userPreferences = { ...state.userPreferences, ...action.payload };
    },
    
    updateNotificationSettingsLocal: (state, action: PayloadAction<Partial<NotificationSettings>>) => {
      state.notificationSettings = { ...state.notificationSettings, ...action.payload };
    },
    
    updateDashboardSettingsLocal: (state, action: PayloadAction<Partial<DashboardSettings>>) => {
      state.dashboardSettings = { ...state.dashboardSettings, ...action.payload };
    },
    
    updateSystemSettingsLocal: (state, action: PayloadAction<Partial<SystemSettings>>) => {
      state.systemSettings = { ...state.systemSettings, ...action.payload };
    },
    
    // Initialize settings
    initializeSettings: (state) => {
      state.isInitialized = true;
      state.lastSync = new Date().toISOString();
    },
    
    // Reset to defaults
    resetToDefaults: (state) => {
      state.userPreferences = initialState.userPreferences;
      state.notificationSettings = initialState.notificationSettings;
      state.dashboardSettings = initialState.dashboardSettings;
      state.systemSettings = initialState.systemSettings;
    },
  },
  extraReducers: (builder) => {
    // User Preferences
    builder
      .addCase(fetchUserPreferences.pending, (state) => {
        state.preferencesLoading = true;
        state.preferencesError = null;
      })
      .addCase(fetchUserPreferences.fulfilled, (state, action) => {
        state.preferencesLoading = false;
        state.userPreferences = action.payload;
      })
      .addCase(fetchUserPreferences.rejected, (state, action) => {
        state.preferencesLoading = false;
        state.preferencesError = action.payload as string;
      })
      
      .addCase(updateUserPreferences.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(updateUserPreferences.fulfilled, (state, action) => {
        state.actionLoading = false;
        state.userPreferences = action.payload;
        state.lastSync = new Date().toISOString();
      })
      .addCase(updateUserPreferences.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // Notification Settings
    builder
      .addCase(fetchNotificationSettings.pending, (state) => {
        state.notificationsLoading = true;
        state.notificationsError = null;
      })
      .addCase(fetchNotificationSettings.fulfilled, (state, action) => {
        state.notificationsLoading = false;
        state.notificationSettings = action.payload;
      })
      .addCase(fetchNotificationSettings.rejected, (state, action) => {
        state.notificationsLoading = false;
        state.notificationsError = action.payload as string;
      })
      
      .addCase(updateNotificationSettings.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(updateNotificationSettings.fulfilled, (state, action) => {
        state.actionLoading = false;
        state.notificationSettings = action.payload;
        state.lastSync = new Date().toISOString();
      })
      .addCase(updateNotificationSettings.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // Dashboard Settings
    builder
      .addCase(fetchDashboardSettings.pending, (state) => {
        state.dashboardLoading = true;
        state.dashboardError = null;
      })
      .addCase(fetchDashboardSettings.fulfilled, (state, action) => {
        state.dashboardLoading = false;
        state.dashboardSettings = action.payload;
      })
      .addCase(fetchDashboardSettings.rejected, (state, action) => {
        state.dashboardLoading = false;
        state.dashboardError = action.payload as string;
      })
      
      .addCase(updateDashboardSettings.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(updateDashboardSettings.fulfilled, (state, action) => {
        state.actionLoading = false;
        state.dashboardSettings = action.payload;
        state.lastSync = new Date().toISOString();
      })
      .addCase(updateDashboardSettings.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // System Settings
    builder
      .addCase(fetchSystemSettings.pending, (state) => {
        state.systemLoading = true;
        state.systemError = null;
      })
      .addCase(fetchSystemSettings.fulfilled, (state, action) => {
        state.systemLoading = false;
        state.systemSettings = action.payload;
      })
      .addCase(fetchSystemSettings.rejected, (state, action) => {
        state.systemLoading = false;
        state.systemError = action.payload as string;
      })
      
      .addCase(updateSystemSettings.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(updateSystemSettings.fulfilled, (state, action) => {
        state.actionLoading = false;
        state.systemSettings = action.payload;
        state.lastSync = new Date().toISOString();
      })
      .addCase(updateSystemSettings.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // Reset Settings
    builder
      .addCase(resetSettings.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(resetSettings.fulfilled, (state) => {
        state.actionLoading = false;
        state.userPreferences = initialState.userPreferences;
        state.notificationSettings = initialState.notificationSettings;
        state.dashboardSettings = initialState.dashboardSettings;
        state.systemSettings = initialState.systemSettings;
        state.lastSync = new Date().toISOString();
      })
      .addCase(resetSettings.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearPreferencesError,
  clearNotificationsError,
  clearDashboardError,
  clearSystemError,
  clearActionError,
  clearAllErrors,
  updateUserPreferencesLocal,
  updateNotificationSettingsLocal,
  updateDashboardSettingsLocal,
  updateSystemSettingsLocal,
  initializeSettings,
  resetToDefaults,
} = settingsSlice.actions;

// Selectors
export const selectUserPreferences = (state: RootState) => state.settings.userPreferences;
export const selectPreferencesLoading = (state: RootState) => state.settings.preferencesLoading;
export const selectPreferencesError = (state: RootState) => state.settings.preferencesError;

export const selectNotificationSettings = (state: RootState) => state.settings.notificationSettings;
export const selectNotificationsLoading = (state: RootState) => state.settings.notificationsLoading;
export const selectNotificationsError = (state: RootState) => state.settings.notificationsError;

export const selectDashboardSettings = (state: RootState) => state.settings.dashboardSettings;
export const selectDashboardLoading = (state: RootState) => state.settings.dashboardLoading;
export const selectDashboardError = (state: RootState) => state.settings.dashboardError;

export const selectSystemSettings = (state: RootState) => state.settings.systemSettings;
export const selectSystemLoading = (state: RootState) => state.settings.systemLoading;
export const selectSystemError = (state: RootState) => state.settings.systemError;

export const selectIsInitialized = (state: RootState) => state.settings.isInitialized;
export const selectLastSync = (state: RootState) => state.settings.lastSync;

export const selectActionLoading = (state: RootState) => state.settings.actionLoading;
export const selectActionError = (state: RootState) => state.settings.actionError;

// Computed selectors
export const selectTheme = (state: RootState) => state.settings.userPreferences.theme;
export const selectLanguage = (state: RootState) => state.settings.userPreferences.language;
export const selectTimezone = (state: RootState) => state.settings.userPreferences.timezone;

export const selectRefreshInterval = (state: RootState) => state.settings.dashboardSettings.refreshInterval;
export const selectAutoRefresh = (state: RootState) => state.settings.dashboardSettings.autoRefresh;
export const selectDefaultView = (state: RootState) => state.settings.dashboardSettings.defaultView;

export const selectDebugMode = (state: RootState) => state.settings.systemSettings.debugMode;
export const selectOfflineMode = (state: RootState) => state.settings.systemSettings.offlineMode;
export const selectCacheEnabled = (state: RootState) => state.settings.systemSettings.cacheEnabled;

// Export reducer
export default settingsSlice.reducer;
