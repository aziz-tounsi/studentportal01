import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/course_model.dart';
import '../services/offline_cache_service.dart';
import '../../core/services/connectivity_service.dart';

class CourseRepository {
  final SupabaseClient _supabase;

  CourseRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client;

  /// Fetch courses for the current student
  /// Filters by student's class and group
  Future<List<CourseModel>> fetchCourses({
    String? subject,
    String? teacherName,
    String? searchQuery,
    bool? hasAttachments,
    String orderBy = 'published_at',
    bool ascending = false,
  }) async {
    final cacheKey = 'cached_courses_${subject ?? "all"}_${teacherName ?? "all"}_${searchQuery ?? "all"}_${orderBy}_$ascending';
    try {
      var query = _supabase
          .from('courses')
          .select('''
            *,
            attachments:course_attachments(*)
          ''')
          .eq('is_published', true);

      // Apply filters
      if (subject != null && subject.isNotEmpty) {
        query = query.eq('subject', subject);
      }

      if (teacherName != null && teacherName.isNotEmpty) {
        query = query.ilike('teacher_name', '%$teacherName%');
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      // Order by - store the result
      final orderedQuery = query.order(orderBy, ascending: ascending);

      final response = await orderedQuery;
      
      final courses = (response as List)
          .map((json) => CourseModel.fromJson(json))
          .toList();

      await OfflineCacheService.instance.setJson(
        cacheKey,
        courses.map((c) => c.toJson()).toList(),
      );

      // If unfiltered, also store as default fallback
      if (subject == null && teacherName == null && searchQuery == null) {
        await OfflineCacheService.instance.setJson(
          'cached_courses_default',
          courses.map((c) => c.toJson()).toList(),
        );
      }

      ConnectivityService.instance.reportNetworkSuccess();

      // Filter by hasAttachments if specified
      if (hasAttachments != null) {
        return courses.where((c) => c.hasAttachments == hasAttachments).toList();
      }

      return courses;
    } catch (e) {
      debugPrint('fetchCourses error: $e');
      ConnectivityService.instance.reportNetworkError(e);

      // Offline / error fallback: check specific cache or default cache
      final cachedList = OfflineCacheService.instance.getListOfMaps(cacheKey) ??
          OfflineCacheService.instance.getListOfMaps('cached_courses_default');

      if (cachedList != null) {
        try {
          var cachedCourses = cachedList.map((j) => CourseModel.fromJson(j)).toList();
          if (subject != null && subject.isNotEmpty) {
            cachedCourses = cachedCourses.where((c) => c.subject == subject).toList();
          }
          if (teacherName != null && teacherName.isNotEmpty) {
            cachedCourses = cachedCourses
                .where((c) => c.teacherName.toLowerCase().contains(teacherName.toLowerCase()))
                .toList();
          }
          if (searchQuery != null && searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            cachedCourses = cachedCourses
                .where((c) =>
                    c.title.toLowerCase().contains(q) ||
                    (c.description?.toLowerCase().contains(q) ?? false))
                .toList();
          }
          if (hasAttachments != null) {
            cachedCourses = cachedCourses.where((c) => c.hasAttachments == hasAttachments).toList();
          }
          return cachedCourses;
        } catch (err) {
          debugPrint('Failed to parse cached courses: $err');
        }
      }

      return [];
    }
  }

  /// Fetch a single course by ID with all attachments
  Future<CourseModel?> fetchCourseById(String courseId) async {
    final cacheKey = 'cached_course_$courseId';
    try {
      final response = await _supabase
          .from('courses')
          .select('''
            *,
            attachments:course_attachments(*)
          ''')
          .eq('id', courseId)
          .single();

      final course = CourseModel.fromJson(response);
      await OfflineCacheService.instance.setJson(cacheKey, course.toJson());
      ConnectivityService.instance.reportNetworkSuccess();
      return course;
    } catch (e) {
      debugPrint('fetchCourseById error: $e');
      ConnectivityService.instance.reportNetworkError(e);
      final cached = OfflineCacheService.instance.getMap(cacheKey);
      if (cached != null) {
        try {
          return CourseModel.fromJson(cached);
        } catch (err) {
          debugPrint('Failed to parse cached course: $err');
        }
      }
      return null;
    }
  }

  /// Get list of unique subjects from all courses
  Future<List<String>> fetchSubjects() async {
    const cacheKey = 'cached_course_subjects';
    try {
      final response = await _supabase
          .from('courses')
          .select('subject')
          .eq('is_published', true);

      final subjects = (response as List)
          .map((json) => json['subject'] as String)
          .toSet()
          .toList();

      subjects.sort();
      await OfflineCacheService.instance.setJson(cacheKey, subjects);
      ConnectivityService.instance.reportNetworkSuccess();
      return subjects;
    } catch (e) {
      debugPrint('fetchSubjects error: $e');
      ConnectivityService.instance.reportNetworkError(e);
      final cached = OfflineCacheService.instance.getList(cacheKey);
      if (cached != null) {
        return cached.map((e) => e.toString()).toList();
      }
      return [];
    }
  }

  /// Get list of unique teacher names
  Future<List<String>> fetchTeacherNames() async {
    const cacheKey = 'cached_course_teachers';
    try {
      final response = await _supabase
          .from('courses')
          .select('teacher_name')
          .eq('is_published', true);

      final teachers = (response as List)
          .map((json) => json['teacher_name'] as String)
          .toSet()
          .toList();

      teachers.sort();
      await OfflineCacheService.instance.setJson(cacheKey, teachers);
      ConnectivityService.instance.reportNetworkSuccess();
      return teachers;
    } catch (e) {
      debugPrint('fetchTeacherNames error: $e');
      ConnectivityService.instance.reportNetworkError(e);
      final cached = OfflineCacheService.instance.getList(cacheKey);
      if (cached != null) {
        return cached.map((e) => e.toString()).toList();
      }
      return [];
    }
  }

  /// Mark a course as viewed by the current student
  Future<void> markAsViewed(String courseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _supabase.from('course_views').upsert({
        'course_id': courseId,
        'student_id': userId,
        'seen_at': DateTime.now().toIso8601String(),
      }, onConflict: 'course_id,student_id');
    } catch (e) {
      // Silently fail if marking as viewed fails
      // This is not critical functionality
      debugPrint('Failed to mark course as viewed: $e');
    }
  }

