import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, FlatList, TouchableOpacity, RefreshControl, SafeAreaView, Modal } from 'react-native';
import { ClipboardList, Clock, CheckCircle, Truck, XCircle, ChevronRight, Phone, User, Home } from 'lucide-react-native';
import { supabase, ALBASEET_ORDERS_TABLE } from '../config/supabase';

export default function OrdersScreen() {
  const [orders, setOrders] = useState([]);
  const [refreshing, setRefreshing] = useState(false);
  const [selectedOrder, setSelectedOrder] = useState(null);

  const fetchOrders = async () => {
    try {
      const { data, error } = await supabase
        .from(ALBASEET_ORDERS_TABLE)
        .select('*')
        .order('created_at', { ascending: false });
      if (data) setOrders(data);
    } catch (error) {
      console.error('Error fetching orders:', error);
    }
  };

  useEffect(() => {
    fetchOrders();
  }, []);

  const onRefresh = React.useCallback(async () => {
    setRefreshing(true);
    await fetchOrders();
    setRefreshing(false);
  }, []);

  const getStatusIcon = (status) => {
    switch (status) {
      case 'pending': return <Clock size={16} color="#fbbf24" />;
      case 'processing': return <Clock size={16} color="#3b82f6" />;
      case 'shipped': return <Truck size={16} color="#a855f7" />;
      case 'delivered': return <CheckCircle size={16} color="#10b981" />;
      default: return <XCircle size={16} color="#ef4444" />;
    }
  };

  const OrderItem = ({ item }) => (
    <TouchableOpacity style={styles.orderCard} onPress={() => setSelectedOrder(item)}>
      <View style={styles.orderHeader}>
        <View style={styles.customerInfo}>
          <Text style={styles.customerName}>{item.customer_name}</Text>
          <Text style={styles.orderDate}>
            {new Date(item.created_at).toLocaleDateString()}
          </Text>
        </View>
        <View style={styles.orderStatus}>
          {getStatusIcon(item.order_status)}
          <Text style={[styles.statusText, { color: getStatusColor(item.order_status)}]}>
            {item.order_status.toUpperCase()}
          </Text>
        </View>
      </View>
      <View style={styles.orderFooter}>
        <Text style={styles.itemCount}>{item.items?.length || 0} Items</Text>
        <Text style={styles.orderTotal}>{item.total_amount.toLocaleString()} EGP</Text>
      </View>
    </TouchableOpacity>
  );

  const getStatusColor = (status) => {
    switch (status) {
      case 'pending': return '#fbbf24';
      case 'processing': return '#3b82f6';
      case 'shipped': return '#a855f7';
      case 'delivered': return '#10b981';
      default: return '#ef4444';
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <FlatList
        data={orders}
        renderItem={({ item }) => <OrderItem item={item} />}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fbbf24" />}
      />

      {/* Basic Detail View (Simplified) */}
      <Modal visible={!!selectedOrder} animationType="slide" transparent={true}>
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Order Details</Text>
              <TouchableOpacity onPress={() => setSelectedOrder(null)}>
                <XCircle size={24} color="#666" />
              </TouchableOpacity>
            </View>

            {selectedOrder && (
              <ScrollView style={styles.modalBody}>
                <View style={styles.detailSection}>
                  <View style={styles.detailRow}><User size={16} color="#666" /><Text style={styles.detailText}>{selectedOrder.customer_name}</Text></View>
                  <View style={styles.detailRow}><Phone size={16} color="#666" /><Text style={styles.detailText}>{selectedOrder.customer_phone}</Text></View>
                  <View style={styles.detailRow}><Home size={16} color="#666" /><Text style={styles.detailText}>{selectedOrder.customer_address}</Text></View>
                </View>

                <Text style={styles.itemsHeader}>ITEMS</Text>
                {selectedOrder.items?.map((item, idx) => (
                  <View key={idx} style={styles.itemRow}>
                    <Text style={styles.itemName}>{item.name}</Text>
                    <Text style={styles.itemPrice}>{item.price} x {item.quantity}</Text>
                  </View>
                ))}
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  listContent: {
    padding: 16,
  },
  orderCard: {
    backgroundColor: '#1a1a1a',
    borderRadius: 16,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#333',
  },
  orderHeader: {
    flexDirection: 'row',
    justifyContent: 'between',
    marginBottom: 12,
  },
  customerInfo: {
    flex: 1,
  },
  customerName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#fff',
  },
  orderDate: {
    fontSize: 12,
    color: '#666',
    marginTop: 2,
  },
  orderStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  statusText: {
    fontSize: 12,
    fontWeight: 'bold',
  },
  orderFooter: {
    flexDirection: 'row',
    justifyContent: 'between',
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: '#333',
  },
  itemCount: {
    color: '#666',
    fontSize: 14,
  },
  orderTotal: {
    color: '#fbbf24',
    fontWeight: 'bold',
    fontSize: 14,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.8)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#1a1a1a',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 24,
    maxHeight: '80%',
  },
  modalHeader: {
    flexDirection: 'row',
    justifyContent: 'between',
    alignItems: 'center',
    marginBottom: 24,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#fff',
  },
  detailSection: {
    gap: 12,
    marginBottom: 24,
    backgroundColor: '#0a0a0a',
    padding: 16,
    borderRadius: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  detailText: {
    color: '#fff',
    fontSize: 14,
  },
  itemsHeader: {
    fontSize: 12,
    color: '#666',
    fontWeight: 'bold',
    marginBottom: 12,
  },
  itemRow: {
    flexDirection: 'row',
    justifyContent: 'between',
    marginBottom: 8,
  },
  itemName: {
    color: '#fff',
    flex: 1,
  },
  itemPrice: {
    color: '#666',
  },
});
