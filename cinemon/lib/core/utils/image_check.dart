import 'package:supabase_flutter/supabase_flutter.dart';

import 'content_refusal.dart';

/// A photo the check refused, or couldn't check.
class ImageRejected implements Exception {
  const ImageRejected(this.code);

  /// `objectionable_image`, or `image_check_failed` when the check itself
  /// didn't answer. Both refuse the photo.
  final String code;

  @override
  String toString() => code;
}

/// Asks the `moderate-image` Edge Function (migration 022) about a photo
/// just uploaded, before anything points at it. Refused photos are deleted
/// by the function. Anything but a clear yes throws [ImageRejected]: a photo
/// that couldn't be checked isn't posted. The one exception is a project
/// where the function hasn't been deployed yet.
Future<void> checkUploadedImage(
    SupabaseClient client, String bucket, String path) async {
  bool ok;
  try {
    final res = await client.functions.invoke(
      'moderate-image',
      body: {'bucket': bucket, 'path': path},
    );
    ok = res.data is Map && (res.data as Map)['ok'] == true;
    if (!ok) {
      noteRefusal('objectionable_image');
      throw const ImageRejected('objectionable_image');
    }
  } on ImageRejected {
    rethrow;
  } on FunctionException catch (e) {
    // Not deployed yet (404): until the function exists there is nothing to
    // ask, so the photo goes through. Once it's deployed, anything but a
    // clear yes refuses the photo.
    final verdict = e.details is Map ? (e.details as Map)['verdict'] : null;
    // (The function's own 404 carries a verdict: the photo is gone, perhaps
    // because it was just refused.)
    if (e.status == 404 && verdict == null) return;
    final code = verdict == 'rejected' || verdict == 'minors'
        ? 'objectionable_image'
        : 'image_check_failed';
    noteRefusal(code);
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {}
    throw ImageRejected(code);
  } catch (_) {
    noteRefusal('image_check_failed');
    try {
      await client.storage.from(bucket).remove([path]);
    } catch (_) {}
    throw const ImageRejected('image_check_failed');
  }
}
