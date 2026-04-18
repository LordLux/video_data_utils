#include "shortcut_resolver.h"
#include <windows.h>
#include <shobjidl.h>
#include <shlguid.h>
#include <strsafe.h>
#include <iostream>

HRESULT ResolveShortcut(HWND hwnd, LPCWSTR lpszLinkFile, LPWSTR lpszPath, int iPathBufferSize)
{
    HRESULT hres;
    IShellLinkW *psl;
    WIN32_FIND_DATAW wfd;

    *lpszPath = 0; // Assume failure

    // Get a pointer to the IShellLinkW interface
    hres = CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, IID_IShellLinkW, (LPVOID *)&psl);
    if (FAILED(hres))
    {
        std::cerr << "Failed to create IShellLinkW instance" << std::endl;
        return hres;
    }

    IPersistFile *ppf;
    // Get a pointer to the IPersistFile interface
    hres = psl->QueryInterface(IID_IPersistFile, (void **)&ppf);
    if (FAILED(hres))
    {
        std::cerr << "Failed to get IPersistFile interface" << std::endl;
        psl->Release();
        return hres;
    }

    // Load the shortcut using the native Wide String
    hres = ppf->Load(lpszLinkFile, STGM_READ);
    if (FAILED(hres))
    {
        std::cerr << "Failed to load shortcut file" << std::endl;
        ppf->Release();
        psl->Release();
        return hres;
    }

    // Resolve the link
    hres = psl->Resolve(hwnd, SLR_NO_UI | SLR_NOUPDATE);
    if (FAILED(hres))
    {
        std::cerr << "Failed to resolve link" << std::endl;
        ppf->Release();
        psl->Release();
        return hres;
    }

    // Get the path directly into the provided output buffer
    hres = psl->GetPath(lpszPath, iPathBufferSize / sizeof(WCHAR), &wfd, SLGP_UNCPRIORITY);
    if (FAILED(hres))
    {
        std::cerr << "Failed to get path" << std::endl;
        ppf->Release();
        psl->Release();
        return hres;
    }

    ppf->Release();
    psl->Release();

    return hres;
}
