#ifndef THUMBNAIL_EXPORTER_H_
#define THUMBNAIL_EXPORTER_H_

#include <string>
#include <wtypes.h>

bool GetExplorerThumbnail(
    const std::wstring &videoPath,
    const std::wstring &outputPng,
    UINT requestedSize);

#endif // THUMBNAIL_EXPORTER_H_