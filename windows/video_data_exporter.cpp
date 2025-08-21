#include "video_data_exporter_api.h"
#include "thumbnail_exporter.h"
#include "video_duration.h"
#include <memory>
#include <gdiplus.h>
#include <mfapi.h>
#include <iostream>

class GdiplusInit
{
public:
    GdiplusInit()
    {
        Gdiplus::GdiplusStartupInput input;
        Gdiplus::GdiplusStartup(&token, &input, nullptr);
    }
    ~GdiplusInit()
    {
        Gdiplus::GdiplusShutdown(token);
    }

private:
    ULONG_PTR token;
};

std::unique_ptr<GdiplusInit> gdiplus_initializer;

API_EXPORT void initialize_exporter()
{
    try
    {
        // Initialize COM and Media Foundation
        CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
        MFStartup(MF_VERSION, MFSTARTUP_FULL);
        if (!gdiplus_initializer)
        {
            // Initialize GDI+ only once
            gdiplus_initializer = std::make_unique<GdiplusInit>();
        }
    }
    catch (const std::exception &e)
    {
        std::cerr << "video_data_exporter | Initialization failed: " << e.what() << std::endl;
    }
}

API_EXPORT bool get_thumbnail(const wchar_t *video_path, const wchar_t *output_path, unsigned int size)
{
    return GetExplorerThumbnail(video_path, output_path, size);
}

API_EXPORT double get_video_duration(const wchar_t *video_path)
{
    return GetVideoFileDuration(video_path);
}

API_EXPORT bool get_file_metadata(const wchar_t *file_path, struct FileMetadata *metadata)
{
    try
    {
        // Ensure file path is not null or empty
        if (file_path == nullptr || wcslen(file_path) == 0)
        {
            std::cerr << L"video_data_exporter | Invalid file path for file: '" << file_path << "'" << std::endl;
            return false;
        }

        // Ensure metadata pointer is not null
        if (metadata == nullptr)
        {
            std::cerr << L"video_data_exporter | Metadata pointer is null for file: " << file_path << std::endl;
            return false;
        }

        // Use GetFileAttributesEx to retrieve file attributes
        WIN32_FILE_ATTRIBUTE_DATA fileAttrData;
        if (GetFileAttributesExW(file_path, GetFileExInfoStandard, &fileAttrData))
        {
            // Convert FILETIME to milliseconds since epoch
            ULARGE_INTEGER creationTime, accessTime, modifiedTime;
            creationTime.LowPart = fileAttrData.ftCreationTime.dwLowDateTime;
            creationTime.HighPart = fileAttrData.ftCreationTime.dwHighDateTime;
            accessTime.LowPart = fileAttrData.ftLastAccessTime.dwLowDateTime;
            accessTime.HighPart = fileAttrData.ftLastAccessTime.dwHighDateTime;
            modifiedTime.LowPart = fileAttrData.ftLastWriteTime.dwLowDateTime;
            modifiedTime.HighPart = fileAttrData.ftLastWriteTime.dwHighDateTime;

            // Calculate file size
            ULARGE_INTEGER fileSize;
            fileSize.HighPart = fileAttrData.nFileSizeHigh;
            fileSize.LowPart = fileAttrData.nFileSizeLow;

            // Use your exact, proven conversion logic
            const int64_t WINDOWS_TICK = 10000000;
            const int64_t SEC_TO_UNIX_EPOCH = 11644473600LL;

            // Fill the metadata structure
            metadata->creation_time_ms = (creationTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
            metadata->access_time_ms = (accessTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
            metadata->modified_time_ms = (modifiedTime.QuadPart / (WINDOWS_TICK / 1000)) - (SEC_TO_UNIX_EPOCH * 1000);
            metadata->file_size_bytes = fileSize.QuadPart;

            return true;
        }

        std::cerr << "video_data_exporter | Failed to retrieve file attributes for: " << file_path << std::endl;
        return false;
    }
    catch (const std::exception &e)
    {
        std::cerr << "video_data_exporter | Exception occurred when getting file metadata for file: " << file_path << ": " << e.what() << std::endl;
        return false;
    }

    std::cerr << "video_data_exporter | Failed to retrieve file attributes for file: " << file_path << ": Unknown error." << std::endl;
    return false;
}