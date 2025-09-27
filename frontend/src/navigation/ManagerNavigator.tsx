/**
 * MS5.0 Floor Dashboard - Manager Navigator
 * 
 * This navigator provides the main navigation structure for managers
 * (Shift Manager and Production Manager), including bottom tabs and
 * stack navigation for management-specific screens.
 */

import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RootState } from '../store';
import { selectUser } from '../store/slices/authSlice';

// Import screens
import ProductionOverviewScreen from '../screens/manager/ProductionOverviewScreen';
import ScheduleManagementScreen from '../screens/manager/ScheduleManagementScreen';
import TeamManagementScreen from '../screens/manager/TeamManagementScreen';
import ReportsScreen from '../screens/manager/ReportsScreen';
import AndonManagementScreen from '../screens/manager/AndonManagementScreen';
import ProfileScreen from '../screens/shared/ProfileScreen';
import LineDetailsScreen from '../screens/manager/LineDetailsScreen';
import ScheduleDetailsScreen from '../screens/manager/ScheduleDetailsScreen';
import TeamMemberDetailsScreen from '../screens/manager/TeamMemberDetailsScreen';
import ReportDetailsScreen from '../screens/manager/ReportDetailsScreen';
import AndonEventDetailsScreen from '../screens/manager/AndonEventDetailsScreen';

// Types
type ManagerTabParamList = {
  ProductionOverview: undefined;
  ScheduleManagement: undefined;
  TeamManagement: undefined;
  Reports: undefined;
  AndonManagement: undefined;
  Profile: undefined;
};

type ManagerStackParamList = {
  ProductionOverview: undefined;
  ScheduleManagement: undefined;
  TeamManagement: undefined;
  Reports: undefined;
  AndonManagement: undefined;
  Profile: undefined;
  LineDetails: { lineId: string };
  ScheduleDetails: { scheduleId: string };
  TeamMemberDetails: { userId: string };
  ReportDetails: { reportId: string };
  AndonEventDetails: { eventId: string };
};

const Tab = createBottomTabNavigator<ManagerTabParamList>();
const Stack = createStackNavigator<ManagerStackParamList>();

// Tab Navigator Component
const ManagerTabNavigator: React.FC = () => {
  const user = useSelector(selectUser);

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'ProductionOverview':
              iconName = 'dashboard';
              break;
            case 'ScheduleManagement':
              iconName = 'schedule';
              break;
            case 'TeamManagement':
              iconName = 'group';
              break;
            case 'Reports':
              iconName = 'assessment';
              break;
            case 'AndonManagement':
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
        name="ProductionOverview"
        component={ProductionOverviewScreen}
        options={{
          title: 'Overview',
        }}
      />
      <Tab.Screen
        name="ScheduleManagement"
        component={ScheduleManagementScreen}
        options={{
          title: 'Schedule',
        }}
      />
      <Tab.Screen
        name="TeamManagement"
        component={TeamManagementScreen}
        options={{
          title: 'Team',
        }}
      />
      <Tab.Screen
        name="Reports"
        component={ReportsScreen}
        options={{
          title: 'Reports',
        }}
      />
      <Tab.Screen
        name="AndonManagement"
        component={AndonManagementScreen}
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
const ManagerNavigator: React.FC = () => {
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
        name="ProductionOverview"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="ScheduleManagement"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="TeamManagement"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Reports"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="AndonManagement"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Profile"
        component={ManagerTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="LineDetails"
        component={LineDetailsScreen}
        options={{
          title: 'Line Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="ScheduleDetails"
        component={ScheduleDetailsScreen}
        options={{
          title: 'Schedule Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="TeamMemberDetails"
        component={TeamMemberDetailsScreen}
        options={{
          title: 'Team Member',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="ReportDetails"
        component={ReportDetailsScreen}
        options={{
          title: 'Report Details',
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

export default ManagerNavigator;
