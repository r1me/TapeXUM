unit libwdi;

{/*
 * Library for USB automated driver installation
 * Copyright (c) 2010-2017 Pete Batard <pete@akeo.ie>
 * Parts of the code from libusb by Daniel Drake, Johannes Erdfelt et al.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */}

interface

uses
  Winapi.Windows;

{/*
 * Maximum length for any string used by libwdi structures
 */  }
const WDI_MAX_STRLEN	=	200;

{/*
 * Type of driver to install
 */ }
type wdi_driver_type = (
	WDI_WINUSB,
	WDI_LIBUSB0,
	WDI_LIBUSBK,
	WDI_CDC,
	WDI_USER,
	WDI_NB_DRIVERS	// Total number of drivers in the enum
);

{/*
 * Log level
 */}
type wdi_log_level = (
	WDI_LOG_LEVEL_DEBUG,
	WDI_LOG_LEVEL_INFO,
	WDI_LOG_LEVEL_WARNING,
	WDI_LOG_LEVEL_ERROR,
	WDI_LOG_LEVEL_NONE
);

{/*
 * Error codes. Most libwdi functions return 0 on success or one of these
 * codes on failure.
 * You can use wdi_strerror() to retrieve a short string description of
 * a wdi_error enumeration value.
 */ }
type wdi_error = (
	///** Success (no error) */
	WDI_SUCCESS = 0,

	///** Input/output error */
	WDI_ERROR_IO = -1,

	///** Invalid parameter */
	WDI_ERROR_INVALID_PARAM = -2,

	///** Access denied (insufficient permissions) */
	WDI_ERROR_ACCESS = -3,

	///** No such device (it may have been disconnected) */
	WDI_ERROR_NO_DEVICE = -4,

	///** Entity not found */
	WDI_ERROR_NOT_FOUND = -5,

	///** Resource busy, or API call already running */
	WDI_ERROR_BUSY = -6,

	///** Operation timed out */
	WDI_ERROR_TIMEOUT = -7,

	///** Overflow */
	WDI_ERROR_OVERFLOW = -8,

	///** Another installation is pending */
	WDI_ERROR_PENDING_INSTALLATION = -9,

	///** System call interrupted (perhaps due to signal) */
	WDI_ERROR_INTERRUPTED = -10,

	///** Could not acquire resource (Insufficient memory, etc) */
	WDI_ERROR_RESOURCE = -11,

	///** Operation not supported or unimplemented on this platform */
	WDI_ERROR_NOT_SUPPORTED = -12,

	///** Entity already exists */
	WDI_ERROR_EXISTS = -13,

	///** Cancelled by user */
	WDI_ERROR_USER_CANCEL = -14,

	///** Couldn't run installer with required privileges */
	WDI_ERROR_NEEDS_ADMIN = -15,

	///** Attempted to run the 32 bit installer on 64 bit */
	WDI_ERROR_WOW64 = -16,

	///** Bad inf syntax */
	WDI_ERROR_INF_SYNTAX = -17,

	///** Missing cat file */
	WDI_ERROR_CAT_MISSING = -18,

	///** System policy prevents the installation of unsigned drivers */
	WDI_ERROR_UNSIGNED = -19,

	///** Other error */
	WDI_ERROR_OTHER = -99

 {	/** IMPORTANT: when adding new values to this enum, remember to
	   update the wdi_strerror() function implementation! */}
);


{/*
 * Device information structure, used by libwdi functions
 */  }
type
  pwdi_device_info = ^wdi_device_info;
  wdi_device_info = record
    ///** (Optional) Pointer to the next element in the chained list. NULL if unused */
    next: pwdi_device_info;
    ///** USB VID */
    vid: Word;
    ///** USB PID */
    pid: Word;
    ///** Whether the USB device is composite */
    is_composite: Boolean;
    ///** (Optional) Composite USB interface number */
    mi: Byte;
    ///** USB Device description, usually provided by the device itself */
    desc: PUTF8Char;
    ///** Windows' driver (service) name */
    driver: PUTF8Char;
    ///** (Optional) Microsoft's device URI string. NULL if unused */
    device_id: PUTF8Char;
    ///** (Optional) Microsoft's Hardware ID string. NULL if unused */
    hardware_id: PUTF8Char;
    ///** (Optional) Microsoft's Compatible ID string. NULL if unused */
    compatible_id: PUTF8Char;
    ///** (Optional) Upper filter. NULL if unused */
    upper_filter: PUTF8Char;
    ///** (Optional) Driver version (four WORDS). 0 if unused */
    driver_version: UINT64;
  end;
  ppwdi_device_info = ^pwdi_device_info;

{/*
 * Optional settings, used by libwdi functions
 */}

// wdi_create_list options
type
  wdi_options_create_list = record
    ///** list all devices, instead of just the ones that are driverless */
    list_all: Boolean;
    ///** also list generic hubs and composite parent devices */
    list_hubs: Boolean;
    ///** trim trailing whitespaces from the description string */
    trim_whitespaces: Boolean;
  end;
  pwdi_options_create_list = ^wdi_options_create_list;

