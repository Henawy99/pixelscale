// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'material_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MaterialItemAdapter extends TypeAdapter<MaterialItem> {
  @override
  final int typeId = 0;

  @override
  MaterialItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MaterialItem(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      name: fields[2] as String,
      unitOfMeasure: fields[3] as String,
      currentQuantity: fields[4] as double,
      sellerName: fields[5] as String?,
      itemNumber: fields[6] as String?,
      category: fields[7] as String?,
      itemImageUrl: fields[8] as String?,
      geminiInfo: fields[9] as String?,
      weightedAverageCost: fields[10] as double?,
      notifyWhenQuantity: fields[11] as double?,
      arabicName: fields[12] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MaterialItem obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.unitOfMeasure)
      ..writeByte(4)
      ..write(obj.currentQuantity)
      ..writeByte(5)
      ..write(obj.sellerName)
      ..writeByte(6)
      ..write(obj.itemNumber)
      ..writeByte(7)
      ..write(obj.category)
      ..writeByte(8)
      ..write(obj.itemImageUrl)
      ..writeByte(9)
      ..write(obj.geminiInfo)
      ..writeByte(10)
      ..write(obj.weightedAverageCost)
      ..writeByte(11)
      ..write(obj.notifyWhenQuantity)
      ..writeByte(12)
      ..write(obj.arabicName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaterialItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
