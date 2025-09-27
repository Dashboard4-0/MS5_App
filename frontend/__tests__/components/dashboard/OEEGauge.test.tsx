/**
 * Unit tests for OEEGauge component
 */

import React from 'react';
import { render, screen } from '@testing-library/react-native';
import { OEEGauge } from '../../../src/components/dashboard/OEEGauge';

describe('OEEGauge', () => {
  const defaultProps = {
    oee: 0.85,
    availability: 0.9,
    performance: 0.95,
    quality: 0.95,
  };

  it('renders with OEE data', () => {
    render(<OEEGauge {...defaultProps} />);
    
    expect(screen.getByTestId('oee-gauge')).toBeTruthy();
    expect(screen.getByText('85%')).toBeTruthy();
  });

  it('displays OEE value correctly', () => {
    render(<OEEGauge {...defaultProps} oee={0.75} />);
    
    expect(screen.getByText('75%')).toBeTruthy();
  });

  it('displays availability value', () => {
    render(<OEEGauge {...defaultProps} />);
    
    expect(screen.getByText('90%')).toBeTruthy();
  });

  it('displays performance value', () => {
    render(<OEEGauge {...defaultProps} />);
    
    expect(screen.getByText('95%')).toBeTruthy();
  });

  it('displays quality value', () => {
    render(<OEEGauge {...defaultProps} />);
    
    expect(screen.getByText('95%')).toBeTruthy();
  });

  it('renders with custom title', () => {
    render(<OEEGauge {...defaultProps} title="Line 1 OEE" />);
    
    expect(screen.getByText('Line 1 OEE')).toBeTruthy();
  });

  it('renders with custom size', () => {
    render(<OEEGauge {...defaultProps} size={200} />);
    
    const gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.style).toMatchObject({
      width: 200,
      height: 200,
    });
  });

  it('applies correct color based on OEE value', () => {
    // High OEE (green)
    const { rerender } = render(<OEEGauge {...defaultProps} oee={0.85} />);
    let gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.style.borderColor).toBe('#4CAF50');

    // Medium OEE (yellow)
    rerender(<OEEGauge {...defaultProps} oee={0.65} />);
    gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.style.borderColor).toBe('#FFC107');

    // Low OEE (red)
    rerender(<OEEGauge {...defaultProps} oee={0.45} />);
    gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.style.borderColor).toBe('#F44336');
  });

  it('handles zero OEE value', () => {
    render(<OEEGauge {...defaultProps} oee={0} />);
    
    expect(screen.getByText('0%')).toBeTruthy();
  });

  it('handles maximum OEE value', () => {
    render(<OEEGauge {...defaultProps} oee={1} />);
    
    expect(screen.getByText('100%')).toBeTruthy();
  });

  it('renders with loading state', () => {
    render(<OEEGauge {...defaultProps} loading />);
    
    expect(screen.getByTestId('loading-spinner')).toBeTruthy();
  });

  it('has proper accessibility label', () => {
    render(<OEEGauge {...defaultProps} accessibilityLabel="OEE gauge showing 85%" />);
    
    const gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.accessibilityLabel).toBe('OEE gauge showing 85%');
  });

  it('renders with custom style', () => {
    const customStyle = { margin: 10 };
    render(<OEEGauge {...defaultProps} style={customStyle} />);
    
    const gauge = screen.getByTestId('oee-gauge');
    expect(gauge.props.style).toMatchObject(customStyle);
  });
});
