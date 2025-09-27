/**
 * Unit tests for LoadingSpinner component
 */

import React from 'react';
import { render, screen } from '@testing-library/react-native';
import { LoadingSpinner } from '../../../src/components/common/LoadingSpinner';

describe('LoadingSpinner', () => {
  it('renders with default message', () => {
    render(<LoadingSpinner />);
    
    expect(screen.getByText('Loading...')).toBeTruthy();
    expect(screen.getByTestId('loading-spinner')).toBeTruthy();
  });

  it('renders with custom message', () => {
    const customMessage = 'Please wait...';
    render(<LoadingSpinner message={customMessage} />);
    
    expect(screen.getByText(customMessage)).toBeTruthy();
    expect(screen.getByTestId('loading-spinner')).toBeTruthy();
  });

  it('has proper accessibility label', () => {
    render(<LoadingSpinner message="Loading data" />);
    
    const spinner = screen.getByTestId('loading-spinner');
    expect(spinner.props.accessibilityLabel).toBe('Loading data');
  });

  it('renders ActivityIndicator', () => {
    render(<LoadingSpinner />);
    
    expect(screen.getByTestId('activity-indicator')).toBeTruthy();
  });

  it('applies correct styles', () => {
    render(<LoadingSpinner />);
    
    const container = screen.getByTestId('loading-container');
    expect(container.props.style).toMatchObject({
      flex: 1,
      justifyContent: 'center',
      alignItems: 'center',
      padding: 20,
    });
  });
});
