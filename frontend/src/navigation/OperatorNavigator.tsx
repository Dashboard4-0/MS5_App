/**
 * MS5.0 Floor Dashboard - Operator Navigator
 * 
 * This navigator provides the main navigation structure for operators,
 * including bottom tabs and stack navigation for operator-specific screens.
 */

import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import { View, Text, StyleSheet } from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RootState } from '../store';
import { selectUser } from '../store/slices/authSlice';

// Import screens
import MyJobsScreen from '../screens/operator/MyJobsScreen';
import LineDashboardScreen from '../screens/operator/LineDashboardScreen';
import ChecklistScreen from '../screens/operator/ChecklistScreen';
import AndonScreen from '../screens/operator/AndonScreen';
import ProfileScreen from '../screens/shared/ProfileScreen';
import JobDetailsScreen from '../screens/operator/JobDetailsScreen';
import JobCountdownScreen from '../screens/operator/JobCountdownScreen';
import ChecklistFormScreen from '../screens/operator/ChecklistFormScreen';
import AndonFormScreen from '../screens/operator/AndonFormScreen';

// Types
type OperatorTabParamList = {
  MyJobs: undefined;
  LineDashboard: undefined;
  Checklist: undefined;
  Andon: undefined;
  Profile: undefined;
};

type OperatorStackParamList = {
  MyJobs: undefined;
  LineDashboard: undefined;
  Checklist: undefined;
  Andon: undefined;
  Profile: undefined;
  JobDetails: { jobId: string };
  JobCountdown: { jobId: string };
  ChecklistForm: { jobId: string; templateId: string };
  AndonForm: { lineId: string };
};

const Tab = createBottomTabNavigator<OperatorTabParamList>();
const Stack = createStackNavigator<OperatorStackParamList>();

// Tab Navigator Component
const OperatorTabNavigator: React.FC = () => {
  const user = useSelector(selectUser);

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'MyJobs':
              iconName = 'work';
              break;
            case 'LineDashboard':
              iconName = 'dashboard';
              break;
            case 'Checklist':
              iconName = 'checklist';
              break;
            case 'Andon':
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
        name="MyJobs"
        component={MyJobsScreen}
        options={{
          title: 'My Jobs',
          tabBarBadge: () => {
            // TODO: Add badge for pending jobs
            return null;
          },
        }}
      />
      <Tab.Screen
        name="LineDashboard"
        component={LineDashboardScreen}
        options={{
          title: 'Dashboard',
        }}
      />
      <Tab.Screen
        name="Checklist"
        component={ChecklistScreen}
        options={{
          title: 'Checklist',
        }}
      />
      <Tab.Screen
        name="Andon"
        component={AndonScreen}
        options={{
          title: 'Andon',
          tabBarBadge: () => {
            // TODO: Add badge for active Andon events
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
const OperatorNavigator: React.FC = () => {
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
        name="MyJobs"
        component={OperatorTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="LineDashboard"
        component={OperatorTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Checklist"
        component={OperatorTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Andon"
        component={OperatorTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Profile"
        component={OperatorTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="JobDetails"
        component={JobDetailsScreen}
        options={{
          title: 'Job Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="JobCountdown"
        component={JobCountdownScreen}
        options={{
          title: 'Job Countdown',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="ChecklistForm"
        component={ChecklistFormScreen}
        options={{
          title: 'Pre-start Checklist',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="AndonForm"
        component={AndonFormScreen}
        options={{
          title: 'Create Andon Event',
          headerBackTitle: 'Back',
        }}
      />
    </Stack.Navigator>
  );
};

export default OperatorNavigator;
