/**
 * MS5.0 Floor Dashboard - Reports Redux Slice
 * 
 * This slice manages report-related state including report generation,
 * templates, scheduling, and report management operations.
 */

import { createSlice, createAsyncThunk, PayloadAction } from '@reduxjs/toolkit';
import { RootState } from '../index';
import { apiService } from '../../services/api';

// Types
interface ReportTemplate {
  id: string;
  name: string;
  description: string;
  category: 'production' | 'oee' | 'downtime' | 'andon' | 'maintenance' | 'quality' | 'custom';
  type: 'summary' | 'detailed' | 'trend' | 'comparison' | 'custom';
  parameters: ReportParameter[];
  isActive: boolean;
  isSystem: boolean;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

interface ReportParameter {
  name: string;
  type: 'string' | 'number' | 'date' | 'boolean' | 'select' | 'multiselect';
  label: string;
  required: boolean;
  defaultValue?: any;
  options?: string[];
  validation?: {
    min?: number;
    max?: number;
    pattern?: string;
  };
}

interface Report {
  id: string;
  templateId: string;
  templateName: string;
  name: string;
  description?: string;
  category: string;
  type: string;
  parameters: Record<string, any>;
  status: 'pending' | 'generating' | 'completed' | 'failed' | 'cancelled';
  progress: number;
  generatedAt?: string;
  completedAt?: string;
  fileUrl?: string;
  fileSize?: number;
  fileFormat: 'pdf' | 'excel' | 'csv' | 'json';
  createdBy: string;
  createdAt: string;
  expiresAt?: string;
  downloadCount: number;
  errorMessage?: string;
}

interface ScheduledReport {
  id: string;
  templateId: string;
  templateName: string;
  name: string;
  description?: string;
  schedule: {
    frequency: 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'yearly' | 'custom';
    time: string; // HH:MM format
    dayOfWeek?: number; // 0-6 for weekly
    dayOfMonth?: number; // 1-31 for monthly
    cronExpression?: string; // For custom schedules
  };
  parameters: Record<string, any>;
  recipients: string[];
  isActive: boolean;
  lastRun?: string;
  nextRun?: string;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

interface ReportData {
  id: string;
  reportId: string;
  data: any;
  metadata: {
    generatedAt: string;
    dataPoints: number;
    timeRange: {
      start: string;
      end: string;
    };
    filters: Record<string, any>;
  };
}

interface ReportsState {
  // Templates
  templates: ReportTemplate[];
  currentTemplate: ReportTemplate | null;
  templatesLoading: boolean;
  templatesError: string | null;
  
  // Reports
  reports: Report[];
  currentReport: Report | null;
  reportsLoading: boolean;
  reportsError: string | null;
  
  // Scheduled Reports
  scheduledReports: ScheduledReport[];
  currentScheduledReport: ScheduledReport | null;
  scheduledReportsLoading: boolean;
  scheduledReportsError: string | null;
  
  // Report Data
  reportData: { [reportId: string]: ReportData };
  dataLoading: boolean;
  dataError: string | null;
  
  // UI State
  selectedCategory: string | null;
  selectedType: string | null;
  reportFilters: {
    status?: string;
    category?: string;
    type?: string;
    dateRange?: {
      start: string;
      end: string;
    };
    createdBy?: string;
  };
  
  // Action states
  actionLoading: boolean;
  actionError: string | null;
  
