import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PromoVideo {
  final String url;
  final String title;
  final String fieldName;
  final String? date;
  final String? fieldId;
  final String? scheduleId;
  final bool isAsset;

  PromoVideo({
    required this.url,
    required this.title,
    required this.fieldName,
    this.date,
    this.fieldId,
    this.scheduleId,
    this.isAsset = false,
  });
}

class PromoRecordingService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Promo videos - streamed from Supabase storage (works on all devices!)
  static final List<PromoVideo> localVideos = [
    PromoVideo(
      url: 'https://upooyypqhftzzwjrfyra.supabase.co/storage/v1/object/public/videos/promo/playmaker_promo.mp4',
      title: 'Playmaker Highlights',
      fieldName: 'Playmaker Football',
      date: 'Featured Recording',
      isAsset: false, // Network video, not local asset
    ),
  ];

  PromoRecordingService();

  /// Get all videos for promo display
  /// Returns local videos immediately, then fetches latest chunk from database
  Future<List<PromoVideo>> getPromoVideos() async {
    print('🎬 PromoRecordingService: Getting videos...');
    
    final List<PromoVideo> allVideos = [];
    
    // 1. ALWAYS add local videos first (instant playback, no loading)
    allVideos.addAll(localVideos);
    print('📹 Added ${localVideos.length} local promo videos');
    
    // 2. Try to fetch latest chunk from the last recording job
    try {
      final latestChunk = await _fetchLatestChunk();
      if (latestChunk != null) {
        allVideos.insert(0, latestChunk); // Add at the beginning
        print('✅ Added latest recording chunk from database');
      }
    } catch (e) {
      print('⚠️ Could not fetch latest chunk: $e');
    }
    
    print('🎬 Total promo videos: ${allVideos.length}');
    return allVideos;
  }

  /// Fetch the latest chunk from the most recent recording job
  Future<PromoVideo?> _fetchLatestChunk() async {
    print('📹 Fetching latest chunk from last recording job...');
    
    try {
      // Get the most recent recording schedule that has chunks with video URLs
      final response = await _supabase
          .from('camera_recording_schedules')
          .select('id, field_id, start_time, camera_recording_chunks(*)')
          .order('created_at', ascending: false)
          .limit(5); // Check last 5 jobs to find one with video
      
      for (final schedule in (response as List)) {
        final chunks = schedule['camera_recording_chunks'] as List?;
        if (chunks == null || chunks.isEmpty) continue;
        
        // Sort chunks by chunk_number descending to get the latest
        chunks.sort((a, b) => (b['chunk_number'] ?? 0).compareTo(a['chunk_number'] ?? 0));
        
        // Find a chunk with a video URL (prefer processed_url over video_url)
        for (final chunk in chunks) {
          String? videoUrl = chunk['processed_url'] as String?;
          videoUrl ??= chunk['video_url'] as String?;
          
          if (videoUrl != null && videoUrl.isNotEmpty && videoUrl.contains('http')) {
            print('✅ Found chunk with video: ${chunk['id']}');
            print('   URL: ${videoUrl.substring(0, 60)}...');
            
            // Get field name
            String fieldName = 'Playmaker Field';
            final fieldId = schedule['field_id'] as String?;
            if (fieldId != null) {
              try {
                final fieldData = await _supabase
                    .from('football_fields')
                    .select('football_field_name')
                    .eq('id', fieldId)
                    .maybeSingle();
                if (fieldData != null) {
                  fieldName = fieldData['football_field_name'] ?? 'Playmaker Field';
                }
              } catch (e) {
                print('  Could not fetch field name: $e');
              }
            }
            
            // Format date
            String? dateStr;
            final startTime = schedule['start_time'] as String?;
            if (startTime != null) {
              try {
                final date = DateTime.parse(startTime).toLocal();
                dateStr = DateFormat('EEEE, MMM d • h:mm a').format(date);
              } catch (e) {
                dateStr = 'Recent Recording';
              }
            }
            
            final chunkNumber = chunk['chunk_number'] ?? 1;
            
            return PromoVideo(
              url: videoUrl,
              title: 'Match Recording - Part $chunkNumber',
              fieldName: fieldName,
              date: dateStr,
              fieldId: fieldId,
              scheduleId: schedule['id'],
              isAsset: false,
            );
          }
        }
      }
      
      print('⚠️ No chunks with video URLs found in recent jobs');
      return null;
    } catch (e) {
      print('❌ Error fetching latest chunk: $e');
      return null;
    }
  }

  /// Refresh and get any new chunks (called periodically)
  Future<PromoVideo?> checkForNewChunk() async {
    return await _fetchLatestChunk();
  }
}
