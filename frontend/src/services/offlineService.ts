/**
 * MS5.0 Floor Dashboard - Offline Service
 * 
 * This service handles offline functionality including data synchronization,
 * offline queue management, and network status monitoring.
 */

import { apiService } from './api';

// Types
export interface OfflineAction {
  id: string;
  type: 'create' | 'update' | 'delete' | 'sync';
  entity: string;
  entityId: string;
  data: any;
  timestamp: string;
  status: 'pending' | 'syncing' | 'completed' | 'failed' | 'cancelled';
  retryCount: number;
  maxRetries: number;
  error?: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  dependencies?: string[];
  created_at: string;
  updated_at: string;
}

export interface SyncStatus {
  isOnline: boolean;
  lastSync: string | null;
  pendingActions: number;
  failedActions: number;
  syncInProgress: boolean;
  networkQuality: 'excellent' | 'good' | 'fair' | 'poor' | 'offline';
  estimatedSyncTime: number;
}

export interface OfflineData {
  id: string;
  entity: string;
  entityId: string;
  data: any;
  version: number;
  lastModified: string;
  isDirty: boolean;
  conflictResolution: 'server' | 'client' | 'manual';
  created_at: string;
  updated_at: string;
}

export interface ConflictResolution {
  id: string;
  entity: string;
  entityId: string;
  serverData: any;
  clientData: any;
  resolution: 'server' | 'client' | 'merge' | 'manual';
  resolvedBy?: string;
  resolvedAt?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface OfflineMetrics {
  totalActions: number;
  completedActions: number;
  failedActions: number;
  pendingActions: number;
  averageSyncTime: number;
  dataSize: number;
  lastSync: string | null;
  uptime: number;
  downtime: number;
}

/**
 * Offline Service Class
 * 
 * Provides methods for offline data management, synchronization, and conflict resolution.
 * Handles offline queue operations and network status monitoring.
 */
class OfflineService {
  private isOnline: boolean = navigator.onLine;
  private syncInProgress: boolean = false;
  private offlineActions: Map<string, OfflineAction> = new Map();
  private offlineData: Map<string, OfflineData> = new Map();
  private conflictResolutions: Map<string, ConflictResolution> = new Map();
  private networkListeners: Array<(isOnline: boolean) => void> = [];

  constructor() {
    this.setupNetworkMonitoring();
  }

  // ============================================================================
  // NETWORK MONITORING
  // ============================================================================

  /**
   * Setup network status monitoring
   */
  private setupNetworkMonitoring(): void {
    window.addEventListener('online', () => {
      this.isOnline = true;
      this.notifyNetworkListeners(true);
      this.autoSync();
    });

    window.addEventListener('offline', () => {
      this.isOnline = false;
      this.notifyNetworkListeners(false);
    });

    // Check network quality periodically
    setInterval(() => {
      this.checkNetworkQuality();
    }, 30000);
  }

  /**
   * Add network status listener
   * 
   * @param listener - Network status listener function
   * @returns Unsubscribe function
   */
  addNetworkListener(listener: (isOnline: boolean) => void): () => void {
    this.networkListeners.push(listener);
    
    return () => {
      const index = this.networkListeners.indexOf(listener);
      if (index > -1) {
        this.networkListeners.splice(index, 1);
      }
    };
  }

  /**
   * Notify network listeners
   * 
   * @param isOnline - Network status
   */
  private notifyNetworkListeners(isOnline: boolean): void {
    this.networkListeners.forEach(listener => {
      try {
        listener(isOnline);
      } catch (error) {
        console.error('Error in network listener:', error);
      }
    });
  }

  /**
   * Check network quality
   */
  private async checkNetworkQuality(): Promise<void> {
    if (!this.isOnline) return;

    try {
      const startTime = Date.now();
      const response = await fetch('/api/v1/health', { method: 'HEAD' });
      const endTime = Date.now();
      
      const responseTime = endTime - startTime;
      // Network quality based on response time
      if (responseTime < 100) {
        this.networkQuality = 'excellent';
      } else if (responseTime < 300) {
        this.networkQuality = 'good';
      } else if (responseTime < 1000) {
        this.networkQuality = 'fair';
      } else {
        this.networkQuality = 'poor';
      }
    } catch (error) {
      this.networkQuality = 'offline';
    }
  }

  // ============================================================================
  // OFFLINE ACTIONS
  // ============================================================================