  // Generation state
  isGenerating: boolean;
  generationProgress: number;
  generationError: string | null;
}

// Initial state
const initialState: ReportsState = {
  templates: [],
  currentTemplate: null,
  templatesLoading: false,
  templatesError: null,
  
  reports: [],
  currentReport: null,
  reportsLoading: false,
  reportsError: null,
  
  scheduledReports: [],
  currentScheduledReport: null,
  scheduledReportsLoading: false,
  scheduledReportsError: null,
  
  reportData: {},
  dataLoading: false,
  dataError: null,
  
  selectedCategory: null,
  selectedType: null,
  reportFilters: {},
  
  actionLoading: false,
  actionError: null,
  
  isGenerating: false,
  generationProgress: 0,
  generationError: null,
};

// Async thunks
export const fetchReportTemplates = createAsyncThunk(
  'reports/fetchTemplates',
  async (filters?: { category?: string; type?: string; isActive?: boolean }, { rejectWithValue }) => {
    try {
      const response = await apiService.getReportTemplates(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch report templates');
    }
  }
);

export const fetchReportTemplate = createAsyncThunk(
  'reports/fetchTemplate',
  async (templateId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getReportTemplate(templateId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch report template');
    }
  }
);

export const createReportTemplate = createAsyncThunk(
  'reports/createTemplate',
  async (templateData: Partial<ReportTemplate>, { rejectWithValue }) => {
    try {
      const response = await apiService.createReportTemplate(templateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create report template');
    }
  }
);

export const updateReportTemplate = createAsyncThunk(
  'reports/updateTemplate',
  async ({ templateId, updateData }: { templateId: string; updateData: Partial<ReportTemplate> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateReportTemplate(templateId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update report template');
    }
  }
);

export const deleteReportTemplate = createAsyncThunk(
  'reports/deleteTemplate',
  async (templateId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteReportTemplate(templateId);
      return templateId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete report template');
    }
  }
);

export const fetchReports = createAsyncThunk(
  'reports/fetchReports',
  async (filters?: { status?: string; category?: string; type?: string; dateRange?: { start: string; end: string } }, { rejectWithValue }) => {
    try {
      const response = await apiService.getReports(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch reports');
    }
  }
);

export const fetchReport = createAsyncThunk(
  'reports/fetchReport',
  async (reportId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getReport(reportId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch report');
    }
  }
);

export const generateReport = createAsyncThunk(
  'reports/generateReport',
  async ({ templateId, parameters, name, description }: { templateId: string; parameters: Record<string, any>; name: string; description?: string }, { rejectWithValue }) => {
    try {
      const response = await apiService.generateReport(templateId, parameters, name, description);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to generate report');
    }
  }
);

export const downloadReport = createAsyncThunk(
  'reports/downloadReport',
  async (reportId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.downloadReport(reportId);
      return { reportId, fileUrl: response.data.fileUrl };
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to download report');
    }
  }
);

export const deleteReport = createAsyncThunk(
  'reports/deleteReport',
  async (reportId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteReport(reportId);
      return reportId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete report');
    }
  }
);

export const fetchScheduledReports = createAsyncThunk(
  'reports/fetchScheduledReports',
  async (filters?: { isActive?: boolean }, { rejectWithValue }) => {
    try {
      const response = await apiService.getScheduledReports(filters);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch scheduled reports');
    }
  }
);

export const fetchScheduledReport = createAsyncThunk(
  'reports/fetchScheduledReport',
  async (scheduledReportId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getScheduledReport(scheduledReportId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch scheduled report');
    }
  }
);

export const createScheduledReport = createAsyncThunk(
  'reports/createScheduledReport',
  async (scheduledReportData: Partial<ScheduledReport>, { rejectWithValue }) => {
    try {
      const response = await apiService.createScheduledReport(scheduledReportData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to create scheduled report');
    }
  }
);

export const updateScheduledReport = createAsyncThunk(
  'reports/updateScheduledReport',
  async ({ scheduledReportId, updateData }: { scheduledReportId: string; updateData: Partial<ScheduledReport> }, { rejectWithValue }) => {
    try {
      const response = await apiService.updateScheduledReport(scheduledReportId, updateData);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to update scheduled report');
    }
  }
);

export const deleteScheduledReport = createAsyncThunk(
  'reports/deleteScheduledReport',
  async (scheduledReportId: string, { rejectWithValue }) => {
    try {
      await apiService.deleteScheduledReport(scheduledReportId);
      return scheduledReportId;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to delete scheduled report');
    }
  }
);

export const toggleScheduledReport = createAsyncThunk(
  'reports/toggleScheduledReport',
  async (scheduledReportId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.toggleScheduledReport(scheduledReportId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to toggle scheduled report');
    }
  }
);

export const fetchReportData = createAsyncThunk(
  'reports/fetchReportData',
  async (reportId: string, { rejectWithValue }) => {
    try {
      const response = await apiService.getReportData(reportId);
      return response.data;
    } catch (error: any) {
      return rejectWithValue(error.message || 'Failed to fetch report data');
    }
  }
);

// Slice
const reportsSlice = createSlice({
  name: 'reports',
  initialState,
  reducers: {
    // Clear errors
    clearTemplatesError: (state) => {
      state.templatesError = null;
    },
    clearReportsError: (state) => {
      state.reportsError = null;
    },
    clearScheduledReportsError: (state) => {
      state.scheduledReportsError = null;
    },
    clearDataError: (state) => {
      state.dataError = null;
    },
    clearActionError: (state) => {
      state.actionError = null;
    },
    clearGenerationError: (state) => {
      state.generationError = null;
    },
    clearAllErrors: (state) => {
      state.templatesError = null;
      state.reportsError = null;
      state.scheduledReportsError = null;
      state.dataError = null;
      state.actionError = null;
      state.generationError = null;
    },
    
    // Set selected items
    setSelectedCategory: (state, action: PayloadAction<string | null>) => {
      state.selectedCategory = action.payload;
    },
    setSelectedType: (state, action: PayloadAction<string | null>) => {
      state.selectedType = action.payload;
    },
    
    // Set filters
    setReportFilters: (state, action: PayloadAction<Partial<ReportsState['reportFilters']>>) => {
      state.reportFilters = { ...state.reportFilters, ...action.payload };
    },
    clearReportFilters: (state) => {
      state.reportFilters = {};
    },
    
    // Update generation progress
    updateGenerationProgress: (state, action: PayloadAction<number>) => {
      state.generationProgress = action.payload;
    },
    
    // Real-time updates
    updateReportStatus: (state, action: PayloadAction<{ reportId: string; status: Report['status']; progress?: number; fileUrl?: string; errorMessage?: string }>) => {
      const { reportId, status, progress, fileUrl, errorMessage } = action.payload;
      const report = state.reports.find(r => r.id === reportId);
      
      if (report) {
        report.status = status;
        if (progress !== undefined) report.progress = progress;
        if (fileUrl) report.fileUrl = fileUrl;
        if (errorMessage) report.errorMessage = errorMessage;
        
        if (status === 'completed') {
          report.completedAt = new Date().toISOString();
          report.generatedAt = new Date().toISOString();
        }
      }
      
      if (state.currentReport?.id === reportId) {
        state.currentReport.status = status;
        if (progress !== undefined) state.currentReport.progress = progress;
        if (fileUrl) state.currentReport.fileUrl = fileUrl;
        if (errorMessage) state.currentReport.errorMessage = errorMessage;
        
        if (status === 'completed') {
          state.currentReport.completedAt = new Date().toISOString();
          state.currentReport.generatedAt = new Date().toISOString();
        }
      }
    },
    
    addReport: (state, action: PayloadAction<Report>) => {
      const report = action.payload;
      const existingIndex = state.reports.findIndex(r => r.id === report.id);
      
      if (existingIndex !== -1) {
        state.reports[existingIndex] = report;
      } else {
        state.reports.unshift(report);
      }
    },
    
    updateReport: (state, action: PayloadAction<Report>) => {
      const report = action.payload;
      const existingIndex = state.reports.findIndex(r => r.id === report.id);
      
      if (existingIndex !== -1) {
        state.reports[existingIndex] = report;
      }
      
      if (state.currentReport?.id === report.id) {
        state.currentReport = report;
      }
    },
    
    addScheduledReport: (state, action: PayloadAction<ScheduledReport>) => {
      const scheduledReport = action.payload;
      const existingIndex = state.scheduledReports.findIndex(sr => sr.id === scheduledReport.id);
      
      if (existingIndex !== -1) {
        state.scheduledReports[existingIndex] = scheduledReport;
      } else {
        state.scheduledReports.push(scheduledReport);
      }
    },
    
    updateScheduledReport: (state, action: PayloadAction<ScheduledReport>) => {
      const scheduledReport = action.payload;
      const existingIndex = state.scheduledReports.findIndex(sr => sr.id === scheduledReport.id);
      
      if (existingIndex !== -1) {
        state.scheduledReports[existingIndex] = scheduledReport;
      }
      
      if (state.currentScheduledReport?.id === scheduledReport.id) {
        state.currentScheduledReport = scheduledReport;
      }
    },
  },
  extraReducers: (builder) => {
    // Templates
    builder
      .addCase(fetchReportTemplates.pending, (state) => {
        state.templatesLoading = true;
        state.templatesError = null;
      })
      .addCase(fetchReportTemplates.fulfilled, (state, action) => {
        state.templatesLoading = false;
        state.templates = action.payload;
      })
      .addCase(fetchReportTemplates.rejected, (state, action) => {
        state.templatesLoading = false;
        state.templatesError = action.payload as string;
      })
      
      .addCase(fetchReportTemplate.pending, (state) => {
        state.templatesLoading = true;
        state.templatesError = null;
      })
      .addCase(fetchReportTemplate.fulfilled, (state, action) => {
        state.templatesLoading = false;
        state.currentTemplate = action.payload;
      })
      .addCase(fetchReportTemplate.rejected, (state, action) => {
        state.templatesLoading = false;
        state.templatesError = action.payload as string;
      })
      
      .addCase(createReportTemplate.fulfilled, (state, action) => {
        state.templates.push(action.payload);
      })
      
      .addCase(updateReportTemplate.fulfilled, (state, action) => {
        const template = action.payload;
        const index = state.templates.findIndex(t => t.id === template.id);
        if (index !== -1) {
          state.templates[index] = template;
        }
        if (state.currentTemplate?.id === template.id) {
          state.currentTemplate = template;
        }
      })
      
      .addCase(deleteReportTemplate.fulfilled, (state, action) => {
        const templateId = action.payload;
        state.templates = state.templates.filter(t => t.id !== templateId);
        if (state.currentTemplate?.id === templateId) {
          state.currentTemplate = null;
        }
      });
    
    // Reports
    builder
      .addCase(fetchReports.pending, (state) => {
        state.reportsLoading = true;
        state.reportsError = null;
      })
      .addCase(fetchReports.fulfilled, (state, action) => {
        state.reportsLoading = false;
        state.reports = action.payload;
      })
      .addCase(fetchReports.rejected, (state, action) => {
        state.reportsLoading = false;
        state.reportsError = action.payload as string;
      })
      
      .addCase(fetchReport.pending, (state) => {
        state.reportsLoading = true;
        state.reportsError = null;
      })
      .addCase(fetchReport.fulfilled, (state, action) => {
        state.reportsLoading = false;
        state.currentReport = action.payload;
      })
      .addCase(fetchReport.rejected, (state, action) => {
        state.reportsLoading = false;
        state.reportsError = action.payload as string;
      })
      
      .addCase(generateReport.pending, (state) => {
        state.isGenerating = true;
        state.generationProgress = 0;
        state.generationError = null;
      })
      .addCase(generateReport.fulfilled, (state, action) => {
        state.isGenerating = false;
        state.generationProgress = 100;
        state.reports.unshift(action.payload);
      })
      .addCase(generateReport.rejected, (state, action) => {
        state.isGenerating = false;
        state.generationProgress = 0;
        state.generationError = action.payload as string;
      })
      
      .addCase(deleteReport.fulfilled, (state, action) => {
        const reportId = action.payload;
        state.reports = state.reports.filter(r => r.id !== reportId);
        if (state.currentReport?.id === reportId) {
          state.currentReport = null;
        }
        delete state.reportData[reportId];
      });
    
    // Scheduled Reports
    builder
      .addCase(fetchScheduledReports.pending, (state) => {
        state.scheduledReportsLoading = true;
        state.scheduledReportsError = null;
      })
      .addCase(fetchScheduledReports.fulfilled, (state, action) => {
        state.scheduledReportsLoading = false;
        state.scheduledReports = action.payload;
      })
      .addCase(fetchScheduledReports.rejected, (state, action) => {
        state.scheduledReportsLoading = false;
        state.scheduledReportsError = action.payload as string;
      })
      
      .addCase(fetchScheduledReport.pending, (state) => {
        state.scheduledReportsLoading = true;
        state.scheduledReportsError = null;
      })
      .addCase(fetchScheduledReport.fulfilled, (state, action) => {
        state.scheduledReportsLoading = false;
        state.currentScheduledReport = action.payload;
      })
      .addCase(fetchScheduledReport.rejected, (state, action) => {
        state.scheduledReportsLoading = false;
        state.scheduledReportsError = action.payload as string;
      })
      
      .addCase(createScheduledReport.fulfilled, (state, action) => {
        state.scheduledReports.push(action.payload);
      })
      
      .addCase(updateScheduledReport.fulfilled, (state, action) => {
        const scheduledReport = action.payload;
        const index = state.scheduledReports.findIndex(sr => sr.id === scheduledReport.id);
        if (index !== -1) {
          state.scheduledReports[index] = scheduledReport;
        }
        if (state.currentScheduledReport?.id === scheduledReport.id) {
          state.currentScheduledReport = scheduledReport;
        }
      })
      
      .addCase(deleteScheduledReport.fulfilled, (state, action) => {
        const scheduledReportId = action.payload;
        state.scheduledReports = state.scheduledReports.filter(sr => sr.id !== scheduledReportId);
        if (state.currentScheduledReport?.id === scheduledReportId) {
          state.currentScheduledReport = null;
        }
      })
      
      .addCase(toggleScheduledReport.fulfilled, (state, action) => {
        const scheduledReport = action.payload;
        const index = state.scheduledReports.findIndex(sr => sr.id === scheduledReport.id);
        if (index !== -1) {
          state.scheduledReports[index] = scheduledReport;
        }
        if (state.currentScheduledReport?.id === scheduledReport.id) {
          state.currentScheduledReport = scheduledReport;
        }
      });
    
    // Report Data
    builder
      .addCase(fetchReportData.pending, (state) => {
        state.dataLoading = true;
        state.dataError = null;
      })
      .addCase(fetchReportData.fulfilled, (state, action) => {
        state.dataLoading = false;
        state.reportData[action.payload.reportId] = action.payload;
      })
      .addCase(fetchReportData.rejected, (state, action) => {
        state.dataLoading = false;
        state.dataError = action.payload as string;
      });
  },
});

// Export actions
export const {
  clearTemplatesError,
  clearReportsError,
  clearScheduledReportsError,
  clearDataError,
  clearActionError,
  clearGenerationError,
  clearAllErrors,
  setSelectedCategory,
  setSelectedType,
  setReportFilters,
  clearReportFilters,
  updateGenerationProgress,
  updateReportStatus,
  addReport,
  updateReport,
  addScheduledReport,
  updateScheduledReport,
} = reportsSlice.actions;

// Selectors
export const selectTemplates = (state: RootState) => state.reports.templates;
export const selectCurrentTemplate = (state: RootState) => state.reports.currentTemplate;
export const selectTemplatesLoading = (state: RootState) => state.reports.templatesLoading;
export const selectTemplatesError = (state: RootState) => state.reports.templatesError;

export const selectReports = (state: RootState) => state.reports.reports;
export const selectCurrentReport = (state: RootState) => state.reports.currentReport;
export const selectReportsLoading = (state: RootState) => state.reports.reportsLoading;
export const selectReportsError = (state: RootState) => state.reports.reportsError;

export const selectScheduledReports = (state: RootState) => state.reports.scheduledReports;
export const selectCurrentScheduledReport = (state: RootState) => state.reports.currentScheduledReport;
export const selectScheduledReportsLoading = (state: RootState) => state.reports.scheduledReportsLoading;
export const selectScheduledReportsError = (state: RootState) => state.reports.scheduledReportsError;

export const selectReportData = (state: RootState) => state.reports.reportData;
export const selectDataLoading = (state: RootState) => state.reports.dataLoading;
export const selectDataError = (state: RootState) => state.reports.dataError;

export const selectSelectedCategory = (state: RootState) => state.reports.selectedCategory;
export const selectSelectedType = (state: RootState) => state.reports.selectedType;
export const selectReportFilters = (state: RootState) => state.reports.reportFilters;

export const selectActionLoading = (state: RootState) => state.reports.actionLoading;
export const selectActionError = (state: RootState) => state.reports.actionError;

export const selectIsGenerating = (state: RootState) => state.reports.isGenerating;
export const selectGenerationProgress = (state: RootState) => state.reports.generationProgress;
export const selectGenerationError = (state: RootState) => state.reports.generationError;

// Filtered selectors
export const selectTemplatesByCategory = (category: string) => (state: RootState) =>
  state.reports.templates.filter(template => template.category === category);

export const selectTemplatesByType = (type: string) => (state: RootState) =>
  state.reports.templates.filter(template => template.type === type);

export const selectActiveTemplates = (state: RootState) =>
  state.reports.templates.filter(template => template.isActive);

export const selectReportsByStatus = (status: string) => (state: RootState) =>
  state.reports.reports.filter(report => report.status === status);

export const selectReportsByCategory = (category: string) => (state: RootState) =>
  state.reports.reports.filter(report => report.category === category);

export const selectCompletedReports = (state: RootState) =>
  state.reports.reports.filter(report => report.status === 'completed');

export const selectPendingReports = (state: RootState) =>
  state.reports.reports.filter(report => report.status === 'pending');

export const selectGeneratingReports = (state: RootState) =>
  state.reports.reports.filter(report => report.status === 'generating');

export const selectFailedReports = (state: RootState) =>
  state.reports.reports.filter(report => report.status === 'failed');

export const selectActiveScheduledReports = (state: RootState) =>
  state.reports.scheduledReports.filter(sr => sr.isActive);

export const selectScheduledReportsByFrequency = (frequency: string) => (state: RootState) =>
  state.reports.scheduledReports.filter(sr => sr.schedule.frequency === frequency);

// Computed selectors
export const selectReportStats = (state: RootState) => {
  const reports = state.reports.reports;
  const total = reports.length;
  const completed = reports.filter(r => r.status === 'completed').length;
  const pending = reports.filter(r => r.status === 'pending').length;
  const generating = reports.filter(r => r.status === 'generating').length;
  const failed = reports.filter(r => r.status === 'failed').length;
  
  return {
    total,
    completed,
    pending,
    generating,
    failed,
    completionRate: total > 0 ? (completed / total) * 100 : 0,
  };
};

export const selectTemplateStats = (state: RootState) => {
  const templates = state.reports.templates;
  const total = templates.length;
  const active = templates.filter(t => t.isActive).length;
  const system = templates.filter(t => t.isSystem).length;
  const custom = templates.filter(t => !t.isSystem).length;
  
  return {
    total,
    active,
    system,
    custom,
    activeRate: total > 0 ? (active / total) * 100 : 0,
  };
};

export const selectScheduledReportStats = (state: RootState) => {
  const scheduledReports = state.reports.scheduledReports;
  const total = scheduledReports.length;
  const active = scheduledReports.filter(sr => sr.isActive).length;
  const inactive = scheduledReports.filter(sr => !sr.isActive).length;
  
  return {
    total,
    active,
    inactive,
    activeRate: total > 0 ? (active / total) * 100 : 0,
  };
};

// Export reducer
export default reportsSlice.reducer;
