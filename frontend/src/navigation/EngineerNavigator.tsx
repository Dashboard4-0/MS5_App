/**
 * MS5.0 Floor Dashboard - Engineer Navigator
 * 
 * This navigator provides the main navigation structure for engineers
 * and maintenance technicians, including bottom tabs and stack navigation
 * for engineering-specific screens.
 */

import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RootState } from '../store';
import { selectUser } from '../store/slices/authSlice';

// Import screens
import EquipmentStatusScreen from '../screens/engineer/EquipmentStatusScreen';
import FaultAnalysisScreen from '../screens/engineer/FaultAnalysisScreen';
import MaintenanceScreen from '../screens/engineer/MaintenanceScreen';
import DiagnosticsScreen from '../screens/engineer/DiagnosticsScreen';
import AndonResolutionScreen from '../screens/engineer/AndonResolutionScreen';
import ProfileScreen from '../screens/shared/ProfileScreen';
import EquipmentDetailsScreen from '../screens/engineer/EquipmentDetailsScreen';
import FaultDetailsScreen from '../screens/engineer/FaultDetailsScreen';
import MaintenanceWorkOrderScreen from '../screens/engineer/MaintenanceWorkOrderScreen';
import DiagnosticDetailsScreen from '../screens/engineer/DiagnosticDetailsScreen';
import AndonEventDetailsScreen from '../screens/engineer/AndonEventDetailsScreen';

// Types
type EngineerTabParamList = {
  EquipmentStatus: undefined;
  FaultAnalysis: undefined;
  Maintenance: undefined;
  Diagnostics: undefined;
  AndonResolution: undefined;
  Profile: undefined;
};

type EngineerStackParamList = {
  EquipmentStatus: undefined;
  FaultAnalysis: undefined;
  Maintenance: undefined;
  Diagnostics: undefined;
  AndonResolution: undefined;
  Profile: undefined;
  EquipmentDetails: { equipmentCode: string };
  FaultDetails: { faultId: string };
  MaintenanceWorkOrder: { workOrderId: string };
  DiagnosticDetails: { diagnosticId: string };
  AndonEventDetails: { eventId: string };
};

const Tab = createBottomTabNavigator<EngineerTabParamList>();
const Stack = createStackNavigator<EngineerStackParamList>();

// Tab Navigator Component
const EngineerTabNavigator: React.FC = () => {
  const user = useSelector(selectUser);

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'EquipmentStatus':
              iconName = 'build';
              break;
            case 'FaultAnalysis':
              iconName = 'bug-report';
              break;
            case 'Maintenance':
              iconName = 'handyman';
              break;
            case 'Diagnostics':
              iconName = 'analytics';
              break;
            case 'AndonResolution':
              iconName = 'warning';
              break;
            case 'Profile':
              iconName = 'person';
              break;
            default:
              iconName = 'help';
          }

          return <Icon name={iconName} size={size} color={color} />;
        },
        tabBarActiveTintColor: '#2196F3',
        tabBarInactiveTintColor: '#757575',
        tabBarStyle: {
          backgroundColor: '#FFFFFF',
          borderTopWidth: 1,
          borderTopColor: '#E0E0E0',
          height: 60,
          paddingBottom: 8,
          paddingTop: 8,
        },
        tabBarLabelStyle: {
          fontSize: 12,
          fontWeight: '500',
        },
        headerShown: false,
      })}
    >
      <Tab.Screen
        name="EquipmentStatus"
        component={EquipmentStatusScreen}
        options={{
          title: 'Equipment',
        }}
      />
      <Tab.Screen
        name="FaultAnalysis"
        component={FaultAnalysisScreen}
        options={{
          title: 'Faults',
        }}
      />
      <Tab.Screen
        name="Maintenance"
        component={MaintenanceScreen}
        options={{
          title: 'Maintenance',
        }}
      />
      <Tab.Screen
        name="Diagnostics"
        component={DiagnosticsScreen}
        options={{
          title: 'Diagnostics',
        }}
      />
      <Tab.Screen
        name="AndonResolution"
        component={AndonResolutionScreen}
        options={{
          title: 'Andon',
          tabBarBadge: () => {
            // TODO: Add badge for active Andon events requiring resolution
            return null;
          },
        }}
      />
      <Tab.Screen
        name="Profile"
        component={ProfileScreen}
        options={{
          title: 'Profile',
        }}
      />
    </Tab.Navigator>
  );
};

// Main Stack Navigator Component
const EngineerNavigator: React.FC = () => {
  return (
    <Stack.Navigator
      screenOptions={{
        headerShown: true,
        headerStyle: {
          backgroundColor: '#2196F3',
        },
        headerTintColor: '#FFFFFF',
        headerTitleStyle: {
          fontWeight: 'bold',
          fontSize: 18,
        },
        headerBackTitleVisible: false,
      }}
    >
      <Stack.Screen
        name="EquipmentStatus"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="FaultAnalysis"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Maintenance"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Diagnostics"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="AndonResolution"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Profile"
        component={EngineerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="EquipmentDetails"
        component={EquipmentDetailsScreen}
        options={{
          title: 'Equipment Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="FaultDetails"
        component={FaultDetailsScreen}
        options={{
          title: 'Fault Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="MaintenanceWorkOrder"
        component={MaintenanceWorkOrderScreen}
        options={{
          title: 'Work Order',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="DiagnosticDetails"
        component={DiagnosticDetailsScreen}
        options={{
          title: 'Diagnostic Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="AndonEventDetails"
        component={AndonEventDetailsScreen}
        options={{
          title: 'Andon Event',
          headerBackTitle: 'Back',
        }}
      />
    </Stack.Navigator>
  );
};

export default EngineerNavigator;
