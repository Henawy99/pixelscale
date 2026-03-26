// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_log_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryLogItemAdapter extends TypeAdapter<InventoryLogItem> {
  @override
  final int typeId = 1;

  @override
  InventoryLogItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryLogItem(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      materialId: fields[2] as String,
      materialName: fields[3] as String,
      changeType: fields[4] as String,
      quantityChange: fields[5] as double,
      newQuantityAfterChange: fields[6] as double,
      sourceDetails: fields[7] as String?,
      userId: fields[8] as String?,
      unitPricePaid: fields[9] as double?,
      totalPricePaid: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryLogItem obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.materialId)
      ..writeByte(3)
      ..write(obj.materialName)
      ..writeByte(4)
      ..write(obj.changeType)
      ..writeByte(5)
      ..write(obj.quantityChange)
      ..writeByte(6)
      ..write(obj.newQuantityAfterChange)
      ..writeByte(7)
      ..write(obj.sourceDetails)
      ..writeByte(8)
      ..write(obj.userId)
      ..writeByte(9)
      ..write(obj.unitPricePaid)
      ..writeByte(10)
      ..write(obj.totalPricePaid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryLogItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
