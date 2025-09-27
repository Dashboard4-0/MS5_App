/**
 * MS5.0 Floor Dashboard - Formatters
 * 
 * Utility functions for formatting data display including dates,
 * numbers, percentages, and other common formats.
 */

import { DATE_FORMATS } from '../config/constants';

// Date and Time Formatters
export const formatDateTime = (dateString: string, format: string = DATE_FORMATS.DISPLAY): string => {
  try {
    const date = new Date(dateString);
    if (isNaN(date.getTime())) {
      return 'Invalid Date';
    }

    switch (format) {
      case DATE_FORMATS.DISPLAY:
        return date.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'short',
          day: '2-digit',
        });
      case DATE_FORMATS.SHORT:
        return date.toLocaleDateString('en-US', {
          month: '2-digit',
          day: '2-digit',
          year: '2-digit',
        });
      case DATE_FORMATS.LONG:
        return date.toLocaleDateString('en-US', {
          year: 'numeric',
          month: 'long',
          day: 'numeric',
        });
      case DATE_FORMATS.TIME:
        return date.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
        });
      case DATE_FORMATS.DATETIME:
        return date.toLocaleString('en-US', {
          year: 'numeric',
          month: 'short',
          day: '2-digit',
          hour: '2-digit',
          minute: '2-digit',
        });
      case DATE_FORMATS.ISO:
        return date.toISOString();
      default:
        return date.toLocaleDateString();
    }
  } catch (error) {
    console.error('Error formatting date:', error);
    return 'Invalid Date';
  }
};

export const formatTime = (dateString: string): string => {
  return formatDateTime(dateString, DATE_FORMATS.TIME);
};

export const formatDate = (dateString: string): string => {
  return formatDateTime(dateString, DATE_FORMATS.DISPLAY);
};

export const formatRelativeTime = (dateString: string): string => {
  try {
    const date = new Date(dateString);
    const now = new Date();
    const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);

    if (diffInSeconds < 60) {
      return 'Just now';
    } else if (diffInSeconds < 3600) {
      const minutes = Math.floor(diffInSeconds / 60);
      return `${minutes} minute${minutes > 1 ? 's' : ''} ago`;
    } else if (diffInSeconds < 86400) {
      const hours = Math.floor(diffInSeconds / 3600);
      return `${hours} hour${hours > 1 ? 's' : ''} ago`;
    } else if (diffInSeconds < 2592000) {
      const days = Math.floor(diffInSeconds / 86400);
      return `${days} day${days > 1 ? 's' : ''} ago`;
    } else {
      return formatDate(dateString);
    }
  } catch (error) {
    console.error('Error formatting relative time:', error);
    return 'Unknown time';
  }
};

// Number Formatters
export const formatNumber = (value: number, decimals: number = 0): string => {
  if (isNaN(value)) return '0';
  return value.toLocaleString('en-US', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
};

export const formatCurrency = (value: number, currency: string = 'USD'): string => {
  if (isNaN(value)) return '$0.00';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency,
  }).format(value);
};

export const formatPercentage = (value: number, decimals: number = 1): string => {
  if (isNaN(value)) return '0%';
  return `${(value * 100).toFixed(decimals)}%`;
};

export const formatOEE = (value: number): string => {
  return formatPercentage(value, 1);
};

// Duration Formatters
export const formatDuration = (seconds: number): string => {
  if (isNaN(seconds) || seconds < 0) return '0s';

  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const remainingSeconds = Math.floor(seconds % 60);

  if (hours > 0) {
    return `${hours}h ${minutes}m ${remainingSeconds}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${remainingSeconds}s`;
  } else {
    return `${remainingSeconds}s`;
  }
};

export const formatDurationShort = (seconds: number): string => {
  if (isNaN(seconds) || seconds < 0) return '0s';

  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);

  if (hours > 0) {
    return `${hours}h ${minutes}m`;
  } else if (minutes > 0) {
    return `${minutes}m`;
  } else {
    return `${Math.floor(seconds)}s`;
  }
};

// File Size Formatters
export const formatFileSize = (bytes: number): string => {
  if (isNaN(bytes) || bytes < 0) return '0 B';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = bytes;
  let unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  return `${size.toFixed(1)} ${units[unitIndex]}`;
};

// Status Formatters
export const formatStatus = (status: string): string => {
  return status
    .split('_')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(' ');
};

export const formatPriority = (priority: string): string => {
  return priority.charAt(0).toUpperCase() + priority.slice(1).toLowerCase();
};

// Phone Number Formatters
export const formatPhoneNumber = (phoneNumber: string): string => {
  const cleaned = phoneNumber.replace(/\D/g, '');
  const match = cleaned.match(/^(\d{3})(\d{3})(\d{4})$/);
  
  if (match) {
    return `(${match[1]}) ${match[2]}-${match[3]}`;
  }
  
  return phoneNumber;
};

// Text Formatters
export const truncateText = (text: string, maxLength: number): string => {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength) + '...';
};

export const capitalizeFirst = (text: string): string => {
  if (!text) return '';
  return text.charAt(0).toUpperCase() + text.slice(1).toLowerCase();
};

export const capitalizeWords = (text: string): string => {
  if (!text) return '';
  return text
    .split(' ')
    .map(word => capitalizeFirst(word))
    .join(' ');
};

// Validation Formatters
export const formatEmail = (email: string): string => {
  return email.toLowerCase().trim();
};

export const formatUsername = (username: string): string => {
  return username.toLowerCase().trim();
};

// OEE Specific Formatters
export const formatOEEStatus = (oee: number): { status: string; color: string } => {
  if (oee >= 0.85) {
    return { status: 'Excellent', color: '#4CAF50' };
  } else if (oee >= 0.70) {
    return { status: 'Good', color: '#8BC34A' };
  } else if (oee >= 0.50) {
    return { status: 'Fair', color: '#FF9800' };
  } else {
    return { status: 'Poor', color: '#F44336' };
  }
};

// Production Formatters
export const formatProductionRate = (rate: number): string => {
  return `${formatNumber(rate, 1)} units/hour`;
};

export const formatEfficiency = (efficiency: number): string => {
  return formatPercentage(efficiency, 1);
};

// Error Formatters
export const formatError = (error: any): string => {
  if (typeof error === 'string') {
    return error;
  }
  
  if (error?.message) {
    return error.message;
  }
  
  if (error?.error) {
    return error.error;
  }
  
  return 'An unknown error occurred';
};

// Data Table Formatters
export const formatTableValue = (value: any, type: 'text' | 'number' | 'date' | 'currency' | 'percentage'): string => {
  switch (type) {
    case 'number':
      return formatNumber(Number(value));
    case 'date':
      return formatDateTime(String(value));
    case 'currency':
      return formatCurrency(Number(value));
    case 'percentage':
      return formatPercentage(Number(value));
    default:
      return String(value || '');
  }
};

// Export all formatters
export default {
  formatDateTime,
  formatTime,
  formatDate,
  formatRelativeTime,
  formatNumber,
  formatCurrency,
  formatPercentage,
  formatOEE,
  formatDuration,
  formatDurationShort,
  formatFileSize,
  formatStatus,
  formatPriority,
  formatPhoneNumber,
  truncateText,
  capitalizeFirst,
  capitalizeWords,
  formatEmail,
  formatUsername,
  formatOEEStatus,
  formatProductionRate,
  formatEfficiency,
  formatError,
  formatTableValue,
};