// wdi_prepare_driver options:
type
  wdi_options_prepare_driver = record
    ///** Type of driver to use. Should be either WDI_WINUSB, WDI_LIBUSB, WDI_LIBUSBK or WDI_USER */
    driver_type: Integer;
    ///** Vendor name that should be used for the Manufacturer in the inf */
    vendor_name: PUTF8Char;
    ///** Device GUID (with braces) that should be used, instead of the automatically generated one */
    device_guid: PUTF8Char;
    ///** Disable the generation of a cat file for libusbK, libusb0 or WinUSB drivers */
    disable_cat: Boolean;
    ///** Disable the signing and installation of a self-signed certificate, for libusbK, libusb0 or WinUSB drivers */
    disable_signing: Boolean;
    {/** Subject to use for the self-signing autogenerated certificate.
      * default is "CN=USB\VID_####&PID_####[&MI_##] (libwdi autogenerated)" */ }
    cert_subject: PUTF8Char;
    ///** Install a generic driver, for WCID devices, to allow for automated installation */
    use_wcid_driver: Boolean;
  end;
  pwdi_options_prepare_driver = ^wdi_options_prepare_driver;

// wdi_install_driver options:
type
  wdi_options_install_driver = record
    ///** Handle to a Window application that should receive a modal progress dialog */
    aWnd: HWND;
    ///** Install a filter driver instead of a regular driver (libusb-win32 only) */
    install_filter_driver: Boolean;
    ///** Number of milliseconds to wait for any pending installations */
    pending_install_timeout: UINT32;
  end;
  pwdi_options_install_driver = ^wdi_options_install_driver;

// wdi_install_trusted_certificate options:
type
  wdi_options_install_cert = record
    ///** handle to a Window application that can receive a modal progress dialog */
    aWnd: HWND;
    ///** Should the warning about a Trusted Publisher installation be disabled? */
    disable_warning: Boolean;
  end;
  pwdi_options_install_cert = ^wdi_options_install_cert;

{/*
 * Convert a libwdi error to a human readable error message
 */}
function wdi_strerror(errcode: Integer): PUTF8Char; stdcall; external 'libwdi.dll';

{/*
 * Check if a specific driver is supported (embedded) in the current libwdi binary
 */}
function wdi_is_driver_supported(driver_type: Integer; driver_info: PVSFixedFileInfo): Boolean; stdcall; external 'libwdi.dll';

{/*
 * Check if a specific file is embedded in the current libwdi binary
 * path is the relative path that would be used for extraction and can be NULL,
 * in which case any instance of "name" will return true, no matter the extraction path
 */}
function wdi_is_file_embedded(const path: PUTF8Char; const name: PUTF8Char): Boolean; stdcall; external 'libwdi.dll';

{/*
 * Retrieve the full Vendor name from a Vendor ID (VID)
 */}
function wdi_get_vendor_name(vid: Word): PUTF8Char; stdcall; external 'libwdi.dll';

{/*
 * Return a wdi_device_info list of USB devices
 * parameter: driverless_only - boolean
 */}
function wdi_create_list(list: ppwdi_device_info; options: pwdi_options_create_list): Integer; stdcall; external 'libwdi.dll';

{/*
 * Release a wdi_device_info list allocated by the previous call
 */}
function wdi_destroy_list(list: pwdi_device_info): Integer; stdcall; external 'libwdi.dll';

{/*
 * Create an inf file for a specific device
 */}
function wdi_prepare_driver(device_info: pwdi_device_info; const path: PUTF8Char;
								  const inf_name: PUTF8Char; options: pwdi_options_prepare_driver): Integer; stdcall; external 'libwdi.dll';

{/*
 * Install a driver for a specific device
 */}
function wdi_install_driver(device_info: pwdi_device_info; const path: PUTF8Char;
								  const inf_name: PUTF8Char; options: pwdi_options_install_driver): Integer; stdcall; external 'libwdi.dll';

{/*
 * Install a code signing certificate (from embedded resources) into
 * the Trusted Publisher repository. Requires elevated privileges.
 */}
function wdi_install_trusted_certificate(const cert_name: PUTF8Char;
														  options: pwdi_options_install_cert): Integer; stdcall; external 'libwdi.dll';

{/*
 * Set the log verbosity
 */}
function wdi_set_log_level(level: Integer): Integer; stdcall; external 'libwdi.dll';

{/*
 * Set the Windows callback message for log notification
 */}
function wdi_register_logger(aWnd: HWND; messge: UINT; buffsize: DWORD): Integer; stdcall; external 'libwdi.dll';

{/*
 * Unset the Windows callback message for log notification
 */}
function wdi_unregister_logger(aWnd: HWND): Integer; stdcall; external 'libwdi.dll';

{/*
 * Read a log message after a log notification
 */}
function wdi_read_logger(buffer: PUTF8Char; buffer_size: DWORD; var message_size: DWORD): Integer; stdcall; external 'libwdi.dll';

{/*
 * Return the WDF version used by the native drivers
 */}
function wdi_get_wdf_version(): Integer; stdcall; external 'libwdi.dll';

implementation

end.
