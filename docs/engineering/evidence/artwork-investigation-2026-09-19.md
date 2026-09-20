# Read-only local artwork investigation

Investigator: /root/mac_installation, Sol Medium. No writes or app interaction.

All four installed Workshop mods contain DXT5 PAA images with uncompressed
mipmaps usable without LZO. CBA, ACE and ACRE provide loose images referenced by
mod.cpp: respectively logo_cba_ca.paa, logo_ace3_ca.paa and
acre_logo_medium_ca.paa. Each has a raw 128x128 mip (16,384 encoded bytes).
ALiVE references x\alive\addons\ui\logo_alive_crop.paa. Its addons/ui.pbo has
that prefix, and the image is a stored entry (20,250 bytes) at offset 780,653.
The embedded raw 128x64 mip is 8,192 encoded bytes. The main.pbo picture also has
a raw 128x64 mip. Headers and requested bytes can be read without extraction.

Scoped local ACF/mod.cpp/meta.cpp inspection found no Workshop dependency IDs.
The ACF records contain installation/manifest state; meta.cpp publishedid is the
mod's own identifier. Do not infer Workshop dependency edges from known names.

Primary format references:
[PAA](https://community.bistudio.com/wiki/PAA_File_Format),
[PBO](https://community.bistudio.com/wiki/PBO).
Read-only rg/stat/xxd/Python header inspection receipts all exited 0. No real
addon artwork or archive data was copied into the repository.
