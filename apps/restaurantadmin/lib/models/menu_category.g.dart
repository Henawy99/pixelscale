// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MenuCategoryAdapter extends TypeAdapter<MenuCategory> {
  @override
  final int typeId = 3;

  @override
  MenuCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MenuCategory(
      id: fields[0] as String,
      brandId: fields[1] as String,
      name: fields[2] as String,
      description: fields[3] as String?,
      displayOrder: fields[4] as int,
      createdAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, MenuCategory obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.brandId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.displayOrder)
      ..writeByte(5)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
