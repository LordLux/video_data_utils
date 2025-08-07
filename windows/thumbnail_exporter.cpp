#include "thumbnail_exporter.h"
#include <windows.h>
#include <shobjidl.h>
#include <shlwapi.h>
#include <wrl/client.h>
#include <gdiplus.h>
#include <vector>
#include <thumbcache.h>
#include <iostream>
#include <shlguid.h>

#pragma comment(lib, "Shlwapi.lib")
#pragma comment(lib, "Shell32.lib")
#pragma comment(lib, "Gdiplus.lib")

bool GetExplorerThumbnail(
    const std::wstring &videoPath,
    const std::wstring &outputPng,
    UINT requestedSize)
{
    try
    {
        // Initialize GDI+
        Microsoft::WRL::ComPtr<IShellItem> shellItem;
        HRESULT hr = SHCreateItemFromParsingName(videoPath.c_str(), nullptr, IID_PPV_ARGS(&shellItem));
        if (FAILED(hr))
        {
            std::cerr << "thumbnail_exporter | Failed to create shell item: " << std::hex << hr << std::endl;
            return false;
        }
        
        // Create a thumbnail provider for the shell item
        Microsoft::WRL::ComPtr<IThumbnailProvider> thumbProvider;
        hr = shellItem->BindToHandler(nullptr, BHID_ThumbnailHandler, IID_PPV_ARGS(&thumbProvider));
        if (FAILED(hr))
        {
            std::cerr << "thumbnail_exporter | Failed to bind to thumbnail handler: " << std::hex << hr << std::endl;
            return false;
        }

        // Request a thumbnail of the specified size
        HBITMAP hBitmap = nullptr;
        WTS_ALPHATYPE alphaType;
        hr = thumbProvider->GetThumbnail(requestedSize, &hBitmap, &alphaType);
        if (FAILED(hr))
        {
            std::cerr << "thumbnail_exporter | Failed to get thumbnail: " << std::hex << hr << std::endl;
            return false;
        }
        
        // Check if the bitmap was created successfully
        Gdiplus::Bitmap bmp(hBitmap, nullptr);
        CLSID pngClsid;
        UINT num = 0, size = 0;
        Gdiplus::GetImageEncodersSize(&num, &size);
        if (size == 0)
        {
            std::cerr << "thumbnail_exporter | No image encoders found." << std::endl;
            DeleteObject(hBitmap);
            return false;
        }
        
        // Allocate a buffer to hold the image encoders
        std::vector<BYTE> buffer(size);
        auto pEncoders = reinterpret_cast<Gdiplus::ImageCodecInfo *>(buffer.data());
        Gdiplus::GetImageEncoders(num, size, pEncoders);
        for (UINT i = 0; i < num; i++)
        {
            if (wcscmp(pEncoders[i].MimeType, L"image/png") == 0)
            {
                // Found the PNG encoder
                pngClsid = pEncoders[i].Clsid;
                break;
            }
        }

        Gdiplus::Status status = bmp.Save(outputPng.c_str(), &pngClsid, nullptr);
        DeleteObject(hBitmap);
        if (status != Gdiplus::Ok)
        {
            std::cerr << "thumbnail_exporter | Failed to save thumbnail: " << status << std::endl;
            return false;
        }
        return true;
    }
    catch (const std::exception &e)
    {
        std::cerr << "thumbnail_exporter | Error extracting thumbnail: " << e.what() << std::endl;
        return false;
    }
}