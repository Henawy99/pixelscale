import React, { useState } from 'react';
import { StyleSheet, View, Text, TextInput, TouchableOpacity, ScrollView, SafeAreaView, Alert, KeyboardAvoidingView, Platform, Image, ActivityIndicator } from 'react-native';
import * as ImagePicker from 'expo-image-picker';
import { supabase, ALBASEET_PRODUCTS_TABLE, ALBASEET_STORAGE_BUCKET, getImageUrl } from '../config/supabase';
import { ArrowLeft, Camera, X } from 'lucide-react-native';

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

export default function AddProductScreen({ navigation }) {
  const [nameEn, setNameEn] = useState('');
  const [nameAr, setNameAr] = useState('');
  const [articleNumber, setArticleNumber] = useState('');
  const [price, setPrice] = useState('');
  const [category, setCategory] = useState(CATEGORIES[0].id);
  const [subcategory, setSubcategory] = useState(SUBCATEGORIES[0].id);
  const [sizes, setSizes] = useState([{ size: '', stock: '' }]);
  const [imageUri, setImageUri] = useState(null);
  const [loading, setLoading] = useState(false);
  const [uploading, setUploading] = useState(false);

  const pickImage = async () => {
    const { status } = await ImagePicker.requestMediaLibraryPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission needed', 'Please grant camera roll permissions to upload images.');
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setImageUri(result.assets[0].uri);
    }
  };

  const takePhoto = async () => {
    const { status } = await ImagePicker.requestCameraPermissionsAsync();
    if (status !== 'granted') {
      Alert.alert('Permission needed', 'Please grant camera permissions.');
      return;
    }

    const result = await ImagePicker.launchCameraAsync({
      allowsEditing: true,
      aspect: [1, 1],
      quality: 0.8,
    });

    if (!result.canceled && result.assets[0]) {
      setImageUri(result.assets[0].uri);
    }
  };

  const uploadImage = async (productId) => {
    if (!imageUri) return [];

    try {
      setUploading(true);
      const ext = imageUri.split('.').pop() || 'jpg';
      const fileName = `${productId}/${Date.now()}.${ext}`;

      const response = await fetch(imageUri);
      const blob = await response.blob();

      // Convert blob to arraybuffer for Supabase
      const arrayBuffer = await new Response(blob).arrayBuffer();

      const { data, error } = await supabase.storage
        .from(ALBASEET_STORAGE_BUCKET)
        .upload(fileName, arrayBuffer, {
          contentType: `image/${ext}`,
          cacheControl: '3600',
          upsert: false,
        });

      if (error) throw error;
      return [data.path];
    } catch (error) {
      console.error('Image upload error:', error);
      return [];
    } finally {
      setUploading(false);
    }
  };

  const handleAddSize = () => {
    setSizes([...sizes, { size: '', stock: '' }]);
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

  const handleSaveProduct = async () => {
    if (!nameEn || !nameAr || !articleNumber || !price) {
      Alert.alert('Error', 'Please fill in all required fields');
      return;
    }

    const validSizes = sizes.filter(s => s.size.trim() !== '');
    if (validSizes.length === 0) {
      Alert.alert('Error', 'Please add at least one size');
      return;
    }

    setLoading(true);
    try {
      // First, create the product to get its ID
      const newProduct = {
        name: { en: nameEn, ar: nameAr },
        description: { en: '', ar: '' },
        article_number: articleNumber.toUpperCase(),
        category,
        subcategory,
        price: parseFloat(price),
        sizes: validSizes.map(s => ({ size: s.size, stock: parseInt(s.stock, 10) || 0 })),
        images: [],
        details: { en: [], ar: [] },
        is_new: true,
      };

      const { data, error } = await supabase
        .from(ALBASEET_PRODUCTS_TABLE)
        .insert([newProduct])
        .select()
        .single();

      if (error) throw error;

      // Then upload image if one was selected
      if (imageUri && data) {
        const imagePaths = await uploadImage(data.id);
        if (imagePaths.length > 0) {
          await supabase
            .from(ALBASEET_PRODUCTS_TABLE)
            .update({ images: imagePaths })
            .eq('id', data.id);
        }
      }

      Alert.alert('Success', 'Product added successfully', [
        { text: 'OK', onPress: () => navigation.goBack() }
      ]);
    } catch (error) {
      console.error('Error adding product:', error);
      Alert.alert('Error', 'Failed to add product');
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
        <Text style={styles.headerTitle}>Add Product</Text>
        <View style={{ width: 40 }} />
      </View>

      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        style={{ flex: 1 }}
      >
        <ScrollView contentContainerStyle={styles.formContainer}>
          {/* Image Picker */}
          <Text style={styles.sectionTitle}>Product Image</Text>
          <View style={styles.imageSection}>
            {imageUri ? (
              <View style={styles.imagePreviewWrap}>
                <Image source={{ uri: imageUri }} style={styles.imagePreview} />
                <TouchableOpacity style={styles.removeImage} onPress={() => setImageUri(null)}>
                  <X size={16} color="#fff" />
                </TouchableOpacity>
              </View>
            ) : (
              <View style={styles.imageActions}>
                <TouchableOpacity style={styles.imageBtn} onPress={pickImage}>
                  <Camera size={24} color="#fbbf24" />
                  <Text style={styles.imageBtnText}>Gallery</Text>
                </TouchableOpacity>
                <TouchableOpacity style={styles.imageBtn} onPress={takePhoto}>
                  <Camera size={24} color="#fbbf24" />
                  <Text style={styles.imageBtnText}>Camera</Text>
                </TouchableOpacity>
              </View>
            )}
          </View>

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
                    value={sizeItem.stock.toString()}
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
            style={[styles.saveButton, (loading || uploading) && styles.saveButtonDisabled]}
            onPress={handleSaveProduct}
            disabled={loading || uploading}
          >
            {loading || uploading ? (
              <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                <ActivityIndicator color="#000" />
                <Text style={styles.saveButtonText}>
                  {uploading ? 'Uploading image...' : 'Saving...'}
                </Text>
              </View>
            ) : (
              <Text style={styles.saveButtonText}>Save Product</Text>
            )}
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
  imageSection: {
    marginBottom: 8,
  },
  imageActions: {
    flexDirection: 'row',
    gap: 12,
  },
  imageBtn: {
    flex: 1,
    backgroundColor: '#1a1a1a',
    borderWidth: 1,
    borderColor: '#333',
    borderStyle: 'dashed',
    borderRadius: 12,
    height: 100,
    justifyContent: 'center',
    alignItems: 'center',
    gap: 8,
  },
  imageBtnText: {
    color: '#888',
    fontSize: 13,
  },
  imagePreviewWrap: {
    width: 120,
    height: 120,
    borderRadius: 12,
    overflow: 'hidden',
    position: 'relative',
  },
  imagePreview: {
    width: '100%',
    height: '100%',
    resizeMode: 'cover',
  },
  removeImage: {
    position: 'absolute',
    top: 4,
    right: 4,
    backgroundColor: 'rgba(0,0,0,0.7)',
    borderRadius: 12,
    width: 24,
    height: 24,
    justifyContent: 'center',
    alignItems: 'center',
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
