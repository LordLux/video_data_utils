#ifndef SHORTCUT_RESOLVER_H
#define SHORTCUT_RESOLVER_H

#include <windows.h>

#ifdef __cplusplus
extern "C"
{
#endif

    /**
     * @brief Resolves a Windows shortcut (.lnk) file to its target path.
     *
     * Uses the Shell's IShellLink and IPersistFile interfaces to retrieve
     * the path from an existing shortcut.
     *
     * @param lpszLinkFile Path to the shortcut file (.lnk)
     * @param lpszPath Buffer to receive the resolved target path
     * @param iPathBufferSize Size of the lpszPath buffer in bytes
     * @return HRESULT S_OK on success, or an error code on failure
     *
     * @note CoInitialize must be called before using this function
     */
    HRESULT ResolveShortcut(HWND hwnd, LPCWSTR lpszLinkFile, LPWSTR lpszPath, int iPathBufferSize);

#ifdef __cplusplus
}
#endif

#endif // SHORTCUT_RESOLVER_H
