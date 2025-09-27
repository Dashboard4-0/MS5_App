/**
 * MS5.0 Floor Dashboard - Signature Pad Component
 * 
 * A signature capture component for digital signatures in checklists
 * with drawing capabilities and signature validation.
 */

import React, { useRef, useState, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ViewStyle,
  PanResponder,
  Dimensions,
  Alert,
} from 'react-native';
import Svg, { Path, G } from 'react-native-svg';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';
import Button from '../common/Button';

// Types
interface SignaturePadProps {
  onSignatureComplete?: (signatureData: string) => void;
  onClear?: () => void;
  width?: number;
  height?: number;
  strokeWidth?: number;
  strokeColor?: string;
  backgroundColor?: string;
  showClearButton?: boolean;
  showSaveButton?: boolean;
  disabled?: boolean;
  style?: ViewStyle;
  testID?: string;
}

interface Point {
  x: number;
  y: number;
}

const { width: screenWidth } = Dimensions.get('window');
const defaultWidth = screenWidth - (SPACING.LARGE * 2);
const defaultHeight = 200;

const SignaturePad: React.FC<SignaturePadProps> = ({
  onSignatureComplete,
  onClear,
  width = defaultWidth,
  height = defaultHeight,
  strokeWidth = 3,
  strokeColor = COLORS.TEXT.PRIMARY,
  backgroundColor = COLORS.BACKGROUND.PRIMARY,
  showClearButton = true,
  showSaveButton = true,
  disabled = false,
  style,
  testID,
}) => {
  const [paths, setPaths] = useState<string[]>([]);
  const [currentPath, setCurrentPath] = useState<string>('');
  const [isDrawing, setIsDrawing] = useState(false);
  const [hasSignature, setHasSignature] = useState(false);
  const [lastPoint, setLastPoint] = useState<Point | null>(null);

  const panResponder = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => !disabled,
      onMoveShouldSetPanResponder: () => !disabled,
      
      onPanResponderGrant: (evt) => {
        if (disabled) return;
        
        const { locationX, locationY } = evt.nativeEvent;
        const newPath = `M${locationX},${locationY}`;
        setCurrentPath(newPath);
        setIsDrawing(true);
        setLastPoint({ x: locationX, y: locationY });
      },
      
      onPanResponderMove: (evt) => {
        if (disabled || !isDrawing) return;
        
        const { locationX, locationY } = evt.nativeEvent;
        const newPoint = { x: locationX, y: locationY };
        
        if (lastPoint) {
          const distance = Math.sqrt(
            Math.pow(newPoint.x - lastPoint.x, 2) + Math.pow(newPoint.y - lastPoint.y, 2)
          );
          
          // Only add point if it's far enough from the last point
          if (distance > 2) {
            const newPath = `${currentPath} L${locationX},${locationY}`;
            setCurrentPath(newPath);
            setLastPoint(newPoint);
          }
        }
      },
      
      onPanResponderRelease: () => {
        if (disabled || !isDrawing) return;
        
        if (currentPath) {
          setPaths(prev => [...prev, currentPath]);
          setHasSignature(true);
        }
        setCurrentPath('');
        setIsDrawing(false);
        setLastPoint(null);
      },
    })
  ).current;

  const handleClear = () => {
    setPaths([]);
    setCurrentPath('');
    setHasSignature(false);
    onClear?.();
  };

  const handleSave = () => {
    if (!hasSignature) {
      Alert.alert('No Signature', 'Please draw a signature before saving.');
      return;
    }

    // Convert paths to SVG string
    const svgData = `
      <svg width="${width}" height="${height}" xmlns="http://www.w3.org/2000/svg">
        <g>
          ${paths.map((path, index) => (
            `<path key="${index}" d="${path}" stroke="${strokeColor}" stroke-width="${strokeWidth}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`
          )).join('')}
          ${currentPath ? `<path d="${currentPath}" stroke="${strokeColor}" stroke-width="${strokeWidth}" fill="none" stroke-linecap="round" stroke-linejoin="round"/>` : ''}
        </g>
      </svg>
    `;

    onSignatureComplete?.(svgData);
  };

  const renderPaths = () => {
    return (
      <G>
        {paths.map((path, index) => (
          <Path
            key={index}
            d={path}
            stroke={strokeColor}
            strokeWidth={strokeWidth}
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        ))}
        {currentPath && (
          <Path
            d={currentPath}
            stroke={strokeColor}
            strokeWidth={strokeWidth}
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        )}
      </G>
    );
  };

  return (
    <View style={[styles.container, style]} testID={testID}>
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.title}>Digital Signature</Text>
        <Text style={styles.subtitle}>Sign below to complete the checklist</Text>
      </View>

      {/* Signature Area */}
      <View style={styles.signatureContainer}>
        <View
          style={[
            styles.signaturePad,
            {
              width,
              height,
              backgroundColor,
              borderColor: disabled ? COLORS.BORDER.DISABLED : COLORS.BORDER.DEFAULT,
            },
          ]}
          {...panResponder.panHandlers}
        >
          <Svg width={width} height={height}>
            {renderPaths()}
          </Svg>
          
          {/* Placeholder when empty */}
          {!hasSignature && !isDrawing && (
            <View style={styles.placeholder}>
              <Text style={styles.placeholderText}>Draw your signature here</Text>
            </View>
          )}
        </View>
      </View>

      {/* Instructions */}
      <View style={styles.instructions}>
        <Text style={styles.instructionText}>
          • Use your finger or stylus to draw your signature
        </Text>
        <Text style={styles.instructionText}>
          • Make sure your signature is clear and readable
        </Text>
        <Text style={styles.instructionText}>
          • You can clear and redraw if needed
        </Text>
      </View>

      {/* Actions */}
      <View style={styles.actions}>
        {showClearButton && (
          <Button
            title="Clear"
            variant="outline"
            size="medium"
            onPress={handleClear}
            disabled={disabled || !hasSignature}
            style={styles.actionButton}
            testID={`${testID}-clear-button`}
          />
        )}
        
        {showSaveButton && (
          <Button
            title="Save Signature"
            variant="primary"
            size="medium"
            onPress={handleSave}
            disabled={disabled || !hasSignature}
            style={styles.actionButton}
            testID={`${testID}-save-button`}
          />
        )}
      </View>

      {/* Signature Status */}
      <View style={styles.statusContainer}>
        <View style={[
          styles.statusIndicator,
          { backgroundColor: hasSignature ? COLORS.SUCCESS : COLORS.WARNING }
        ]} />
        <Text style={styles.statusText}>
          {hasSignature ? 'Signature captured' : 'No signature yet'}
        </Text>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    borderRadius: 12,
    padding: SPACING.MEDIUM,
    marginVertical: SPACING.SMALL,
  },
  
  // Header
  header: {
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    marginBottom: SPACING.XS,
  },
  subtitle: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    textAlign: 'center',
  },
  
  // Signature area
  signatureContainer: {
    alignItems: 'center',
    marginBottom: SPACING.MEDIUM,
  },
  signaturePad: {
    borderWidth: 2,
    borderStyle: 'dashed',
    borderRadius: 8,
    position: 'relative',
    overflow: 'hidden',
  },
  placeholder: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    justifyContent: 'center',
    alignItems: 'center',
  },
  placeholderText: {
    fontSize: TYPOGRAPHY.SIZES.MEDIUM,
    color: COLORS.TEXT.PLACEHOLDER,
    textAlign: 'center',
  },
  
  // Instructions
  instructions: {
    marginBottom: SPACING.MEDIUM,
    paddingHorizontal: SPACING.SMALL,
  },
  instructionText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    marginBottom: SPACING.XS,
  },
  
  // Actions
  actions: {
    flexDirection: 'row',
    justifyContent: 'center',
    marginBottom: SPACING.MEDIUM,
  },
  actionButton: {
    marginHorizontal: SPACING.SMALL,
    minWidth: 120,
  },
  
  // Status
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statusIndicator: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginRight: SPACING.XS,
  },
  statusText: {
    fontSize: TYPOGRAPHY.SIZES.SMALL,
    color: COLORS.TEXT.SECONDARY,
    fontWeight: '500',
  },
});

export default SignaturePad;
