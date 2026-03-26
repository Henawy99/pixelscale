import React, { useState, useEffect } from 'react';
import { StyleSheet, View, Text, FlatList, TouchableOpacity, RefreshControl, SafeAreaView, TextInput, Alert, Image, ScrollView } from 'react-native';
import { Search, Package, AlertCircle, Plus, Trash2 } from 'lucide-react-native';
import { useNavigation } from '@react-navigation/native';
import { supabase, ALBASEET_PRODUCTS_TABLE, getImageUrl } from '../config/supabase';

const CATEGORIES = [
  { id: '', name: 'All' },
  { id: 'padel', name: 'Padel' },
  { id: 'football', name: 'Football' },
  { id: 'swimming', name: 'Swimming' },
  { id: 'tennis', name: 'Tennis' },
];

export default function ProductsScreen() {
  const navigation = useNavigation();
  const [products, setProducts] = useState([]);
  const [refreshing, setRefreshing] = useState(false);
  const [search, setSearch] = useState('');
  const [selectedCategory, setSelectedCategory] = useState('');

  const fetchProducts = async () => {
    try {
      const { data, error } = await supabase
        .from(ALBASEET_PRODUCTS_TABLE)
        .select('*')
        .order('created_at', { ascending: false });
      if (data) setProducts(data);
    } catch (error) {
      console.error('Error fetching products:', error);
    }
  };

  useEffect(() => {
    const unsubscribe = navigation.addListener('focus', () => {
      fetchProducts();
    });
    fetchProducts();
    return unsubscribe;
  }, [navigation]);

  const handleDeleteProduct = (id) => {
    Alert.alert(
      "Delete Product",
      "Are you sure you want to delete this product? This action cannot be undone.",
      [
        { text: "Cancel", style: "cancel" },
        { 
          text: "Delete", 
          style: "destructive",
          onPress: async () => {
            try {
              const { error } = await supabase.from(ALBASEET_PRODUCTS_TABLE).delete().eq('id', id);
              if (error) throw error;
              setProducts(products.filter(p => p.id !== id));
            } catch (error) {
              console.error('Error deleting product:', error);
              Alert.alert('Error', 'Failed to delete product');
            }
          }
        }
      ]
    );
  };

  const onRefresh = React.useCallback(async () => {
    setRefreshing(true);
    await fetchProducts();
    setRefreshing(false);
  }, []);

  const getStockCount = (sizes) => {
    return sizes?.reduce((sum, s) => sum + (s.stock || 0), 0) || 0;
  };

  const getProductImageUrl = (product) => {
    if (!product.images || product.images.length === 0) return null;
    return getImageUrl(product.images[0]);
  };

  const filteredProducts = products.filter(p => {
    const matchesSearch = 
      p.name?.en?.toLowerCase().includes(search.toLowerCase()) || 
      p.article_number?.toLowerCase().includes(search.toLowerCase());
    const matchesCategory = selectedCategory === '' || p.category === selectedCategory;
    return matchesSearch && matchesCategory;
  });

  const ProductItem = ({ item }) => {
    const stock = getStockCount(item.sizes);
    const isLow = stock > 0 && stock <= 10;
    const isOut = stock === 0;
    const imageUrl = getProductImageUrl(item);

    return (
      <TouchableOpacity 
        style={styles.productCard} 
        activeOpacity={0.7}
        onPress={() => navigation.navigate('EditProduct', { product: item })}
      >
        <View style={styles.imageContainer}>
          {imageUrl ? (
            <Image source={{ uri: imageUrl }} style={styles.productImage} />
          ) : (
            <View style={styles.noImage}>
              <Package size={24} color="#555" />
            </View>
          )}
        </View>
        <View style={styles.productInfo}>
          <Text style={styles.productName} numberOfLines={1}>{item.name?.en || 'Untitled'}</Text>
          <Text style={styles.articleNumber}>{item.article_number}</Text>
          <Text style={styles.categoryText}>{item.category} • {item.subcategory}</Text>
          <Text style={styles.priceText}>{item.price?.toLocaleString()} EGP</Text>
        </View>
        <View style={styles.stockInfo}>
          <Text style={[
            styles.stockText,
            isOut ? styles.stockOut : isLow ? styles.stockLow : styles.stockOk
          ]}>
            {stock}
          </Text>
          <Text style={styles.stockLabel}>STOCK</Text>
          {(isLow || isOut) && <AlertCircle size={14} color={isOut ? '#ef4444' : '#fbbf24'} style={{marginTop: 4}} />}
        </View>
        <TouchableOpacity style={styles.deleteButton} onPress={() => handleDeleteProduct(item.id)}>
          <Trash2 size={20} color="#ef4444" />
        </TouchableOpacity>
      </TouchableOpacity>
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      {/* Search + Add */}
      <View style={styles.header}>
        <View style={styles.searchContainer}>
          <Search size={20} color="#666" style={styles.searchIcon} />
          <TextInput
            style={styles.searchInput}
            placeholder="Search products..."
            placeholderTextColor="#666"
            value={search}
            onChangeText={setSearch}
          />
        </View>
        <TouchableOpacity style={styles.addButton} onPress={() => navigation.navigate('AddProduct')}>
          <Plus size={24} color="#000" />
        </TouchableOpacity>
      </View>

      {/* Category Filter */}
      <View style={styles.filterRow}>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.filterScroll}>
          {CATEGORIES.map(cat => (
            <TouchableOpacity
              key={cat.id}
              style={[styles.filterPill, selectedCategory === cat.id && styles.filterPillActive]}
              onPress={() => setSelectedCategory(cat.id)}
            >
              <Text style={[styles.filterPillText, selectedCategory === cat.id && styles.filterPillTextActive]}>
                {cat.name}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </View>

      {/* Product count */}
      <Text style={styles.countText}>{filteredProducts.length} products</Text>

      <FlatList
        data={filteredProducts}
        renderItem={({ item }) => <ProductItem item={item} />}
        keyExtractor={item => item.id}
        contentContainerStyle={styles.listContent}
        refreshControl={<RefreshControl refreshing={refreshing} onRefresh={onRefresh} tintColor="#fbbf24" />}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Package size={48} color="#333" />
            <Text style={styles.emptyText}>No products found</Text>
          </View>
        }
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    marginTop: 16,
  },
  searchContainer: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: '#333',
    marginRight: 12,
  },
  searchIcon: {
    marginRight: 10,
  },
  searchInput: {
    flex: 1,
    height: 48,
    color: '#fff',
  },
  filterRow: {
    marginTop: 12,
    paddingLeft: 16,
  },
  filterScroll: {
    gap: 8,
    paddingRight: 16,
  },
  filterPill: {
    backgroundColor: '#1a1a1a',
    borderWidth: 1,
    borderColor: '#333',
    borderRadius: 20,
    paddingVertical: 6,
    paddingHorizontal: 16,
  },
  filterPillActive: {
    backgroundColor: '#fbbf24',
    borderColor: '#fbbf24',
  },
  filterPillText: {
    color: '#888',
    fontSize: 13,
    fontWeight: '500',
  },
  filterPillTextActive: {
    color: '#000',
    fontWeight: 'bold',
  },
  countText: {
    color: '#666',
    fontSize: 12,
    paddingHorizontal: 16,
    marginTop: 12,
    marginBottom: 4,
  },
  listContent: {
    padding: 16,
    paddingTop: 8,
  },
  productCard: {
    flexDirection: 'row',
    backgroundColor: '#1a1a1a',
    borderRadius: 16,
    padding: 12,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#333',
    alignItems: 'center',
  },
  imageContainer: {
    width: 56,
    height: 56,
    borderRadius: 10,
    overflow: 'hidden',
    marginRight: 12,
  },
  productImage: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  noImage: {
    width: '100%',
    height: '100%',
    backgroundColor: '#222',
    justifyContent: 'center',
    alignItems: 'center',
    borderRadius: 10,
  },
  productInfo: {
    flex: 1,
  },
  productName: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#fff',
    marginBottom: 2,
  },
  articleNumber: {
    fontSize: 11,
    color: '#666',
    fontFamily: 'monospace',
    marginBottom: 2,
  },
  categoryText: {
    fontSize: 11,
    color: '#fbbf24',
    textTransform: 'uppercase',
  },
  priceText: {
    fontSize: 13,
    color: '#10b981',
    fontWeight: 'bold',
    marginTop: 2,
  },
  stockInfo: {
    alignItems: 'center',
    justifyContent: 'center',
    minWidth: 50,
  },
  stockText: {
    fontSize: 18,
    fontWeight: 'bold',
  },
  stockOk: { color: '#10b981' },
  stockLow: { color: '#fbbf24' },
  stockOut: { color: '#ef4444' },
  stockLabel: {
    fontSize: 9,
    color: '#666',
    fontWeight: 'bold',
  },
  addButton: {
    width: 48,
    height: 48,
    backgroundColor: '#fbbf24',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
  },
  deleteButton: {
    padding: 8,
    marginLeft: 8,
  },
  emptyState: {
    alignItems: 'center',
    paddingTop: 60,
  },
  emptyText: {
    color: '#666',
    marginTop: 12,
    fontSize: 14,
  },
});
