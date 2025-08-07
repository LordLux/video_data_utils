#ifndef VIDEO_DATA_EXPORTER_API_H
#define VIDEO_DATA_EXPORTER_API_H

#include <windows.h>
#include <cstdint>

struct FileMetadata {
    int64_t creation_time_ms;
    int64_t access_time_ms;
    int64_t modified_time_ms;
    int64_t file_size_bytes;
};

#if defined(__cplusplus)
extern "C" {
#endif

#define API_EXPORT __declspec(dllexport)

API_EXPORT void initialize_exporter();
API_EXPORT bool get_thumbnail(const wchar_t* video_path, const wchar_t* output_path, unsigned int size);
API_EXPORT double get_video_duration(const wchar_t* video_path);
API_EXPORT bool get_file_metadata(const wchar_t* file_path, struct FileMetadata* metadata);

#if defined(__cplusplus)
}
#endif

#endif // VIDEO_DATA_EXPORTER_API_H