/**
 * MS5.0 Floor Dashboard - Admin Navigator
 * 
 * This navigator provides the main navigation structure for administrators,
 * including bottom tabs and stack navigation for admin-specific screens.
 */

import React from 'react';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createStackNavigator } from '@react-navigation/stack';
import { useSelector } from 'react-redux';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { RootState } from '../store';
import { selectUser } from '../store/slices/authSlice';

// Import screens
import SystemOverviewScreen from '../screens/admin/SystemOverviewScreen';
import UserManagementScreen from '../screens/admin/UserManagementScreen';
import SystemConfigurationScreen from '../screens/admin/SystemConfigurationScreen';
import AnalyticsScreen from '../screens/admin/AnalyticsScreen';
import ReportsScreen from '../screens/admin/ReportsScreen';
import ProfileScreen from '../screens/shared/ProfileScreen';
import UserDetailsScreen from '../screens/admin/UserDetailsScreen';
import SystemSettingsScreen from '../screens/admin/SystemSettingsScreen';
import ReportDetailsScreen from '../screens/admin/ReportDetailsScreen';
import AnalyticsDetailsScreen from '../screens/admin/AnalyticsDetailsScreen';

// Types
type AdminTabParamList = {
  SystemOverview: undefined;
  UserManagement: undefined;
  SystemConfiguration: undefined;
  Analytics: undefined;
  Reports: undefined;
  Profile: undefined;
};

type AdminStackParamList = {
  SystemOverview: undefined;
  UserManagement: undefined;
  SystemConfiguration: undefined;
  Analytics: undefined;
  Reports: undefined;
  Profile: undefined;
  UserDetails: { userId: string };
  SystemSettings: { category: string };
  ReportDetails: { reportId: string };
  AnalyticsDetails: { analyticsId: string };
};

const Tab = createBottomTabNavigator<AdminTabParamList>();
const Stack = createStackNavigator<AdminStackParamList>();

// Tab Navigator Component
const AdminTabNavigator: React.FC = () => {
  const user = useSelector(selectUser);

  return (
    <Tab.Navigator
      screenOptions={({ route }) => ({
        tabBarIcon: ({ focused, color, size }) => {
          let iconName: string;

          switch (route.name) {
            case 'SystemOverview':
              iconName = 'dashboard';
              break;
            case 'UserManagement':
              iconName = 'people';
              break;
            case 'SystemConfiguration':
              iconName = 'settings';
              break;
            case 'Analytics':
              iconName = 'analytics';
              break;
            case 'Reports':
              iconName = 'assessment';
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
        name="SystemOverview"
        component={SystemOverviewScreen}
        options={{
          title: 'Overview',
        }}
      />
      <Tab.Screen
        name="UserManagement"
        component={UserManagementScreen}
        options={{
          title: 'Users',
        }}
      />
      <Tab.Screen
        name="SystemConfiguration"
        component={SystemConfigurationScreen}
        options={{
          title: 'Config',
        }}
      />
      <Tab.Screen
        name="Analytics"
        component={AnalyticsScreen}
        options={{
          title: 'Analytics',
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
const AdminNavigator: React.FC = () => {
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
        name="SystemOverview"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="UserManagement"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="SystemConfiguration"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Analytics"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Reports"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="Profile"
        component={AdminTabNavigator}
        options={{ headerShown: false }}
      />
      <Stack.Screen
        name="UserDetails"
        component={UserDetailsScreen}
        options={{
          title: 'User Details',
          headerBackTitle: 'Back',
        }}
      />
      <Stack.Screen
        name="SystemSettings"
        component={SystemSettingsScreen}
        options={{
          title: 'System Settings',
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
        name="AnalyticsDetails"
        component={AnalyticsDetailsScreen}
        options={{
          title: 'Analytics Details',
          headerBackTitle: 'Back',
        }}
      />
    </Stack.Navigator>
  );
};

export default AdminNavigator;