  /// Check if student has viewed a course
  Future<bool> hasViewed(String courseId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return false;
      }

      final response = await _supabase
          .from('course_views')
          .select('id')
          .eq('course_id', courseId)
          .eq('student_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Get count of courses matching filters
  Future<int> getCourseCount({
    String? subject,
    String? teacherName,
    String? searchQuery,
  }) async {
    try {
      var count = _supabase
          .from('courses')
          .select('id')
          .eq('is_published', true);

      if (subject != null && subject.isNotEmpty) {
        count = count.eq('subject', subject);
      }

      if (teacherName != null && teacherName.isNotEmpty) {
        count = count.ilike('teacher_name', '%$teacherName%');
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        count = count.or('title.ilike.%$searchQuery%,description.ilike.%$searchQuery%');
      }

      final response = await count.count();
      return response.count;
    } catch (e) {
      return 0;
    }
  }

  /// Download file URL (generates a signed URL for private files)
  Future<String> getAttachmentUrl(String fileUrl) async {
    try {
      // If the URL is already a full URL, return it
      if (fileUrl.startsWith('http')) {
        return fileUrl;
      }

      // Otherwise, generate a signed URL from storage
      final signedUrl = await _supabase.storage
          .from('courses')
          .createSignedUrl(fileUrl, 3600); // 1 hour expiry

      return signedUrl;
    } catch (e) {
      throw Exception('Failed to get attachment URL: $e');
    }
  }
}
