#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.


# We get the source code of busybox and
# We compile it in CONFIG_STATIC
# This will allow us to have some basic commande
# like ls, cd, uname etc ... without the need
# of a libc

wget http://busybox.net/downloads/busybox-1.24.2.tar.bz2
tar -xvf busybox-1.24.2.tar.bz2
cd busybox-1.24.2
make distclean defconfig
sed -i "s/.*CONFIG_STATIC.*/CONFIG_STATIC=y/" .config
make busybox install

# Now we need to create the init process
# this is the first process lunch by the kernel
# this is where the kernel pass execution to
# user space application

# In our case the init process is a simple bash script
cd _install
rm -f linuxrc
mkdir dev proc sys
echo '#!/bin/sh' > init
echo 'dmesg -n 1' >> init
echo 'mount -t devtmpfs none /dev' >> init
echo 'mount -t proc none /proc' >> init
echo 'mount -t sysfs none /sys' >> init
echo 'setsid cttyhack /bin/sh' >> init
chmod +x init

# Now we pack everything and create the initrd
find . | cpio -R root:root -H newc -o | gzip > ../../../initrd
