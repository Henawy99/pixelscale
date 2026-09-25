import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity, ActivityIndicator } from 'react-native';
import { RefreshCw, Settings, Sparkles } from 'lucide-react-native';
import * as Haptics from 'expo-haptics';

interface HeaderProps {
  isZohoConnected: boolean;
  isSyncing: boolean;
  onRefresh: () => void;
  onOpenSettings: () => void;
}

export function Header({
  isZohoConnected,
  isSyncing,
  onRefresh,
  onOpenSettings,
}: HeaderProps) {
  const handleRefresh = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onRefresh();
  };

  const handleSettings = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    onOpenSettings();
  };

  return (
    <View style={styles.container}>
      <View style={styles.brandRow}>
        <View style={styles.logoBadge}>
          <Sparkles size={18} color="#ffffff" />
        </View>
        <Text style={styles.brandTitle}>PixelReview</Text>
        <View style={styles.gygTag}>
          <Text style={styles.gygText}>GYG</Text>
        </View>
      </View>

      <View style={styles.actionsRow}>
        <View
          style={[
            styles.statusPill,
            isZohoConnected ? styles.statusPillLive : styles.statusPillDemo,
          ]}
        >
          <View
            style={[
              styles.statusDot,
              isZohoConnected ? styles.statusDotLive : styles.statusDotDemo,
            ]}
          />
          <Text
            style={[
              styles.statusText,
              isZohoConnected ? styles.statusTextLive : styles.statusTextDemo,
            ]}
          >
            {isZohoConnected ? 'Zoho Live' : 'Demo Mode'}
          </Text>
        </View>

        <TouchableOpacity
          onPress={handleRefresh}
          disabled={isSyncing}
          style={styles.iconBtn}
          activeOpacity={0.7}
        >
          {isSyncing ? (
            <ActivityIndicator size="small" color="#4f46e5" />
          ) : (
            <RefreshCw size={17} color="#475569" />
          )}
        </TouchableOpacity>

        <TouchableOpacity
          onPress={handleSettings}
          style={styles.iconBtn}
          activeOpacity={0.7}
        >
          <Settings size={18} color="#475569" />
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  brandRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  logoBadge: {
    width: 32,
    height: 32,
    borderRadius: 10,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  brandTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0f172a',
    letterSpacing: -0.4,
  },
  gygTag: {
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    backgroundColor: '#eef2ff',
  },
  gygText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#4f46e5',
  },
  actionsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  statusPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 9,
    paddingVertical: 4.5,
    borderRadius: 20,
    borderWidth: 1,
  },
  statusPillLive: {
    backgroundColor: '#ecfdf5',
    borderColor: '#a7f3d0',
  },
  statusPillDemo: {
    backgroundColor: '#fffbeb',
    borderColor: '#fde68a',
  },
  statusDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  statusDotLive: {
    backgroundColor: '#10b981',
  },
  statusDotDemo: {
    backgroundColor: '#f59e0b',
  },
  statusText: {
    fontSize: 11,
    fontWeight: '700',
  },
  statusTextLive: {
    color: '#065f46',
  },
  statusTextDemo: {
    color: '#92400e',
  },
  iconBtn: {
    width: 34,
    height: 34,
    borderRadius: 10,
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    alignItems: 'center',
    justifyContent: 'center',
  },
});
