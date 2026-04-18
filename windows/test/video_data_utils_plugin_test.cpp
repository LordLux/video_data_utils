#include <gtest/gtest.h>
#include <windows.h>
#include <shobjidl.h>
#include <objbase.h>
#include <tchar.h>
#include <fstream>
#include <iostream>
#include <string>

// Include the real API header
#include "../video_data_exporter_api.h"

// Helper to create a temp file for testing
std::wstring CreateTempFile(const std::wstring& suffix) {
    wchar_t temp_path[MAX_PATH];
    GetTempPathW(MAX_PATH, temp_path);
    std::wstring file_path = std::wstring(temp_path) + L"test_vdu_" + suffix;
    
    FILE* file = nullptr;
    _wfopen_s(&file, file_path.c_str(), L"w");
    if (file) {
        fputs("Sample test data to have non-zero file size.", file);
        fclose(file);
    }
    
    return file_path;
}

// Helper to create a Windows shortcut (.lnk)
bool CreateDummyShortcut(const std::wstring& target_path, const std::wstring& shortcut_path) {
    HRESULT hr = CoInitialize(NULL);
    bool co_init = SUCCEEDED(hr);
    
    IShellLinkW* psl;
    hr = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID*)&psl);
    if (SUCCEEDED(hr)) {
        psl->SetPath(target_path.c_str());
        psl->SetDescription(L"Test shortcut");

        IPersistFile* ppf;
        hr = psl->QueryInterface(IID_IPersistFile, (LPVOID*)&ppf);
        if (SUCCEEDED(hr)) {
            hr = ppf->Save(shortcut_path.c_str(), TRUE);
            ppf->Release();
        }
        psl->Release();
    }
    
    if (co_init) CoUninitialize();
    return SUCCEEDED(hr);
}

// Clean up helper
void DeleteFileWStr(const std::wstring& path) {
    DeleteFileW(path.c_str());
}

