// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'podcast_models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserProfileAdapter extends TypeAdapter<UserProfile> {
  @override
  final int typeId = 0;

  @override
  UserProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserProfile(
      uid: fields[0] as String,
      email: fields[1] as String,
      displayName: fields[2] as String,
      photoUrl: fields[3] as String?,
      preferredLanguage: fields[4] as String,
      createdAt: fields[5] as DateTime,
      lastSeen: fields[6] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, UserProfile obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.uid)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.displayName)
      ..writeByte(3)
      ..write(obj.photoUrl)
      ..writeByte(4)
      ..write(obj.preferredLanguage)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.lastSeen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PodcastAdapter extends TypeAdapter<Podcast> {
  @override
  final int typeId = 1;

  @override
  Podcast read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Podcast(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      imageUrl: fields[3] as String,
      publisher: fields[4] as String,
      language: fields[5] as String,
      genres: (fields[6] as List).cast<String>(),
      totalEpisodes: fields[7] as int,
      website: fields[8] as String?,
      isUserUploaded: fields[9] as bool,
      uploadedByUserId: fields[10] as String?,
      thumbnailUrl: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Podcast obj) {
    writer
      ..writeByte(12)
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.imageUrl)
      ..writeByte(4)
      ..write(obj.publisher)
      ..writeByte(5)
      ..write(obj.language)
      ..writeByte(6)
      ..write(obj.genres)
      ..writeByte(7)
      ..write(obj.totalEpisodes)
      ..writeByte(8)
      ..write(obj.website)
      ..writeByte(9)
      ..write(obj.isUserUploaded)
      ..writeByte(10)
      ..write(obj.uploadedByUserId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PodcastAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EpisodeAdapter extends TypeAdapter<Episode> {
  @override
  final int typeId = 2;

  @override
  Episode read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Episode(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      audioUrl: fields[3] as String,
      imageUrl: fields[4] as String,
      audioLengthSec: fields[5] as int,
      pubDateMs: fields[6] as DateTime,
      podcastId: fields[7] as String,
      isUserUploaded: fields[8] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, Episode obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.audioUrl)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.audioLengthSec)
      ..writeByte(6)
      ..write(obj.pubDateMs)
      ..writeByte(7)
      ..write(obj.podcastId)
      ..writeByte(8)
      ..write(obj.isUserUploaded);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EpisodeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ListeningProgressAdapter extends TypeAdapter<ListeningProgress> {
  @override
  final int typeId = 3;

  @override
  ListeningProgress read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ListeningProgress(
      episodeId: fields[0] as String,
      userId: fields[1] as String,
      positionMs: fields[2] as int,
      durationMs: fields[3] as int,
      lastListened: fields[4] as DateTime,
      isCompleted: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, ListeningProgress obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.episodeId)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.positionMs)
      ..writeByte(3)
      ..write(obj.durationMs)
      ..writeByte(4)
      ..write(obj.lastListened)
      ..writeByte(5)
      ..write(obj.isCompleted);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningProgressAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FavoriteAdapter extends TypeAdapter<Favorite> {
  @override
  final int typeId = 4;

  @override
  Favorite read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Favorite(
      id: fields[0] as String,
      userId: fields[1] as String,
      itemId: fields[2] as String,
      itemType: fields[3] as String,
      addedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Favorite obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.itemId)
      ..writeByte(3)
      ..write(obj.itemType)
      ..writeByte(4)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ListeningStatsAdapter extends TypeAdapter<ListeningStats> {
  @override
  final int typeId = 5;

  @override
  ListeningStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ListeningStats(
      userId: fields[0] as String,
      totalListeningTimeMs: fields[1] as int,
      episodesCompleted: fields[2] as int,
      categoryStats: (fields[3] as Map).cast<String, int>(),
      dailyStats: (fields[4] as Map).cast<String, int>(),
      lastUpdated: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ListeningStats obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.userId)
      ..writeByte(1)
      ..write(obj.totalListeningTimeMs)
      ..writeByte(2)
      ..write(obj.episodesCompleted)
      ..writeByte(3)
      ..write(obj.categoryStats)
      ..writeByte(4)
      ..write(obj.dailyStats)
      ..writeByte(5)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListeningStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
