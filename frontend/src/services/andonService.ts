/**
 * MS5.0 Floor Dashboard - Andon Service
 * 
 * This service handles Andon-related operations including Andon events,
 * escalations, and real-time notifications.
 */

import { apiService } from './api';

// Types
export interface AndonEvent {
  id: string;
  lineId: string;
  lineCode: string;
  equipmentId: string;
  equipmentName: string;
  eventType: 'fault' | 'maintenance' | 'quality' | 'safety' | 'material' | 'other';
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: 'active' | 'acknowledged' | 'resolved' | 'escalated';
  title: string;
  description: string;
  timestamp: string;
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  escalationLevel: number;
  maxEscalationLevel: number;
  assignedTo?: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface AndonEscalation {
  id: string;
  eventId: string;
  level: number;
  status: 'pending' | 'acknowledged' | 'resolved';
  escalatedBy: string;
  escalatedAt: string;
  acknowledgedBy?: string;
  acknowledgedAt?: string;
  resolvedBy?: string;
  resolvedAt?: string;
  escalationReason: string;
  notes?: string;
  created_at: string;
  updated_at: string;
}

export interface AndonNotification {
  id: string;
  eventId: string;
  userId: string;
  type: 'new_event' | 'escalation' | 'resolution' | 'acknowledgment';
  title: string;
  message: string;
  read: boolean;
  timestamp: string;
  created_at: string;
}

export interface AndonMetrics {
  totalEvents: number;
  activeEvents: number;
  resolvedEvents: number;
  escalatedEvents: number;
  averageResolutionTime: number;
  averageEscalationTime: number;
  eventsByType: Record<string, number>;
  eventsBySeverity: Record<string, number>;
  eventsByStatus: Record<string, number>;
}

/**
 * Andon Service Class
 * 
 * Provides methods for managing Andon events, escalations, and notifications.
 * Handles real-time event processing and escalation workflows.
 */
class AndonService {
  // ============================================================================
  // ANDON EVENTS
  // ============================================================================

  /**
   * Get Andon events
   * 
   * @param filters - Optional filters for line ID, status, and severity
   * @returns Promise resolving to Andon events
   */
  async getAndonEvents(filters?: { lineId?: string; status?: string; severity?: string }) {
    return apiService.getAndonEvents(filters);
  }

  /**
   * Get specific Andon event
   * 
   * @param eventId - Andon event ID
   * @returns Promise resolving to Andon event data
   */
  async getAndonEvent(eventId: string) {
    return apiService.getAndonEvent(eventId);
  }

  /**
   * Create new Andon event
   * 
   * @param eventData - Andon event data
   * @returns Promise resolving to created Andon event
   */
  async createAndonEvent(eventData: Partial<AndonEvent>) {
    return apiService.createAndonEvent(eventData);
  }

  /**
   * Update Andon event
   * 
   * @param eventId - Andon event ID
   * @param eventData - Updated Andon event data
   * @returns Promise resolving to updated Andon event
   */
  async updateAndonEvent(eventId: string, eventData: Partial<AndonEvent>) {
    return apiService.updateAndonEvent(eventId, eventData);
  }

  /**
   * Acknowledge Andon event
   * 
   * @param eventId - Andon event ID
   * @param notes - Optional acknowledgment notes
   * @returns Promise resolving to acknowledged Andon event
   */
  async acknowledgeAndonEvent(eventId: string, notes?: string) {
    return apiService.acknowledgeAndonEvent(eventId, notes);
  }

  /**
   * Resolve Andon event
   * 
   * @param eventId - Andon event ID
   * @param notes - Optional resolution notes
   * @returns Promise resolving to resolved Andon event
   */
  async resolveAndonEvent(eventId: string, notes?: string) {
    return apiService.resolveAndonEvent(eventId, notes);
  }

  /**
   * Escalate Andon event
   * 
   * @param eventId - Andon event ID
   * @param escalationReason - Reason for escalation
   * @param notes - Optional escalation notes
   * @returns Promise resolving to escalated Andon event
   */
  async escalateAndonEvent(eventId: string, escalationReason: string, notes?: string) {
    return apiService.escalateAndonEvent(eventId, escalationReason, notes);
  }

