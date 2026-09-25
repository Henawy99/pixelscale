import React from 'react';
import { View, Text, StyleSheet, FlatList, TouchableOpacity } from 'react-native';
import { Star, Copy, Trash2, History } from 'lucide-react-native';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { HistoryItem } from '../types';

interface HistoryScreenProps {
  history: HistoryItem[];
  onDeleteHistoryItem: (id: string) => void;
  onSelectHistoryItem: (item: HistoryItem) => void;
}

export function HistoryScreen({
  history,
  onDeleteHistoryItem,
  onSelectHistoryItem,
}: HistoryScreenProps) {
  const handleCopy = async (text: string) => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await Clipboard.setStringAsync(text);
  };

  const handleDelete = (id: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onDeleteHistoryItem(id);
  };

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <View style={styles.headerIcon}>
          <History size={18} color="#ffffff" />
        </View>
        <Text style={styles.headerTitle}>Generated History ({history.length})</Text>
      </View>

      <FlatList
        data={history}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.listContent}
        renderItem={({ item }) => (
          <View style={styles.card}>
            <View style={styles.cardHeader}>
              <View style={styles.starsRow}>
                {[1, 2, 3, 4, 5].map((s) => (
                  <Star key={s} size={13} color="#f59e0b" fill="#f59e0b" />
                ))}
                <Text style={styles.starsText}>5.0 · {item.review?.tone}</Text>
              </View>

              <View style={styles.actionsRow}>
                <TouchableOpacity
                  style={styles.iconBtn}
                  onPress={() => handleCopy(item.review?.text || '')}
                >
                  <Copy size={14} color="#4f46e5" />
                </TouchableOpacity>

                <TouchableOpacity
                  style={styles.iconBtn}
                  onPress={() => handleDelete(item.id)}
                >
                  <Trash2 size={14} color="#e11d48" />
                </TouchableOpacity>
              </View>
            </View>

            <Text style={styles.tourTitle} numberOfLines={1}>
              {item.tour?.title || 'Tour Review'}
            </Text>

            <Text style={styles.reviewText} numberOfLines={4}>
              {item.review?.text}
            </Text>

            <Text style={styles.dateText}>
              {new Date(item.timestamp).toLocaleDateString()} · {item.photos?.length || 0} photos
            </Text>
          </View>
        )}
        ListEmptyComponent={
          <View style={styles.emptyContainer}>
            <Text style={styles.emptyTitle}>No history yet</Text>
            <Text style={styles.emptySubtitle}>
              Reviews generated in the Studio will appear here automatically.
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 16,
    paddingVertical: 12,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  headerIcon: {
    width: 30,
    height: 30,
    borderRadius: 8,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#0f172a',
  },
  listContent: {
    padding: 16,
    paddingBottom: 40,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  starsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  starsText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#64748b',
    marginLeft: 4,
  },
  actionsRow: {
    flexDirection: 'row',
    gap: 6,
  },
  iconBtn: {
    width: 30,
    height: 30,
    borderRadius: 8,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  tourTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 4,
  },
  reviewText: {
    fontSize: 12,
    color: '#475569',
    lineHeight: 18,
    marginBottom: 8,
  },
  dateText: {
    fontSize: 10,
    color: '#94a3b8',
    fontWeight: '600',
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#334155',
  },
  emptySubtitle: {
    fontSize: 12,
    color: '#94a3b8',
    marginTop: 4,
    textAlign: 'center',
  },
});
