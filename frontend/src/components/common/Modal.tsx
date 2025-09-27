/**
 * MS5.0 Floor Dashboard - Modal Component
 * 
 * A reusable modal component with various styles and animations
 * optimized for tablet use with proper touch targets.
 */

import React, { useEffect } from 'react';
import {
  Modal as RNModal,
  View,
  Text,
  StyleSheet,
  ViewStyle,
  TextStyle,
  TouchableOpacity,
  TouchableWithoutFeedback,
  Dimensions,
  KeyboardAvoidingView,
  Platform,
  ScrollView,
} from 'react-native';
import { COLORS, TYPOGRAPHY, SPACING, TOUCH_TARGETS } from '../../config/constants';

// Types
interface ModalProps {
  visible: boolean;
  onClose: () => void;
  title?: string;
  children: React.ReactNode;
  variant?: 'default' | 'fullscreen' | 'bottomSheet' | 'center';
  size?: 'small' | 'medium' | 'large' | 'full';
  showCloseButton?: boolean;
  closeOnBackdropPress?: boolean;
  closeOnEscape?: boolean;
  animationType?: 'slide' | 'fade' | 'none';
  containerStyle?: ViewStyle;
  contentStyle?: ViewStyle;
  titleStyle?: TextStyle;
  testID?: string;
}

const { width: screenWidth, height: screenHeight } = Dimensions.get('window');

const Modal: React.FC<ModalProps> = ({
  visible,
  onClose,
  title,
  children,
  variant = 'default',
  size = 'medium',
  showCloseButton = true,
  closeOnBackdropPress = true,
  closeOnEscape = true,
  animationType = 'slide',
  containerStyle,
  contentStyle,
  titleStyle,
  testID,
}) => {
  useEffect(() => {
    if (closeOnEscape && visible) {
      const handleEscape = (event: KeyboardEvent) => {
        if (event.key === 'Escape') {
          onClose();
        }
      };
      
      document.addEventListener('keydown', handleEscape);
      return () => document.removeEventListener('keydown', handleEscape);
    }
  }, [visible, closeOnEscape, onClose]);

  const handleBackdropPress = () => {
    if (closeOnBackdropPress) {
      onClose();
    }
  };

  const getModalStyle = () => {
    const baseStyle = [styles.modal, styles[variant]];
    
    switch (size) {
      case 'small':
        return [...baseStyle, styles.small];
      case 'medium':
        return [...baseStyle, styles.medium];
      case 'large':
        return [...baseStyle, styles.large];
      case 'full':
        return [...baseStyle, styles.full];
      default:
        return [...baseStyle, styles.medium];
    }
  };

  const getContentStyle = () => {
    const baseStyle = [styles.content, styles[`${variant}Content`]];
    return [...baseStyle, contentStyle];
  };

  const renderHeader = () => {
    if (!title && !showCloseButton) return null;
    
    return (
      <View style={styles.header}>
        {title && (
          <Text style={[styles.title, titleStyle]} numberOfLines={2}>
            {title}
          </Text>
        )}
        {showCloseButton && (
          <TouchableOpacity
            style={styles.closeButton}
            onPress={onClose}
            hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
            testID={`${testID}-close-button`}
          >
            <Text style={styles.closeButtonText}>×</Text>
          </TouchableOpacity>
        )}
      </View>
    );
  };

  const renderContent = () => {
    if (variant === 'fullscreen') {
      return (
        <View style={getContentStyle()}>
          {renderHeader()}
          <ScrollView style={styles.scrollContent} showsVerticalScrollIndicator={false}>
            {children}
          </ScrollView>
        </View>
      );
    }
    
    return (
      <View style={getContentStyle()}>
        {renderHeader()}
        <View style={styles.body}>
          {children}
        </View>
      </View>
    );
  };

  return (
    <RNModal
      visible={visible}
      transparent
      animationType={animationType}
      onRequestClose={onClose}
      testID={testID}
    >
      <KeyboardAvoidingView
        style={styles.overlay}
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
      >
        <TouchableWithoutFeedback onPress={handleBackdropPress}>
          <View style={styles.backdrop} />
        </TouchableWithoutFeedback>
        
        <View style={[getModalStyle(), containerStyle]}>
          {renderContent()}
        </View>
      </KeyboardAvoidingView>
    </RNModal>
  );
};

const styles = StyleSheet.create({
  overlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  backdrop: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
  },
  
  // Modal variants
  modal: {
    backgroundColor: COLORS.BACKGROUND.PRIMARY,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 4,
    },
    shadowOpacity: 0.25,
    shadowRadius: 8,
    elevation: 8,
  },
  default: {
    maxWidth: screenWidth * 0.9,
    maxHeight: screenHeight * 0.8,
  },
  fullscreen: {
    width: screenWidth,
    height: screenHeight,
    borderRadius: 0,
  },
  bottomSheet: {
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    borderTopLeftRadius: 20,
    borderTopRightRadius: 20,
    borderBottomLeftRadius: 0,
    borderBottomRightRadius: 0,
  },
  center: {
    maxWidth: screenWidth * 0.8,
    maxHeight: screenHeight * 0.6,
  },
  
  // Modal sizes
  small: {
    width: screenWidth * 0.4,
    minHeight: 200,
  },
  medium: {
    width: screenWidth * 0.6,
    minHeight: 300,
  },
  large: {
    width: screenWidth * 0.8,
    minHeight: 400,
  },
  full: {
    width: screenWidth * 0.95,
    height: screenHeight * 0.9,
  },
  
  // Content styles
  content: {
    flex: 1,
  },
  defaultContent: {
    padding: SPACING.MEDIUM,
  },
  fullscreenContent: {
    flex: 1,
  },
  bottomSheetContent: {
    padding: SPACING.MEDIUM,
    paddingBottom: SPACING.LARGE,
  },
  centerContent: {
    padding: SPACING.LARGE,
  },
  
  // Header styles
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: SPACING.MEDIUM,
    paddingBottom: SPACING.SMALL,
    borderBottomWidth: 1,
    borderBottomColor: COLORS.BORDER.DEFAULT,
  },
  title: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '700',
    color: COLORS.TEXT.PRIMARY,
    flex: 1,
    marginRight: SPACING.SMALL,
  },
  closeButton: {
    width: TOUCH_TARGETS.MIN_SIZE,
    height: TOUCH_TARGETS.MIN_SIZE,
    borderRadius: TOUCH_TARGETS.MIN_SIZE / 2,
    backgroundColor: COLORS.BACKGROUND.SECONDARY,
    alignItems: 'center',
    justifyContent: 'center',
  },
  closeButtonText: {
    fontSize: TYPOGRAPHY.SIZES.LARGE,
    fontWeight: '600',
    color: COLORS.TEXT.SECONDARY,
    lineHeight: TYPOGRAPHY.SIZES.LARGE,
  },
  
  // Body styles
  body: {
    flex: 1,
  },
  scrollContent: {
    flex: 1,
  },
});

export default Modal;