  // ============================================================================
  // ANDON ESCALATIONS
  // ============================================================================

  /**
   * Get Andon escalations
   * 
   * @param filters - Optional filters for event ID and status
   * @returns Promise resolving to Andon escalations
   */
  async getAndonEscalations(filters?: { eventId?: string; status?: string }) {
    return apiService.getAndonEscalations(filters);
  }

  /**
   * Get specific Andon escalation
   * 
   * @param escalationId - Andon escalation ID
   * @returns Promise resolving to Andon escalation data
   */
  async getAndonEscalation(escalationId: string) {
    return apiService.getAndonEscalation(escalationId);
  }

  /**
   * Acknowledge Andon escalation
   * 
   * @param escalationId - Andon escalation ID
   * @param notes - Optional acknowledgment notes
   * @returns Promise resolving to acknowledged Andon escalation
   */
  async acknowledgeEscalation(escalationId: string, notes?: string) {
    return apiService.acknowledgeEscalation(escalationId, notes);
  }

  /**
   * Resolve Andon escalation
   * 
   * @param escalationId - Andon escalation ID
   * @param notes - Optional resolution notes
   * @returns Promise resolving to resolved Andon escalation
   */
  async resolveEscalation(escalationId: string, notes?: string) {
    return apiService.resolveEscalation(escalationId, notes);
  }

  // ============================================================================
  // ANDON NOTIFICATIONS
  // ============================================================================

  /**
   * Get Andon notifications
   * 
   * @param filters - Optional filters for user ID and read status
   * @returns Promise resolving to Andon notifications
   */
  async getAndonNotifications(filters?: { userId?: string; read?: boolean }) {
    return apiService.getAndonNotifications(filters);
  }

  /**
   * Mark notification as read
   * 
   * @param notificationId - Notification ID
   * @returns Promise resolving when notification is marked as read
   */
  async markNotificationAsRead(notificationId: string) {
    return apiService.markNotificationAsRead(notificationId);
  }

  /**
   * Mark all notifications as read
   * 
   * @param userId - User ID
   * @returns Promise resolving when all notifications are marked as read
   */
  async markAllNotificationsAsRead(userId: string) {
    return apiService.markAllNotificationsAsRead(userId);
  }

  // ============================================================================
  // ANDON METRICS
  // ============================================================================

  /**
   * Get Andon metrics
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to Andon metrics
   */
  async getAndonMetrics(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getAndonMetrics(filters);
  }

  /**
   * Get Andon analytics
   * 
   * @param filters - Optional filters for line ID and date range
   * @returns Promise resolving to Andon analytics
   */
  async getAndonAnalytics(filters?: { lineId?: string; dateRange?: { start: string; end: string } }) {
    return apiService.getAndonAnalytics(filters);
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  /**
   * Get event type color
   * 
   * @param eventType - Andon event type
   * @returns Color code for event type
   */
  getEventTypeColor(eventType: string): string {
    const typeColors: Record<string, string> = {
      'fault': '#F44336',
      'maintenance': '#FF9800',
      'quality': '#9C27B0',
      'safety': '#F44336',
      'material': '#2196F3',
      'other': '#9E9E9E',
    };
    return typeColors[eventType] || '#9E9E9E';
  }

  /**
   * Get severity color
   * 
   * @param severity - Andon event severity
   * @returns Color code for severity
   */
  getSeverityColor(severity: string): string {
    const severityColors: Record<string, string> = {
      'low': '#4CAF50',
      'medium': '#FF9800',
      'high': '#FF5722',
      'critical': '#F44336',
    };
    return severityColors[severity] || '#9E9E9E';
  }

  /**
   * Get status color
   * 
   * @param status - Andon event status
   * @returns Color code for status
   */
  getStatusColor(status: string): string {
    const statusColors: Record<string, string> = {
      'active': '#F44336',
      'acknowledged': '#FF9800',
      'resolved': '#4CAF50',
      'escalated': '#9C27B0',
    };
    return statusColors[status] || '#9E9E9E';
  }

  /**
   * Get escalation level color
   * 
   * @param level - Escalation level
   * @param maxLevel - Maximum escalation level
   * @returns Color code for escalation level
   */
  getEscalationLevelColor(level: number, maxLevel: number): string {
    const percentage = (level / maxLevel) * 100;
    if (percentage >= 80) return '#F44336';
    if (percentage >= 60) return '#FF5722';
    if (percentage >= 40) return '#FF9800';
    if (percentage >= 20) return '#FFC107';
    return '#4CAF50';
  }

  /**
   * Format event duration
   * 
   * @param startTime - Event start time
   * @param endTime - Event end time (optional)
   * @returns Formatted duration string
   */
  formatEventDuration(startTime: string, endTime?: string): string {
    const start = new Date(startTime);
    const end = endTime ? new Date(endTime) : new Date();
    const duration = end.getTime() - start.getTime();
    
    const minutes = Math.floor(duration / (1000 * 60));
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
      return `${days}d ${hours % 24}h ${minutes % 60}m`;
    } else if (hours > 0) {
      return `${hours}h ${minutes % 60}m`;
    } else {
      return `${minutes}m`;
    }
  }

