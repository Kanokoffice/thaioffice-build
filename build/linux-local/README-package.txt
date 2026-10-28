กนก ออฟฟิศ (Kanok Office) 26.8.1.1 สำหรับ Linux x86-64 · แพ็กเกจ .deb · ภาษาไทย + อังกฤษ
==========================================================================================

ระบบที่รองรับ
  Ubuntu 24.04 LTS และ distro ที่ใช้ฐาน Ubuntu 24.04 (เช่น Linux Mint 22) บนเครื่อง 64 บิต (x86-64)
  ไม่รองรับ Debian 12 และ distro ที่เก่ากว่า Ubuntu 24.04 (ตัวโปรแกรมต้องการ glibc 2.38 ขึ้นไป,
  libstdc++ ของ GCC 13 ขึ้นไป และ Python 3.12)

ติดตั้ง
  tar -xzf KanokOffice_26.8.1.1_Linux_x86-64_deb_th.tar.gz
  cd KanokOffice_26.8.1.1_Linux_x86-64_deb_th
  sudo apt install ./DEBS/*.deb

  โปรแกรมติดตั้งที่ /opt/kanokoffice26.8 · เปิดจากเมนูโปรแกรม หรือพิมพ์คำสั่ง kanokoffice26.8
  หน้าจอเป็นภาษาไทยตั้งแต่เปิดครั้งแรก (เปลี่ยนได้ที่ เครื่องมือ > ตัวเลือก > ภาษาและท้องถิ่น)

  เครื่อง desktop ทั่วไปมีไลบรารีที่โปรแกรมใช้อยู่แล้ว ถ้าเป็นเครื่องแบบติดตั้งน้อยที่สุด ให้ติดตั้งก่อนด้วย
  sudo apt install libgtk-3-0t64 libcups2t64 libdbus-1-3 libdconf1 libnss3 libgssapi-krb5-2 \
       libgstreamer-plugins-base1.0-0 libxinerama1 libx11-xcb1 libsm6 libice6 \
       libpython3.12t64 python3

ถอนการติดตั้ง
  sudo apt purge 'kanokoffice26.8*' 'kanokbasis26.8*'

ที่มาและสัญญาอนุญาต
  อ่าน KANOK-NOTICE.txt ในโฟลเดอร์นี้ (ติดตั้งไว้ที่ /opt/kanokoffice26.8/KANOK-NOTICE.txt ด้วย)
  ซอร์สโค้ด: https://kanokoffice.com/source


Kanok Office 26.8.1.1 for Linux x86-64 · .deb packages · Thai + English
=======================================================================

Supported systems
  Ubuntu 24.04 LTS and distributions based on Ubuntu 24.04 (such as Linux Mint 22), 64-bit (x86-64).
  Not supported: Debian 12 and distributions older than Ubuntu 24.04 (the program needs glibc 2.38 or later,
  the libstdc++ of GCC 13 or later, and Python 3.12).

Install
  tar -xzf KanokOffice_26.8.1.1_Linux_x86-64_deb_th.tar.gz
  cd KanokOffice_26.8.1.1_Linux_x86-64_deb_th
  sudo apt install ./DEBS/*.deb

  The office is installed in /opt/kanokoffice26.8. Start it from the applications menu or with the command
  kanokoffice26.8. The user interface is in Thai from the first start (Tools > Options > Languages and Locales
  to change it).

  A desktop system already has the libraries the office uses. On a minimal system install them first:
  sudo apt install libgtk-3-0t64 libcups2t64 libdbus-1-3 libdconf1 libnss3 libgssapi-krb5-2 \
       libgstreamer-plugins-base1.0-0 libxinerama1 libx11-xcb1 libsm6 libice6 \
       libpython3.12t64 python3

Uninstall
  sudo apt purge 'kanokoffice26.8*' 'kanokbasis26.8*'

Origin and licenses
  See KANOK-NOTICE.txt in this folder (also installed as /opt/kanokoffice26.8/KANOK-NOTICE.txt).
  Source code: https://kanokoffice.com/source
