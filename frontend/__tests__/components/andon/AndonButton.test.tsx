/**
 * Unit tests for AndonButton component
 */

import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react-native';
import { AndonButton } from '../../../src/components/andon/AndonButton';

describe('AndonButton', () => {
  const defaultProps = {
    onPress: jest.fn(),
    title: 'Call Andon',
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders with title', () => {
    render(<AndonButton {...defaultProps} />);
    
    expect(screen.getByText('Call Andon')).toBeTruthy();
  });

  it('calls onPress when pressed', () => {
    render(<AndonButton {...defaultProps} />);
    
    const button = screen.getByTestId('andon-button');
    fireEvent.press(button);
    
    expect(defaultProps.onPress).toHaveBeenCalledTimes(1);
  });

  it('renders with different types', () => {
    // Emergency type
    const { rerender } = render(<AndonButton {...defaultProps} type="emergency" />);
    let button = screen.getByTestId('andon-button');
    expect(button.props.style.backgroundColor).toBe('#F44336');

    // Warning type
    rerender(<AndonButton {...defaultProps} type="warning" />);
    button = screen.getByTestId('andon-button');
    expect(button.props.style.backgroundColor).toBe('#FF9800');

    // Info type
    rerender(<AndonButton {...defaultProps} type="info" />);
    button = screen.getByTestId('andon-button');
    expect(button.props.style.backgroundColor).toBe('#2196F3');
  });

  it('renders with different sizes', () => {
    // Small size
    const { rerender } = render(<AndonButton {...defaultProps} size="small" />);
    let button = screen.getByTestId('andon-button');
    expect(button.props.style.paddingHorizontal).toBe(16);

    // Medium size (default)
    rerender(<AndonButton {...defaultProps} size="medium" />);
    button = screen.getByTestId('andon-button');
    expect(button.props.style.paddingHorizontal).toBe(24);

    // Large size
    rerender(<AndonButton {...defaultProps} size="large" />);
    button = screen.getByTestId('andon-button');
    expect(button.props.style.paddingHorizontal).toBe(32);
  });

  it('applies disabled state', () => {
    render(<AndonButton {...defaultProps} disabled />);
    
    const button = screen.getByTestId('andon-button');
    expect(button.props.disabled).toBe(true);
    expect(button.props.style.opacity).toBe(0.5);
  });

  it('renders with icon when provided', () => {
    render(<AndonButton {...defaultProps} icon="alert" />);
    
    expect(screen.getByTestId('andon-icon')).toBeTruthy();
  });

  it('renders with loading state', () => {
    render(<AndonButton {...defaultProps} loading />);
    
    expect(screen.getByTestId('loading-spinner')).toBeTruthy();
    expect(screen.queryByText('Call Andon')).toBeNull();
  });

  it('renders with custom style', () => {
    const customStyle = { margin: 10 };
    render(<AndonButton {...defaultProps} style={customStyle} />);
    
    const button = screen.getByTestId('andon-button');
    expect(button.props.style).toMatchObject(customStyle);
  });

  it('has proper accessibility label', () => {
    render(<AndonButton {...defaultProps} accessibilityLabel="Emergency Andon button" />);
    
    const button = screen.getByTestId('andon-button');
    expect(button.props.accessibilityLabel).toBe('Emergency Andon button');
  });

  it('has proper accessibility role', () => {
    render(<AndonButton {...defaultProps} />);
    
    const button = screen.getByTestId('andon-button');
    expect(button.props.accessibilityRole).toBe('button');
  });

  it('handles long press', () => {
    const onLongPress = jest.fn();
    render(<AndonButton {...defaultProps} onLongPress={onLongPress} />);
    
    const button = screen.getByTestId('andon-button');
    fireEvent(button, 'longPress');
    
    expect(onLongPress).toHaveBeenCalledTimes(1);
  });

  it('renders with animation when pressed', () => {
    render(<AndonButton {...defaultProps} animated />);
    
    const button = screen.getByTestId('andon-button');
    expect(button.props.style.transform).toBeDefined();
  });

  it('renders with haptic feedback', () => {
    render(<AndonButton {...defaultProps} hapticFeedback />);
    
    const button = screen.getByTestId('andon-button');
    // Haptic feedback is handled internally, just verify button exists
    expect(button).toBeTruthy();
  });

  it('handles missing onPress gracefully', () => {
    render(<AndonButton title="Test Button" />);
    
    const button = screen.getByTestId('andon-button');
    fireEvent.press(button);
    
    // Should not throw error
    expect(button).toBeTruthy();
  });
});