  /**
   * Add offline action
   * 
   * @param action - Offline action to add
   * @returns Promise resolving to added action
   */
  async addOfflineAction(action: Partial<OfflineAction>): Promise<OfflineAction> {
    const offlineAction: OfflineAction = {
      id: `action_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: action.type || 'create',
      entity: action.entity || '',
      entityId: action.entityId || '',
      data: action.data || {},
      timestamp: new Date().toISOString(),
      status: 'pending',
      retryCount: 0,
      maxRetries: action.maxRetries || 3,
      priority: action.priority || 'medium',
      dependencies: action.dependencies || [],
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    this.offlineActions.set(offlineAction.id, offlineAction);
    
    if (this.isOnline) {
      this.autoSync();
    }

    return offlineAction;
  }

  /**
   * Get offline actions
   * 
   * @param filters - Optional filters for status and entity
   * @returns Array of offline actions
   */
  getOfflineActions(filters?: { status?: string; entity?: string }): OfflineAction[] {
    let actions = Array.from(this.offlineActions.values());

    if (filters) {
      if (filters.status) {
        actions = actions.filter(action => action.status === filters.status);
      }
      if (filters.entity) {
        actions = actions.filter(action => action.entity === filters.entity);
      }
    }

    return actions.sort((a, b) => {
      // Sort by priority first, then by timestamp
      const priorityOrder = { critical: 4, high: 3, medium: 2, low: 1 };
      const aPriority = priorityOrder[a.priority] || 0;
      const bPriority = priorityOrder[b.priority] || 0;
      
      if (aPriority !== bPriority) {
        return bPriority - aPriority;
      }
      
      return new Date(a.timestamp).getTime() - new Date(b.timestamp).getTime();
    });
  }

  /**
   * Update offline action
   * 
   * @param actionId - Action ID
   * @param updates - Updates to apply
   * @returns Updated action
   */
  updateOfflineAction(actionId: string, updates: Partial<OfflineAction>): OfflineAction | null {
    const action = this.offlineActions.get(actionId);
    if (!action) return null;

    const updatedAction = {
      ...action,
      ...updates,
      updated_at: new Date().toISOString(),
    };

    this.offlineActions.set(actionId, updatedAction);
    return updatedAction;
  }

  /**
   * Remove offline action
   * 
   * @param actionId - Action ID
   * @returns True if action was removed
   */
  removeOfflineAction(actionId: string): boolean {
    return this.offlineActions.delete(actionId);
  }

  // ============================================================================
  // DATA SYNCHRONIZATION
  // ============================================================================

  /**
   * Sync offline actions
   * 
   * @returns Promise resolving to sync result
   */
  async syncOfflineActions(): Promise<{ success: number; failed: number; errors: string[] }> {
    if (!this.isOnline || this.syncInProgress) {
      return { success: 0, failed: 0, errors: ['Not online or sync in progress'] };
    }

    this.syncInProgress = true;
    const pendingActions = this.getOfflineActions({ status: 'pending' });
    let successCount = 0;
    let failedCount = 0;
    const errors: string[] = [];

    for (const action of pendingActions) {
      try {
        await this.executeOfflineAction(action);
        this.updateOfflineAction(action.id, { status: 'completed' });
        successCount++;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        errors.push(`Action ${action.id}: ${errorMessage}`);
        
        if (action.retryCount < action.maxRetries) {
          this.updateOfflineAction(action.id, {
            status: 'pending',
            retryCount: action.retryCount + 1,
            error: errorMessage,
          });
        } else {
          this.updateOfflineAction(action.id, {
            status: 'failed',
            error: errorMessage,
          });
        }
        failedCount++;
      }
    }

    this.syncInProgress = false;
    return { success: successCount, failed: failedCount, errors };
  }

  /**
   * Execute offline action
   * 
   * @param action - Offline action to execute
   * @returns Promise resolving when action is executed
   */
  private async executeOfflineAction(action: OfflineAction): Promise<void> {
    this.updateOfflineAction(action.id, { status: 'syncing' });

    switch (action.type) {
      case 'create':
        await this.executeCreateAction(action);
        break;
      case 'update':
        await this.executeUpdateAction(action);
        break;
      case 'delete':
        await this.executeDeleteAction(action);
        break;
      case 'sync':
        await this.executeSyncAction(action);
        break;
      default:
        throw new Error(`Unknown action type: ${action.type}`);
    }
  }

  /**
   * Execute create action
   * 
   * @param action - Create action
   */
  private async executeCreateAction(action: OfflineAction): Promise<void> {
    // Implementation depends on entity type
    switch (action.entity) {
      case 'production_line':
        await apiService.createProductionLine(action.data);
        break;
      case 'job_assignment':
        await apiService.createJobAssignment(action.data);
        break;
      case 'andon_event':
        await apiService.createAndonEvent(action.data);
        break;
      default:
        throw new Error(`Unknown entity type: ${action.entity}`);
    }
  }

  /**
   * Execute update action
   * 
   * @param action - Update action
   */
  private async executeUpdateAction(action: OfflineAction): Promise<void> {
    // Implementation depends on entity type
    switch (action.entity) {
      case 'production_line':
        await apiService.updateProductionLine(action.entityId, action.data);
        break;
      case 'job_assignment':
        await apiService.updateJobAssignment(action.entityId, action.data);
        break;
      case 'andon_event':
        await apiService.updateAndonEvent(action.entityId, action.data);
        break;
      default:
        throw new Error(`Unknown entity type: ${action.entity}`);
    }
  }

  /**
   * Execute delete action
   * 
   * @param action - Delete action
   */
  private async executeDeleteAction(action: OfflineAction): Promise<void> {
    // Implementation depends on entity type
    switch (action.entity) {
      case 'production_line':
        await apiService.deleteProductionLine(action.entityId);
        break;
      case 'job_assignment':
        await apiService.deleteJobAssignment(action.entityId);
        break;
      case 'andon_event':
        await apiService.deleteAndonEvent(action.entityId);
        break;
      default:
        throw new Error(`Unknown entity type: ${action.entity}`);
    }
  }

  /**
   * Execute sync action
   * 
   * @param action - Sync action
   */
  private async executeSyncAction(action: OfflineAction): Promise<void> {
    // Implementation depends on entity type
    switch (action.entity) {
      case 'production_line':
        await apiService.getProductionLine(action.entityId);
        break;
      case 'job_assignment':
        await apiService.getJobAssignment(action.entityId);
        break;
      case 'andon_event':
        await apiService.getAndonEvent(action.entityId);
        break;
      default:
        throw new Error(`Unknown entity type: ${action.entity}`);
    }
  }

  /**
   * Auto sync when online
   */
  private async autoSync(): Promise<void> {
    if (this.isOnline && !this.syncInProgress) {
      const pendingActions = this.getOfflineActions({ status: 'pending' });
      if (pendingActions.length > 0) {
        await this.syncOfflineActions();
      }
    }
  }

  // ============================================================================
  // OFFLINE DATA MANAGEMENT
  // ============================================================================

  /**
   * Store offline data
   * 
   * @param entity - Entity type
   * @param entityId - Entity ID
   * @param data - Data to store
   * @returns Stored offline data
   */
  storeOfflineData(entity: string, entityId: string, data: any): OfflineData {
    const offlineData: OfflineData = {
      id: `data_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      entity,
      entityId,
      data,
      version: 1,
      lastModified: new Date().toISOString(),
      isDirty: true,
      conflictResolution: 'client',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    this.offlineData.set(`${entity}_${entityId}`, offlineData);
    return offlineData;
  }

  /**
   * Get offline data
   * 
   * @param entity - Entity type
   * @param entityId - Entity ID
   * @returns Offline data or null
   */
  getOfflineData(entity: string, entityId: string): OfflineData | null {
    return this.offlineData.get(`${entity}_${entityId}`) || null;
  }

  /**
   * Update offline data
   * 
   * @param entity - Entity type
   * @param entityId - Entity ID
   * @param data - Updated data
   * @returns Updated offline data
   */
  updateOfflineData(entity: string, entityId: string, data: any): OfflineData | null {
    const existing = this.getOfflineData(entity, entityId);
    if (!existing) return null;

    const updatedData: OfflineData = {
      ...existing,
      data,
      version: existing.version + 1,
      lastModified: new Date().toISOString(),
      isDirty: true,
      updated_at: new Date().toISOString(),
    };

    this.offlineData.set(`${entity}_${entityId}`, updatedData);
    return updatedData;
  }

  /**
   * Remove offline data
   * 
   * @param entity - Entity type
   * @param entityId - Entity ID
   * @returns True if data was removed
   */
  removeOfflineData(entity: string, entityId: string): boolean {
    return this.offlineData.delete(`${entity}_${entityId}`);
  }

  // ============================================================================
  // CONFLICT RESOLUTION
  // ============================================================================

  /**
   * Resolve conflict
   * 
   * @param entity - Entity type
   * @param entityId - Entity ID
   * @param serverData - Server data
   * @param clientData - Client data
   * @param resolution - Resolution strategy
   * @returns Conflict resolution result
   */
  resolveConflict(
    entity: string,
    entityId: string,
    serverData: any,
    clientData: any,
    resolution: 'server' | 'client' | 'merge' | 'manual'
  ): ConflictResolution {
    const conflictResolution: ConflictResolution = {
      id: `conflict_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      entity,
      entityId,
      serverData,
      clientData,
      resolution,
      resolvedAt: new Date().toISOString(),
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    this.conflictResolutions.set(conflictResolution.id, conflictResolution);
    return conflictResolution;
  }

  /**
   * Get conflict resolutions
   * 
   * @param filters - Optional filters for entity and resolution
   * @returns Array of conflict resolutions
   */
  getConflictResolutions(filters?: { entity?: string; resolution?: string }): ConflictResolution[] {
    let resolutions = Array.from(this.conflictResolutions.values());

    if (filters) {
      if (filters.entity) {
        resolutions = resolutions.filter(resolution => resolution.entity === filters.entity);
      }
      if (filters.resolution) {
        resolutions = resolutions.filter(resolution => resolution.resolution === filters.resolution);
      }
    }

    return resolutions.sort((a, b) => 
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    );
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get sync status
   * 
   * @returns Current sync status
   */
  getSyncStatus(): SyncStatus {
    const pendingActions = this.getOfflineActions({ status: 'pending' });
    const failedActions = this.getOfflineActions({ status: 'failed' });
    
    return {
      isOnline: this.isOnline,
      lastSync: this.lastSync,
      pendingActions: pendingActions.length,
      failedActions: failedActions.length,
      syncInProgress: this.syncInProgress,
      networkQuality: this.networkQuality,
      estimatedSyncTime: this.estimateSyncTime(pendingActions),
    };
  }

  /**
   * Get offline metrics
   * 
   * @returns Offline metrics
   */
  getOfflineMetrics(): OfflineMetrics {
    const allActions = this.getOfflineActions();
    const completedActions = allActions.filter(action => action.status === 'completed');
    const failedActions = allActions.filter(action => action.status === 'failed');
    const pendingActions = allActions.filter(action => action.status === 'pending');
    
    const dataSize = Array.from(this.offlineData.values()).reduce((size, data) => {
      return size + JSON.stringify(data.data).length;
    }, 0);

    return {
      totalActions: allActions.length,
      completedActions: completedActions.length,
      failedActions: failedActions.length,
      pendingActions: pendingActions.length,
      averageSyncTime: this.calculateAverageSyncTime(completedActions),
      dataSize,
      lastSync: this.lastSync,
      uptime: this.calculateUptime(),
      downtime: this.calculateDowntime(),
    };
  }

  /**
   * Estimate sync time
   * 
   * @param actions - Actions to sync
   * @returns Estimated sync time in seconds
   */
  private estimateSyncTime(actions: OfflineAction[]): number {
    // Base estimation: 1 second per action
    const baseTime = actions.length;
    
    // Adjust based on network quality
    const networkMultiplier = {
      'excellent': 1,
      'good': 1.5,
      'fair': 2,
      'poor': 3,
      'offline': 0,
    };
    
    return baseTime * (networkMultiplier[this.networkQuality] || 1);
  }

  /**
   * Calculate average sync time
   * 
   * @param actions - Completed actions
   * @returns Average sync time in seconds
   */
  private calculateAverageSyncTime(actions: OfflineAction[]): number {
    if (actions.length === 0) return 0;
    
    // This would need to be tracked during sync
    // For now, return a placeholder
    return 2.5;
  }

  /**
   * Calculate uptime
   * 
   * @returns Uptime percentage
   */
  private calculateUptime(): number {
    // This would need to be tracked over time
    // For now, return a placeholder
    return 95.5;
  }

  /**
   * Calculate downtime
   * 
   * @returns Downtime percentage
   */
  private calculateDowntime(): number {
    return 100 - this.calculateUptime();
  }

  /**
   * Clear completed actions
   * 
   * @returns Number of cleared actions
   */
  clearCompletedActions(): number {
    let clearedCount = 0;
    
    this.offlineActions.forEach((action, id) => {
      if (action.status === 'completed') {
        this.offlineActions.delete(id);
        clearedCount++;
      }
    });
    
    return clearedCount;
  }

  /**
   * Clear failed actions
   * 
   * @returns Number of cleared actions
   */
  clearFailedActions(): number {
    let clearedCount = 0;
    
    this.offlineActions.forEach((action, id) => {
      if (action.status === 'failed') {
        this.offlineActions.delete(id);
        clearedCount++;
      }
    });
    
    return clearedCount;
  }

  /**
   * Reset offline service
   */
  reset(): void {
    this.offlineActions.clear();
    this.offlineData.clear();
    this.conflictResolutions.clear();
    this.syncInProgress = false;
    this.lastSync = null;
  }

  // Private properties
  private networkQuality: 'excellent' | 'good' | 'fair' | 'poor' | 'offline' = 'good';
  private lastSync: string | null = null;
}

// Export singleton instance
export const offlineService = new OfflineService();
export default offlineService;
