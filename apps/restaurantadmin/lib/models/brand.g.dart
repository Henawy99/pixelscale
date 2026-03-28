// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'brand.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BrandAdapter extends TypeAdapter<Brand> {
  @override
  final int typeId = 2;

  @override
  Brand read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Brand(
      id: fields[0] as String,
      createdAt: fields[1] as DateTime,
      name: fields[2] as String,
      description: fields[3] as String?,
      imageUrl: fields[4] as String?,
      lieferandoUrl: fields[5] as String?,
      foodoraUrl: fields[6] as String?,
      woltUrl: fields[7] as String?,
      googleUrl: fields[8] as String?,
      lieferandoRating: fields[9] as double?,
      foodoraRating: fields[10] as double?,
      woltRating: fields[11] as double?,
      googleRating: fields[12] as double?,
      lieferandoReviewCount: fields[13] as int?,
      foodoraReviewCount: fields[14] as int?,
      woltReviewCount: fields[15] as int?,
      googleReviewCount: fields[16] as int?,
      lieferandoUpdatedAt: fields[17] as DateTime?,
      foodoraUpdatedAt: fields[18] as DateTime?,
      woltUpdatedAt: fields[19] as DateTime?,
      googleUpdatedAt: fields[20] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Brand obj) {
    writer
      ..writeByte(21)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.createdAt)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.description)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.lieferandoUrl)
      ..writeByte(6)
      ..write(obj.foodoraUrl)
      ..writeByte(7)
      ..write(obj.woltUrl)
      ..writeByte(8)
      ..write(obj.googleUrl)
      ..writeByte(9)
      ..write(obj.lieferandoRating)
      ..writeByte(10)
      ..write(obj.foodoraRating)
      ..writeByte(11)
      ..write(obj.woltRating)
      ..writeByte(12)
      ..write(obj.googleRating)
      ..writeByte(13)
      ..write(obj.lieferandoReviewCount)
      ..writeByte(14)
      ..write(obj.foodoraReviewCount)
      ..writeByte(15)
      ..write(obj.woltReviewCount)
      ..writeByte(16)
      ..write(obj.googleReviewCount)
      ..writeByte(17)
      ..write(obj.lieferandoUpdatedAt)
      ..writeByte(18)
      ..write(obj.foodoraUpdatedAt)
      ..writeByte(19)
      ..write(obj.woltUpdatedAt)
      ..writeByte(20)
      ..write(obj.googleUpdatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BrandAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
