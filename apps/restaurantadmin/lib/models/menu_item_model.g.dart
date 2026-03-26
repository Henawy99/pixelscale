// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'menu_item_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MenuItemAdapter extends TypeAdapter<MenuItem> {
  @override
  final int typeId = 4;

  @override
  MenuItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MenuItem(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      brandId: fields[2] as String?,
      categoryId: fields[3] as String,
      name: fields[4] as String,
      description: fields[5] as String?,
      price: fields[6] as double,
      imageUrl: fields[7] as String?,
      attributes: (fields[8] as Map?)?.cast<String, dynamic>(),
      displayOrder: fields[9] as int,
      isAvailable: fields[10] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, MenuItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.brandId)
      ..writeByte(3)
      ..write(obj.categoryId)
      ..writeByte(4)
      ..write(obj.name)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.price)
      ..writeByte(7)
      ..write(obj.imageUrl)
      ..writeByte(8)
      ..write(obj.attributes)
      ..writeByte(9)
      ..write(obj.displayOrder)
      ..writeByte(10)
      ..write(obj.isAvailable);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
