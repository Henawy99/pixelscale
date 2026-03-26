import React from 'react';
import { createStackNavigator } from '@react-navigation/stack';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { LayoutDashboard, ShoppingBag, ClipboardList } from 'lucide-react-native';

import LoginScreen from '../screens/LoginScreen';
import DashboardScreen from '../screens/DashboardScreen';
import ProductsScreen from '../screens/ProductsScreen';
import OrdersScreen from '../screens/OrdersScreen';
import AddProductScreen from '../screens/AddProductScreen';
import EditProductScreen from '../screens/EditProductScreen';

const Stack = createStackNavigator();
const Tab = createBottomTabNavigator();

function MainTabs() {
  return (
    <Tab.Navigator
      screenOptions={{
        headerShown: true,
        headerStyle: { backgroundColor: '#1a1a1a' },
        headerTintColor: '#fff',
        tabBarStyle: { backgroundColor: '#1a1a1a', borderTopColor: '#333' },
        tabBarActiveTintColor: '#fbbf24',
        tabBarInactiveTintColor: '#666',
      }}
    >
      <Tab.Screen
        name="DashboardTab"
        component={DashboardScreen}
        options={{
          title: 'Dashboard',
          tabBarLabel: 'Home',
          tabBarIcon: ({ color, size }) => <LayoutDashboard size={size} color={color} />,
        }}
      />
      <Tab.Screen
        name="ProductsTab"
        component={ProductsScreen}
        options={{
          title: 'Products',
          tabBarLabel: 'Products',
          tabBarIcon: ({ color, size }) => <ShoppingBag size={size} color={color} />,
        }}
      />
      <Tab.Screen
        name="OrdersTab"
        component={OrdersScreen}
        options={{
          title: 'Orders',
          tabBarLabel: 'Orders',
          tabBarIcon: ({ color, size }) => <ClipboardList size={size} color={color} />,
        }}
      />
    </Tab.Navigator>
  );
}

export default function AppNavigator() {
  return (
    <Stack.Navigator screenOptions={{ headerShown: false }}>
      <Stack.Screen name="Login" component={LoginScreen} />
      <Stack.Screen name="Main" component={MainTabs} />
      <Stack.Screen name="AddProduct" component={AddProductScreen} options={{ presentation: 'modal' }} />
      <Stack.Screen name="EditProduct" component={EditProductScreen} options={{ presentation: 'modal' }} />
    </Stack.Navigator>
  );
}
