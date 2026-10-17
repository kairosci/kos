# OnlyOffice

Setup installs `onlyoffice-bin` from AUR after integrity verification and merges
`data/DesktopEditors.conf` into the native user configuration. Existing account
data, recent files and unrelated preferences are preserved with a backup.

Documents open in tabs and use the application's custom title bar. OnlyOffice
handles word processing, spreadsheets and presentations, including Microsoft
Office and OpenDocument formats. Papers remains the PDF viewer; Zed handles
plain text and source code.

Apply changes through `make setup`.
