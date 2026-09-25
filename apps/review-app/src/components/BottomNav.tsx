import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import {
  CalendarCheck2,
  CalendarDays,
  Users,
  Sparkles,
  Settings2,
} from 'lucide-react-native';
import * as Haptics from 'expo-haptics';
import { ActiveTab } from '../types';

interface BottomNavProps {
  activeTab: ActiveTab;
  onSelectTab: (tab: ActiveTab) => void;
  bookingsCount: number;
}

export function BottomNav({ activeTab, onSelectTab, bookingsCount }: BottomNavProps) {
  const insets = useSafeAreaInsets();

  const handlePress = (tab: ActiveTab) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onSelectTab(tab);
  };

  return (
    <View style={[styles.container, { paddingBottom: Math.max(insets.bottom, 10) }]}>
      {/* 1. Bookings Tab */}
      <TouchableOpacity
        style={styles.tabItem}
        onPress={() => handlePress('bookings')}
        activeOpacity={0.7}
      >
        <View style={styles.iconWrapper}>
          <CalendarCheck2
            size={20}
            color={activeTab === 'bookings' ? '#4f46e5' : '#94a3b8'}
          />
          {bookingsCount > 0 && (
            <View style={styles.badge}>
              <Text style={styles.badgeText}>
                {bookingsCount > 99 ? '99+' : bookingsCount}
              </Text>
            </View>
          )}
        </View>
        <Text
          style={[
            styles.tabLabel,
            activeTab === 'bookings' && styles.tabLabelActive,
          ]}
        >
          Bookings
        </Text>
      </TouchableOpacity>

      {/* 2. Calendar Tab */}
      <TouchableOpacity
        style={styles.tabItem}
        onPress={() => handlePress('calendar')}
        activeOpacity={0.7}
      >
        <View style={styles.iconWrapper}>
          <CalendarDays
            size={20}
            color={activeTab === 'calendar' ? '#4f46e5' : '#94a3b8'}
          />
        </View>
        <Text
          style={[
            styles.tabLabel,
            activeTab === 'calendar' && styles.tabLabelActive,
          ]}
        >
          Calendar
        </Text>
      </TouchableOpacity>

      {/* 3. Drivers Tab */}
      <TouchableOpacity
        style={styles.tabItem}
        onPress={() => handlePress('drivers')}
        activeOpacity={0.7}
      >
        <View style={styles.iconWrapper}>
          <Users
            size={20}
            color={activeTab === 'drivers' ? '#4f46e5' : '#94a3b8'}
          />
        </View>
        <Text
          style={[
            styles.tabLabel,
            activeTab === 'drivers' && styles.tabLabelActive,
          ]}
        >
          Drivers
        </Text>
      </TouchableOpacity>

      {/* 4. Review Studio Tab */}
      <TouchableOpacity
        style={styles.tabItem}
        onPress={() => handlePress('studio')}
        activeOpacity={0.7}
      >
        <View style={styles.iconWrapper}>
          <Sparkles
            size={20}
            color={activeTab === 'studio' ? '#4f46e5' : '#94a3b8'}
          />
        </View>
        <Text
          style={[
            styles.tabLabel,
            activeTab === 'studio' && styles.tabLabelActive,
          ]}
        >
          Reviews
        </Text>
      </TouchableOpacity>

      {/* 5. Settings Tab */}
      <TouchableOpacity
        style={styles.tabItem}
        onPress={() => handlePress('settings')}
        activeOpacity={0.7}
      >
        <View style={styles.iconWrapper}>
          <Settings2
            size={20}
            color={activeTab === 'settings' ? '#4f46e5' : '#94a3b8'}
          />
        </View>
        <Text
          style={[
            styles.tabLabel,
            activeTab === 'settings' && styles.tabLabelActive,
          ]}
        >
          Settings
        </Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    backgroundColor: '#ffffff',
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
    paddingTop: 8,
  },
  tabItem: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
  },
  iconWrapper: {
    position: 'relative',
    padding: 2,
  },
  badge: {
    position: 'absolute',
    top: -3,
    right: -8,
    backgroundColor: '#ef4444',
    borderRadius: 8,
    paddingHorizontal: 4,
    paddingVertical: 1,
    minWidth: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  badgeText: {
    color: '#ffffff',
    fontSize: 9,
    fontWeight: '800',
  },
  tabLabel: {
    fontSize: 10,
    fontWeight: '600',
    color: '#94a3b8',
    marginTop: 3,
  },
  tabLabelActive: {
    color: '#4f46e5',
    fontWeight: '800',
  },
});
