import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ScrollView } from 'react-native';
import * as Haptics from 'expo-haptics';
import { FilterType } from '../types';

interface FilterTabsProps {
  selectedFilter: FilterType;
  onSelectFilter: (filter: FilterType) => void;
  counts: {
    all: number;
    normal: number;
    review: number;
    lastMinute: number;
    confirmed: number;
    cancelled: number;
  };
}

export function FilterTabs({
  selectedFilter,
  onSelectFilter,
  counts,
}: FilterTabsProps) {
  const tabs: { key: FilterType; label: string; count: number }[] = [
    { key: 'all', label: 'All', count: counts.all },
    { key: 'normal', label: 'Normal (≥€30)', count: counts.normal },
    { key: 'review', label: 'Review (<€30)', count: counts.review },
    { key: 'last-minute', label: 'Last Minute', count: counts.lastMinute },
    { key: 'confirmed', label: 'Confirmed', count: counts.confirmed },
    { key: 'cancelled', label: 'Cancelled', count: counts.cancelled },
  ];

  const handleSelect = (key: FilterType) => {
    Haptics.selectionAsync();
    onSelectFilter(key);
  };

  return (
    <View style={styles.container}>
      <ScrollView
        horizontal
        showsHorizontalScrollIndicator={false}
        contentContainerStyle={styles.scrollContent}
      >
        {tabs.map((tab) => {
          const isActive = selectedFilter === tab.key;
          return (
            <TouchableOpacity
              key={tab.key}
              onPress={() => handleSelect(tab.key)}
              style={[styles.pill, isActive && styles.pillActive]}
              activeOpacity={0.7}
            >
              <Text style={[styles.pillText, isActive && styles.pillTextActive]}>
                {tab.label}
              </Text>
              <View
                style={[
                  styles.countBadge,
                  isActive && styles.countBadgeActive,
                ]}
              >
                <Text
                  style={[
                    styles.countText,
                    isActive && styles.countTextActive,
                  ]}
                >
                  {tab.count}
                </Text>
              </View>
            </TouchableOpacity>
          );
        })}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    paddingVertical: 4,
  },
  scrollContent: {
    paddingHorizontal: 16,
    gap: 8,
  },
  pill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 20,
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  pillActive: {
    backgroundColor: '#4f46e5',
    borderColor: '#4f46e5',
  },
  pillText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#64748b',
  },
  pillTextActive: {
    color: '#ffffff',
  },
  countBadge: {
    paddingHorizontal: 6,
    paddingVertical: 1.5,
    borderRadius: 10,
    backgroundColor: '#f1f5f9',
  },
  countBadgeActive: {
    backgroundColor: 'rgba(255,255,255,0.25)',
  },
  countText: {
    fontSize: 10,
    fontWeight: '800',
    color: '#475569',
  },
  countTextActive: {
    color: '#ffffff',
  },
});