namespace video_data_utils {
namespace test {

TEST(VideoDataUtilsNativeTests, InitializeExporter) {
    // Should not crash when called multiple times
    EXPECT_NO_THROW({
        initialize_exporter();
        initialize_exporter();
    });
}

TEST(VideoDataUtilsNativeTests, GetFileMetadata_Success) {
    std::wstring txt_file = CreateTempFile(L"meta.txt");
    
    FileMetadata meta = {0};
    bool result = get_file_metadata(txt_file.c_str(), &meta);
    
    EXPECT_TRUE(result);
    EXPECT_GT(meta.file_size_bytes, 0); 
    EXPECT_GT(meta.creation_time_ms, 0);
    EXPECT_GT(meta.modified_time_ms, 0);
    
    DeleteFileWStr(txt_file);
}

TEST(VideoDataUtilsNativeTests, GetFileMetadata_Failure_MissingFile) {
    FileMetadata meta = {0};
    bool result = get_file_metadata(L"C:\\invalid_path_that_does_not_exist_12345.xyz", &meta);
    EXPECT_FALSE(result);
}

TEST(VideoDataUtilsNativeTests, ResolveShortcut_Success) {
    std::wstring target_file = CreateTempFile(L"target.txt");
    std::wstring shortcut_file = target_file + L".lnk";
    
    EXPECT_TRUE(CreateDummyShortcut(target_file, shortcut_file));
    
    wchar_t resolved_path[MAX_PATH];
    bool result = resolve_shortcut(shortcut_file.c_str(), resolved_path, MAX_PATH);
    
    EXPECT_TRUE(result);
    std::wstring resolved_wstr(resolved_path);
    // Verify target matches resolved path irrespective of casing
    std::wcout << L"Target expected: " << target_file << std::endl;
    std::wcout << L"Actual resolved: " << resolved_wstr << std::endl;
    wchar_t long1[MAX_PATH], long2[MAX_PATH]; GetLongPathNameW(target_file.c_str(), long1, MAX_PATH); GetLongPathNameW(resolved_wstr.c_str(), long2, MAX_PATH); EXPECT_TRUE(_wcsicmp(long1, long2) == 0);
    
    DeleteFileWStr(target_file);
    DeleteFileWStr(shortcut_file);
}

TEST(VideoDataUtilsNativeTests, ResolveShortcut_Failure_NotAShortcut) {
    std::wstring txt_file = CreateTempFile(L"not_a_shortcut.txt");
    
    wchar_t resolved_path[MAX_PATH];
    bool result = resolve_shortcut(txt_file.c_str(), resolved_path, MAX_PATH);
    
    EXPECT_FALSE(result); // Should fail because it's not a real .lnk file
    
    DeleteFileWStr(txt_file);
}

TEST(VideoDataUtilsNativeTests, GetVideoDuration_Failure_NotAVideo) {
    initialize_exporter(); 
    std::wstring txt_file = CreateTempFile(L"not_a_video.txt");
    
    double duration = get_video_duration(txt_file.c_str());
    EXPECT_LE(duration, 0.0); // Should return 0 or negative on fail
    
    DeleteFileWStr(txt_file);
}

TEST(VideoDataUtilsNativeTests, GetThumbnail_Failure_NotAVideo) {
    initialize_exporter();
    std::wstring txt_file = CreateTempFile(L"not_a_video2.txt");
    std::wstring out_thumb = txt_file + L"_thumb.jpg";
    
    bool result = get_thumbnail(txt_file.c_str(), out_thumb.c_str(), 256);
    
    EXPECT_FALSE(result);
    
    DeleteFileWStr(txt_file);
    DeleteFileWStr(out_thumb); 
}

TEST(VideoDataUtilsNativeTests, EdgeCases_NullPointers) {
    FileMetadata meta = {0};
    EXPECT_FALSE(get_file_metadata(nullptr, &meta));
    EXPECT_FALSE(get_file_metadata(L"C:\\dummy.txt", nullptr));
    
    wchar_t res_buf[MAX_PATH];
    EXPECT_FALSE(resolve_shortcut(nullptr, res_buf, MAX_PATH));
    EXPECT_FALSE(resolve_shortcut(L"C:\\dummy.lnk", nullptr, MAX_PATH));
    
    // We expect defensive 0.0 returns for duration rather than crashes
    EXPECT_LE(get_video_duration(nullptr), 0.0);
    
    EXPECT_FALSE(get_thumbnail(nullptr, L"out.jpg", 100));
    EXPECT_FALSE(get_thumbnail(L"vid.mp4", nullptr, 100));
}

TEST(VideoDataUtilsNativeTests, EdgeCases_EmptyStrings) {
    FileMetadata meta = {0};
    EXPECT_FALSE(get_file_metadata(L"", &meta));
    
    wchar_t res_buf[MAX_PATH];
    EXPECT_FALSE(resolve_shortcut(L"", res_buf, MAX_PATH));
    
    EXPECT_LE(get_video_duration(L""), 0.0);
    EXPECT_FALSE(get_thumbnail(L"", L"out.jpg", 100));
    EXPECT_FALSE(get_thumbnail(L"vid.mp4", L"", 100));
}

TEST(VideoDataUtilsNativeTests, EdgeCases_ExtremelyLongPath) {
    // Generate a proper Windows Long Path
    wchar_t temp_path[MAX_PATH];
    GetTempPathW(MAX_PATH, temp_path);
    std::wstring base_dir = std::wstring(temp_path) + L"test_vdu_long_path_dir\\";
    CreateDirectoryW(base_dir.c_str(), NULL);

    // Bypass MAX_PATH via \\?\ prefix natively supported by Windows W-APIs
    std::wstring current_path = L"\\\\?\\" + base_dir;
    for (int i = 0; i < 4; i++) {
        current_path += L"vdutest_long_dir_name_padding_to_exceed_max_path_limits_sz_";
        current_path += std::to_wstring(i) + L"\\";
        CreateDirectoryW(current_path.c_str(), NULL);
    }
    
    std::wstring file_path = current_path + L"long_target.txt";
    
    FILE* file = nullptr;
    _wfopen_s(&file, file_path.c_str(), L"w");
    if (file) {
        fputs("Sample test data to have non-zero file size.", file);
        fclose(file);
    }
    
    // Verify it exceeds standard restrictions
    EXPECT_GT(file_path.length(), 260);
    
    FileMetadata meta = {0};
    EXPECT_TRUE(get_file_metadata(file_path.c_str(), &meta));
    EXPECT_GT(meta.file_size_bytes, 0);

    // Cleanup generated file (we'll leave the nested temp dirs)
    DeleteFileW(file_path.c_str());
}

TEST(VideoDataUtilsNativeTests, EdgeCases_TinyBufferForShortcut) {
    std::wstring target_file = CreateTempFile(L"tiny_target.txt");
    std::wstring shortcut_file = target_file + L".lnk";
    CreateDummyShortcut(target_file, shortcut_file);
    
    wchar_t small_buf[3]; // Unreasonably small
    // The underlying impl shouldn't crash, it should reject or handle safely 
    resolve_shortcut(shortcut_file.c_str(), small_buf, 3);
    
    // Clean up
    DeleteFileWStr(target_file);
    DeleteFileWStr(shortcut_file);
}

TEST(VideoDataUtilsNativeTests, ActualVideo_SuccessPath) {
    initialize_exporter();
    // Known file likely present on this developer's environment (Adobe plugin asset)
    std::wstring video_file = L"C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat\\WebResources\\Resource3\\static\\js\\plugins\\on-boarding\\videos\\whats_new\\de-de\\UnifiedShareSheet.mp4";
    
    DWORD attrib = GetFileAttributesW(video_file.c_str());
    if (attrib != INVALID_FILE_ATTRIBUTES) {
        double duration = get_video_duration(video_file.c_str());
        EXPECT_GT(duration, 0.0);
        
        std::wstring thumb_out = CreateTempFile(L"thumb.jpg"); // just gets a valid temp path
        bool thumb_res = get_thumbnail(video_file.c_str(), thumb_out.c_str(), 128);
        EXPECT_TRUE(thumb_res);
        
        FileMetadata meta = {0};
        EXPECT_TRUE(get_file_metadata(thumb_out.c_str(), &meta));
        // Verify a meaningful image file size was written
        EXPECT_GT(meta.file_size_bytes, 100); 
        
        DeleteFileWStr(thumb_out);
    } else {
        std::wcout << L"[  SKIPPED ] ActualVideo_SuccessPath: Sample video file not found on disk." << std::endl;
    }
}

} // namespace test
} // namespace video_data_utils
