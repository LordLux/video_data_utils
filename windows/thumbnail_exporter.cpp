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
    Microsoft::WRL::ComPtr<IShellItem> shellItem;
    HRESULT hr = SHCreateItemFromParsingName(videoPath.c_str(), nullptr, IID_PPV_ARGS(&shellItem));
    if (FAILED(hr)) {
        return false;
    }

    Microsoft::WRL::ComPtr<IThumbnailProvider> thumbProvider;
    hr = shellItem->BindToHandler(nullptr, BHID_ThumbnailHandler, IID_PPV_ARGS(&thumbProvider));
    if (FAILED(hr)) {
        return false;
    }

    HBITMAP hBitmap = nullptr;
    WTS_ALPHATYPE alphaType;
    hr = thumbProvider->GetThumbnail(requestedSize, &hBitmap, &alphaType);
    if (FAILED(hr)) {
        return false;
    }

    Gdiplus::Bitmap bmp(hBitmap, nullptr);
    CLSID pngClsid;
    UINT num = 0, size = 0;
    Gdiplus::GetImageEncodersSize(&num, &size);
    if (size == 0) {
        DeleteObject(hBitmap);
        return false;
    }

    std::vector<BYTE> buffer(size);
    auto pEncoders = reinterpret_cast<Gdiplus::ImageCodecInfo*>(buffer.data());
    Gdiplus::GetImageEncoders(num, size, pEncoders);
    for (UINT i = 0; i < num; i++) {
        if (wcscmp(pEncoders[i].MimeType, L"image/png") == 0) {
            pngClsid = pEncoders[i].Clsid;
            break;
        }
    }
    
    Gdiplus::Status status = bmp.Save(outputPng.c_str(), &pngClsid, nullptr);
    DeleteObject(hBitmap);
    return (status == Gdiplus::Ok);
}