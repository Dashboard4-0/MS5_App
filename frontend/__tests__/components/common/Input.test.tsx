/**
 * Unit tests for Input component
 */

import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react-native';
import { Input } from '../../../src/components/common/Input';

describe('Input', () => {
  const defaultProps = {
    label: 'Test Label',
    value: '',
    onChangeText: jest.fn(),
  };

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('renders with label', () => {
    render(<Input {...defaultProps} />);
    
    expect(screen.getByText('Test Label')).toBeTruthy();
    expect(screen.getByTestId('input-field')).toBeTruthy();
  });

  it('renders with placeholder', () => {
    render(<Input {...defaultProps} placeholder="Enter text" />);
    
    expect(screen.getByPlaceholderText('Enter text')).toBeTruthy();
  });

  it('calls onChangeText when text changes', () => {
    const onChangeText = jest.fn();
    render(<Input {...defaultProps} onChangeText={onChangeText} />);
    
    const input = screen.getByTestId('input-field');
    fireEvent.changeText(input, 'New text');
    
    expect(onChangeText).toHaveBeenCalledWith('New text');
  });

  it('displays error message when provided', () => {
    render(<Input {...defaultProps} error="This field is required" />);
    
    expect(screen.getByText('This field is required')).toBeTruthy();
  });

  it('renders as secure text entry when password type', () => {
    render(<Input {...defaultProps} type="password" />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.secureTextEntry).toBe(true);
  });

  it('renders as numeric input when type is number', () => {
    render(<Input {...defaultProps} type="number" />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.keyboardType).toBe('numeric');
  });

  it('renders as email input when type is email', () => {
    render(<Input {...defaultProps} type="email" />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.keyboardType).toBe('email-address');
  });

  it('applies disabled state', () => {
    render(<Input {...defaultProps} disabled />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.editable).toBe(false);
  });

  it('renders with multiline when specified', () => {
    render(<Input {...defaultProps} multiline />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.multiline).toBe(true);
  });

  it('renders with required indicator', () => {
    render(<Input {...defaultProps} required />);
    
    expect(screen.getByText('*')).toBeTruthy();
  });

  it('has proper accessibility label', () => {
    render(<Input {...defaultProps} accessibilityLabel="Test input field" />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.accessibilityLabel).toBe('Test input field');
  });

  it('renders with custom style', () => {
    const customStyle = { backgroundColor: 'red' };
    render(<Input {...defaultProps} style={customStyle} />);
    
    const input = screen.getByTestId('input-field');
    expect(input.props.style).toMatchObject(customStyle);
  });
});
