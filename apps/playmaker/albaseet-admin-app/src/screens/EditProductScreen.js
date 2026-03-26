import React, { useState } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, ScrollView, SafeAreaView, Alert, KeyboardAvoidingView, Platform } from 'react-native';
import { supabase, ALBASEET_PRODUCTS_TABLE } from '../config/supabase';
import { ArrowLeft } from 'lucide-react-native';

const CATEGORIES = [
  { id: 'padel', name: 'Padel' },
  { id: 'football', name: 'Football' },
  { id: 'swimming', name: 'Swimming' },
  { id: 'tennis', name: 'Tennis' },
];

const SUBCATEGORIES = [
  { id: 'shoes', name: 'Shoes' },
  { id: 'rackets', name: 'Rackets / Balls' },
  { id: 'apparel', name: 'Apparel' },
  { id: 'accessories', name: 'Accessories' },
  { id: 'equipment', name: 'Training Equipment' },
];

export default function EditProductScreen({ route, navigation }) {
  const { product } = route.params;

  const [nameEn, setNameEn] = useState(product.name?.en || '');
  const [nameAr, setNameAr] = useState(product.name?.ar || '');
  const [articleNumber, setArticleNumber] = useState(product.article_number || '');
  const [price, setPrice] = useState(product.price ? product.price.toString() : '');
  const [category, setCategory] = useState(product.category || CATEGORIES[0].id);
  const [subcategory, setSubcategory] = useState(product.subcategory || SUBCATEGORIES[0].id);
  const [sizes, setSizes] = useState(
    (product.sizes || []).map(s => ({ size: s.size || s.name || '', stock: (s.stock ?? 0).toString() }))
  );
  const [loading, setLoading] = useState(false);

  const handleAddSize = () => {
    setSizes([...sizes, { size: '', stock: '0' }]);
  };

  const handleRemoveSize = (index) => {
    if (sizes.length <= 1) return;
    setSizes(sizes.filter((_, i) => i !== index));
  };

  const handleSizeChange = (index, field, value) => {
    const newSizes = [...sizes];
    newSizes[index] = { ...newSizes[index], [field]: value };
    setSizes(newSizes);
  };

  const handleUpdateProduct = async () => {
    if (!nameEn || !nameAr || !articleNumber || !price) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    const validSizes = sizes.filter(s => s.size.trim() !== '');
    if (validSizes.length === 0) {
      Alert.alert('Error', 'Please keep at least one size');
      return;
    }

    setLoading(true);
    try {
      const updatedProduct = {
        name: { en: nameEn, ar: nameAr },
        article_number: articleNumber.toUpperCase(),
        category,
        subcategory,
        price: parseFloat(price),
        sizes: validSizes.map(s => ({ size: s.size, stock: parseInt(s.stock, 10) || 0 })),
      };

      const { error } = await supabase
        .from(ALBASEET_PRODUCTS_TABLE)
        .update(updatedProduct)
        .eq('id', product.id);

      if (error) throw error;

      Alert.alert('Success', 'Product updated successfully', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      console.error('Error updating product:', error);
      Alert.alert('Error', 'Failed to update product');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.backButton} onPress={() => navigation.goBack()}>
          <ArrowLeft size={24} color="#fff" />
        </TouchableOpacity>
        <Text style={styles.headerTitle}>Edit Product</Text>
        <View style={{ width: 40 }} />
      </View>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <ScrollView contentContainerStyle={styles.formContainer}>
          <Text style={styles.sectionTitle}>Product Details</Text>

          <Text style={styles.label}>Name (English) *</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g. Pro Padel Court Shoes"
            placeholderTextColor="#555"
            value={nameEn}
            onChangeText={setNameEn}
          />

          <Text style={styles.label}>Name (Arabic) *</Text>
          <TextInput
            style={[styles.input, { textAlign: 'right' }]}
            placeholder="اسم المنتج بالعربي"
            placeholderTextColor="#555"
            value={nameAr}
            onChangeText={setNameAr}
          />

          <Text style={styles.label}>Article Number *</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g. PD-SH-001"
            placeholderTextColor="#555"
            value={articleNumber}
            onChangeText={setArticleNumber}
            autoCapitalize="characters"
          />

          <Text style={styles.label}>Price (EGP) *</Text>
          <TextInput
            style={styles.input}
            placeholder="e.g. 2499"
            placeholderTextColor="#555"
            value={price}
            onChangeText={setPrice}
            keyboardType="numeric"
          />

          <Text style={styles.sectionTitle}>Category</Text>
          <View style={styles.pillContainer}>
            {CATEGORIES.map(cat => (
              <TouchableOpacity
                key={cat.id}
                style={[styles.pill, category === cat.id && styles.pillActive]}
                onPress={() => setCategory(cat.id)}
              >
                <Text style={[styles.pillText, category === cat.id && styles.pillTextActive]}>
                  {cat.name}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.sectionTitle}>Subcategory</Text>
          <View style={styles.pillContainer}>
            {SUBCATEGORIES.map(sub => (
              <TouchableOpacity
                key={sub.id}
                style={[styles.pill, subcategory === sub.id && styles.pillActive]}
                onPress={() => setSubcategory(sub.id)}
              >
                <Text style={[styles.pillText, subcategory === sub.id && styles.pillTextActive]}>
                  {sub.name}
                </Text>
              </TouchableOpacity>
            ))}
          </View>

          <Text style={styles.sectionTitle}>Sizes & Stock</Text>
          <View style={styles.sizesCard}>
            {sizes.map((sizeItem, index) => (
              <View key={index} style={styles.sizeRow}>
                <View style={{ flex: 1, marginRight: 8 }}>
                  <Text style={styles.sizeFieldLabel}>Size</Text>
                  <TextInput
                    style={styles.sizeInput}
                    placeholder="e.g. 42"
                    placeholderTextColor="#555"
                    value={sizeItem.size}
                    onChangeText={(val) => handleSizeChange(index, 'size', val)}
                  />
                </View>
                <View style={{ flex: 1, marginRight: 8 }}>
                  <Text style={styles.sizeFieldLabel}>Stock</Text>
                  <TextInput
                    style={styles.sizeInput}
                    placeholder="0"
                    placeholderTextColor="#555"
                    value={sizeItem.stock}
                    onChangeText={(val) => handleSizeChange(index, 'stock', val)}
                    keyboardType="number-pad"
                  />
                </View>
                {sizes.length > 1 && (
                  <TouchableOpacity style={styles.removeSizeBtn} onPress={() => handleRemoveSize(index)}>
                    <Text style={{ color: '#ef4444', fontWeight: 'bold', fontSize: 18 }}>✕</Text>
                  </TouchableOpacity>
                )}
              </View>
            ))}
            <TouchableOpacity style={styles.addSizeBtn} onPress={handleAddSize}>
              <Text style={styles.addSizeBtnText}>+ Add Size</Text>
            </TouchableOpacity>
          </View>

          <TouchableOpacity
            style={[styles.saveButton, loading && styles.saveButtonDisabled]}
            onPress={handleUpdateProduct}
            disabled={loading}
          >
            <Text style={styles.saveButtonText}>
              {loading ? 'Updating...' : 'Update Product'}
            </Text>
          </TouchableOpacity>
        </ScrollView>
      </KeyboardAvoidingView>
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
    justifyContent: 'space-between',
    padding: 16,
    borderBottomWidth: 1,
    borderBottomColor: '#333',
    backgroundColor: '#1a1a1a',
  },
  backButton: {
    padding: 8,
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#fff',
  },
  formContainer: {
    padding: 20,
    paddingBottom: 40,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#fbbf24',
    marginTop: 24,
    marginBottom: 12,
  },
  label: {
    fontSize: 13,
    color: '#999',
    fontWeight: '600',
    marginBottom: 6,
    marginTop: 12,
  },
  input: {
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 16,
    height: 52,
    color: '#fff',
    fontSize: 16,
  },
  pillContainer: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  pill: {
    backgroundColor: '#1a1a1a',
    borderWidth: 1,
    borderColor: '#333',
    borderRadius: 20,
    paddingVertical: 8,
    paddingHorizontal: 16,
  },
  pillActive: {
    backgroundColor: '#fbbf24',
    borderColor: '#fbbf24',
  },
  pillText: {
    color: '#888',
    fontSize: 14,
    fontWeight: '500',
  },
  pillTextActive: {
    color: '#000',
    fontWeight: 'bold',
  },
  sizesCard: {
    backgroundColor: '#1a1a1a',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#333',
    padding: 16,
  },
  sizeRow: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    marginBottom: 12,
  },
  sizeFieldLabel: {
    fontSize: 12,
    color: '#888',
    marginBottom: 4,
  },
  sizeInput: {
    backgroundColor: '#0a0a0a',
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#333',
    paddingHorizontal: 12,
    height: 44,
    color: '#fff',
    fontSize: 15,
  },
  removeSizeBtn: {
    width: 36,
    height: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  addSizeBtn: {
    borderWidth: 1,
    borderColor: '#fbbf24',
    borderStyle: 'dashed',
    borderRadius: 8,
    paddingVertical: 10,
    alignItems: 'center',
    marginTop: 4,
  },
  addSizeBtnText: {
    color: '#fbbf24',
    fontWeight: 'bold',
    fontSize: 14,
  },
  saveButton: {
    backgroundColor: '#fbbf24',
    height: 56,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginTop: 32,
  },
  saveButtonDisabled: {
    opacity: 0.5,
  },
  saveButtonText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#000',
  },
});
