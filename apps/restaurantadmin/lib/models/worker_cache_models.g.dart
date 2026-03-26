// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'worker_cache_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedBrandAdapter extends TypeAdapter<CachedBrand> {
  @override
  final int typeId = 20;

  @override
  CachedBrand read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedBrand(
      id: fields[0] as String,
      name: fields[1] as String,
      imageUrl: fields[2] as String?,
      lastUpdated: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedBrand obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imageUrl)
      ..writeByte(3)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedBrandAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedCategoryAdapter extends TypeAdapter<CachedCategory> {
  @override
  final int typeId = 21;

  @override
  CachedCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedCategory(
      id: fields[0] as String,
      name: fields[1] as String,
      brandId: fields[2] as String,
      displayOrder: fields[3] as int,
      lastUpdated: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedCategory obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.brandId)
      ..writeByte(3)
      ..write(obj.displayOrder)
      ..writeByte(4)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedMenuItemAdapter extends TypeAdapter<CachedMenuItem> {
  @override
  final int typeId = 22;

  @override
  CachedMenuItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedMenuItem(
      id: fields[0] as String,
      name: fields[1] as String,
      categoryId: fields[2] as String,
      price: fields[3] as double,
      imageUrl: fields[4] as String?,
      displayOrder: fields[5] as int,
      lastUpdated: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMenuItem obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.categoryId)
      ..writeByte(3)
      ..write(obj.price)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.displayOrder)
      ..writeByte(6)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedMenuItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedMaterialAdapter extends TypeAdapter<CachedMaterial> {
  @override
  final int typeId = 23;

  @override
  CachedMaterial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedMaterial(
      id: fields[0] as String,
      name: fields[1] as String,
      arabicName: fields[2] as String?,
      unitOfMeasure: fields[3] as String,
      imageUrl: fields[4] as String?,
      lastUpdated: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMaterial obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.arabicName)
      ..writeByte(3)
      ..write(obj.unitOfMeasure)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedMaterialAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedMenuItemMaterialAdapter
    extends TypeAdapter<CachedMenuItemMaterial> {
  @override
  final int typeId = 24;

  @override
  CachedMenuItemMaterial read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedMenuItemMaterial(
      id: fields[0] as String,
      menuItemId: fields[1] as String,
      materialId: fields[2] as String,
      quantityUsed: fields[3] as double,
      unitOfMeasureForUsage: fields[4] as String,
      notes: fields[5] as String?,
      lastUpdated: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMenuItemMaterial obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.menuItemId)
      ..writeByte(2)
      ..write(obj.materialId)
      ..writeByte(3)
      ..write(obj.quantityUsed)
      ..writeByte(4)
      ..write(obj.unitOfMeasureForUsage)
      ..writeByte(5)
      ..write(obj.notes)
      ..writeByte(6)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedMenuItemMaterialAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class WorkerCacheMetadataAdapter extends TypeAdapter<WorkerCacheMetadata> {
  @override
  final int typeId = 25;

  @override
  WorkerCacheMetadata read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkerCacheMetadata(
      cacheType: fields[0] as String,
      lastUpdated: fields[1] as DateTime,
      brandId: fields[2] as String?,
      version: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, WorkerCacheMetadata obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.cacheType)
      ..writeByte(1)
      ..write(obj.lastUpdated)
      ..writeByte(2)
      ..write(obj.brandId)
      ..writeByte(3)
      ..write(obj.version);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerCacheMetadataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
