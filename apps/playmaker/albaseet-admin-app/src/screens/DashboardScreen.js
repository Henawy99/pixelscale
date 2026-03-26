import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, ScrollView, RefreshControl, TouchableOpacity, SafeAreaView } from 'react-native';
import { ShoppingBag, ClipboardList, AlertTriangle, Play, Package, Users, Eye } from 'lucide-react-native';
import { supabase, ALBASEET_PRODUCTS_TABLE, ALBASEET_ORDERS_TABLE } from '../config/supabase';

export default function DashboardScreen({ navigation }) {
  const [stats, setStats] = useState({
    totalProducts: 0,
    lowStock: 0,
    totalOrders: 0,
    pendingOrders: 0,
    visitorsToday: 0,
    pageViewsToday: 0,
  });
  const [refreshing, setRefreshing] = useState(false);

  const fetchStats = async () => {
    try {
      const { data: products } = await supabase.from(ALBASEET_PRODUCTS_TABLE).select('sizes');
      const { data: orders } = await supabase.from(ALBASEET_ORDERS_TABLE).select('order_status');

      const lowStock = products?.filter(p => {
        const total = p.sizes?.reduce((sum, s) => sum + (s.stock || 0), 0) || 0;
        return total > 0 && total <= 10;
      }).length || 0;

      // Fetch today's analytics from Supabase
      const todayStart = new Date();
      todayStart.setHours(0, 0, 0, 0);

      let visitorsToday = 0;
      let pageViewsToday = 0;

      try {
        const { data: pageViews } = await supabase
          .from('albaseet_page_views')
          .select('visitor_id')
          .gte('created_at', todayStart.toISOString());

        if (pageViews) {
          pageViewsToday = pageViews.length;
          const uniqueVisitors = new Set(pageViews.map(pv => pv.visitor_id));
          visitorsToday = uniqueVisitors.size;
        }
      } catch (e) {
        // Table might not exist yet
      }

      setStats({
        totalProducts: products?.length || 0,
        lowStock,
        totalOrders: orders?.length || 0,
        pendingOrders: orders?.filter(o => o.order_status === 'pending').length || 0,
        visitorsToday,
        pageViewsToday,
      });
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  useEffect(() => {
    fetchStats();
    const unsubscribe = navigation.addListener('focus', () => {
      fetchStats();
    });
    return unsubscribe;
  }, [navigation]);

  const onRefresh = React.useCallback(async () => {
    setRefreshing(true);
    await fetchStats();
    setRefreshing(false);
  }, []);

  const StatCard = ({ title, value, icon: Icon, color, onPress }) => (
    <TouchableOpacity style={styles.card} onPress={onPress} activeOpacity={onPress ? 0.7 : 1}>
      <View style={[styles.iconContainer, { backgroundColor: `${color}20` }]}>
        <Icon size={24} color={color} />
      </View>
      <View>
        <Text style={styles.cardValue}>{value}</Text>
        <Text style={styles.cardTitle}>{title}</Text>
      </View>
    </TouchableOpacity>
  );

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView
        contentContainerStyle={styles.scrollContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fbbf24" />}
      >
        <View style={styles.header}>
          <Text style={[styles.greeting, {color: '#666'}]}>Welcome back,</Text>
          <Text style={styles.title}>Admin Panel</Text>
        </View>

        {/* Visitor Stats Row */}
        <View style={styles.visitorRow}>
          <View style={styles.visitorCard}>
            <View style={styles.visitorIconWrap}>
              <Users size={20} color="#10b981" />
            </View>
            <Text style={styles.visitorValue}>{stats.visitorsToday}</Text>
            <Text style={styles.visitorLabel}>Visitors Today</Text>
          </View>
          <View style={styles.visitorCard}>
            <View style={[styles.visitorIconWrap, { backgroundColor: '#8b5cf620' }]}>
              <Eye size={20} color="#8b5cf6" />
            </View>
            <Text style={styles.visitorValue}>{stats.pageViewsToday}</Text>
            <Text style={styles.visitorLabel}>Page Views</Text>
          </View>
        </View>

        <View style={styles.statsGrid}>
          <StatCard
            title="Total Orders"
            value={stats.totalOrders}
            icon={ClipboardList}
            color="#3b82f6"
            onPress={() => navigation.navigate('OrdersTab')}
          />
          <StatCard
            title="Pending Orders"
            value={stats.pendingOrders}
            icon={Play}
            color="#fbbf24"
            onPress={() => navigation.navigate('OrdersTab')}
          />
          <StatCard
            title="Products"
            value={stats.totalProducts}
            icon={Package}
            color="#10b981"
            onPress={() => navigation.navigate('ProductsTab')}
          />
          <StatCard
            title="Low Stock"
            value={stats.lowStock}
            icon={AlertTriangle}
            color="#ef4444"
            onPress={() => navigation.navigate('ProductsTab')}
          />
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Quick Overview</Text>
          <View style={styles.infoBox}>
            <Text style={styles.infoText}>
              Your store is currently running normally. {stats.lowStock} products are running low on stock.
              {'\n\n'}Today you have {stats.visitorsToday} unique visitor{stats.visitorsToday !== 1 ? 's' : ''} with {stats.pageViewsToday} page view{stats.pageViewsToday !== 1 ? 's' : ''}.
            </Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  scrollContent: {
    padding: 20,
  },
  header: {
    marginBottom: 24,
    marginTop: 10,
  },
  greeting: {
    fontSize: 16,
    color: '#666',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#fff',
  },
  visitorRow: {
    flexDirection: 'row',
    gap: 16,
    marginBottom: 20,
  },
  visitorCard: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#333',
    alignItems: 'center',
  },
  visitorIconWrap: {
    width: 40,
    height: 40,
    borderRadius: 12,
    backgroundColor: '#10b98120',
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 12,
  },
  visitorValue: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#fff',
  },
  visitorLabel: {
    fontSize: 13,
    color: '#666',
    marginTop: 4,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 16,
    marginBottom: 32,
  },
  card: {
    width: '47%',
    backgroundColor: '#1a1a1a',
    borderRadius: 20,
    padding: 20,
    borderWidth: 1,
    borderColor: '#333',
    gap: 12,
  },
  iconContainer: {
    width: 44,
    height: 44,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  cardValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
  },
  cardTitle: {
    fontSize: 13,
    color: '#666',
    marginTop: 2,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 16,
  },
  infoBox: {
    backgroundColor: '#1a1a1a',
    borderRadius: 16,
    padding: 20,
    borderWidth: 1,
    borderColor: '#333',
  },
  infoText: {
    color: '#aaa',
    lineHeight: 22,
  },
});
