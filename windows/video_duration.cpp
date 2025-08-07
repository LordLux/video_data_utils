// In windows/video_duration.cpp

#include "video_duration.h"
#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfreadwrite.h>
#include <propvarutil.h>
#include <shlwapi.h> // For PathFileExistsW
#include <iostream>  // For debug output if needed

// Link necessary libraries
#pragma comment(lib, "mfplat.lib")
#pragma comment(lib, "mfreadwrite.lib")
#pragma comment(lib, "mfuuid.lib")
#pragma comment(lib, "shlwapi.lib")

// A helper function to safely release a COM object pointer.
template <class T>
void SafeRelease(T **ppT)
{
  if (*ppT)
  {
    (*ppT)->Release();
    *ppT = NULL;
  }
}

// Your proven implementation for getting video duration
double GetVideoFileDuration(const std::wstring &filePath)
{
  IMFByteStream *pByteStream = NULL;
  IMFSourceReader *pReader = NULL;
  PROPVARIANT var;
  PropVariantInit(&var);
  
  std::wcout << L"A" << std::endl;

  // Checks if the file exists first (good practice!)
  if (!PathFileExistsW(filePath.c_str()))
  {
    // You can add a debug print here if you want
    std::wcerr << L"File not found: " << filePath << std::endl;
    return 0.0;
  }

  std::wcout << L"B" << std::endl;
  // Creates a byte stream from the file path. This is more robust.
  HRESULT hr = MFCreateFile(
      MF_ACCESSMODE_READ,
      MF_OPENMODE_FAIL_IF_NOT_EXIST,
      MF_FILEFLAGS_NONE,
      filePath.c_str(),
      &pByteStream
  );

  if (FAILED(hr))
  {
    std::wcerr << L"Failed to create Byte Stream from file path" << std::endl;
    SafeRelease(&pByteStream);
    return 0.0;
  }

  // Creates the source reader from the byte stream
  hr = MFCreateSourceReaderFromByteStream(pByteStream, NULL, &pReader);
  if (FAILED(hr))
  {
    std::wcerr << L"Failed to create Source Reader from byte stream" << std::endl;
    SafeRelease(&pByteStream);
    SafeRelease(&pReader);
    return 0.0;
  }

  // Gets duration from the presentation descriptor
  hr = pReader->GetPresentationAttribute(MF_SOURCE_READER_MEDIASOURCE, MF_PD_DURATION, &var);
  
  double durationMs = 0.0;
  if (SUCCEEDED(hr))
  {
    ULONGLONG duration = var.uhVal.QuadPart;
    durationMs = static_cast<double>(duration) / 10000.0; // Converts from 100-nanosecond units to milliseconds
    std::wcout << L"Successfully extracted duration: " << durationMs << std::endl;
  }

  // Cleanup all resources
  PropVariantClear(&var);
  SafeRelease(&pReader);
  SafeRelease(&pByteStream);

  return durationMs;
}