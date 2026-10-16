# Brave Origin

Setup applies the Lua application registry and installs `data/component/application/brave/brave-origin-flags.conf` at the native XDG config path read by the Arch Brave Origin launcher. Browser profiles remain in Brave Origin's existing user directory.

The privileged setup stage creates the protected managed-policy directory and applies the current desktop background color through OS's packaged browser-policy helper. The color scheme follows the system; first setup defaults to dark. Running Brave Origin instances refresh platform policies without opening a new window or editing their profile files.
