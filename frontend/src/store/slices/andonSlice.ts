/**
 * MS5.0 Floor Dashboard - Andon Redux Slice
 * 
 * This slice manages Andon-related state including Andon events,
 * escalations, and real-time notifications.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface AndonEvent {
  id: string;
  lineId: string;
  equipmentCode: string;
  eventType: 'stop' | 'quality' | 'maintenance' | 'material';
  priority: 'low' | 'medium' | 'high' | 'critical';
  description: string;
  reportedBy: string;
  reportedAt: string;
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  resolutionNotes?: string;
  status: 'open' | 'acknowledged' | 'resolved' | 'escalated';
  escalationLevel: number;
}

interface AndonEscalation {
  id: string;
  eventId: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  acknowledgmentTimeoutMinutes: number;
  resolutionTimeoutMinutes: number;
  escalationRecipients: string[];
  escalationLevel: number;
  status: 'active' | 'acknowledged' | 'escalated' | 'resolved';
  createdAt: string;
  acknowledgedAt?: string;
  escalatedAt?: string;
  resolvedAt?: string;
  acknowledgedBy?: string;
  escalatedBy?: string;
  escalationNotes?: string;
  lastReminderSentAt?: string;
}

interface AndonState {
  // Andon Events
  events: AndonEvent[];
  currentEvent: AndonEvent | null;
  eventsLoading: boolean;
  eventsError: string | null;
  
  // Escalations
  escalations: AndonEscalation[];
  currentEscalation: AndonEscalation | null;
  escalationsLoading: boolean;
  escalationsError: string | null;
  
  // UI State
  selectedEventId: string | null;
  selectedEscalationId: string | null;
  eventFilters: {
    status?: string;
    priority?: string;
    eventType?: string;
    lineId?: string;
  };
  
  // Real-time notifications
  unreadNotifications: number;
  lastNotificationTime: string | null;
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
}

// Initial state
const initialState: AndonState = {
  events: [],
  currentEvent: null,
  eventsLoading: false,
  eventsError: null,
  
  escalations: [],
  currentEscalation: null,
  escalationsLoading: false,
  escalationsError: null,
  
  selectedEventId: null,
  selectedEscalationId: null,
  eventFilters: {},
  
  unreadNotifications: 0,
  lastNotificationTime: null,
  
  actionLoading: false,
  actionError: null,
};

// Async thunks
export const fetchAndonEvents = createAsyncThunk(
  'andon/fetchEvents',
  async (filters?: { status?: string; priority?: string; eventType?: string; lineId?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getAndonEvents(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch Andon events');
    }
  }
);

export const fetchAndonEvent = createAsyncThunk(
  'andon/fetchEvent',
  async (eventId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getAndonEvent(eventId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch Andon event');
    }
  }
);

export const createAndonEvent = createAsyncThunk(
  'andon/createEvent',
  async (eventData: Partial<AndonEvent>, { rejectWithValue }) => {
    try {
      const response = await apiService.createAndonEvent(eventData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create Andon event');
    }
  }
);

export const acknowledgeAndonEvent = createAsyncThunk(
  'andon/acknowledgeEvent',
  async (eventId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acknowledgeAndonEvent(eventId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to acknowledge Andon event');
    }
  }
);

export const resolveAndonEvent = createAsyncThunk(
  'andon/resolveEvent',
  async ({ eventId, resolutionNotes }: { eventId: string; resolutionNotes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.resolveAndonEvent(eventId, resolutionNotes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve Andon event');
    }
  }
);

export const escalateAndonEvent = createAsyncThunk(
  'andon/escalateEvent',
  async ({ eventId, escalationLevel }: { eventId: string; escalationLevel: number }, { rejectWithValue }) => {
    try {
      const response = await apiService.escalateAndonEvent(eventId, escalationLevel);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to escalate Andon event');
    }
  }
);

export const fetchAndonEscalations = createAsyncThunk(
  'andon/fetchEscalations',
  async (filters?: { status?: string; priority?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.getAndonEscalations(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch Andon escalations');
    }
  }
);

export const fetchAndonEscalation = createAsyncThunk(
  'andon/fetchEscalation',
  async (escalationId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getAndonEscalation(escalationId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch Andon escalation');
    }
  }
);

export const acknowledgeEscalation = createAsyncThunk(
  'andon/acknowledgeEscalation',
  async (escalationId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.acknowledgeEscalation(escalationId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to acknowledge escalation');
    }
  }
);

export const resolveEscalation = createAsyncThunk(
  'andon/resolveEscalation',
  async ({ escalationId, resolutionNotes }: { escalationId: string; resolutionNotes: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.resolveEscalation(escalationId, resolutionNotes);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to resolve escalation');
    }
  }
);

// Slice
const andonSlice = createSlice({
  name: 'andon',
  initialState,
  reducers: {
    // Clear errors
    clearEventsError: (state) => {
      state.eventsError = null;
    },
    clearEscalationsError: (state) => {
      state.escalationsError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearAllErrors: (state) => {
      state.eventsError = null;
      state.escalationsError = null;
      state.actionError = null;
    },
    
    // Set selected items
    setSelectedEventId: (state, action: PayloadAction<string | null>) => {
      state.selectedEventId = action.payload;
    },
    setSelectedEscalationId: (state, action: PayloadAction<string | null>) => {
      state.selectedEscalationId = action.payload;
    },
    
    // Set filters
    setEventFilters: (state, action: PayloadAction<Partial<AndonState['eventFilters']>>) => {
      state.eventFilters = { ...state.eventFilters, ...action.payload };
    },
    clearEventFilters: (state) => {
      state.eventFilters = {};
    },
    
    // Real-time updates
    addAndonEvent: (state, action: PayloadAction<AndonEvent>) => {
      const event = action.payload;
      const existingIndex = state.events.findIndex(e => e.id === event.id);
      
      if (existingIndex !== -1) {
        state.events[existingIndex] = event;
      } else {
        state.events.unshift(event);
        state.unreadNotifications += 1;
      }
    },
    
    updateAndonEvent: (state, action: PayloadAction<AndonEvent>) => {
      const event = action.payload;
      const existingIndex = state.events.findIndex(e => e.id === event.id);
      
      if (existingIndex !== -1) {
        state.events[existingIndex] = event;
      }
      
      if (state.currentEvent?.id === event.id) {
        state.currentEvent = event;
      }
    },
    
    addEscalation: (state, action: PayloadAction<AndonEscalation>) => {
      const escalation = action.payload;
      const existingIndex = state.escalations.findIndex(e => e.id === escalation.id);
      
      if (existingIndex !== -1) {
        state.escalations[existingIndex] = escalation;
      } else {
        state.escalations.unshift(escalation);
        state.unreadNotifications += 1;
      }
    },
    
    updateEscalation: (state, action: PayloadAction<AndonEscalation>) => {
      const escalation = action.payload;
      const existingIndex = state.escalations.findIndex(e => e.id === escalation.id);
      
      if (existingIndex !== -1) {
        state.escalations[existingIndex] = escalation;
      }
      
      if (state.currentEscalation?.id === escalation.id) {
        state.currentEscalation = escalation;
      }
    },
    
    // Notifications
    markNotificationsAsRead: (state) => {
      state.unreadNotifications = 0;
      state.lastNotificationTime = new Date().toISOString();
    },
    
    incrementUnreadNotifications: (state) => {
      state.unreadNotifications += 1;
    },
  },
  extraReducers: (builder) => {
    // Andon Events
    builder
      .addCase(fetchAndonEvents.pending, (state) => {
        state.eventsLoading = true;
        state.eventsError = null;
      })
      .addCase(fetchAndonEvents.fulfilled, (state, action) => {
        state.eventsLoading = false;
        state.events = action.payload;
      })
      .addCase(fetchAndonEvents.rejected, (state, action) => {
        state.eventsLoading = false;
        state.eventsError = action.payload as string;
      })
      
      .addCase(fetchAndonEvent.pending, (state) => {
        state.eventsLoading = true;
        state.eventsError = null;
      })
      .addCase(fetchAndonEvent.fulfilled, (state, action) => {
        state.eventsLoading = false;
        state.currentEvent = action.payload;
      })
      .addCase(fetchAndonEvent.rejected, (state, action) => {
        state.eventsLoading = false;
        state.eventsError = action.payload as string;
      })
      
      .addCase(createAndonEvent.fulfilled, (state, action) => {
        state.events.unshift(action.payload);
        state.unreadNotifications += 1;
      })
      
      .addCase(acknowledgeAndonEvent.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(acknowledgeAndonEvent.fulfilled, (state, action) => {
        state.actionLoading = false;
        const event = action.payload;
        const index = state.events.findIndex(e => e.id === event.id);
        if (index !== -1) {
          state.events[index] = event;
        }
        if (state.currentEvent?.id === event.id) {
          state.currentEvent = event;
        }
      })
      .addCase(acknowledgeAndonEvent.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      })
      
      .addCase(resolveAndonEvent.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(resolveAndonEvent.fulfilled, (state, action) => {
        state.actionLoading = false;
        const event = action.payload;
        const index = state.events.findIndex(e => e.id === event.id);
        if (index !== -1) {
          state.events[index] = event;
        }
        if (state.currentEvent?.id === event.id) {
          state.currentEvent = event;
        }
      })
      .addCase(resolveAndonEvent.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      })
      
      .addCase(escalateAndonEvent.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(escalateAndonEvent.fulfilled, (state, action) => {
        state.actionLoading = false;
        const event = action.payload;
        const index = state.events.findIndex(e => e.id === event.id);
        if (index !== -1) {
          state.events[index] = event;
        }
        if (state.currentEvent?.id === event.id) {
          state.currentEvent = event;
        }
      })
      .addCase(escalateAndonEvent.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
    
    // Andon Escalations
    builder
      .addCase(fetchAndonEscalations.pending, (state) => {
        state.escalationsLoading = true;
        state.escalationsError = null;
      })
      .addCase(fetchAndonEscalations.fulfilled, (state, action) => {
        state.escalationsLoading = false;
        state.escalations = action.payload;
      })
      .addCase(fetchAndonEscalations.rejected, (state, action) => {
        state.escalationsLoading = false;
        state.escalationsError = action.payload as string;
      })
      
      .addCase(fetchAndonEscalation.pending, (state) => {
        state.escalationsLoading = true;
        state.escalationsError = null;
      })
      .addCase(fetchAndonEscalation.fulfilled, (state, action) => {
        state.escalationsLoading = false;
        state.currentEscalation = action.payload;
      })
      .addCase(fetchAndonEscalation.rejected, (state, action) => {
        state.escalationsLoading = false;
        state.escalationsError = action.payload as string;
      })
      
      .addCase(acknowledgeEscalation.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(acknowledgeEscalation.fulfilled, (state, action) => {
        state.actionLoading = false;
        const escalation = action.payload;
        const index = state.escalations.findIndex(e => e.id === escalation.id);
        if (index !== -1) {
          state.escalations[index] = escalation;
        }
        if (state.currentEscalation?.id === escalation.id) {
          state.currentEscalation = escalation;
        }
      })
      .addCase(acknowledgeEscalation.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      })
      
      .addCase(resolveEscalation.pending, (state) => {
        state.actionLoading = true;
        state.actionError = null;
      })
      .addCase(resolveEscalation.fulfilled, (state, action) => {
        state.actionLoading = false;
        const escalation = action.payload;
        const index = state.escalations.findIndex(e => e.id === escalation.id);
        if (index !== -1) {
          state.escalations[index] = escalation;
        }
        if (state.currentEscalation?.id === escalation.id) {
          state.currentEscalation = escalation;
        }
      })
      .addCase(resolveEscalation.rejected, (state, action) => {
        state.actionLoading = false;
        state.actionError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearEventsError,
  clearEscalationsError,
  clearActionError,
  clearAllErrors,
  setSelectedEventId,
  setSelectedEscalationId,
  setEventFilters,
  clearEventFilters,
  addAndonEvent,
  updateAndonEvent,
  addEscalation,
  updateEscalation,
  markNotificationsAsRead,
  incrementUnreadNotifications,
} = andonSlice.actions;

// Selectors
export const selectAndonEvents = (state: RootState) => state.andon.events;
export const selectCurrentAndonEvent = (state: RootState) => state.andon.currentEvent;
export const selectEventsLoading = (state: RootState) => state.andon.eventsLoading;
export const selectEventsError = (state: RootState) => state.andon.eventsError;

export const selectAndonEscalations = (state: RootState) => state.andon.escalations;
export const selectCurrentEscalation = (state: RootState) => state.andon.currentEscalation;
export const selectEscalationsLoading = (state: RootState) => state.andon.escalationsLoading;
export const selectEscalationsError = (state: RootState) => state.andon.escalationsError;

export const selectSelectedEventId = (state: RootState) => state.andon.selectedEventId;
export const selectSelectedEscalationId = (state: RootState) => state.andon.selectedEscalationId;
export const selectEventFilters = (state: RootState) => state.andon.eventFilters;

export const selectUnreadNotifications = (state: RootState) => state.andon.unreadNotifications;
export const selectLastNotificationTime = (state: RootState) => state.andon.lastNotificationTime;

export const selectActionLoading = (state: RootState) => state.andon.actionLoading;
export const selectActionError = (state: RootState) => state.andon.actionError;

// Filtered selectors
export const selectEventsByStatus = (status: string) => (state: RootState) =>
  state.andon.events.filter(event => event.status === status);

export const selectEventsByPriority = (priority: string) => (state: RootState) =>
  state.andon.events.filter(event => event.priority === priority);

export const selectEventsByLine = (lineId: string) => (state: RootState) =>
  state.andon.events.filter(event => event.lineId === lineId);

export const selectActiveEvents = (state: RootState) =>
  state.andon.events.filter(event => event.status === 'open' || event.status === 'acknowledged');

export const selectCriticalEvents = (state: RootState) =>
  state.andon.events.filter(event => event.priority === 'critical' && event.status !== 'resolved');

export const selectEscalationsByStatus = (status: string) => (state: RootState) =>
  state.andon.escalations.filter(escalation => escalation.status === status);

export const selectActiveEscalations = (state: RootState) =>
  state.andon.escalations.filter(escalation => escalation.status === 'active');

// Export reducer
export default andonSlice.reducer;
