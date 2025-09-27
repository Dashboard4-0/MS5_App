/**
 * Unit tests for JobCard component
 */

import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react-native';
import { JobCard } from '../../../src/components/jobs/JobCard';

describe('JobCard', () => {
  const defaultProps = {
    job: {
      id: '1',
      title: 'Production Job',
      description: 'Complete production run',
      status: 'assigned',
      priority: 'high',
      assignedTo: 'John Doe',
      dueDate: '2024-01-15T10:00:00Z',
      equipment: 'EQ-001',
    },
    onAccept: jest.fn(),
    onStart: jest.fn(),
    onComplete: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders job information', () => {
    render(<JobCard {...defaultProps} />);
    
    expect(screen.getByText('Production Job')).toBeTruthy();
    expect(screen.getByText('Complete production run')).toBeTruthy();
    expect(screen.getByText('John Doe')).toBeTruthy();
    expect(screen.getByText('EQ-001')).toBeTruthy();
  });

  it('displays job status', () => {
    render(<JobCard {...defaultProps} />);
    
    expect(screen.getByText('assigned')).toBeTruthy();
  });

  it('displays job priority', () => {
    render(<JobCard {...defaultProps} />);
    
    expect(screen.getByText('high')).toBeTruthy();
  });

  it('calls onAccept when accept button is pressed', () => {
    render(<JobCard {...defaultProps} />);
    
    const acceptButton = screen.getByTestId('accept-button');
    fireEvent.press(acceptButton);
    
    expect(defaultProps.onAccept).toHaveBeenCalledWith('1');
  });

  it('calls onStart when start button is pressed', () => {
    render(<JobCard {...defaultProps} />);
    
    const startButton = screen.getByTestId('start-button');
    fireEvent.press(startButton);
    
    expect(defaultProps.onStart).toHaveBeenCalledWith('1');
  });

  it('calls onComplete when complete button is pressed', () => {
    render(<JobCard {...defaultProps} />);
    
    const completeButton = screen.getByTestId('complete-button');
    fireEvent.press(completeButton);
    
    expect(defaultProps.onComplete).toHaveBeenCalledWith('1');
  });

  it('shows correct buttons based on status', () => {
    // Assigned status - should show accept button
    const { rerender } = render(<JobCard {...defaultProps} />);
    expect(screen.getByTestId('accept-button')).toBeTruthy();

    // Accepted status - should show start button
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'accepted' }} />);
    expect(screen.getByTestId('start-button')).toBeTruthy();

    // In progress status - should show complete button
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'in_progress' }} />);
    expect(screen.getByTestId('complete-button')).toBeTruthy();

    // Completed status - should show no action buttons
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'completed' }} />);
    expect(screen.queryByTestId('accept-button')).toBeNull();
    expect(screen.queryByTestId('start-button')).toBeNull();
    expect(screen.queryByTestId('complete-button')).toBeNull();
  });

  it('applies correct priority styling', () => {
    // High priority
    const { rerender } = render(<JobCard {...defaultProps} />);
    let priorityBadge = screen.getByTestId('priority-badge');
    expect(priorityBadge.props.style.backgroundColor).toBe('#F44336');

    // Medium priority
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, priority: 'medium' }} />);
    priorityBadge = screen.getByTestId('priority-badge');
    expect(priorityBadge.props.style.backgroundColor).toBe('#FFC107');

    // Low priority
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, priority: 'low' }} />);
    priorityBadge = screen.getByTestId('priority-badge');
    expect(priorityBadge.props.style.backgroundColor).toBe('#4CAF50');
  });

  it('applies correct status styling', () => {
    // Assigned status
    const { rerender } = render(<JobCard {...defaultProps} />);
    let statusBadge = screen.getByTestId('status-badge');
    expect(statusBadge.props.style.backgroundColor).toBe('#2196F3');

    // Accepted status
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'accepted' }} />);
    statusBadge = screen.getByTestId('status-badge');
    expect(statusBadge.props.style.backgroundColor).toBe('#FF9800');

    // In progress status
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'in_progress' }} />);
    statusBadge = screen.getByTestId('status-badge');
    expect(statusBadge.props.style.backgroundColor).toBe('#9C27B0');

    // Completed status
    rerender(<JobCard {...defaultProps} job={{ ...defaultProps.job, status: 'completed' }} />);
    statusBadge = screen.getByTestId('status-badge');
    expect(statusBadge.props.style.backgroundColor).toBe('#4CAF50');
  });

  it('formats due date correctly', () => {
    render(<JobCard {...defaultProps} />);
    
    expect(screen.getByText('Jan 15, 2024')).toBeTruthy();
  });

  it('renders with custom style', () => {
    const customStyle = { margin: 10 };
    render(<JobCard {...defaultProps} style={customStyle} />);
    
    const card = screen.getByTestId('job-card');
    expect(card.props.style).toMatchObject(customStyle);
  });

  it('has proper accessibility label', () => {
    render(<JobCard {...defaultProps} accessibilityLabel="Production Job assigned to John Doe" />);
    
    const card = screen.getByTestId('job-card');
    expect(card.props.accessibilityLabel).toBe('Production Job assigned to John Doe');
  });

  it('handles missing optional props', () => {
    const minimalProps = {
      job: {
        id: '1',
        title: 'Minimal Job',
        status: 'assigned',
      },
    };
    
    render(<JobCard {...minimalProps} />);
    
    expect(screen.getByText('Minimal Job')).toBeTruthy();
    expect(screen.getByText('assigned')).toBeTruthy();
  });
});
