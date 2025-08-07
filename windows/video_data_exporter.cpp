#include "video_data_exporter_api.h"
#include "thumbnail_exporter.h"
#include "video_duration.h"
#include <memory>
#include <gdiplus.h>
#include <mfapi.h>
#include <iostream>

class GdiplusInit {
public:
    GdiplusInit() {
        Gdiplus::GdiplusStartupInput input;
        Gdiplus::GdiplusStartup(&token, &input, nullptr);
    }
    ~GdiplusInit() {
        Gdiplus::GdiplusShutdown(token);
    }
private:
    ULONG_PTR token;
};

std::unique_ptr<GdiplusInit> gdiplus_initializer;

API_EXPORT void initialize_exporter() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    MFStartup(MF_VERSION, MFSTARTUP_FULL);
    if (!gdiplus_initializer) {
        gdiplus_initializer = std::make_unique<GdiplusInit>();
    }
}

API_EXPORT bool get_thumbnail(const wchar_t* video_path, const wchar_t* output_path, unsigned int size) {
    return GetExplorerThumbnail(video_path, output_path, size);
}

API_EXPORT double get_video_duration(const wchar_t* video_path) {
    return GetVideoFileDuration(video_path);
}

// === THIS IS THE CORRECTED FUNCTION USING YOUR PROVEN LOGIC ===
API_EXPORT bool get_file_metadata(const wchar_t* file_path, struct FileMetadata* metadata) {
    //print for debug
    // std::wcout << L"Getting metadata for: " << file_path << std::endl;
    if (metadata == nullptr) return false;
    
    // std::wcout << L"Metadata pointer is valid." << std::endl;

    WIN32_FILE_ATTRIBUTE_DATA fileAttrData;
    if (GetFileAttributesExW(file_path, GetFileExInfoStandard, &fileAttrData)) {
        // std::wcout << L"File attributes retrieved successfully." << std::endl;
        // Convert FILETIME to milliseconds since epoch
        ULARGE_INTEGER creationTime, accessTime, modifiedTime;
        creationTime.LowPart = fileAttrData.ftCreationTime.dwLowDateTime;
        creationTime.HighPart = fileAttrData.ftCreationTime.dwHighDateTime;
        accessTime.LowPart = fileAttrData.ftLastAccessTime.dwLowDateTime;
        accessTime.HighPart = fileAttrData.ftLastAccessTime.dwHighDateTime;
        modifiedTime.LowPart = fileAttrData.ftLastWriteTime.dwLowDateTime;
        modifiedTime.HighPart = fileAttrData.ftLastWriteTime.dwHighDateTime;
        // std::wcout << L"File times converted successfully." << std::endl;

        // Calculate file size
        ULARGE_INTEGER fileSize;
        fileSize.HighPart = fileAttrData.nFileSizeHigh;
        fileSize.LowPart = fileAttrData.nFileSizeLow;
        // std::wcout << L"File size calculated successfully." << std::endl;

        // Use your exact, proven conversion logic
        const int64_t WINDOWS_TICK = 10000000;
        const int64_t SEC_TO_UNIX_EPOCH = 11644473600LL;
        // std::wcout << L"Converting times to milliseconds since epoch." << std::endl;

        metadata->creation_time_ms = (creationTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
        metadata->access_time_ms = (accessTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
        metadata->modified_time_ms = (modifiedTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
        metadata->file_size_bytes = fileSize.QuadPart;
        // std::wcout << L"Metadata populated successfully." << std::endl;

        return true;
    }
    std::wcout << L"Failed to retrieve file attributes." << std::endl;
    
    return false;
}