  /**
   * Get event priority score
   * 
   * @param severity - Event severity
   * @param escalationLevel - Escalation level
   * @param duration - Event duration in minutes
   * @returns Priority score (higher = more urgent)
   */
  getEventPriorityScore(severity: string, escalationLevel: number, duration: number): number {
    const severityScores: Record<string, number> = {
      'low': 1,
      'medium': 2,
      'high': 3,
      'critical': 4,
    };
    
    const severityScore = severityScores[severity] || 1;
    const escalationScore = escalationLevel * 0.5;
    const durationScore = Math.min(duration / 60, 2); // Cap at 2 hours
    
    return severityScore + escalationScore + durationScore;
  }

  /**
   * Get event urgency level
   * 
   * @param priorityScore - Event priority score
   * @returns Urgency level string
   */
  getEventUrgencyLevel(priorityScore: number): string {
    if (priorityScore >= 6) return 'Critical';
    if (priorityScore >= 4) return 'High';
    if (priorityScore >= 2) return 'Medium';
    return 'Low';
  }

  /**
   * Calculate resolution time
   * 
   * @param startTime - Event start time
   * @param endTime - Event end time
   * @returns Resolution time in minutes
   */
  calculateResolutionTime(startTime: string, endTime: string): number {
    const start = new Date(startTime);
    const end = new Date(endTime);
    return Math.floor((end.getTime() - start.getTime()) / (1000 * 60));
  }

  /**
   * Get event status icon
   * 
   * @param status - Event status
   * @returns Icon name for status
   */
  getEventStatusIcon(status: string): string {
    const statusIcons: Record<string, string> = {
      'active': 'warning',
      'acknowledged': 'check-circle',
      'resolved': 'check',
      'escalated': 'arrow-up',
    };
    return statusIcons[status] || 'circle';
  }

  /**
   * Get event type icon
   * 
   * @param eventType - Event type
   * @returns Icon name for event type
   */
  getEventTypeIcon(eventType: string): string {
    const typeIcons: Record<string, string> = {
      'fault': 'alert-triangle',
      'maintenance': 'wrench',
      'quality': 'shield-check',
      'safety': 'shield-alert',
      'material': 'package',
      'other': 'help-circle',
    };
    return typeIcons[eventType] || 'circle';
  }

  /**
   * Format event timestamp
   * 
   * @param timestamp - Event timestamp
   * @returns Formatted timestamp string
   */
  formatEventTimestamp(timestamp: string): string {
    const date = new Date(timestamp);
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    
    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);
    
    if (days > 0) {
      return `${days}d ago`;
    } else if (hours > 0) {
      return `${hours}h ago`;
    } else if (minutes > 0) {
      return `${minutes}m ago`;
    } else {
      return 'Just now';
    }
  }
}

// Export singleton instance
export const andonService = new AndonService();
export default andonService;
